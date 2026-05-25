import XCTest
@testable import RoadTripBingo

final class PackManagerTests: XCTestCase {

    func test_loadAll_returnsNonEmptyList() {
        // Requires pack JSON files to be present in the bundle (added in Task 4).
        // This test will fail until Task 4 is complete — that's expected.
        let packs = PackManager.loadAll()
        XCTAssertFalse(packs.isEmpty, "At least one pack-*.json must be bundled")
    }

    func test_loadAll_allPacksHaveNonEmptyID() {
        let packs = PackManager.loadAll()
        for pack in packs {
            XCTAssertFalse(pack.id.isEmpty, "Pack id must not be empty: \(pack.name)")
        }
    }

    func test_loadAll_isSortedByName() {
        let packs = PackManager.loadAll()
        let names = packs.map(\.name)
        XCTAssertEqual(names, names.sorted(), "loadAll should return packs sorted by name")
    }

    func test_pack_returnsCorrectPackByID() {
        // Only meaningful after Task 4 adds real pack files.
        guard let farm = PackManager.pack(id: "farm-country") else {
            XCTSkip("farm-country pack not yet bundled — will pass after Task 4")
        }
        XCTAssertEqual(farm.name, "Farm Country")
    }

    func test_pack_returnsNilForUnknownID() {
        XCTAssertNil(PackManager.pack(id: "does-not-exist"))
    }
}
