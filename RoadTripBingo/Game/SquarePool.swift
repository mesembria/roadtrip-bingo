import Foundation

enum SquarePool {
    static func load() -> [BingoSquare] {
        guard let url = Bundle.main.url(forResource: "squares", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let squares = try? JSONDecoder().decode([BingoSquare].self, from: data)
        else { fatalError("squares.json missing from bundle or malformed") }
        return squares
    }

    // Returns one 25-element array per player name (index 12 = FREE).
    // Each player's 24 non-FREE squares are non-overlapping slices of the shuffled pool.
    // Precondition: pool.count >= playerNames.count * 24
    static func dealBoards(for playerNames: [String], from pool: [BingoSquare]) -> [String: [BingoSquare]] {
        precondition(pool.count >= playerNames.count * 24)
        var remaining = pool.shuffled()
        var result: [String: [BingoSquare]] = [:]
        for name in playerNames {
            var squares = Array(remaining.prefix(24))
            remaining.removeFirst(24)
            squares.insert(.free, at: 12)
            result[name] = squares
        }
        return result
    }
}
