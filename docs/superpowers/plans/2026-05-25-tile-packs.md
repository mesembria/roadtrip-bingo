# Tile Packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add location-aware tile packs that players select before a session; each pack adds exclusive tiles, overrides base tile rarities, and optionally excludes base tiles that don't fit the setting.

**Architecture:** A new `TilePack` model is loaded from `pack-*.json` bundle files by `PackManager`. `SquarePool.buildPool(base:activePacks:)` combines the base pool with active packs (exclusions, most-common-wins rarity overrides, exclusive tiles). `AppState` persists active pack IDs, applies the pack-aware pool at round start, and broadcasts pack IDs to peers via `MultipeerMessage`. A new `TilePacksView` sheet (grid + rarity bar) is accessible from `HomeView` and `PlayAgainView`.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, xcodegen, `Bundle.main.urls(forResourcesWithExtension:subdirectory:)`

---

## File Map

| File | Status | Purpose |
|---|---|---|
| `RoadTripBingo/Models/TilePack.swift` | Create | `TilePack` struct — Codable model for a pack |
| `RoadTripBingo/Game/PackManager.swift` | Create | Loads all `pack-*.json` from bundle |
| `RoadTripBingo/Game/SquarePool.swift` | Modify | Add `buildPool(base:activePacks:)` and `mostCommon(_:_:)` |
| `RoadTripBingo/Resources/pack-interstate.json` | Create | Interstate pack data |
| `RoadTripBingo/Resources/pack-city.json` | Create | City pack data |
| `RoadTripBingo/Resources/pack-farm-country.json` | Create | Farm Country pack data |
| `RoadTripBingo/Resources/pack-mountains.json` | Create | Mountains pack data |
| `RoadTripBingo/Resources/pack-beach-coast.json` | Create | Beach & Coast pack data |
| `RoadTripBingo/Resources/pack-desert-southwest.json` | Create | Desert Southwest pack data |
| `RoadTripBingo/State/AppState.swift` | Modify | `activePackIDs` published + persisted, `togglePack`, updated `dealAndLaunchRound` |
| `RoadTripBingo/Models/MultipeerMessage.swift` | Modify | Add `activePackIDs` to `gameStarted` and `playAgain` cases |
| `RoadTripBingo/Views/TilePacksView.swift` | Create | Pack selection sheet — grid + rarity bar + pool indicator |
| `RoadTripBingo/Views/HomeView.swift` | Modify | Add "Tile Packs" tertiary button |
| `RoadTripBingo/Views/PlayAgainView.swift` | Modify | Add "Change Packs" button (host only) |
| `RoadTripBingoTests/TilePackTests.swift` | Create | TilePack model encode/decode tests |
| `RoadTripBingoTests/PackManagerTests.swift` | Create | PackManager.loadAll tests |
| `RoadTripBingoTests/SquarePoolTests.swift` | Modify | Add buildPool tests |

---

## Task 1: TilePack Model

**Files:**
- Create: `RoadTripBingo/Models/TilePack.swift`
- Create: `RoadTripBingoTests/TilePackTests.swift`

- [ ] **Step 1.1: Write failing tests**

Create `RoadTripBingoTests/TilePackTests.swift`:

```swift
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
```

- [ ] **Step 1.2: Run tests — expect compile failure**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|FAILED" | head -20
```

Expected: compile error — `TilePack` not defined.

- [ ] **Step 1.3: Create the model**

Create `RoadTripBingo/Models/TilePack.swift`:

```swift
import Foundation

struct TilePack: Codable, Identifiable {
    /// Stable string ID matching the JSON filename suffix (e.g. "farm-country").
    let id: String
    /// Display name shown in the pack selection grid.
    let name: String
    /// Short flavor text shown below the pack name.
    let description: String
    /// Asset catalog image name for the AI-generated pack card image.
    let imageName: String
    /// Pack-exclusive tiles — only appear when this pack is active.
    let tiles: [BingoSquare]
    /// Base tile UUID string → new rarity. Applied via most-common-wins when multiple packs are active.
    let rarityOverrides: [String: SquareRarity]
    /// Base tile UUID strings to remove when this pack is active.
    let excludedTileIDs: [String]
}
```

- [ ] **Step 1.4: Regenerate Xcode project and run tests**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodegen generate 2>&1 | tail -5
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "TilePackTests|PASSED|FAILED|error:" | head -20
```

Expected: all 5 `TilePackTests` pass.

- [ ] **Step 1.5: Commit**

```bash
git add RoadTripBingo/Models/TilePack.swift RoadTripBingoTests/TilePackTests.swift
git commit -m "feat: add TilePack model with Codable support"
```

---

## Task 2: PackManager

**Files:**
- Create: `RoadTripBingo/Game/PackManager.swift`
- Create: `RoadTripBingoTests/PackManagerTests.swift`

- [ ] **Step 2.1: Write failing tests**

Create `RoadTripBingoTests/PackManagerTests.swift`:

```swift
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
```

- [ ] **Step 2.2: Run tests — expect compile failure**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|FAILED" | head -20
```

Expected: compile error — `PackManager` not defined.

- [ ] **Step 2.3: Create PackManager**

Create `RoadTripBingo/Game/PackManager.swift`:

```swift
import Foundation

enum PackManager {
    /// Loads all `pack-*.json` files from the main bundle, sorted by pack name.
    /// Returns an empty array if none are found or all fail to decode.
    static func loadAll() -> [TilePack] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json",
                                          subdirectory: nil) else { return [] }
        return urls
            .filter { $0.lastPathComponent.hasPrefix("pack-") }
            .compactMap { url -> TilePack? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(TilePack.self, from: data)
            }
            .sorted { $0.name < $1.name }
    }

    /// Returns the pack with the given ID, or nil if not found.
    static func pack(id: String) -> TilePack? {
        loadAll().first { $0.id == id }
    }

    /// Returns all packs whose IDs are in the given list, preserving sort order.
    static func packs(forIDs ids: [String]) -> [TilePack] {
        let all = loadAll()
        return ids.compactMap { id in all.first { $0.id == id } }
    }
}
```

- [ ] **Step 2.4: Regenerate project and run tests**

```bash
xcodegen generate 2>&1 | tail -5
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "PackManagerTests|PASSED|FAILED|error:" | head -20
```

Expected: `test_loadAll_returnsNonEmptyList` and `test_pack_returnsCorrectPackByID` skip or fail (no pack JSONs yet). `test_pack_returnsNilForUnknownID` passes. No compile errors.

- [ ] **Step 2.5: Commit**

```bash
git add RoadTripBingo/Game/PackManager.swift RoadTripBingoTests/PackManagerTests.swift
git commit -m "feat: add PackManager — loads pack-*.json files from bundle"
```

---

## Task 3: SquarePool.buildPool

**Files:**
- Modify: `RoadTripBingo/Game/SquarePool.swift`
- Modify: `RoadTripBingoTests/SquarePoolTests.swift`

- [ ] **Step 3.1: Write failing tests**

Append to `RoadTripBingoTests/SquarePoolTests.swift` (add inside the `final class SquarePoolTests` braces):

```swift
    // MARK: - buildPool

    // Helper: make a minimal BingoSquare for tests
    private func square(_ id: String, rarity: SquareRarity, text: String = "Test") -> BingoSquare {
        BingoSquare(id: UUID(uuidString: id)!, text: text, emoji: nil,
                    category: .vehicles, rarity: rarity)
    }

    // Helper: make a TilePack with explicit overrides, exclusions, and exclusive tiles
    private func pack(id: String = "test", overrides: [String: SquareRarity] = [:],
                      excluded: [String] = [], tiles: [BingoSquare] = []) -> TilePack {
        TilePack(id: id, name: id, description: "", imageName: "",
                 tiles: tiles, rarityOverrides: overrides, excludedTileIDs: excluded)
    }

    func test_buildPool_emptyPacksReturnsBaseUnchanged() {
        let base = [square("00000000-0000-0000-0000-000000000001", rarity: .common)]
        let result = SquarePool.buildPool(base: base, activePacks: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].rarity, .common)
    }

    func test_buildPool_appliesRarityOverride() {
        let tractorID = "4A495FE0-B728-477D-8863-FD00E9140BB6"
        let base = [square(tractorID, rarity: .uncommon, text: "Tractor")]
        let farmPack = pack(overrides: [tractorID: .veryCommon])
        let result = SquarePool.buildPool(base: base, activePacks: [farmPack])
        XCTAssertEqual(result.first?.rarity, .veryCommon)
    }

    func test_buildPool_mostCommonWinsWhenTwoPacksOverrideSameTile() {
        let id = "4A495FE0-B728-471D-8863-FD00E9140BB6"
        let base = [square(id, rarity: .uncommon)]
        let pack1 = pack(id: "a", overrides: [id: .common])
        let pack2 = pack(id: "b", overrides: [id: .veryCommon])
        let result = SquarePool.buildPool(base: base, activePacks: [pack1, pack2])
        XCTAssertEqual(result.first?.rarity, .veryCommon,
                       "veryCommon should beat common under most-common-wins")
    }

    func test_buildPool_excludesTileFromAnyActivePack() {
        let excludedID = "3DE3F367-3105-4F8B-A89D-2F134E21D01D"
        let base = [
            square(excludedID, rarity: .veryCommon, text: "Subway"),
            square("11111111-1111-1111-1111-111111111111", rarity: .common, text: "Other")
        ]
        let p = pack(excluded: [excludedID])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertFalse(result.contains { $0.id.uuidString == excludedID })
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Other")
    }

    func test_buildPool_appendsExclusiveTiles() {
        let base = [square("11111111-1111-1111-1111-111111111111", rarity: .common)]
        let exclusive = BingoSquare(id: UUID(), text: "Combine Harvester", emoji: nil,
                                    category: .vehicles, rarity: .veryCommon)
        let p = pack(tiles: [exclusive])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.text == "Combine Harvester" })
    }

    func test_buildPool_exclusionAndOverrideAreCombined() {
        let excludedID = "3DE3F367-3105-4F8B-A89D-2F134E21D01D"
        let overriddenID = "4A495FE0-B728-471D-8863-FD00E9140BB6"
        let base = [
            square(excludedID, rarity: .veryCommon, text: "Subway"),
            square(overriddenID, rarity: .uncommon, text: "Tractor")
        ]
        let p = pack(overrides: [overriddenID: .veryCommon], excluded: [excludedID])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Tractor")
        XCTAssertEqual(result[0].rarity, .veryCommon)
    }

    func test_buildPool_withRealBasePool_doesNotShrinkBelowUsableSize() {
        let base = SquarePool.load()
        // With no packs: pool should be unchanged
        let result = SquarePool.buildPool(base: base, activePacks: [])
        XCTAssertEqual(result.count, base.count)
    }
```

- [ ] **Step 3.2: Run tests — expect compile failure**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|FAILED" | head -20
```

Expected: compile error — `SquarePool.buildPool` not defined.

- [ ] **Step 3.3: Add buildPool to SquarePool**

In `RoadTripBingo/Game/SquarePool.swift`, add these two functions after the existing `dealReserve` and before the `// MARK: - Private helpers` comment:

```swift
    /// Combines the base pool with active packs:
    /// 1. Removes base tiles excluded by any active pack (union of all exclusions).
    /// 2. Applies rarity overrides with most-common-wins when packs conflict.
    /// 3. Appends pack-exclusive tiles from all active packs.
    ///
    /// When `activePacks` is empty, returns `base` unmodified.
    static func buildPool(base: [BingoSquare], activePacks: [TilePack]) -> [BingoSquare] {
        guard !activePacks.isEmpty else { return base }

        // 1. Build exclusion set from all active packs
        let excludedIDs = Set(activePacks.flatMap { $0.excludedTileIDs }
                                         .compactMap { UUID(uuidString: $0) })

        // 2. Build override map: UUID → most-common rarity across all active packs
        var overrideMap: [UUID: SquareRarity] = [:]
        for pack in activePacks {
            for (idString, rarity) in pack.rarityOverrides {
                guard let id = UUID(uuidString: idString) else { continue }
                overrideMap[id] = overrideMap[id].map { mostCommon($0, rarity) } ?? rarity
            }
        }

        // 3. Filter exclusions and apply overrides to base tiles
        let filteredBase: [BingoSquare] = base
            .filter { !excludedIDs.contains($0.id) }
            .map { square in
                guard let newRarity = overrideMap[square.id] else { return square }
                return BingoSquare(id: square.id, text: square.text, emoji: square.emoji,
                                   category: square.category, rarity: newRarity)
            }

        // 4. Append exclusive tiles from all active packs
        let exclusiveTiles = activePacks.flatMap { $0.tiles }

        return filteredBase + exclusiveTiles
    }

    /// Returns the rarity that is further toward veryCommon.
    /// `allCases` order is [veryCommon, common, uncommon, rare, veryRare] so lower index = more common.
    private static func mostCommon(_ a: SquareRarity, _ b: SquareRarity) -> SquareRarity {
        let order = SquareRarity.allCases
        let ia = order.firstIndex(of: a) ?? order.count
        let ib = order.firstIndex(of: b) ?? order.count
        return ia <= ib ? a : b
    }
```

- [ ] **Step 3.4: Run tests**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "SquarePoolTests|PASSED|FAILED|error:" | head -30
```

Expected: all existing `SquarePoolTests` pass, all new `buildPool` tests pass.

- [ ] **Step 3.5: Commit**

```bash
git add RoadTripBingo/Game/SquarePool.swift RoadTripBingoTests/SquarePoolTests.swift
git commit -m "feat: add SquarePool.buildPool with exclusion and most-common-wins rarity override"
```

---

## Task 4: Pack JSON Files

**Files:**
- Create: `RoadTripBingo/Resources/pack-interstate.json`
- Create: `RoadTripBingo/Resources/pack-city.json`
- Create: `RoadTripBingo/Resources/pack-farm-country.json`
- Create: `RoadTripBingo/Resources/pack-mountains.json`
- Create: `RoadTripBingo/Resources/pack-beach-coast.json`
- Create: `RoadTripBingo/Resources/pack-desert-southwest.json`

All UUIDs for `rarityOverrides` and `excludedTileIDs` reference tiles in `squares.json`. New exclusive tile UUIDs are freshly generated (must not collide with `squares.json`).

- [ ] **Step 4.1: Create pack-interstate.json**

```json
{
  "id": "interstate",
  "name": "Interstate",
  "description": "Highways, rest stops, weigh stations, and the endless white line.",
  "imageName": "pack-interstate",
  "tiles": [],
  "rarityOverrides": {
    "95F10877-1BC5-4F38-A6B1-5C8469946794": "veryCommon",
    "B15573AB-373C-4093-957F-87EAAD1FF91D": "veryCommon",
    "69822FBE-A091-40B0-BE4A-9BE98A51293A": "veryCommon",
    "01B2195F-8A68-431D-BE3F-19E2C2457C03": "veryCommon",
    "96794F0E-2FF3-49BB-A03A-FE760A8B728A": "common",
    "0ED19DD6-E519-44AD-A531-66A65D01C3F6": "veryCommon",
    "8031441A-0A40-43A1-9A1D-908CF7CD08BE": "veryCommon",
    "BDF48176-EA53-4AE5-9BBD-57A4C1BF35AA": "veryCommon",
    "B2DEEFBA-A491-4019-B51D-82C346B9B175": "common",
    "6452E9FD-291D-4DDE-8CA4-6FFDEB73A24F": "common"
  },
  "excludedTileIDs": []
}
```

Key overrides:
- Semi Truck `95F10877` uncommon→veryCommon (already veryCommon — no-op but explicit)
- Flatbed Truck `B15573AB` common→veryCommon
- Dump Truck `69822FBE` common→veryCommon
- Rest Area Sign `01B2195F` common→veryCommon
- Weigh Station `96794F0E` uncommon→common
- Truck Stop `0ED19DD6` common→veryCommon
- Mile Marker ×0 `8031441A` common→veryCommon
- Highway Interchange `BDF48176` common→veryCommon
- Toll Booth `B2DEEFBA` uncommon→common
- Runaway Truck Ramp `6452E9FD` rare→common

- [ ] **Step 4.2: Create pack-city.json**

```json
{
  "id": "city",
  "name": "City",
  "description": "Traffic, towers, crosswalks, and the organized chaos of the American city.",
  "imageName": "pack-city",
  "tiles": [],
  "rarityOverrides": {
    "170DDCD4-5B1C-4A27-AF08-3EFE0F723A94": "veryCommon",
    "537CBB6C-15E0-49AE-A2C9-7F4E5D0804F2": "veryCommon",
    "F50FE702-488F-44D8-9173-D2BFDA251793": "common",
    "686F9B09-BB0F-4890-A32D-1EAE02656756": "common",
    "6296D382-C8DD-406B-92FA-D53A490DCCB2": "veryCommon",
    "D598618B-F39A-4D8D-B456-58F75264ECE9": "common",
    "A4817B0E-0016-49C9-B685-4A1B0F29EA81": "veryCommon",
    "3DE3F367-3105-4F8B-A89D-2F134E21D01D": "veryCommon"
  },
  "excludedTileIDs": [
    "4A495FE0-B728-477D-8863-FD00E9140BB6",
    "FA75C56E-321A-4958-9F9A-050CA316AB90",
    "A14147C1-EDE5-4762-9302-0D4EEE5E9E2D",
    "CB998D77-472F-4201-8025-9790FE1B3C82",
    "725B6E6E-33F5-413E-831B-1B0A79B00A99",
    "1532CC43-DDA7-400A-BFD0-0ADD8874D565",
    "3055B218-5E2B-4574-A83B-9EDD80E79E8F"
  ]
}
```

Key overrides:
- Police Car `170DDCD4` common→veryCommon
- School Bus `537CBB6C` common→veryCommon
- Ambulance `F50FE702` uncommon→common
- Fire Truck `686F9B09` uncommon→common
- Food Truck `6296D382` uncommon→veryCommon
- Convertible `D598618B` uncommon→common
- Airport `A4817B0E` uncommon→veryCommon
- Subway `3DE3F367` veryCommon (already — explicit)

Exclusions: Tractor, Hay Bale, Grain Silo, Grain Elevator, White Fence Horse Farm, Wheat Field, Cornfield

- [ ] **Step 4.3: Create pack-farm-country.json**

```json
{
  "id": "farm-country",
  "name": "Farm Country",
  "description": "Hay bales, open fields, livestock, and the quiet rhythm of rural America.",
  "imageName": "pack-farm-country",
  "tiles": [
    {
      "id": "F1A00001-0000-0000-0000-000000000001",
      "text": "Combine Harvester",
      "emoji": "🌾",
      "category": "vehicles",
      "rarity": "veryCommon"
    },
    {
      "id": "F1A00001-0000-0000-0000-000000000002",
      "text": "Irrigation Pivot",
      "emoji": "💧",
      "category": "landmarks",
      "rarity": "common"
    }
  ],
  "rarityOverrides": {
    "4A495FE0-B728-477D-8863-FD00E9140BB6": "veryCommon",
    "2AB6C54B-DEAD-401A-BCE8-B5E4F50AE481": "common",
    "744CE9F9-887F-460D-B022-262622D6BAB1": "veryCommon",
    "725B6E6E-33F5-413E-831B-1B0A79B00A99": "common",
    "A14147C1-EDE5-4762-9302-0D4EEE5E9E2D": "veryCommon",
    "CB998D77-472F-4201-8025-9790FE1B3C82": "veryCommon",
    "814EBF76-AD02-4C8D-9943-DC94892B3B1D": "common",
    "BF9F37F8-B798-41D5-9669-9B55BC69A4F1": "veryCommon",
    "E17D0F7E-2FC8-489F-84F5-4CE627C31BE0": "veryCommon",
    "E7AA2D29-1891-4662-9FA3-8E021212A14A": "veryCommon",
    "6DA38EF8-1586-4C66-A554-EC4E49CBE8F1": "veryCommon",
    "507FA95C-5CEB-40D3-B4E2-EEC40DDE2135": "uncommon"
  },
  "excludedTileIDs": [
    "3DE3F367-3105-4F8B-A89D-2F134E21D01D"
  ]
}
```

Key overrides:
- Tractor `4A495FE0` uncommon→veryCommon
- Horse Trailer `2AB6C54B` rare→common
- Livestock Trailer `744CE9F9` common→veryCommon
- White Fence Horse Farm `725B6E6E` uncommon→common
- Grain Silo `A14147C1` common→veryCommon
- Grain Elevator `CB998D77` common→veryCommon
- Sunflower Field `814EBF76` uncommon→common
- Goat `BF9F37F8` common→veryCommon
- Sheep `E17D0F7E` common→veryCommon
- Pig `E7AA2D29` common→veryCommon
- Horse `6DA38EF8` common→veryCommon
- Amish Buggy `507FA95C` rare→uncommon

Exclusions: Subway

- [ ] **Step 4.4: Create pack-mountains.json**

```json
{
  "id": "mountains",
  "name": "Mountains",
  "description": "Snow caps, switchbacks, pine forests, and the thin air of elevation.",
  "imageName": "pack-mountains",
  "tiles": [
    {
      "id": "F1A00001-0000-0000-0000-000000000010",
      "text": "Switchback Road",
      "emoji": "🛣️",
      "category": "landmarks",
      "rarity": "common"
    },
    {
      "id": "F1A00001-0000-0000-0000-000000000011",
      "text": "Mountain Stream",
      "emoji": "💧",
      "category": "nature",
      "rarity": "common"
    }
  ],
  "rarityOverrides": {
    "1CA02B04-B431-467D-A705-D64A1CA3D9F7": "veryCommon",
    "3123E8B9-FD3E-4DC4-A370-4E1E13F95F40": "veryCommon",
    "60F03332-B413-4CBF-83C8-A65B266C65D0": "common",
    "6452E9FD-291D-4DDE-8CA4-6FFDEB73A24F": "common",
    "87D08710-197C-4864-BE1A-C03FA82435E6": "common",
    "05150C84-9A42-4F02-9FA8-685C4881A307": "rare",
    "75077334-D3F1-40CA-B3C2-E8481BE4EAB6": "uncommon",
    "321FA7B9-C0A4-42FD-8AB8-F0A3CB768041": "common",
    "B492D74A-9B0D-4149-AD42-C6C720808A22": "common",
    "80067278-3DC2-425E-BD95-DCD19E535633": "common"
  },
  "excludedTileIDs": [
    "3DE3F367-3105-4F8B-A89D-2F134E21D01D",
    "1532CC43-DDA7-400A-BFD0-0ADD8874D565",
    "3055B218-5E2B-4574-A83B-9EDD80E79E8F",
    "A14147C1-EDE5-4762-9302-0D4EEE5E9E2D"
  ]
}
```

Key overrides:
- Snow on Mountains `1CA02B04` uncommon→veryCommon
- Mountain `3123E8B9` common→veryCommon
- Ski Lift `60F03332` uncommon→common
- Runaway Truck Ramp `6452E9FD` rare→common
- Elk Crossing Sign `87D08710` uncommon→common
- Elk `05150C84` veryRare→rare
- Buffalo `75077334` rare→uncommon
- Ice on Road Sign `321FA7B9` rare→common
- Frost on Windows `B492D74A` rare→common
- Motorcycle `80067278` veryCommon (already — explicit)

Exclusions: Subway, Wheat Field, Cornfield, Grain Silo

- [ ] **Step 4.5: Create pack-beach-coast.json**

```json
{
  "id": "beach-coast",
  "name": "Beach & Coast",
  "description": "Surf shops, piers, seagulls, and the salt-air side of the road.",
  "imageName": "pack-beach-coast",
  "tiles": [
    {
      "id": "F1A00001-0000-0000-0000-000000000020",
      "text": "Surf Shop",
      "emoji": "🏄",
      "category": "landmarks",
      "rarity": "common"
    },
    {
      "id": "F1A00001-0000-0000-0000-000000000021",
      "text": "Lifeguard Tower",
      "emoji": "🚨",
      "category": "landmarks",
      "rarity": "common"
    },
    {
      "id": "F1A00001-0000-0000-0000-000000000022",
      "text": "Seagull Flock",
      "emoji": "🐦",
      "category": "nature",
      "rarity": "veryCommon"
    },
    {
      "id": "F1A00001-0000-0000-0000-000000000023",
      "text": "Pier",
      "emoji": "🎣",
      "category": "landmarks",
      "rarity": "common"
    }
  ],
  "rarityOverrides": {
    "D598618B-F39A-4D8D-B456-58F75264ECE9": "common",
    "1FA254CD-692C-47EC-9716-44C1712F42F3": "common",
    "E044FC0C-DE73-4F07-9812-45FE6AA69E63": "veryCommon",
    "80067278-3DC2-425E-BD95-DCD19E535633": "common",
    "3EC043CB-6069-4CFB-9F1E-73068068A53C": "veryCommon",
    "CE3A8924-5C4F-499C-BA33-322CCAF2593B": "veryCommon"
  },
  "excludedTileIDs": [
    "1CA02B04-B431-467D-A705-D64A1CA3D9F7",
    "A14147C1-EDE5-4762-9302-0D4EEE5E9E2D",
    "4A495FE0-B728-477D-8863-FD00E9140BB6",
    "6452E9FD-291D-4DDE-8CA4-6FFDEB73A24F"
  ]
}
```

Key overrides:
- Convertible `D598618B` uncommon→common
- Lighthouse `1FA254CD` rare→common
- Pickup Truck `E044FC0C` veryCommon (explicit)
- Motorcycle `80067278` veryCommon→common
- Lake `3EC043CB` common→veryCommon
- River `CE3A8924` common→veryCommon

Exclusions: Snow on Mountains, Grain Silo, Tractor, Runaway Truck Ramp

- [ ] **Step 4.6: Create pack-desert-southwest.json**

```json
{
  "id": "desert-southwest",
  "name": "Desert Southwest",
  "description": "Saguaros, red rock, dust devils, and the vast silence of the American desert.",
  "imageName": "pack-desert-southwest",
  "tiles": [
    {
      "id": "F1A00001-0000-0000-0000-000000000030",
      "text": "Saguaro Cactus",
      "emoji": "🌵",
      "category": "nature",
      "rarity": "veryCommon"
    },
    {
      "id": "F1A00001-0000-0000-0000-000000000031",
      "text": "Trading Post Sign",
      "emoji": "🪶",
      "category": "signs",
      "rarity": "uncommon"
    },
    {
      "id": "F1A00001-0000-0000-0000-000000000032",
      "text": "Dry Riverbed",
      "emoji": "🏜️",
      "category": "nature",
      "rarity": "common"
    }
  ],
  "rarityOverrides": {
    "65FAFD7F-384F-43B2-B90A-300A844F79D0": "veryCommon",
    "B957584E-97A2-4DBB-B421-A80D1832D7C5": "common",
    "B7ED7D37-B022-45D6-8FFE-B8FA780B6684": "common",
    "944B6E26-F677-455F-B087-9D883297CF5B": "common",
    "EFDF3832-1699-449C-A7B5-124E44366CE9": "uncommon",
    "E044FC0C-DE73-4F07-9812-45FE6AA69E63": "veryCommon",
    "75077334-D3F1-40CA-B3C2-E8481BE4EAB6": "uncommon",
    "C2738543-1B62-4D94-A914-3ECF040D81D0": "common",
    "BA705AAF-0D8B-43EE-8DA9-476B3E5A97D0": "veryCommon"
  },
  "excludedTileIDs": [
    "1CA02B04-B431-467D-A705-D64A1CA3D9F7",
    "FA75C56E-321A-4958-9F9A-050CA316AB90",
    "A14147C1-EDE5-4762-9302-0D4EEE5E9E2D",
    "3DE3F367-3105-4F8B-A89D-2F134E21D01D",
    "3055B218-5E2B-4574-A83B-9EDD80E79E8F",
    "1532CC43-DDA7-400A-BFD0-0ADD8874D565"
  ]
}
```

Key overrides:
- Cactus `65FAFD7F` uncommon→veryCommon
- Dust Devil `B957584E` rare→common
- Red Rock Cliffs `B7ED7D37` rare→common
- Mirage `944B6E26` veryRare→common
- Dust Storm `EFDF3832` veryRare→uncommon
- Pickup Truck `E044FC0C` veryCommon (explicit)
- Buffalo `75077334` rare→uncommon
- Pronghorn Antelope `C2738543` veryRare→common
- Hot Haze Shimmer `BA705AAF` uncommon→veryCommon

Exclusions: Snow on Mountains, Hay Bale, Grain Silo, Subway, Cornfield, Wheat Field

- [ ] **Step 4.7: Regenerate Xcode project and run all tests**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodegen generate 2>&1 | tail -5
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "PASSED|FAILED|error:" | head -30
```

Expected: `PackManagerTests.test_loadAll_returnsNonEmptyList` now passes. `test_pack_returnsCorrectPackByID` passes. All other tests still pass.

- [ ] **Step 4.8: Commit**

```bash
git add RoadTripBingo/Resources/pack-*.json
git commit -m "feat: add 6 tile pack JSON files (interstate, city, farm, mountains, beach, desert)"
```

---

## Task 5: AppState — activePackIDs

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 5.1: Add activePackIDs property, togglePack, update dealAndLaunchRound**

In `AppState.swift`, make these three changes:

**a) Add the published property** after the `@Published var playerDifficulties` line (around line 31):

```swift
    // MARK: - Tile packs (host only — persisted and broadcast at game start)
    @Published var activePackIDs: [String] = {
        UserDefaults.standard.stringArray(forKey: "activePackIDs") ?? []
    }() {
        didSet {
            UserDefaults.standard.set(activePackIDs, forKey: "activePackIDs")
        }
    }
```

**b) Add togglePack** in the `// MARK: - Home actions` section, after `chooseDifficulty`:

```swift
    func togglePack(_ packID: String) {
        if activePackIDs.contains(packID) {
            activePackIDs.removeAll { $0 == packID }
        } else {
            activePackIDs.append(packID)
        }
    }
```

**c) Update dealAndLaunchRound** — replace the existing `let pool = SquarePool.load()` line (currently around line 261):

```swift
        let baseTiles = SquarePool.load()
        let activePacks = PackManager.packs(forIDs: activePackIDs)
        let pool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks)
```

- [ ] **Step 5.2: Run tests**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "PASSED|FAILED|error:" | head -30
```

Expected: all existing tests still pass (buildPool with empty packs returns base pool unchanged).

- [ ] **Step 5.3: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: AppState persists activePackIDs and applies tile packs at round start"
```

---

## Task 6: MultipeerMessage — activePackIDs

Non-host peers receive `activePackIDs` so their `TilePacksView` shows the correct read-only pack selection.

**Files:**
- Modify: `RoadTripBingo/Models/MultipeerMessage.swift`

- [ ] **Step 6.1: Update MultipeerMessage**

Make the following changes to `MultipeerMessage.swift`:

**a) Update the two case declarations** (replace existing `gameStarted` and `playAgain` cases):

```swift
    case gameStarted(boards: [String: [BingoSquare]], activePackIDs: [String])
    // ...existing cases...
    case playAgain(boards: [String: [BingoSquare]], activePackIDs: [String])
```

**b) Add `activePackIDs` to the `CodingKeys` enum**:

```swift
    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName, difficulty
        case newBalance, powerUp, targetPlayer, targetIndex, replacementSquare
        case toName, squares
        case modifier, shuffledSquares, shuffledByName
        case handicapToPlayer, handicapTokens
        case activePackIDs   // ← add this
    }
```

**c) Update the `encode` cases for `gameStarted` and `playAgain`**:

```swift
        case .gameStarted(let boards, let activePackIDs):
            try c.encode(MessageType.gameStarted, forKey: .type)
            try c.encode(boards, forKey: .boards)
            try c.encode(activePackIDs, forKey: .activePackIDs)
        // ...
        case .playAgain(let boards, let activePackIDs):
            try c.encode(MessageType.playAgain, forKey: .type)
            try c.encode(boards, forKey: .boards)
            try c.encode(activePackIDs, forKey: .activePackIDs)
```

**d) Update the `init(from:)` decode cases** (use `decodeIfPresent` for backward compat):

```swift
        case .gameStarted:
            self = .gameStarted(
                boards: try c.decode([String: [BingoSquare]].self, forKey: .boards),
                activePackIDs: (try? c.decodeIfPresent([String].self, forKey: .activePackIDs)) ?? []
            )
        // ...
        case .playAgain:
            self = .playAgain(
                boards: try c.decode([String: [BingoSquare]].self, forKey: .boards),
                activePackIDs: (try? c.decodeIfPresent([String].self, forKey: .activePackIDs)) ?? []
            )
```

- [ ] **Step 6.2: Fix call sites in AppState**

The `gameStarted` and `playAgain` sends in `AppState` now need `activePackIDs`. Update `dealAndLaunchRound` — the existing send calls:

```swift
// In startGame():
self?.multipeerSession?.send(.gameStarted(boards: boards, activePackIDs: self?.activePackIDs ?? []))

// In requestPlayAgain():
self?.multipeerSession?.send(.playAgain(boards: boards, activePackIDs: self?.activePackIDs ?? []))
```

Also update the `didReceive` handler for peers to store received pack IDs. In the `.gameStarted` case of `multipeerSession(_:didReceive:from:)`:

```swift
        case .gameStarted(let boards, let activePackIDs):
            self.activePackIDs = activePackIDs  // ← add this line
            rollDailyChallengesIfNeeded()
            // ... rest of existing handler unchanged
```

And in the `.playAgain` case:

```swift
        case .playAgain(let boards, let activePackIDs):
            self.activePackIDs = activePackIDs  // ← add this line
            rollDailyChallengesIfNeeded()
            // ... rest of existing handler unchanged
```

- [ ] **Step 6.3: Update MultipeerMessageTests**

`MultipeerMessageTests.swift` constructs `gameStarted` and `playAgain` with the old signatures and pattern-matches with the old labels. Update both tests:

```swift
    func test_gameStarted_roundtrip() throws {
        let square = BingoSquare(id: UUID(), text: "Cow", emoji: "🐄", category: .nature, rarity: .veryCommon)
        let boards: [String: [BingoSquare]] = ["Emma": [square]]
        let msg = MultipeerMessage.gameStarted(boards: boards, activePackIDs: ["farm-country"])
        let decoded = try roundtrip(msg)
        guard case .gameStarted(let decodedBoards, let packIDs) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(decodedBoards["Emma"]?.first?.text, "Cow")
        XCTAssertEqual(packIDs, ["farm-country"])
    }

    func test_playAgain_roundtrip() throws {
        let square = BingoSquare(id: UUID(), text: "Barn", emoji: "🏚️", category: .nature, rarity: .veryCommon)
        let boards: [String: [BingoSquare]] = ["Zoe": [square]]
        let msg = MultipeerMessage.playAgain(boards: boards, activePackIDs: [])
        let decoded = try roundtrip(msg)
        guard case .playAgain(let decodedBoards, let packIDs) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(decodedBoards["Zoe"]?.first?.text, "Barn")
        XCTAssertTrue(packIDs.isEmpty)
    }
```

Also add a backward-compat test (decoding an old message without `activePackIDs` should default to `[]`):

```swift
    func test_gameStarted_backwardCompat_missingActivePackIDsDecodesAsEmpty() throws {
        // Simulate a message from an older client that doesn't send activePackIDs
        let json = """
        {
          "type": "gameStarted",
          "boards": {}
        }
        """
        let decoded = try JSONDecoder().decode(MultipeerMessage.self, from: Data(json.utf8))
        guard case .gameStarted(_, let packIDs) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertTrue(packIDs.isEmpty, "Missing activePackIDs should decode as empty array")
    }
```

- [ ] **Step 6.5: Run tests**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "PASSED|FAILED|error:" | head -30
```

Expected: all tests pass including `MultipeerMessageTests`.

- [ ] **Step 6.6: Commit**

```bash
git add RoadTripBingo/Models/MultipeerMessage.swift RoadTripBingo/State/AppState.swift
git commit -m "feat: broadcast activePackIDs in gameStarted and playAgain messages"
```

---

## Task 7: TilePacksView

**Files:**
- Create: `RoadTripBingo/Views/TilePacksView.swift`

This sheet presents the 2-column pack grid, rarity distribution bar, and pool size indicator. The visual design was approved in the brainstorming mockup.

- [ ] **Step 7.1: Create TilePacksView.swift**

Create `RoadTripBingo/Views/TilePacksView.swift`:

```swift
import SwiftUI

struct TilePacksView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    private let allPacks: [TilePack] = PackManager.loadAll()
    private let basePool: [BingoSquare] = SquarePool.load()

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(AmericanaTheme.ink.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tile Packs")
                        .font(AmericanaTheme.rye(18))
                        .foregroundColor(AmericanaTheme.ink)
                    Text("SELECT YOUR SCENERY")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.45))
                        .kerning(2)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .font(AmericanaTheme.barlowBold(14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(AmericanaTheme.green)
                    .cornerRadius(8)
                    .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .overlay(Rectangle().fill(AmericanaTheme.ink.opacity(0.10)).frame(height: 1), alignment: .bottom)

            // Scrollable body
            ScrollView {
                VStack(spacing: 12) {
                    // Pack grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(allPacks) { pack in
                            PackCardView(
                                pack: pack,
                                isSelected: appState.activePackIDs.contains(pack.id),
                                isReadOnly: !appState.isHost
                            ) {
                                appState.togglePack(pack.id)
                            }
                        }
                    }

                    // Rarity distribution
                    RarityDistributionView(pool: activePool)

                    // Pool size indicator
                    PoolSizeIndicatorView(pool: activePool, playerCount: playerCount)
                }
                .padding(20)
            }
        }
        .background(AmericanaTheme.paper.ignoresSafeArea())
    }

    private var activePool: [BingoSquare] {
        let packs = PackManager.packs(forIDs: appState.activePackIDs)
        return SquarePool.buildPool(base: basePool, activePacks: packs)
    }

    private var playerCount: Int {
        max(1, appState.connectedPlayerNames.count + 1)
    }
}

// MARK: - PackCardView

struct PackCardView: View {
    let pack: TilePack
    let isSelected: Bool
    let isReadOnly: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !isReadOnly { onTap() } }) {
            VStack(spacing: 0) {
                // Pack image
                ZStack(alignment: .topTrailing) {
                    if let uiImage = UIImage(named: pack.imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 90)
                            .clipped()
                    } else {
                        // Placeholder when image asset not yet added
                        Rectangle()
                            .fill(AmericanaTheme.ink.opacity(0.08))
                            .frame(height: 90)
                            .overlay(
                                Text(pack.name.prefix(1))
                                    .font(AmericanaTheme.rye(28))
                                    .foregroundColor(AmericanaTheme.ink.opacity(0.3))
                            )
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .padding(8)
                    }
                }

                // Pack name and description
                VStack(alignment: .leading, spacing: 3) {
                    Text(pack.name)
                        .font(AmericanaTheme.barlowBold(13))
                        .foregroundColor(AmericanaTheme.ink)
                        .lineLimit(1)
                    Text(pack.description)
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.5))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .background(AmericanaTheme.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? AmericanaTheme.green : AmericanaTheme.ink.opacity(0.12),
                              lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: AmericanaTheme.shadow, radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - RarityDistributionView

struct RarityDistributionView: View {
    let pool: [BingoSquare]

    private var counts: [SquareRarity: Int] {
        var c: [SquareRarity: Int] = [:]
        for rarity in SquareRarity.allCases { c[rarity] = 0 }
        for square in pool { c[square.rarity, default: 0] += 1 }
        return c
    }

    private var total: Int { pool.count }

    // Colors from most-common (green) to rarest (deep red)
    private let rarityColors: [SquareRarity: Color] = [
        .veryCommon: Color(red: 0.102, green: 0.361, blue: 0.165),
        .common:     Color(red: 0.353, green: 0.541, blue: 0.227),
        .uncommon:   Color(red: 0.545, green: 0.412, blue: 0.078),
        .rare:       Color(red: 0.753, green: 0.224, blue: 0.169),
        .veryRare:   Color(red: 0.416, green: 0.063, blue: 0.035)
    ]

    private let rarityLabels: [SquareRarity: String] = [
        .veryCommon: "Very Common",
        .common:     "Common",
        .uncommon:   "Uncommon",
        .rare:       "Rare",
        .veryRare:   "Very Rare"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RARITY DISTRIBUTION — \(total) TILES")
                .font(AmericanaTheme.barlowSemiBold(9))
                .foregroundColor(AmericanaTheme.ink.opacity(0.45))
                .kerning(2)

            // Segmented bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(SquareRarity.allCases, id: \.self) { rarity in
                        let count = counts[rarity] ?? 0
                        let fraction = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                        if fraction > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(rarityColors[rarity] ?? .gray)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            // Legend
            HStack(spacing: 0) {
                ForEach(SquareRarity.allCases, id: \.self) { rarity in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(rarityColors[rarity] ?? .gray)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(rarityLabels[rarity] ?? "")
                                .font(AmericanaTheme.barlowSemiBold(8))
                                .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                            Text("\(counts[rarity] ?? 0)")
                                .font(AmericanaTheme.barlowBold(9))
                                .foregroundColor(AmericanaTheme.ink)
                        }
                    }
                    if rarity != .veryRare { Spacer() }
                }
            }
        }
        .padding(12)
        .background(AmericanaTheme.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AmericanaTheme.ink.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - PoolSizeIndicatorView

struct PoolSizeIndicatorView: View {
    let pool: [BingoSquare]
    let playerCount: Int

    private var minimumNeeded: Int { playerCount * 24 + playerCount * 6 }  // boards + reserve
    private var isThin: Bool { pool.count < minimumNeeded }

    var body: some View {
        HStack {
            if isThin {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AmericanaTheme.red)
                    .font(.system(size: 13))
                Text("Not enough tiles for \(playerCount) player\(playerCount == 1 ? "" : "s") — add another pack")
                    .font(AmericanaTheme.barlowSemiBold(11))
                    .foregroundColor(AmericanaTheme.red)
            } else {
                Text("Tile pool for \(playerCount) player\(playerCount == 1 ? "" : "s")")
                    .font(AmericanaTheme.barlowSemiBold(11))
                    .foregroundColor(AmericanaTheme.ink)
            }
            Spacer()
            Text("\(pool.count) tiles \(isThin ? "⚠️" : "✓")")
                .font(AmericanaTheme.barlowBold(15))
                .foregroundColor(isThin ? AmericanaTheme.red : AmericanaTheme.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isThin ? AmericanaTheme.red.opacity(0.08) : AmericanaTheme.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isThin ? AmericanaTheme.red.opacity(0.3) : AmericanaTheme.yellow.opacity(0.4),
                              lineWidth: 1)
        )
    }
}
```

- [ ] **Step 7.2: Regenerate Xcode project and verify build**

```bash
xcodegen generate 2>&1 | tail -5
xcodebuild build -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7.3: Commit**

```bash
git add RoadTripBingo/Views/TilePacksView.swift
git commit -m "feat: add TilePacksView with pack grid, rarity distribution bar, and pool indicator"
```

---

## Task 8: HomeView — Tile Packs Button

**Files:**
- Modify: `RoadTripBingo/Views/HomeView.swift`

- [ ] **Step 8.1: Add state and button**

In `HomeView`, add a `@State` variable for the sheet at the top of the struct (alongside the existing `showChallenges`):

```swift
    @State private var showPacks = false
```

In the `rightPanel` body, add the "Tile Packs" button **immediately after** the existing "Today's Challenges" button block (after its `.frame(maxWidth: 360).sheet(...)` modifier):

```swift
                    Button {
                        showPacks = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 13))
                            Text("Tile Packs")
                                .font(AmericanaTheme.barlowBold(15))
                        }
                        .foregroundColor(AmericanaTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AmericanaTheme.parchment)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(AmericanaTheme.brown.opacity(0.5), lineWidth: 1.5)
                                )
                        )
                    }
                    .frame(maxWidth: 360)
                    .sheet(isPresented: $showPacks) {
                        TilePacksView()
                            .presentationDetents([.large])
                    }
```

- [ ] **Step 8.2: Build and verify**

```bash
xcodebuild build -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 8.3: Commit**

```bash
git add RoadTripBingo/Views/HomeView.swift
git commit -m "feat: add Tile Packs button to HomeView"
```

---

## Task 9: PlayAgainView — Change Packs Button

**Files:**
- Modify: `RoadTripBingo/Views/PlayAgainView.swift`

- [ ] **Step 9.1: Add state and button**

In `PlayAgainView`, add a `@State` variable:

```swift
    @State private var showPacks = false
```

In the `VStack(spacing: 14)` that contains the host buttons, add the "Change Packs" button **between** the "New Game" button and the "Go Home" button, and only show it for the host:

```swift
                    if appState.isHost {
                        Button(action: appState.requestPlayAgain) {
                            Text("New Game")
                                .font(AmericanaTheme.barlowBold(17))
                                .frame(maxWidth: 360).padding()
                                .background(AmericanaTheme.green)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }

                        Button {
                            showPacks = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "map")
                                    .font(.system(size: 13))
                                Text("Change Packs")
                                    .font(AmericanaTheme.barlowBold(15))
                            }
                            .foregroundColor(AmericanaTheme.ink)
                            .frame(maxWidth: 360)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AmericanaTheme.parchment)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(AmericanaTheme.brown.opacity(0.5), lineWidth: 1.5)
                                    )
                            )
                        }
                        .sheet(isPresented: $showPacks) {
                            TilePacksView()
                                .presentationDetents([.large])
                        }
                    } else {
                        Text("Waiting for host to start a new game…")
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                    }
```

- [ ] **Step 9.2: Build and run all tests**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "PASSED|FAILED|error:" | head -30
```

Expected: BUILD SUCCEEDED, all tests pass.

- [ ] **Step 9.3: Commit**

```bash
git add RoadTripBingo/Views/PlayAgainView.swift
git commit -m "feat: add Change Packs button to PlayAgainView (host only)"
```

---

## Task 10: Image Assets

Pack card images must be added to the Xcode asset catalog. This is a manual step — generate images using the prompts in the spec, then add them as named image sets.

- [ ] **Step 10.1: Add image assets**

In Xcode, open `Assets.xcassets`. For each pack, create a new Image Set named exactly as listed:

| Image Set Name | Pack |
|---|---|
| `pack-interstate` | Interstate |
| `pack-city` | City |
| `pack-farm-country` | Farm Country |
| `pack-mountains` | Mountains |
| `pack-beach-coast` | Beach & Coast |
| `pack-desert-southwest` | Desert Southwest |

Drag the AI-generated images into each Image Set's `1x` slot. Use the image prompts from `docs/superpowers/specs/2026-05-25-tile-packs-design.md` Section 4 to generate the images.

> **Note:** Until images are added, `PackCardView` shows a letter-initial placeholder (first letter of pack name on a parchment background). The app is fully functional without images.

- [ ] **Step 10.2: Build and verify no asset errors**

```bash
xcodebuild build -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | grep -v "warning:" | head -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 10.3: Commit**

```bash
git add RoadTripBingo/RoadTripBingo/Assets.xcassets
git commit -m "feat: add tile pack card images to asset catalog"
```

---

## Spec Coverage Check

| Spec requirement | Task |
|---|---|
| `TilePack` model with tiles, rarityOverrides, excludedTileIDs | Task 1 |
| `PackManager.loadAll()` and `pack(id:)` | Task 2 |
| `SquarePool.buildPool` — exclusions, most-common-wins override, exclusive tiles | Task 3 |
| Six bundled pack JSON files | Task 4 |
| `AppState.activePackIDs` persisted to UserDefaults | Task 5 |
| `AppState.togglePack` | Task 5 |
| `dealAndLaunchRound` uses `buildPool` | Task 5 |
| `MultipeerMessage.gameStarted` carries `activePackIDs` | Task 6 |
| `MultipeerMessage.playAgain` carries `activePackIDs` | Task 6 |
| Peers receive and store `activePackIDs` | Task 6 |
| 2-column pack grid with selection state | Task 7 |
| Rarity distribution bar + legend | Task 7 |
| Pool size indicator with warning | Task 7 |
| Read-only for non-host | Task 7 (`isReadOnly` in PackCardView) |
| "Tile Packs" button on HomeView | Task 8 |
| "Change Packs" button on PlayAgainView (host only) | Task 9 |
| AI-generated pack card images | Task 10 |
