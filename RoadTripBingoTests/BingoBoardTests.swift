import XCTest
@testable import RoadTripBingo

final class BingoBoardTests: XCTestCase {

    private func makeBoard() -> BingoBoard {
        let squares = (0..<25).map { i -> BingoSquare in
            if i == 12 { return .free }
            return BingoSquare(id: UUID(), text: "Item \(i)", emoji: "🚗", category: .vehicles, rarity: .common)
        }
        return BingoBoard(squares: squares)
    }

    func test_freeSquare_isAtIndex12() {
        let board = makeBoard()
        XCTAssertEqual(board.squares[12].id, BingoSquare.freeSquareID)
    }

    func test_freeSquare_isPreMarked() {
        let board = makeBoard()
        XCTAssertTrue(board.isMarked(at: 12))
    }

    func test_toggle_marksUnmarkedSquare() {
        var board = makeBoard()
        XCTAssertFalse(board.isMarked(at: 0))
        board.toggle(at: 0)
        XCTAssertTrue(board.isMarked(at: 0))
    }

    func test_toggle_unmarksMarkedSquare() {
        var board = makeBoard()
        board.toggle(at: 0)
        board.toggle(at: 0)
        XCTAssertFalse(board.isMarked(at: 0))
    }

    func test_toggle_doesNotUnmarkFreeSquare() {
        var board = makeBoard()
        board.toggle(at: 12)
        XCTAssertTrue(board.isMarked(at: 12))
    }

    // MARK: - mark / unmark

    func test_mark_marksTile() {
        var board = makeBoard()
        board.mark(at: 0)
        XCTAssertTrue(board.isMarked(at: 0))
    }

    func test_mark_isIdempotent() {
        var board = makeBoard()
        board.mark(at: 0)
        board.mark(at: 0)
        XCTAssertTrue(board.isMarked(at: 0))
    }

    func test_mark_ignoresFreeSquare() {
        var board = makeBoard()
        board.mark(at: 12)
        XCTAssertTrue(board.isMarked(at: 12))
    }

    func test_unmark_unmarksTile() {
        var board = makeBoard()
        board.toggle(at: 0)
        board.unmark(at: 0)
        XCTAssertFalse(board.isMarked(at: 0))
    }

    func test_unmark_ignoresFreeSquare() {
        var board = makeBoard()
        board.unmark(at: 12)
        XCTAssertTrue(board.isMarked(at: 12))
    }

    // MARK: - replaceSquare

    func test_replaceSquare_changesContent() {
        var board = makeBoard()
        let newSquare = BingoSquare(id: UUID(), text: "New", emoji: "⭐", category: .vehicles, rarity: .rare)
        board.replaceSquare(at: 0, with: newSquare)
        XCTAssertEqual(board.squares[0].text, "New")
    }

    func test_replaceSquare_unmarksOldTile() {
        var board = makeBoard()
        board.toggle(at: 0)
        XCTAssertTrue(board.isMarked(at: 0))
        let newSquare = BingoSquare(id: UUID(), text: "New", emoji: "⭐", category: .vehicles, rarity: .rare)
        board.replaceSquare(at: 0, with: newSquare)
        XCTAssertFalse(board.isMarked(at: 0))
    }

    func test_replaceSquare_doesNotAffectFreeSquare() {
        var board = makeBoard()
        let oldID = board.squares[12].id
        let newSquare = BingoSquare(id: UUID(), text: "Not Free", emoji: "❌", category: .vehicles, rarity: .common)
        board.replaceSquare(at: 12, with: newSquare)
        XCTAssertEqual(board.squares[12].id, oldID)
    }
}
