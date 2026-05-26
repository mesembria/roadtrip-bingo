#!/usr/bin/env python3
"""Tests for tile_manager.py pure functions.
Run: python3 -m pytest tools/test_tile_manager.py -v
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import tile_manager as tm


def test_build_prompt_includes_name():
    result = tm.build_prompt("Semi Truck", "vehicles")
    assert "semi truck" in result.lower()


def test_build_prompt_includes_category_hint():
    result = tm.build_prompt("Mountain", "nature")
    assert "Full subject visible" in result


def test_build_prompt_includes_style():
    result = tm.build_prompt("Cow", "nature")
    assert "Flat vector illustration" in result


def test_build_prompt_unknown_category_omits_hint():
    result = tm.build_prompt("Spaceship", "unknown")
    assert "spaceship" in result.lower()
    assert "Flat vector illustration" in result


def test_build_prompt_uses_override():
    original = dict(tm.OVERRIDES)
    tm.OVERRIDES["Widget"] = "a very specific widget description"
    try:
        result = tm.build_prompt("Widget", "vehicles")
        assert "very specific widget" in result
        assert "Flat vector illustration" in result  # style still applied
    finally:
        tm.OVERRIDES.clear()
        tm.OVERRIDES.update(original)


import base64, json
import pytest
from unittest.mock import MagicMock, patch


def test_load_tiles(tmp_path):
    data = [{"id": "AAA", "text": "Cow", "emoji": "🐄",
             "category": "nature", "rarity": "veryCommon"}]
    squares = tmp_path / "squares.json"
    squares.write_text(json.dumps(data))
    with patch.object(tm, "SQUARES_JSON", squares):
        result = tm.load_tiles()
    assert len(result) == 1
    assert result[0]["text"] == "Cow"


def test_save_tiles_round_trips(tmp_path):
    squares = tmp_path / "squares.json"
    data = [{"id": "BBB", "text": "Horse", "emoji": "🐎",
             "category": "nature", "rarity": "common"}]
    with patch.object(tm, "SQUARES_JSON", squares):
        tm.save_tiles(data)
        loaded = tm.load_tiles()
    assert loaded[0]["id"] == "BBB"
    assert loaded[0]["rarity"] == "common"


def test_save_tiles_preserves_insertion_order(tmp_path):
    squares = tmp_path / "squares.json"
    data = [
        {"id": "1", "text": "Zebra",  "emoji": "🦓", "category": "nature", "rarity": "rare"},
        {"id": "2", "text": "Antler", "emoji": "🦌", "category": "nature", "rarity": "common"},
    ]
    with patch.object(tm, "SQUARES_JSON", squares):
        tm.save_tiles(data)
        loaded = tm.load_tiles()
    assert loaded[0]["id"] == "1"   # order preserved
    assert loaded[1]["id"] == "2"


def test_image_path(tmp_path):
    with patch.object(tm, "TILE_IMAGES", tmp_path):
        p = tm.image_path("MY-UUID")
    assert p == tmp_path / "MY-UUID.png"


def test_save_image(tmp_path):
    # 1×1 transparent PNG, base64-encoded
    png_b64 = (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
        "+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    )
    with patch.object(tm, "TILE_IMAGES", tmp_path):
        tm.save_image("TEST-ID", png_b64)
        saved = (tmp_path / "TEST-ID.png").read_bytes()
    assert saved == base64.b64decode(png_b64)


def test_generate_image_extracts_base64():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "candidates": [{
            "content": {
                "parts": [{"inlineData": {"data": "abc123base64=="}}]
            }
        }]
    }
    mock_resp.raise_for_status = MagicMock()

    with patch("tile_manager.requests.post", return_value=mock_resp):
        result = tm.generate_image("A cow.", "fake-key")

    assert result == "abc123base64=="


def test_generate_image_raises_when_no_image_part():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "candidates": [{"content": {"parts": [{"text": "no image here"}]}}]
    }
    mock_resp.raise_for_status = MagicMock()

    with patch("tile_manager.requests.post", return_value=mock_resp):
        with pytest.raises(ValueError, match="No image"):
            tm.generate_image("A cow.", "fake-key")


def test_generate_image_passes_api_key_in_url():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "candidates": [{"content": {"parts": [{"inlineData": {"data": "x"}}]}}]
    }
    mock_resp.raise_for_status = MagicMock()

    with patch("tile_manager.requests.post", return_value=mock_resp) as mock_post:
        tm.generate_image("prompt", "my-secret-key")

    called_url = mock_post.call_args.args[0]
    assert "my-secret-key" in called_url


# ── Pack I/O tests ────────────────────────────────────────────────────────────

def test_discover_packs(tmp_path):
    """discover_packs returns summary info sorted by filename."""
    pack_a = {
        "id": "alpha", "name": "Alpha", "description": "Desc A",
        "tiles": [{"id": "X", "text": "T", "emoji": "🎯", "category": "nature", "rarity": "common"}],
        "rarityOverrides": {},
        "excludedTileIDs": ["Y"],
    }
    pack_b = {
        "id": "beta", "name": "Beta", "description": "Desc B",
        "tiles": [],
        "rarityOverrides": {"UUID-1": "common", "UUID-2": "veryCommon"},
        "excludedTileIDs": [],
    }
    (tmp_path / "pack-alpha.json").write_text(json.dumps(pack_a))
    (tmp_path / "pack-beta.json").write_text(json.dumps(pack_b))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 2
    assert result[0]["id"] == "alpha"
    assert result[0]["tileCount"] == 1
    assert result[0]["overrideCount"] == 0
    assert result[0]["excludedCount"] == 1
    assert result[1]["id"] == "beta"
    assert result[1]["tileCount"] == 0
    assert result[1]["overrideCount"] == 2


def test_discover_packs_ignores_non_pack_json(tmp_path):
    (tmp_path / "squares.json").write_text("[]")
    (tmp_path / "pack-one.json").write_text(json.dumps(
        {"id": "one", "name": "One", "tiles": [], "rarityOverrides": {}, "excludedTileIDs": []}
    ))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 1
    assert result[0]["id"] == "one"


def test_load_pack(tmp_path):
    data = {"id": "farm-country", "name": "Farm Country", "tiles": [],
            "rarityOverrides": {}, "excludedTileIDs": []}
    (tmp_path / "pack-farm-country.json").write_text(json.dumps(data))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.load_pack("farm-country")
    assert result["name"] == "Farm Country"


def test_load_pack_missing_raises(tmp_path):
    with patch.object(tm, "PACKS_DIR", tmp_path):
        with pytest.raises(FileNotFoundError):
            tm.load_pack("nonexistent")


def test_save_pack_round_trips(tmp_path):
    initial = {"id": "test", "name": "Test", "tiles": [],
               "rarityOverrides": {}, "excludedTileIDs": []}
    (tmp_path / "pack-test.json").write_text(json.dumps(initial))
    updated = {"id": "test", "name": "Test", "tiles": [{"id": "T1", "text": "Cow",
               "emoji": "🐄", "category": "nature", "rarity": "veryCommon"}],
               "rarityOverrides": {"UUID-A": "common"}, "excludedTileIDs": ["UUID-B"]}
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("test", updated)
        result = tm.load_pack("test")
    assert result["tiles"][0]["id"] == "T1"
    assert result["rarityOverrides"]["UUID-A"] == "common"
    assert result["excludedTileIDs"] == ["UUID-B"]


def test_save_pack_writes_trailing_newline(tmp_path):
    data = {"id": "x", "name": "X", "tiles": [], "rarityOverrides": {}, "excludedTileIDs": []}
    (tmp_path / "pack-x.json").write_text("{}")
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("x", data)
        raw = (tmp_path / "pack-x.json").read_text()
    assert raw.endswith("\n")
