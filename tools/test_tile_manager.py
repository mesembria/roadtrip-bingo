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

    import pytest
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

    called_url = mock_post.call_args[0][0]
    assert "my-secret-key" in called_url
