import Foundation

struct BingoBoard {
    // 25 squares row-major. Index 12 must always be BingoSquare.free.
    let squares: [BingoSquare]
    var marked: Set<UUID>

    init(squares: [BingoSquare]) {
        precondition(squares.count == 25, "Board must have exactly 25 squares")
        precondition(squares[12].id == BingoSquare.freeSquareID, "Index 12 must be the FREE square")
        self.squares = squares
        self.marked = [BingoSquare.freeSquareID]
    }

    mutating func toggle(at position: Int) {
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
    }

    func isMarked(at position: Int) -> Bool {
        marked.contains(squares[position].id)
    }
}
