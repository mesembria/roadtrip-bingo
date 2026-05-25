import XCTest
@testable import RoadTripBingo

final class TilePackTests: XCTestCase {

    // Minimal valid pack JSON — mirrors the real pack file format
    private let farmJSON = """
    {
      "id": "farm-country",
      "name": "Farm Country",
      "description": "Hay bales, open fields, livestock.",
      "imageName": "pack-farm-country",
      "tiles": [
        {
          "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
          "text": "Combine Harvester",
          "emoji": "🌾",
          "category": "vehicles",
          "rarity": "veryCommon"
        }
      ],
      "rarityOverrides": {
        "4A495FE0-B728-477D-8863-FD00E9140BB6": "veryCommon"
      },
      "excludedTileIDs": [
        "3DE3F367-3105-4F8B-A89D-2F134E21D01D"
      ]
    }
    """

    func test_decode_setsIDAndName() throws {
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(farmJSON.utf8))
        XCTAssertEqual(pack.id, "farm-country")
        XCTAssertEqual(pack.name, "Farm Country")
    }

    func test_decode_parsesExclusiveTiles() throws {
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(farmJSON.utf8))
        XCTAssertEqual(pack.tiles.count, 1)
        XCTAssertEqual(pack.tiles[0].text, "Combine Harvester")
        XCTAssertEqual(pack.tiles[0].rarity, .veryCommon)
    }

    func test_decode_parsesRarityOverrides() throws {
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(farmJSON.utf8))
        XCTAssertEqual(pack.rarityOverrides["4A495FE0-B728-477D-8863-FD00E9140BB6"], .veryCommon)
    }

    func test_decode_parsesExcludedTileIDs() throws {
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(farmJSON.utf8))
        XCTAssertEqual(pack.excludedTileIDs, ["3DE3F367-3105-4F8B-A89D-2F134E21D01D"])
    }

    func test_decode_emptyPackIsValid() throws {
        let json = """
        {
          "id": "empty",
          "name": "Empty",
          "description": "Nothing.",
          "imageName": "pack-empty",
          "tiles": [],
          "rarityOverrides": {},
          "excludedTileIDs": []
        }
        """
        let pack = try JSONDecoder().decode(TilePack.self, from: Data(json.utf8))
        XCTAssertEqual(pack.id, "empty")
        XCTAssertTrue(pack.tiles.isEmpty)
        XCTAssertTrue(pack.rarityOverrides.isEmpty)
        XCTAssertTrue(pack.excludedTileIDs.isEmpty)
    }
}
