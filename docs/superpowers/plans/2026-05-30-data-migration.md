# Data Migration + SquarePool Update — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all pack JSON files from old implicit-pool format to new explicit tile-ref format, and update the Swift `TilePack` model + `SquarePool.buildPool` to match.

**Architecture:** Three independent changes: (1) Swift model change — `TilePack.tiles` becomes `[PackTileRef]`, (2) `SquarePool.buildPool` resolves explicit tile refs against the base pool instead of filtering/appending, (3) one-time Python migration script promotes exclusive tiles into `squares.json` and rewrites pack files. Run Plan 1 (this plan) in full before starting Plan 2 (tile manager v2).

**Tech Stack:** Swift/XCTest for model + engine changes; Python 3 + pytest for migration script.

---

## File Map

| Status | Path | Change |
|--------|------|--------|
| Modify | `RoadTripBingo/Models/TilePack.swift` | Add `PackTileRef`; update `TilePack.tiles` type |
| Modify | `RoadTripBingoTests/TilePackTests.swift` | Rewrite tests for new JSON format |
| Modify | `RoadTripBingo/Game/SquarePool.swift` | Replace `buildPool` body |
| Modify | `RoadTripBingoTests/SquarePoolTests.swift` | Rewrite buildPool tests + update pack() helper |
| Create | `tools/migrate_packs.py` | One-time migration script |
| Create | `tools/test_migrate_packs.py` | pytest tests for migration logic |

---

## Task 1: TilePack Swift model — add PackTileRef, update TilePack

**Files:**
- Modify: `RoadTripBingo/Models/TilePack.swift`
- Modify: `RoadTripBingoTests/TilePackTests.swift`

- [ ] **Step 1: Write the failing tests**

Replace all content in `RoadTripBingoTests/TilePackTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/TilePackTests 2>&1 | tail -20
```

Expected: FAIL — `tiles: [BingoSquare]` cannot decode `{"id": ..., "rarity": ...}` and `rarityOverrides` / `excludedTileIDs` are required by current decoder.

- [ ] **Step 3: Replace TilePack.swift with new model**

```swift
import Foundation

/// A lightweight reference to a tile within a pack: just the tile UUID and pack-specific rarity.
/// Full tile metadata (name, category, image) always lives in squares.json.
struct PackTileRef: Codable {
    let id: String
    let rarity: SquareRarity
}

struct TilePack: Codable, Identifiable {
    /// Stable string ID matching the JSON filename suffix (e.g. "farm-country").
    let id: String
    /// Display name shown in the pack selection grid.
    let name: String
    /// Short flavor text shown below the pack name.
    let description: String
    /// Asset catalog image name for the pack card image.
    let imageName: String
    /// Explicit curated list of tile refs. Every tile in this pack appears here.
    let tiles: [PackTileRef]
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/TilePackTests 2>&1 | tail -20
```

Expected: PASS — all 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Models/TilePack.swift RoadTripBingoTests/TilePackTests.swift
git commit -m "feat: PackTileRef struct, TilePack uses explicit tile ref list"
```

---

## Task 2: SquarePool.buildPool — resolve explicit tile refs

**Files:**
- Modify: `RoadTripBingo/Game/SquarePool.swift`
- Modify: `RoadTripBingoTests/SquarePoolTests.swift`

- [ ] **Step 1: Write the failing buildPool tests**

In `RoadTripBingoTests/SquarePoolTests.swift`, replace the `// MARK: - buildPool` section (from the `private func square(...)` helper through end of file) with:

```swift
    // MARK: - buildPool

    // Helper: make a minimal BingoSquare for tests
    private func square(_ id: String, rarity: SquareRarity, text: String = "Test") -> BingoSquare {
        BingoSquare(id: UUID(uuidString: id)!, text: text, emoji: nil,
                    category: .vehicles, rarity: rarity)
    }

    // Helper: make a TilePack with explicit {id, rarity} tile refs
    private func pack(id: String = "test", tileRefs: [(String, SquareRarity)] = []) -> TilePack {
        let refs = tileRefs.map { PackTileRef(id: $0.0, rarity: $0.1) }
        return TilePack(id: id, name: id, description: "", imageName: "", tiles: refs)
    }

    func test_buildPool_emptyPacksReturnsBaseUnchanged() {
        let id1 = "00000000-0000-0000-0000-000000000001"
        let base = [square(id1, rarity: .common)]
        let result = SquarePool.buildPool(base: base, activePacks: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].rarity, .common)
    }

    func test_buildPool_onlyIncludesReferencedTiles() {
        let id1 = "00000000-0000-0000-0000-000000000001"
        let id2 = "00000000-0000-0000-0000-000000000002"
        let id3 = "00000000-0000-0000-0000-000000000003"
        let base = [
            square(id1, rarity: .common, text: "A"),
            square(id2, rarity: .common, text: "B"),
            square(id3, rarity: .common, text: "C"),
        ]
        let p = pack(tileRefs: [(id1, .common), (id3, .common)])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.text == "A" })
        XCTAssertTrue(result.contains { $0.text == "C" })
        XCTAssertFalse(result.contains { $0.text == "B" },
                       "Tile not in pack's refs must not appear in pool")
    }

    func test_buildPool_appliesPackRarity() {
        let tractorID = "4A495FE0-B728-477D-8863-FD00E9140BB6"
        let base = [square(tractorID, rarity: .uncommon, text: "Tractor")]
        let farmPack = pack(tileRefs: [(tractorID, .veryCommon)])
        let result = SquarePool.buildPool(base: base, activePacks: [farmPack])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.rarity, .veryCommon,
                       "Pack-specific rarity should override tile's default rarity")
    }

    func test_buildPool_sameRarityReturnsSameTileObject() {
        // When pack rarity == tile's default rarity, the original BingoSquare is returned
        let id = "4A495FE0-B728-477D-8863-FD00E9140BB6"
        let base = [square(id, rarity: .common, text: "Tractor")]
        let p = pack(tileRefs: [(id, .common)])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.first?.text, "Tractor")
        XCTAssertEqual(result.first?.rarity, .common)
    }

    func test_buildPool_mostCommonWinsWhenTwoPacksReferSameTile() {
        let id = "4A495FE0-B728-471D-8863-FD00E9140BB6"
        let base = [square(id, rarity: .uncommon)]
        let pack1 = pack(id: "a", tileRefs: [(id, .common)])
        let pack2 = pack(id: "b", tileRefs: [(id, .veryCommon)])
        let result = SquarePool.buildPool(base: base, activePacks: [pack1, pack2])
        XCTAssertEqual(result.first?.rarity, .veryCommon,
                       "veryCommon should beat common under most-common-wins")
    }

    func test_buildPool_unknownRefIDIsIgnored() {
        let validID = "00000000-0000-0000-0000-000000000001"
        let base = [square(validID, rarity: .common)]
        let p = pack(tileRefs: [(validID, .common), ("not-a-uuid", .rare)])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.count, 1, "Malformed UUID in pack ref should be silently ignored")
    }

    func test_buildPool_refToNonExistentTileIsIgnored() {
        let existingID = "00000000-0000-0000-0000-000000000001"
        let missingID  = "00000000-0000-0000-0000-000000000099"
        let base = [square(existingID, rarity: .common)]
        let p = pack(tileRefs: [(existingID, .common), (missingID, .rare)])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.count, 1,
                       "Ref to a tile not in base should be silently ignored")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests 2>&1 | tail -30
```

Expected: FAIL — `pack()` helper signature mismatch (old uses `tiles: [BingoSquare]`, new uses `tileRefs:`); `PackTileRef` type not available in test scope; new test assertions don't match old buildPool behaviour.

- [ ] **Step 3: Replace buildPool in SquarePool.swift**

Replace the entire `buildPool` method (lines 105–141 in the original):

```swift
    /// Combines the base pool with a set of active packs.
    ///
    /// Each pack carries an explicit, curated tile list as `{id, rarity}` refs.
    /// A tile must be referenced by at least one active pack to appear in the result;
    /// tiles in `base` but not referenced by any pack are excluded.
    ///
    /// When two active packs reference the same tile with different rarities,
    /// the most-common rarity wins (most-common-wins rule).
    ///
    /// When `activePacks` is empty, returns `base` unmodified (base game with no pack active).
    static func buildPool(base: [BingoSquare], activePacks: [TilePack]) -> [BingoSquare] {
        guard !activePacks.isEmpty else { return base }

        // Build a fast lookup: UUID → BingoSquare
        let baseByID = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })

        // Resolve all tile refs: UUID → most-common rarity across all active packs
        var resolved: [UUID: SquareRarity] = [:]
        for pack in activePacks {
            for ref in pack.tiles {
                guard let id = UUID(uuidString: ref.id) else { continue }
                resolved[id] = resolved[id].map { mostCommon($0, ref.rarity) } ?? ref.rarity
            }
        }

        // Map each resolved ref to a BingoSquare, applying pack rarity when different
        return resolved.compactMap { id, rarity in
            guard let tile = baseByID[id] else { return nil }
            if tile.rarity == rarity { return tile }
            return BingoSquare(id: tile.id, text: tile.text, emoji: tile.emoji,
                               category: tile.category, rarity: rarity)
        }
    }
```

> The `mostCommon` helper below it is unchanged — keep it as-is.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests 2>&1 | tail -30
```

Expected: PASS — all SquarePoolTests green, including the newly added ones. Verify `dealBoards`, `dealReserve`, `adjustedWeights`, `load` tests are still passing (those functions are untouched).

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Game/SquarePool.swift RoadTripBingoTests/SquarePoolTests.swift
git commit -m "feat: SquarePool.buildPool resolves explicit pack tile refs"
```

---

## Task 3: Migration script — tools/migrate_packs.py

**Files:**
- Create: `tools/migrate_packs.py`
- Create: `tools/test_migrate_packs.py`

- [ ] **Step 1: Write the failing tests**

Create `tools/test_migrate_packs.py`:

```python
"""Tests for migrate_packs module: is_old_format, migrate_pack, run_migration."""
import json
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent))
import migrate_packs as mp


# ── Sample data ──────────────────────────────────────────────────────────────

OLD_FARM = {
    "id": "farm-country",
    "name": "Farm Country",
    "description": "Fields and barns.",
    "imageName": "pack-farm-country",
    "tiles": [
        {
            "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            "text": "Combine Harvester",
            "emoji": "🌾",
            "category": "vehicles",
            "rarity": "veryCommon",
            "description": "A large green combine harvester",
        }
    ],
    "rarityOverrides": {
        # BASE-IN: this tile exists in base → gets a ref
        "4A495FE0-B728-477D-8863-FD00E9140BB6": "veryCommon",
        # BASE-MISSING: this tile is NOT in base → ref skipped
        "99999999-9999-9999-9999-999999999999": "common",
    },
    "excludedTileIDs": [
        "3DE3F367-3105-4F8B-A89D-2F134E21D01D",
    ],
}

# Base contains only one of the two overridden tiles
BASE_IDS = {"4A495FE0-B728-477D-8863-FD00E9140BB6"}


# ── is_old_format ─────────────────────────────────────────────────────────────

def test_is_old_format_true_when_has_rarityOverrides():
    pack = {"id": "x", "tiles": [], "rarityOverrides": {"UUID": "common"}}
    assert mp.is_old_format(pack)


def test_is_old_format_true_when_has_excludedTileIDs():
    pack = {"id": "x", "tiles": [], "excludedTileIDs": ["UUID"]}
    assert mp.is_old_format(pack)


def test_is_old_format_true_when_tiles_have_text_key():
    pack = {"id": "x", "tiles": [{"id": "U", "text": "Cow", "rarity": "common"}]}
    assert mp.is_old_format(pack)


def test_is_old_format_false_for_new_format_with_refs():
    pack = {"id": "x", "tiles": [{"id": "U", "rarity": "common"}]}
    assert not mp.is_old_format(pack)


def test_is_old_format_false_for_empty_new_pack():
    pack = {"id": "x", "tiles": []}
    assert not mp.is_old_format(pack)


# ── migrate_pack ──────────────────────────────────────────────────────────────

def test_migrate_pack_removes_rarityOverrides():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    assert "rarityOverrides" not in new_pack


def test_migrate_pack_removes_excludedTileIDs():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    assert "excludedTileIDs" not in new_pack


def test_migrate_pack_promotes_exclusive_tile_not_in_base():
    _, promoted = mp.migrate_pack(OLD_FARM, BASE_IDS)
    assert len(promoted) == 1
    assert promoted[0]["id"] == "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
    assert promoted[0]["text"] == "Combine Harvester"


def test_migrate_pack_does_not_promote_tile_already_in_base():
    base_ids_with_exclusive = BASE_IDS | {"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"}
    _, promoted = mp.migrate_pack(OLD_FARM, base_ids_with_exclusive)
    assert len(promoted) == 0, "Tile already in base should not be promoted again"


def test_migrate_pack_exclusive_tile_appears_as_ref():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    ref_ids = {t["id"] for t in new_pack["tiles"]}
    assert "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA" in ref_ids


def test_migrate_pack_override_tile_in_base_appears_as_ref():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    ref_ids = {t["id"] for t in new_pack["tiles"]}
    assert "4A495FE0-B728-477D-8863-FD00E9140BB6" in ref_ids


def test_migrate_pack_override_tile_missing_from_base_is_skipped():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    ref_ids = {t["id"] for t in new_pack["tiles"]}
    assert "99999999-9999-9999-9999-999999999999" not in ref_ids


def test_migrate_pack_excluded_tile_not_in_refs():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    ref_ids = {t["id"] for t in new_pack["tiles"]}
    assert "3DE3F367-3105-4F8B-A89D-2F134E21D01D" not in ref_ids


def test_migrate_pack_override_rarity_preserved():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    ref = next(t for t in new_pack["tiles"]
               if t["id"] == "4A495FE0-B728-477D-8863-FD00E9140BB6")
    assert ref["rarity"] == "veryCommon"


def test_migrate_pack_exclusive_tile_rarity_preserved():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    ref = next(t for t in new_pack["tiles"]
               if t["id"] == "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
    assert ref["rarity"] == "veryCommon"


def test_migrate_pack_preserves_pack_metadata():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    assert new_pack["id"] == "farm-country"
    assert new_pack["name"] == "Farm Country"
    assert new_pack["description"] == "Fields and barns."
    assert new_pack["imageName"] == "pack-farm-country"


def test_migrate_pack_already_new_format_is_identity():
    new_format = {
        "id": "done",
        "name": "Done",
        "description": "Already migrated.",
        "imageName": "pack-done",
        "tiles": [{"id": "SOME-ID", "rarity": "common"}],
    }
    result_pack, promoted = mp.migrate_pack(new_format, set())
    assert result_pack == new_format
    assert promoted == []


# ── run_migration integration ─────────────────────────────────────────────────

def test_run_migration_writes_new_format(tmp_path):
    squares = [
        {"id": "BASE-0001", "text": "Semi Truck", "emoji": "🚛",
         "category": "vehicles", "rarity": "veryCommon"}
    ]
    pack_data = {
        "id": "test-pack",
        "name": "Test Pack",
        "description": "Test.",
        "imageName": "pack-test",
        "tiles": [
            {"id": "EXCL-0001", "text": "Combine Harvester", "emoji": "🌾",
             "category": "vehicles", "rarity": "common"}
        ],
        "rarityOverrides": {"BASE-0001": "veryCommon"},
        "excludedTileIDs": [],
    }
    (tmp_path / "squares.json").write_text(json.dumps(squares))
    (tmp_path / "pack-test-pack.json").write_text(json.dumps(pack_data))

    with patch.object(mp, "SQUARES_JSON", tmp_path / "squares.json"), \
         patch.object(mp, "PACKS_DIR", tmp_path):
        mp.run_migration()

    result_pack = json.loads((tmp_path / "pack-test-pack.json").read_text())
    assert "rarityOverrides" not in result_pack
    assert "excludedTileIDs" not in result_pack
    ref_ids = {t["id"] for t in result_pack["tiles"]}
    assert "EXCL-0001" in ref_ids
    assert "BASE-0001" in ref_ids

    result_squares = json.loads((tmp_path / "squares.json").read_text())
    sq_ids = {s["id"] for s in result_squares}
    assert "EXCL-0001" in sq_ids, "Exclusive tile should be promoted to squares.json"
    assert len(result_squares) == 2, "squares.json should gain exactly one promoted tile"


def test_run_migration_idempotent(tmp_path):
    new_format_pack = {
        "id": "already-done",
        "name": "Already Done",
        "description": "Already migrated.",
        "imageName": "pack-already-done",
        "tiles": [{"id": "SOME-ID", "rarity": "common"}],
    }
    squares = []
    (tmp_path / "squares.json").write_text(json.dumps(squares))
    (tmp_path / "pack-already-done.json").write_text(json.dumps(new_format_pack))

    with patch.object(mp, "SQUARES_JSON", tmp_path / "squares.json"), \
         patch.object(mp, "PACKS_DIR", tmp_path):
        mp.run_migration()
        mp.run_migration()  # run twice — should be stable

    result = json.loads((tmp_path / "pack-already-done.json").read_text())
    assert result == new_format_pack, "Already-migrated pack must be unchanged on second run"


def test_run_migration_dry_run_does_not_write(tmp_path):
    squares = []
    pack_data = {
        "id": "test",
        "name": "Test",
        "description": "",
        "imageName": "pack-test",
        "tiles": [{"id": "X", "text": "Thing", "emoji": "🎯",
                   "category": "nature", "rarity": "common"}],
        "rarityOverrides": {},
        "excludedTileIDs": [],
    }
    sq_path = tmp_path / "squares.json"
    pk_path = tmp_path / "pack-test.json"
    sq_path.write_text(json.dumps(squares))
    pk_path.write_text(json.dumps(pack_data))
    original_pack = pk_path.read_text()

    with patch.object(mp, "SQUARES_JSON", sq_path), \
         patch.object(mp, "PACKS_DIR", tmp_path):
        mp.run_migration(dry_run=True)

    assert pk_path.read_text() == original_pack, "dry_run must not write pack file"
    assert sq_path.read_text() == json.dumps(squares), "dry_run must not write squares.json"
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /path/to/roadtrip-bingo
python3 -m pytest tools/test_migrate_packs.py -v 2>&1 | tail -20
```

Expected: FAIL — `migrate_packs` module not found.

- [ ] **Step 3: Create tools/migrate_packs.py**

```python
#!/usr/bin/env python3
"""
tools/migrate_packs.py
One-time migration from old pack format to new explicit tile-ref format.

Old format:
  tiles: [{id, text, emoji, category, rarity, ...}]  # full tile objects (exclusive)
  rarityOverrides: {uuid: rarity}
  excludedTileIDs: [uuid, ...]

New format:
  tiles: [{id, rarity}]   # explicit tile refs only

Seeding strategy:
  - Exclusive tiles (full objects in old tiles array):
      → Promote full metadata to squares.json (if not already there)
      → Add {id, rarity} ref to new pack
  - Rarity-overridden tiles (rarityOverrides entries):
      → Add {id, rarity} ref with override rarity (only if tile exists in base)
  - Everything else (base tiles not explicitly configured, excluded tiles):
      → NOT added to pack

Usage:
  python3 tools/migrate_packs.py           # live migration
  python3 tools/migrate_packs.py --dry-run # preview changes without writing
"""

import json
import sys
from pathlib import Path

SCRIPT_DIR   = Path(__file__).parent
REPO_ROOT    = SCRIPT_DIR.parent
SQUARES_JSON = REPO_ROOT / "RoadTripBingo/Resources/squares.json"
PACKS_DIR    = REPO_ROOT / "RoadTripBingo/Resources"


def load_squares() -> list[dict]:
    with open(SQUARES_JSON, encoding="utf-8") as f:
        return json.load(f)


def save_squares(squares: list[dict], dry_run: bool = False) -> None:
    if dry_run:
        print(f"  [dry-run] would write {len(squares)} tiles to squares.json")
        return
    with open(SQUARES_JSON, "w", encoding="utf-8") as f:
        json.dump(squares, f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")


def is_old_format(pack_data: dict) -> bool:
    """True if pack uses old format (has rarityOverrides/excludedTileIDs, or tiles with 'text')."""
    if "rarityOverrides" in pack_data or "excludedTileIDs" in pack_data:
        return True
    return any("text" in tile for tile in pack_data.get("tiles", []))


def migrate_pack(pack_data: dict, base_ids: set[str]) -> tuple[dict, list[dict]]:
    """Convert one pack from old to new format. Returns (new_pack, promoted_tiles).

    promoted_tiles: full tile dicts to append to squares.json.
    If pack is already in new format (is_old_format returns False), returns it unchanged.
    """
    if not is_old_format(pack_data):
        return pack_data, []

    new_tile_refs: list[dict] = []
    promoted_tiles: list[dict] = []
    seen_ids: set[str] = set()

    # 1. Exclusive tiles: promote full tile to squares.json, add {id, rarity} ref
    for tile in pack_data.get("tiles", []):
        tile_id = tile.get("id", "")
        if not tile_id or tile_id in seen_ids:
            continue
        seen_ids.add(tile_id)
        if tile_id not in base_ids:
            promoted_tiles.append(tile)
        new_tile_refs.append({"id": tile_id, "rarity": tile["rarity"]})

    # 2. Rarity-overridden tiles: add {id, rarity} with override rarity
    #    Skip if not in base (and not just promoted) — avoids dangling refs.
    promoted_ids = {t["id"] for t in promoted_tiles}
    for tile_id, rarity in pack_data.get("rarityOverrides", {}).items():
        if tile_id in seen_ids:
            continue
        if tile_id not in base_ids and tile_id not in promoted_ids:
            continue  # dangling ref — base tile doesn't exist
        seen_ids.add(tile_id)
        new_tile_refs.append({"id": tile_id, "rarity": rarity})

    # 3. excludedTileIDs — silently dropped (not-in-pack is the natural default)

    new_pack = {
        "id":          pack_data["id"],
        "name":        pack_data["name"],
        "description": pack_data.get("description", ""),
        "imageName":   pack_data.get("imageName", ""),
        "tiles":       new_tile_refs,
    }
    return new_pack, promoted_tiles


def _save_pack(pack_data: dict, path: Path, dry_run: bool = False) -> None:
    if dry_run:
        print(f"  [dry-run] would write {len(pack_data['tiles'])} tile refs to {path.name}")
        return
    with open(path, "w", encoding="utf-8") as f:
        json.dump(pack_data, f, indent=2, sort_keys=False, ensure_ascii=False)
        f.write("\n")


def run_migration(dry_run: bool = False) -> None:
    squares = load_squares()
    base_ids = {s["id"] for s in squares}
    all_promoted: list[dict] = []

    pack_paths = sorted(PACKS_DIR.glob("pack-*.json"))
    if not pack_paths:
        print("No pack-*.json files found.")
        return

    for path in pack_paths:
        with open(path, encoding="utf-8") as f:
            pack_data = json.load(f)

        if not is_old_format(pack_data):
            print(f"✓ {path.name} — already migrated, skipping")
            continue

        n_exclusive = sum(1 for t in pack_data.get("tiles", []) if "text" in t)
        n_overrides = len(pack_data.get("rarityOverrides", {}))
        n_excluded  = len(pack_data.get("excludedTileIDs", []))

        new_pack, promoted = migrate_pack(pack_data, base_ids)

        # Track promoted IDs so subsequent packs recognise them as base tiles
        for t in promoted:
            base_ids.add(t["id"])
        all_promoted.extend(promoted)

        _save_pack(new_pack, path, dry_run)

        print(
            f"  {path.name}: {n_exclusive} exclusive promoted, "
            f"{n_overrides} overrides → refs ({len(new_pack['tiles'])} total refs), "
            f"{n_excluded} excluded dropped"
        )

    if all_promoted:
        squares.extend(all_promoted)
        save_squares(squares, dry_run)
        print(f"\nsquares.json: +{len(all_promoted)} promoted tiles → {len(squares)} total")
    else:
        print("\nsquares.json: no changes needed")


if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    if dry_run:
        print("=== DRY RUN — no files will be written ===\n")
    run_migration(dry_run=dry_run)
    print("\nDone.")
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
python3 -m pytest tools/test_migrate_packs.py -v 2>&1 | tail -30
```

Expected: PASS — all tests green, including idempotency and dry_run tests.

- [ ] **Step 5: Commit**

```bash
git add tools/migrate_packs.py tools/test_migrate_packs.py
git commit -m "feat: migration script — promote exclusive tiles, convert packs to ref format"
```

---

## Task 4: Run the migration on actual data + verify

**Files:** All `pack-*.json` in `RoadTripBingo/Resources/`, `squares.json`

- [ ] **Step 1: Dry run — preview changes**

```bash
python3 tools/migrate_packs.py --dry-run
```

Expected output (approximate):
```
=== DRY RUN — no files will be written ===

  pack-beach-coast.json: 4 exclusive promoted, 6 overrides → refs (10 total refs), 0 excluded dropped
  pack-city.json: 9 exclusive promoted, 9 overrides → refs (18 total refs), N excluded dropped
  pack-desert-southwest.json: 6 exclusive promoted, 7 overrides → refs (13 total refs), N excluded dropped
  pack-farm-country.json: 4 exclusive promoted, 11 overrides → refs (15 total refs), N excluded dropped
  pack-interstate.json: 6 exclusive promoted, 8 overrides → refs (14 total refs), N excluded dropped
  pack-mountains.json: 7 exclusive promoted, 9 overrides → refs (16 total refs), 3 excluded dropped

squares.json: +36 promoted tiles → 234 total

Done.
```

Verify the summary looks reasonable (36 promoted tiles = 4+9+6+4+6+7 exclusive tiles across all packs, 198+36=234 total).

- [ ] **Step 2: Run the actual migration**

```bash
python3 tools/migrate_packs.py
```

Same output without `[dry-run]` prefix. Verify no errors.

- [ ] **Step 3: Verify squares.json**

```bash
python3 -c "
import json
with open('RoadTripBingo/Resources/squares.json') as f:
    sq = json.load(f)
print(f'Total tiles: {len(sq)}')
ids = [s['id'] for s in sq]
print(f'Unique IDs: {len(set(ids))}')
print(f'All have required keys: {all(\"id\" in s and \"text\" in s and \"rarity\" in s for s in sq)}')
"
```

Expected: `Total tiles: 234`, `Unique IDs: 234`, `All have required keys: True`.

- [ ] **Step 4: Verify a migrated pack**

```bash
python3 -c "
import json
with open('RoadTripBingo/Resources/pack-mountains.json') as f:
    p = json.load(f)
print('Keys:', list(p.keys()))
print('Tile refs:', len(p['tiles']))
print('First ref:', p['tiles'][0])
print('rarityOverrides present:', 'rarityOverrides' in p)
print('excludedTileIDs present:', 'excludedTileIDs' in p)
"
```

Expected:
```
Keys: ['id', 'name', 'description', 'imageName', 'tiles']
Tile refs: 16
First ref: {'id': '...', 'rarity': '...'}
rarityOverrides present: False
excludedTileIDs present: False
```

- [ ] **Step 5: Run all Python tests to confirm no regressions**

```bash
python3 -m pytest tools/test_tile_manager.py tools/test_migrate_packs.py -v 2>&1 | tail -20
```

Expected: PASS — all tests green. `test_save_pack_round_trips` in `test_tile_manager.py` currently saves old-format fields. Check if it fails — if so, it's a pre-existing test that uses the old format for save_pack (which is format-agnostic — it just writes whatever dict you give it). That test should still pass since `save_pack` doesn't validate structure.

- [ ] **Step 6: Build the Swift app to confirm it compiles**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run all Swift tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test 2>&1 | tail -20
```

Expected: All tests pass. Note: `test_load_*` tests (which load from the real `squares.json` bundled in the app) will still pass — the bundle is read at runtime, so changes to the JSON on disk don't affect already-bundled test runs. The test that checks for at least 150 tiles (`test_load_returnsAtLeast150Squares`) will easily pass with 234.

- [ ] **Step 8: Commit everything**

```bash
git add RoadTripBingo/Resources/squares.json \
        RoadTripBingo/Resources/pack-beach-coast.json \
        RoadTripBingo/Resources/pack-city.json \
        RoadTripBingo/Resources/pack-desert-southwest.json \
        RoadTripBingo/Resources/pack-farm-country.json \
        RoadTripBingo/Resources/pack-interstate.json \
        RoadTripBingo/Resources/pack-mountains.json
git commit -m "chore: migrate packs to explicit tile-ref format, promote 36 exclusive tiles"
```

---

## Post-migration state

After this plan completes:
- `squares.json`: 234 tiles (was 198; +36 exclusive tiles promoted from packs)
- Each `pack-*.json`: lean starting list of 10–18 tiles (exclusive + overridden only)
- Swift app: compiles and runs — packs load their explicit tile lists; game deals from those tiles only
- Pack content is intentionally lean — curation happens via the Tile Manager v2 tool (Plan 2)
