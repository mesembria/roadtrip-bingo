"""Tests for tile_manager.build_prompt()."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import tile_manager as tm


def test_uses_description_when_present():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red Kenworth semi truck cab, side view"}
    result = tm.build_prompt(tile)
    assert result.startswith("A red Kenworth semi truck cab, side view.")
    assert "Side view, full vehicle visible." in result
    assert "Flat vector illustration" in result


def test_falls_back_to_text_when_no_description():
    tile = {"text": "Semi Truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")
    assert "Side view, full vehicle visible." in result


def test_falls_back_to_text_when_description_is_empty_string():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": ""}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")


def test_strips_trailing_period_from_description():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red truck."}
    result = tm.build_prompt(tile)
    assert "A red truck.." not in result


def test_capitalises_first_letter():
    tile = {"text": "semi truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi truck.")


def test_unknown_category_omits_hint():
    tile = {"text": "Mystery", "category": "unknown_cat"}
    result = tm.build_prompt(tile)
    # Only subject + STYLE, no hint
    assert result.count(".") >= 1
    assert "Flat vector illustration" in result
