import XCTest
@testable import RoadTripBingo

final class PowerUpTypeTests: XCTestCase {

    func test_cost_upgradeTileRandom() { XCTAssertEqual(PowerUpType.upgradeTileRandom.cost, 3) }
    func test_cost_upgradeTileTargeted() { XCTAssertEqual(PowerUpType.upgradeTileTargeted.cost, 7) }
    func test_cost_downgradeTileRandom() { XCTAssertEqual(PowerUpType.downgradeTileRandom.cost, 3) }
    func test_cost_downgradeTileTargeted() { XCTAssertEqual(PowerUpType.downgradeTileTargeted.cost, 7) }
    func test_cost_freeMark() { XCTAssertEqual(PowerUpType.freeMark.cost, 5) }
    func test_cost_unmarkOpponentRandom() { XCTAssertEqual(PowerUpType.unmarkOpponentRandom.cost, 4) }
    func test_cost_unmarkOpponentTargeted() { XCTAssertEqual(PowerUpType.unmarkOpponentTargeted.cost, 7) }

    func test_isTargeted_freeMark() { XCTAssertTrue(PowerUpType.freeMark.isTargeted) }
    func test_isTargeted_upgradeTileTargeted() { XCTAssertTrue(PowerUpType.upgradeTileTargeted.isTargeted) }
    func test_isTargeted_upgradeTileRandom() { XCTAssertFalse(PowerUpType.upgradeTileRandom.isTargeted) }

    func test_affectsOpponent_downgradeTileRandom() { XCTAssertTrue(PowerUpType.downgradeTileRandom.affectsOpponent) }
    func test_affectsOpponent_unmarkOpponentTargeted() { XCTAssertTrue(PowerUpType.unmarkOpponentTargeted.affectsOpponent) }
    func test_affectsOpponent_upgradeTileRandom() { XCTAssertFalse(PowerUpType.upgradeTileRandom.affectsOpponent) }
    func test_affectsOpponent_freeMark() { XCTAssertFalse(PowerUpType.freeMark.affectsOpponent) }

    func test_codable_roundtrip() throws {
        for type in PowerUpType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(PowerUpType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }
}
