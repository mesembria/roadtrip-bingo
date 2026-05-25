import Foundation

enum SquarePool {
    static func load() -> [BingoSquare] {
        guard let url = Bundle.main.url(forResource: "squares", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let squares = try? JSONDecoder().decode([BingoSquare].self, from: data)
        else { fatalError("squares.json missing from bundle or malformed") }
        return squares
    }

    // Each player's 24 non-FREE squares are sampled from per-rarity buckets weighted by difficulty.
    // Non-overlap between players is best-effort; overlaps may occur when a rarity bucket runs thin.
    static func dealBoards(
        for players: [(name: String, difficulty: BoardDifficulty)],
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        precondition(pool.count >= players.count * 24)
        var queues = makeQueues(from: pool)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            result[player.name] = drawBoard(for: player.difficulty, from: &queues)
        }
        return result
    }

    // Returns `count` extra squares per player, drawn from pool minus usedIDs.
    // Used to deal each player's power-up reserve hand at game start.
    static func dealReserve(
        for players: [(name: String, difficulty: BoardDifficulty)],
        count: Int,
        excluding usedIDs: Set<UUID>,
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        let available = pool.filter { !usedIDs.contains($0.id) }
        assert(available.count >= players.count * count,
               "Reserve pool too thin: need \(players.count * count) squares, got \(available.count)")
        var queues = makeQueues(from: available)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            result[player.name] = drawBoard(for: player.difficulty, from: &queues, total: count)
        }
        return result
    }

    // Returns the rarity weight distribution for a player at the given handicap level.
    // Each level shifts 4% weight from rare/veryRare toward veryCommon/common.
    // When a source bucket is depleted the deficit cascades to the next-hardest bucket.
    // Level is clamped to 3; weights always sum to 1.0.
    static func adjustedWeights(for difficulty: BoardDifficulty,
                                handicapLevel: Int) -> [SquareRarity: Double] {
        let level = min(handicapLevel, 3)
        guard level > 0 else { return difficulty.weights }

        var w = difficulty.weights
        let delta = 0.04

        for _ in 0..<level {
            // Reduce rare; cascade deficit to uncommon if rare is depleted.
            let rareTaken = min(delta, w[.rare, default: 0])
            w[.rare, default: 0] -= rareTaken
            let rareDeficit = delta - rareTaken
            if rareDeficit > 0 {
                let uncommonTaken = min(rareDeficit, w[.uncommon, default: 0])
                w[.uncommon, default: 0] -= uncommonTaken
            }

            // Reduce veryRare; cascade deficit to uncommon if veryRare is depleted.
            let veryRareTaken = min(delta, w[.veryRare, default: 0])
            w[.veryRare, default: 0] -= veryRareTaken
            let veryRareDeficit = delta - veryRareTaken
            if veryRareDeficit > 0 {
                let uncommonTaken = min(veryRareDeficit, w[.uncommon, default: 0])
                w[.uncommon, default: 0] -= uncommonTaken
            }

            w[.veryCommon, default: 0] += delta
            w[.common, default: 0] += delta
        }

        // Renormalise to guard against floating-point drift.
        let total = w.values.reduce(0, +)
        if total > 0 {
            for rarity in SquareRarity.allCases {
                w[rarity, default: 0] /= total
            }
        }
        return w
    }

    // MARK: - Private helpers

    private static func makeQueues(from pool: [BingoSquare]) -> [SquareRarity: [BingoSquare]] {
        var queues: [SquareRarity: [BingoSquare]] = [:]
        for rarity in SquareRarity.allCases {
            queues[rarity] = pool.filter { $0.rarity == rarity }.shuffled()
        }
        return queues
    }

    private static func drawBoard(
        for difficulty: BoardDifficulty,
        from queues: inout [SquareRarity: [BingoSquare]],
        total: Int = 24
    ) -> [BingoSquare] {
        let targets = targetCounts(for: difficulty, total: total)
        var squares: [BingoSquare] = []
        for rarity in SquareRarity.allCases {
            squares += draw(targets[rarity, default: 0], from: &queues[rarity]!)
        }
        if squares.count < total {
            var spill = SquareRarity.allCases.flatMap { queues[$0]! }.shuffled()
            let extra = draw(total - squares.count, from: &spill)
            let extraIDs = Set(extra.map(\.id))
            for rarity in SquareRarity.allCases {
                queues[rarity]!.removeAll { extraIDs.contains($0.id) }
            }
            squares += extra
        }
        if total == 24 {
            squares.shuffle()
            squares.insert(.free, at: 12)
        } else {
            squares.shuffle()
        }
        return squares
    }

    private static func draw(_ count: Int, from bucket: inout [BingoSquare]) -> [BingoSquare] {
        let actual = min(count, bucket.count)
        let drawn = Array(bucket.prefix(actual))
        bucket.removeFirst(actual)
        return drawn
    }

    private static func targetCounts(for difficulty: BoardDifficulty, total: Int = 24) -> [SquareRarity: Int] {
        let tiers = SquareRarity.allCases
        var counts: [SquareRarity: Int] = [:]
        var running = 0
        for (i, rarity) in tiers.enumerated() {
            if i == tiers.count - 1 {
                counts[rarity] = max(0, total - running)
                break
            }
            let n = Int((Double(total) * difficulty.weights[rarity, default: 0]).rounded())
            counts[rarity] = n
            running += n
        }
        return counts
    }
}
