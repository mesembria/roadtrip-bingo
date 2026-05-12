import Foundation

enum GameEngine {
    static let winLines: [[Int]] = {
        var lines = [[Int]]()
        for row in 0..<5 { lines.append((0..<5).map { row * 5 + $0 }) }
        for col in 0..<5 { lines.append((0..<5).map { $0 * 5 + col }) }
        lines.append([0, 6, 12, 18, 24])
        lines.append([4, 8, 12, 16, 20])
        return lines
    }()

    static func winningLine(for board: BingoBoard) -> [Int]? {
        winLines.first { line in line.allSatisfy { board.isMarked(at: $0) } }
    }

    static func closeCallLines(for board: BingoBoard) -> [[Int]] {
        winLines.filter { line in
            line.filter { board.isMarked(at: $0) }.count == 4
        }
    }

    static func completedLines(for board: BingoBoard) -> [[Int]] {
        winLines.filter { $0.allSatisfy { board.isMarked(at: $0) } }
    }
}
