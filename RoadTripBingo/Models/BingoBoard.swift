import Foundation

struct BingoBoard {
    // 25 squares row-major. Index 12 must always be BingoSquare.free.
    var squares: [BingoSquare]   // var (was let) to support tile replacement
    var marked: Set<UUID>
    var freeMarked: Set<UUID>    // subset of `marked`; tiles marked via the freeMark power-up

    init(squares: [BingoSquare]) {
        precondition(squares.count == 25, "Board must have exactly 25 squares")
        precondition(squares[12].id == BingoSquare.freeSquareID, "Index 12 must be the FREE square")
        self.squares = squares
        self.marked = [BingoSquare.freeSquareID]
        self.freeMarked = []
    }

    mutating func toggle(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
    }

    // Force-marks a square without toggling. No-op on the FREE square.
    mutating func mark(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.insert(id)
    }

    // Force-marks a square as a free pick (via the freeMark power-up).
    // Inserts into both `marked` and `freeMarked`. No-op on the FREE square.
    mutating func markFree(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.insert(id)
        freeMarked.insert(id)
    }

    // Force-unmarks a square. No-op on the FREE square.
    mutating func unmark(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.remove(id)
        freeMarked.remove(id)
    }

    // Replaces the tile at position with newSquare, clearing its old mark.
    // No-op if position is 12 (the FREE square must not be replaced).
    mutating func replaceSquare(at position: Int, with newSquare: BingoSquare) {
        guard (0..<25).contains(position), position != 12 else { return }
        let oldID = squares[position].id
        marked.remove(oldID)
        freeMarked.remove(oldID)
        squares[position] = newSquare
    }

    func isMarked(at position: Int) -> Bool {
        marked.contains(squares[position].id)
    }

    mutating func shuffleUnmarkedPositions() {
        let unmarkedIndices = (0..<25).filter { $0 != 12 && !isMarked(at: $0) }
        let shuffledTiles = unmarkedIndices.map { squares[$0] }.shuffled()
        for (i, idx) in unmarkedIndices.enumerated() {
            squares[idx] = shuffledTiles[i]
        }
    }
}
