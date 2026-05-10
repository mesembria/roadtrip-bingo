import XCTest
@testable import RoadTripBingo

final class BingoBoardTests: XCTestCase {

    private func makeBoard() -> BingoBoard {
        let squares = (0..<25).map { i -> BingoSquare in
            if i == 12 { return .free }
            return BingoSquare(id: UUID(), text: "Item \(i)", emoji: "🚗", category: .vehicles)
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
}
