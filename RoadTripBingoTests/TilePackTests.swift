import XCTest
@testable import RoadTripBingo

final class TilePackTests: XCTestCase {

    // New pack JSON format: tiles are {id, rarity} refs only
    private let farmJSON = """
    {
      "id": "farm-country",
      "name": "Farm Country",
      "description": "Hay bales, open fields, livestock.",
      "imageName": "pack-farm-country",
      "tiles": [
        {"id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", "rarity": "veryCommon"},
        {"id": "4A495FE0-B728-477D-8863-FD00E9140BB6", "rarity": "common"}
      ]
    }
    """

    func test_decode_setsIDAndName() throws {
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(farmJSON.utf8))
        XCTAssertEqual(pack.id, "farm-country")
        XCTAssertEqual(pack.name, "Farm Country")
    }

    func test_decode_parsesTileRefs() throws {
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(farmJSON.utf8))
        XCTAssertEqual(pack.tiles.count, 2)
        XCTAssertEqual(pack.tiles[0].id, "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
        XCTAssertEqual(pack.tiles[0].rarity, .veryCommon)
        XCTAssertEqual(pack.tiles[1].id, "4A495FE0-B728-477D-8863-FD00E9140BB6")
        XCTAssertEqual(pack.tiles[1].rarity, .common)
    }

    func test_decode_emptyPackIsValid() throws {
        let json = """
        {
          "id": "empty",
          "name": "Empty",
          "description": "Nothing.",
          "imageName": "pack-empty",
          "tiles": []
        }
        """
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(json.utf8))
        XCTAssertEqual(pack.id, "empty")
        XCTAssertTrue(pack.tiles.isEmpty)
    }

    func test_decode_setsDescription() throws {
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(farmJSON.utf8))
        XCTAssertEqual(pack.description, "Hay bales, open fields, livestock.")
    }
}
