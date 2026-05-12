import XCTest
@testable import RoadTripBingo

final class GameEngineTests: XCTestCase {

    private func makeBoard(marking positions: Set<Int> = []) -> BingoBoard {
        let squares = (0..<25).map { i -> BingoSquare in
            if i == 12 { return .free }
            return BingoSquare(id: UUID(), text: "Item \(i)", emoji: "🔵", category: .vehicles, rarity: .common)
        }
        var board = BingoBoard(squares: squares)
        for pos in positions where pos != 12 { board.toggle(at: pos) }
        return board
    }

    func test_noWin_onFreshBoard() {
        XCTAssertNil(GameEngine.winningLine(for: makeBoard()))
    }

    func test_win_firstRow() {
        XCTAssertEqual(GameEngine.winningLine(for: makeBoard(marking: [0,1,2,3,4])), [0,1,2,3,4])
    }

    func test_win_lastRow() {
        XCTAssertEqual(GameEngine.winningLine(for: makeBoard(marking: [20,21,22,23,24])), [20,21,22,23,24])
    }

    func test_win_firstColumn() {
        XCTAssertEqual(GameEngine.winningLine(for: makeBoard(marking: [0,5,10,15,20])), [0,5,10,15,20])
    }

    func test_win_lastColumn() {
        XCTAssertEqual(GameEngine.winningLine(for: makeBoard(marking: [4,9,14,19,24])), [4,9,14,19,24])
    }

    func test_win_mainDiagonal() {
        // Index 12 (FREE) is pre-marked; only need 0,6,18,24
        XCTAssertEqual(GameEngine.winningLine(for: makeBoard(marking: [0,6,18,24])), [0,6,12,18,24])
    }

    func test_win_antiDiagonal() {
        // Index 12 (FREE) is pre-marked; only need 4,8,16,20
        XCTAssertEqual(GameEngine.winningLine(for: makeBoard(marking: [4,8,16,20])), [4,8,12,16,20])
    }

    func test_noWin_fourInRow() {
        XCTAssertNil(GameEngine.winningLine(for: makeBoard(marking: [0,1,2,3])))
    }

    func test_winLines_has12Lines() {
        XCTAssertEqual(GameEngine.winLines.count, 12)
    }

    // MARK: - closeCallLines

    func test_closeCallLines_emptyBoardReturnsNone() {
        let board = makeBoard()
        XCTAssertTrue(GameEngine.closeCallLines(for: board).isEmpty)
    }

    func test_closeCallLines_detectsFourInARow() {
        var board = makeBoard()
        // Mark row 0 positions 0–3 (not 4)
        for i in [0, 1, 2, 3] { board.toggle(at: i) }
        let lines = GameEngine.closeCallLines(for: board)
        XCTAssertTrue(lines.contains([0, 1, 2, 3, 4]))
    }

    func test_closeCallLines_excludesCompleteLines() {
        var board = makeBoard()
        for i in 0..<5 { board.toggle(at: i) }    // complete row 0
        let lines = GameEngine.closeCallLines(for: board)
        XCTAssertFalse(lines.contains([0, 1, 2, 3, 4]))
    }

    // MARK: - completedLines

    func test_completedLines_emptyBoardReturnsNone() {
        let board = makeBoard()
        XCTAssertTrue(GameEngine.completedLines(for: board).isEmpty)
    }

    func test_completedLines_returnsAllCompleteLines() {
        var board = makeBoard()
        for i in 0..<5 { board.toggle(at: i) }       // complete row 0
        for i in [0, 5, 10, 15, 20] { board.toggle(at: i) }  // complete col 0 (pos 0 already marked)
        let lines = GameEngine.completedLines(for: board)
        XCTAssertEqual(lines.count, 2)
    }
}
