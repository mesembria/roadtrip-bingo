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

    func test_load_semiTruckIsVeryCommon() {
        let semiTruck = SquarePool.load().first { $0.text == "Semi Truck" }
        XCTAssertEqual(semiTruck?.rarity, .veryCommon)
    }

    func test_load_ghostTownIsVeryRare() {
        let ghostTown = SquarePool.load().first { $0.text == "Ghost Town" }
        XCTAssertEqual(ghostTown?.rarity, .veryRare)
    }

    func test_dealBoards_eachBoardHas25Squares() {
        let players = [("A", BoardDifficulty.backseat), ("B", .backseat), ("C", .backseat)]
            .map { (name: $0.0, difficulty: $0.1) }
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        XCTAssertEqual(boards["A"]?.count, 25)
        XCTAssertEqual(boards["B"]?.count, 25)
        XCTAssertEqual(boards["C"]?.count, 25)
    }

    func test_dealBoards_index12IsFree() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        XCTAssertEqual(boards["A"]?[12].id, BingoSquare.freeSquareID)
    }

    func test_dealBoards_noOverlapBetweenPlayers() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let aIDs = Set(boards["A"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        let bIDs = Set(boards["B"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        XCTAssertTrue(aIDs.isDisjoint(with: bIDs))
    }

    func test_dealBoards_backseatBoardHasAtLeast15CommonOrBetterSquares() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let nonFree = boards["A"]!.filter { $0.id != BingoSquare.freeSquareID }
        let easyCount = nonFree.filter { $0.rarity == .veryCommon || $0.rarity == .common }.count
        XCTAssertGreaterThanOrEqual(easyCount, 15,
            "Backseat board should have at least 15 veryCommon+common squares")
    }

    func test_dealBoards_navigatorBoardHasAtLeast8RareOrVeryRareSquares() {
        let players = [(name: "A", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let nonFree = boards["A"]!.filter { $0.id != BingoSquare.freeSquareID }
        let hardCount = nonFree.filter { $0.rarity == .rare || $0.rarity == .veryRare }.count
        XCTAssertGreaterThanOrEqual(hardCount, 8,
            "Navigator board should have at least 8 rare+veryRare squares")
    }

    func test_dealReserve_returnsCorrectCountPerPlayer() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        XCTAssertEqual(reserve["A"]?.count, 6)
        XCTAssertEqual(reserve["B"]?.count, 6)
    }

    func test_dealReserve_noOverlapWithDealtBoards() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.shotgun)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        let reserveIDs = Set(reserve["A"]!.map(\.id))
        XCTAssertTrue(reserveIDs.isDisjoint(with: usedIDs))
    }

    func test_dealReserve_noOverlapBetweenPlayers() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        let aIDs = Set(reserve["A"]!.map(\.id))
        let bIDs = Set(reserve["B"]!.map(\.id))
        XCTAssertTrue(aIDs.isDisjoint(with: bIDs))
    }
}
