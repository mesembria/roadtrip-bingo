import json, sys
from pathlib import Path
from unittest.mock import patch
import pytest

sys.path.insert(0, str(Path(__file__).parent))
import migrate_packs as mp

# Sample data
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
        "4A495FE0-B728-477D-8863-FD00E9140BB6": "veryCommon",  # IN base
        "99999999-9999-9999-9999-999999999999": "common",     # NOT in base
    },
    "excludedTileIDs": ["3DE3F367-3105-4F8B-A89D-2F134E21D01D"],
}
BASE_IDS = {"4A495FE0-B728-477D-8863-FD00E9140BB6"}


# is_old_format
def test_is_old_format_true_when_has_rarityOverrides():
    assert mp.is_old_format({"id": "x", "tiles": [], "rarityOverrides": {"UUID": "common"}})

def test_is_old_format_true_when_has_excludedTileIDs():
    assert mp.is_old_format({"id": "x", "tiles": [], "excludedTileIDs": ["UUID"]})

def test_is_old_format_true_when_tiles_have_text_key():
    assert mp.is_old_format({"id": "x", "tiles": [{"id": "U", "text": "Cow", "rarity": "common"}]})

def test_is_old_format_false_for_new_format_with_refs():
    assert not mp.is_old_format({"id": "x", "tiles": [{"id": "U", "rarity": "common"}]})

def test_is_old_format_false_for_empty_new_pack():
    assert not mp.is_old_format({"id": "x", "tiles": []})


# migrate_pack
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
    base_with_exclusive = BASE_IDS | {"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"}
    _, promoted = mp.migrate_pack(OLD_FARM, base_with_exclusive)
    assert len(promoted) == 0

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
    ref = next(t for t in new_pack["tiles"] if t["id"] == "4A495FE0-B728-477D-8863-FD00E9140BB6")
    assert ref["rarity"] == "veryCommon"

def test_migrate_pack_exclusive_tile_rarity_preserved():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    ref = next(t for t in new_pack["tiles"] if t["id"] == "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
    assert ref["rarity"] == "veryCommon"

def test_migrate_pack_preserves_pack_metadata():
    new_pack, _ = mp.migrate_pack(OLD_FARM, BASE_IDS)
    assert new_pack["id"] == "farm-country"
    assert new_pack["name"] == "Farm Country"
    assert new_pack["description"] == "Fields and barns."
    assert new_pack["imageName"] == "pack-farm-country"

def test_migrate_pack_already_new_format_is_identity():
    new_format = {"id": "done", "name": "Done", "description": ".", "imageName": "x",
                  "tiles": [{"id": "SOME-ID", "rarity": "common"}]}
    result_pack, promoted = mp.migrate_pack(new_format, set())
    assert result_pack == new_format
    assert promoted == []


# run_migration integration
def test_run_migration_writes_new_format(tmp_path):
    squares = [{"id": "BASE-0001", "text": "Semi Truck", "emoji": "🚛",
                "category": "vehicles", "rarity": "veryCommon"}]
    pack_data = {
        "id": "test-pack", "name": "Test Pack", "description": "Test.", "imageName": "pack-test",
        "tiles": [{"id": "EXCL-0001", "text": "Combine Harvester", "emoji": "🌾",
                   "category": "vehicles", "rarity": "common"}],
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
    assert "EXCL-0001" in sq_ids
    assert len(result_squares) == 2

def test_run_migration_idempotent(tmp_path):
    new_format = {"id": "done", "name": "Done", "description": ".", "imageName": "x",
                  "tiles": [{"id": "SOME-ID", "rarity": "common"}]}
    (tmp_path / "squares.json").write_text("[]")
    (tmp_path / "pack-done.json").write_text(json.dumps(new_format))

    with patch.object(mp, "SQUARES_JSON", tmp_path / "squares.json"), \
         patch.object(mp, "PACKS_DIR", tmp_path):
        mp.run_migration()
        mp.run_migration()

    result = json.loads((tmp_path / "pack-done.json").read_text())
    assert result == new_format

def test_run_migration_dry_run_does_not_write(tmp_path):
    pack_data = {
        "id": "test", "name": "Test", "description": "", "imageName": "pack-test",
        "tiles": [{"id": "X", "text": "Thing", "emoji": "🎯",
                   "category": "nature", "rarity": "common"}],
        "rarityOverrides": {}, "excludedTileIDs": [],
    }
    sq_path = tmp_path / "squares.json"
    pk_path = tmp_path / "pack-test.json"
    sq_path.write_text("[]")
    pk_path.write_text(json.dumps(pack_data))
    original_pack = pk_path.read_text()

    with patch.object(mp, "SQUARES_JSON", sq_path), \
         patch.object(mp, "PACKS_DIR", tmp_path):
        mp.run_migration(dry_run=True)

    assert pk_path.read_text() == original_pack
    assert sq_path.read_text() == "[]"
