"""Tests for tile_manager Python functions."""
import base64, json, sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent))
import tile_manager as tm


# ── build_prompt ──────────────────────────────────────────────────────────────
# New behaviour: description + STYLE only. No category hints at generation time.

def test_build_prompt_uses_description():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red Kenworth semi truck cab, side view"}
    result = tm.build_prompt(tile)
    assert result.startswith("A red Kenworth semi truck cab, side view.")
    assert "Flat vector illustration" in result


def test_build_prompt_no_category_hint_in_result():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red Kenworth semi truck cab"}
    result = tm.build_prompt(tile)
    # Category hints (e.g., "Side view, full vehicle visible.") must NOT appear
    assert "Side view, full vehicle visible." not in result


def test_build_prompt_falls_back_to_text_when_no_description():
    tile = {"text": "Semi Truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")
    assert "Flat vector illustration" in result
    assert "Side view, full vehicle visible." not in result


def test_build_prompt_falls_back_to_text_when_description_is_empty():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": ""}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")


def test_build_prompt_strips_trailing_period_from_description():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": "A red truck."}
    result = tm.build_prompt(tile)
    assert "A red truck.." not in result


def test_build_prompt_capitalises_first_letter():
    tile = {"text": "semi truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi truck.")


def test_build_prompt_all_periods_falls_back_to_text():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": "..."}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")


# ── File I/O ──────────────────────────────────────────────────────────────────

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
    assert loaded[0]["id"] == "1"
    assert loaded[1]["id"] == "2"


def test_image_path(tmp_path):
    with patch.object(tm, "TILE_IMAGES", tmp_path):
        p = tm.image_path("MY-UUID")
    assert p == tmp_path / "MY-UUID.png"


def test_save_image(tmp_path):
    png_b64 = (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
        "+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    )
    with patch.object(tm, "TILE_IMAGES", tmp_path):
        tm.save_image("TEST-ID", png_b64)
        saved = (tmp_path / "TEST-ID.png").read_bytes()
    assert saved == base64.b64decode(png_b64)


# ── Pack I/O ──────────────────────────────────────────────────────────────────

def test_discover_packs(tmp_path):
    pack_a = {
        "id": "alpha", "name": "Alpha", "description": "Desc A",
        "tiles": [{"id": "X", "rarity": "common"}, {"id": "Y", "rarity": "rare"}],
    }
    pack_b = {
        "id": "beta", "name": "Beta", "description": "Desc B",
        "tiles": [],
    }
    (tmp_path / "pack-alpha.json").write_text(json.dumps(pack_a))
    (tmp_path / "pack-beta.json").write_text(json.dumps(pack_b))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 2
    assert result[0]["id"] == "alpha"
    assert result[0]["tileCount"] == 2
    assert "overrideCount" not in result[0]
    assert "excludedCount" not in result[0]
    assert result[1]["id"] == "beta"
    assert result[1]["tileCount"] == 0


def test_discover_packs_ignores_non_pack_json(tmp_path):
    (tmp_path / "squares.json").write_text("[]")
    (tmp_path / "pack-one.json").write_text(json.dumps(
        {"id": "one", "name": "One", "tiles": []}
    ))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 1
    assert result[0]["id"] == "one"


def test_load_pack(tmp_path):
    data = {"id": "farm-country", "name": "Farm Country",
            "tiles": [{"id": "UUID-1", "rarity": "common"}]}
    (tmp_path / "pack-farm-country.json").write_text(json.dumps(data))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.load_pack("farm-country")
    assert result["name"] == "Farm Country"
    assert result["tiles"][0]["id"] == "UUID-1"


def test_load_pack_missing_raises(tmp_path):
    with patch.object(tm, "PACKS_DIR", tmp_path):
        with pytest.raises(FileNotFoundError):
            tm.load_pack("nonexistent")


def test_save_pack_round_trips(tmp_path):
    initial = {"id": "test", "name": "Test", "tiles": []}
    (tmp_path / "pack-test.json").write_text(json.dumps(initial))
    updated = {"id": "test", "name": "Test",
               "tiles": [{"id": "UUID-1", "rarity": "veryCommon"}]}
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("test", updated)
        result = tm.load_pack("test")
    assert result["tiles"][0]["id"] == "UUID-1"
    assert result["tiles"][0]["rarity"] == "veryCommon"


def test_save_pack_writes_trailing_newline(tmp_path):
    data = {"id": "x", "name": "X", "tiles": []}
    (tmp_path / "pack-x.json").write_text("{}")
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("x", data)
        raw = (tmp_path / "pack-x.json").read_text()
    assert raw.endswith("\n")


# ── description_prefill ───────────────────────────────────────────────────────

def test_description_prefill_known_category():
    result = tm.description_prefill("Suspension Bridge", "landmarks")
    assert result.startswith("Suspension Bridge.")
    assert "Full structure visible." in result


def test_description_prefill_unknown_category():
    result = tm.description_prefill("Mystery Object", "unknown")
    assert result == "Mystery Object."


# ── generate_image ─────────────────────────────────────────────────────────────

def test_generate_image_extracts_base64():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "candidates": [{"content": {"parts": [{"inlineData": {"data": "abc123base64=="}}]}}]
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
