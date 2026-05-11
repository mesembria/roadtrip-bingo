import XCTest
@testable import RoadTripBingo

final class SquarePoolTests: XCTestCase {

    func test_load_returnsAtLeast150Squares() {
        XCTAssertGreaterThanOrEqual(SquarePool.load().count, 150)
    }

    func test_load_allIDsUnique() {
        let pool = SquarePool.load()
        XCTAssertEqual(pool.map(\.id).count, Set(pool.map(\.id)).count)
    }

    func test_load_noFreeSquareInPool() {
        XCTAssertFalse(SquarePool.load().contains { $0.id == BingoSquare.freeSquareID })
    }

    func test_dealBoards_eachBoardHas25Squares() {
        let boards = SquarePool.dealBoards(for: ["A","B","C"], from: SquarePool.load())
        XCTAssertEqual(boards["A"]?.count, 25)
        XCTAssertEqual(boards["B"]?.count, 25)
        XCTAssertEqual(boards["C"]?.count, 25)
    }

    func test_dealBoards_index12IsFree() {
        let boards = SquarePool.dealBoards(for: ["A"], from: SquarePool.load())
        XCTAssertEqual(boards["A"]?[12].id, BingoSquare.freeSquareID)
    }

    func test_dealBoards_noOverlapBetweenPlayers() {
        let boards = SquarePool.dealBoards(for: ["A","B"], from: SquarePool.load())
        let aIDs = Set(boards["A"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        let bIDs = Set(boards["B"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        XCTAssertTrue(aIDs.isDisjoint(with: bIDs))
    }
}
