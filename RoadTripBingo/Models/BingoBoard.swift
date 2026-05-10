import Foundation

// Stub — full implementation in Phase 2 (Task 7)
struct BingoBoard {
    let squares: [BingoSquare]
    var marked: Set<UUID>

    init(squares: [BingoSquare]) {
        self.squares = squares
        self.marked = [BingoSquare.freeSquareID]
    }

    mutating func toggle(at position: Int) {}
    func isMarked(at position: Int) -> Bool { false }
}
