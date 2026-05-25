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
