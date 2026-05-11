import Foundation

enum SquarePool {
    static func load() -> [BingoSquare] {
        guard let url = Bundle.main.url(forResource: "squares", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let squares = try? JSONDecoder().decode([BingoSquare].self, from: data)
        else { fatalError("squares.json missing from bundle or malformed") }
        return squares
    }

    // Returns one 25-element array per player (index 12 = FREE).
    // Each player's 24 non-FREE squares are sampled from per-rarity buckets weighted by difficulty.
    // Non-overlap between players is best-effort; overlaps may occur when a rarity bucket runs thin.
    // Precondition: pool.count >= players.count * 24
    static func dealBoards(
        for players: [(name: String, difficulty: BoardDifficulty)],
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        precondition(pool.count >= players.count * 24)

        // Build per-rarity shuffled queues; players draw from the front.
        var queues: [SquareRarity: [BingoSquare]] = [:]
        for rarity in SquareRarity.allCases {
            queues[rarity] = pool.filter { $0.rarity == rarity }.shuffled()
        }

        var result: [String: [BingoSquare]] = [:]

        for player in players {
            let targets = targetCounts(for: player.difficulty)
            var squares: [BingoSquare] = []

            for rarity in SquareRarity.allCases {
                squares += draw(targets[rarity, default: 0], from: &queues[rarity]!)
            }

            // Thin-bucket fallback: fill any shortage from the combined remainder.
            if squares.count < 24 {
                var spill = SquareRarity.allCases.flatMap { queues[$0]! }.shuffled()
                let extra = draw(24 - squares.count, from: &spill)
                let extraIDs = Set(extra.map(\.id))
                for rarity in SquareRarity.allCases {
                    queues[rarity]!.removeAll { extraIDs.contains($0.id) }
                }
                squares += extra
            }

            squares.shuffle()
            squares.insert(.free, at: 12)
            result[player.name] = squares
        }

        return result
    }

    // MARK: - Private helpers

    private static func draw(_ count: Int, from bucket: inout [BingoSquare]) -> [BingoSquare] {
        let actual = min(count, bucket.count)
        let drawn = Array(bucket.prefix(actual))
        bucket.removeFirst(actual)
        return drawn
    }

    // Returns target square count per rarity tier summing to exactly 24.
    private static func targetCounts(for difficulty: BoardDifficulty) -> [SquareRarity: Int] {
        let tiers = SquareRarity.allCases
        var counts: [SquareRarity: Int] = [:]
        var running = 0
        for (i, rarity) in tiers.enumerated() {
            if i == tiers.count - 1 {
                counts[rarity] = 24 - running
                break
            }
            let n = Int((24.0 * difficulty.weights[rarity, default: 0]).rounded())
            counts[rarity] = n
            running += n
        }
        return counts
    }
}
