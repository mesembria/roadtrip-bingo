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

    func test_closeCallLines_detectsFourInDiagonal() {
        var board = makeBoard()
        // Main diagonal [0,6,12,18,24]: pos 12 is FREE (pre-marked). Mark 3 more.
        for i in [0, 6, 18] { board.toggle(at: i) }
        let lines = GameEngine.closeCallLines(for: board)
        XCTAssertTrue(lines.contains([0, 6, 12, 18, 24]))
    }

    // MARK: - completedLines

    func test_completedLines_emptyBoardReturnsNone() {
        let board = makeBoard()
        XCTAssertTrue(GameEngine.completedLines(for: board).isEmpty)
    }

    func test_completedLines_returnsAllCompleteLines() {
        var board = makeBoard()
        for i in 0..<5 { board.toggle(at: i) }           // complete row 0
        for i in [5, 10, 15, 20] { board.toggle(at: i) } // complete col 0 (pos 0 already marked)
        let lines = GameEngine.completedLines(for: board)
        XCTAssertEqual(lines.count, 2)
    }

    // MARK: - hotStreakLine

    func test_hotStreakLine_freshBoardReturnsNil() {
        XCTAssertNil(GameEngine.hotStreakLine(for: makeBoard()))
    }

    func test_hotStreakLine_two_markedReturnsNil() {
        XCTAssertNil(GameEngine.hotStreakLine(for: makeBoard(marking: [0, 1])))
    }

    func test_hotStreakLine_three_inRow_returnsLine() {
        let line = GameEngine.hotStreakLine(for: makeBoard(marking: [0, 1, 2]))
        XCTAssertEqual(line, [0, 1, 2, 3, 4])
    }

    func test_hotStreakLine_three_inCol_returnsLine() {
        let line = GameEngine.hotStreakLine(for: makeBoard(marking: [0, 5, 10]))
        XCTAssertEqual(line, [0, 5, 10, 15, 20])
    }

    func test_hotStreakLine_three_inDiagonal_withFree_returnsLine() {
        // Main diagonal [0,6,12,18,24]: 12 is FREE (pre-marked). Mark 2 more → 3 total.
        let line = GameEngine.hotStreakLine(for: makeBoard(marking: [0, 6]))
        XCTAssertEqual(line, [0, 6, 12, 18, 24])
    }

    // MARK: - patternLine

    func test_patternLine_fourCorners_allMarked_returnsPositions() {
        let board = makeBoard(marking: [0, 4, 20, 24])
        let line = GameEngine.patternLine(for: board, shape: .fourCorners)
        XCTAssertEqual(line?.sorted(), [0, 4, 20, 24])
    }

    func test_patternLine_fourCorners_threeMarked_returnsNil() {
        XCTAssertNil(GameEngine.patternLine(for: makeBoard(marking: [0, 4, 20]), shape: .fourCorners))
    }

    func test_patternLine_x_allMarked_returnsPositions() {
        // X = [0,4,6,8,12,16,18,20,24]. 12 is FREE. Mark remaining 8.
        let board = makeBoard(marking: [0, 4, 6, 8, 16, 18, 20, 24])
        let line = GameEngine.patternLine(for: board, shape: .x)
        XCTAssertEqual(line?.sorted(), [0, 4, 6, 8, 12, 16, 18, 20, 24])
    }

    func test_patternLine_plus_allMarked_returnsPositions() {
        // Plus = [2,7,10,11,12,13,14,17,22]. 12 is FREE. Mark remaining 8.
        let board = makeBoard(marking: [2, 7, 10, 11, 13, 14, 17, 22])
        let line = GameEngine.patternLine(for: board, shape: .plus)
        XCTAssertEqual(line?.sorted(), [2, 7, 10, 11, 12, 13, 14, 17, 22])
    }
}
