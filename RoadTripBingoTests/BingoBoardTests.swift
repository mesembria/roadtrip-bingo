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

    // MARK: - shuffleUnmarkedPositions

    func test_shuffleUnmarkedPositions_preservesMarkedTileIDs() {
        var board = BingoBoard(squares: (0..<25).map { i in
            i == 12 ? .free : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                                           category: .nature, rarity: .common)
        })
        board.toggle(at: 0)
        board.toggle(at: 1)
        let markedBefore = board.marked

        board.shuffleUnmarkedPositions()

        XCTAssertEqual(board.marked, markedBefore, "Marked UUID set must be unchanged after shuffle")
        XCTAssertEqual(board.squares.count, 25)
        XCTAssertEqual(board.squares[12].id, BingoSquare.freeSquareID)
    }

    func test_shuffleUnmarkedPositions_keepsMarkedTilesAtOriginalPositions() {
        let tile0 = BingoSquare(id: UUID(), text: "Tile 0", emoji: "x", category: .nature, rarity: .common)
        let squares: [BingoSquare] = (0..<25).map { i in
            i == 0  ? tile0 :
            i == 12 ? .free :
            BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x", category: .nature, rarity: .common)
        }
        var board = BingoBoard(squares: squares)
        board.toggle(at: 0)  // mark tile at position 0

        board.shuffleUnmarkedPositions()

        XCTAssertEqual(board.squares[0].id, tile0.id, "Marked tile must stay at its position")
    }
}
