import XCTest
@testable import RoadTripBingo

final class RoundModifierTests: XCTestCase {

    func test_roundModifier_codable_roundtrip() throws {
        let modifiers: [RoundModifier] = [
            .hotStreak, .doubleDown, .noPowers, .sniper,
            .fogOfWar, .shiftingTiles, .shuffleBoard,
            .patternWin(.x), .patternWin(.fourCorners), .patternWin(.plus)
        ]
        for modifier in modifiers {
            let data = try JSONEncoder().encode(modifier)
            let decoded = try JSONDecoder().decode(RoundModifier.self, from: data)
            XCTAssertEqual(decoded, modifier, "Failed roundtrip for \(modifier)")
        }
    }

    func test_roundModifier_random_returnsValidModifier() {
        for _ in 0..<20 {
            let m = RoundModifier.random()
            XCTAssertNotNil(m)
        }
    }

    func test_patternShape_x_positions() {
        XCTAssertEqual(PatternShape.x.positions.sorted(), [0, 4, 6, 8, 12, 16, 18, 20, 24])
    }

    func test_patternShape_fourCorners_positions() {
        XCTAssertEqual(PatternShape.fourCorners.positions.sorted(), [0, 4, 20, 24])
    }

    func test_patternShape_plus_positions() {
        XCTAssertEqual(PatternShape.plus.positions.sorted(), [2, 7, 10, 11, 12, 13, 14, 17, 22])
    }
}
