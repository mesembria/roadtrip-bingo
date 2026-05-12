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
        var queues = makeQueues(from: available)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            result[player.name] = drawBoard(for: player.difficulty, from: &queues, total: count)
        }
        return result
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
                counts[rarity] = total - running
                break
            }
            let n = Int((Double(total) * difficulty.weights[rarity, default: 0]).rounded())
            counts[rarity] = n
            running += n
        }
        return counts
    }
}
