import XCTest
@testable import RoadTripBingo

final class BingoSquareTests: XCTestCase {

    func test_decode_squareWithoutEmoji_hasNilEmoji() throws {
        let json = """
        {"id":"1686B2E7-ED35-44B1-95F2-31353A7F2039","text":"Large Plane","category":"vehicles","rarity":"common"}
        """.data(using: .utf8)!
        let square = try JSONDecoder().decode(BingoSquare.self, from: json)
        XCTAssertNil(square.emoji)
    }

    func test_decode_squareWithEmoji_hasEmoji() throws {
        let json = """
        {"id":"B23F16C4-D19A-4D6C-A61A-3D6A65E86DE1","text":"Deer","emoji":"🦌","category":"nature","rarity":"common"}
        """.data(using: .utf8)!
        let square = try JSONDecoder().decode(BingoSquare.self, from: json)
        XCTAssertEqual(square.emoji, "🦌")
    }

    func test_load_largePlane_hasNilEmoji() {
        let largePlane = SquarePool.load().first { $0.text == "Large Plane" }
        XCTAssertNotNil(largePlane)
        XCTAssertNil(largePlane?.emoji)
    }

    func test_load_billboardIsInSignsCategory() {
        let billboard = SquarePool.load().first { $0.text == "Billboard" }
        XCTAssertNotNil(billboard, "Billboard must exist in the pool")
        XCTAssertEqual(billboard?.category, .signs,
                       "Billboard was miscategorised as food; it must be in signs")
    }

    func test_load_licensePlateFromAnotherStateExists() {
        let tile = SquarePool.load().first { $0.text == "License Plate from Another State" }
        XCTAssertNotNil(tile, "License Plate from Another State must be in the pool")
        XCTAssertEqual(tile?.rarity, .veryCommon)
        XCTAssertEqual(tile?.category, .vehicles)
    }
}
