#!/usr/bin/env python3
"""
Road Trip Bingo — Tile Manager
Usage: GEMINI_API_KEY=your_key python3 tools/tile_manager.py
Opens a browser UI for managing tiles in squares.json and TileImages/.
"""

import base64, json, os, sys, uuid, webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

import requests

# ── Paths (resolved relative to this script) ────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent
REPO_ROOT    = SCRIPT_DIR.parent
SQUARES_JSON = REPO_ROOT / "RoadTripBingo/Resources/squares.json"
TILE_IMAGES  = REPO_ROOT / "RoadTripBingo/Resources/TileImages"

# ── To add a new category: add it to BOTH constants below ───────────────────

CATEGORIES = [
    "vehicles", "nature", "food", "landmarks", "weather", "signs",
    # Add new categories here — they appear in the UI dropdowns automatically
]

CATEGORY_HINTS = {
    # Add a hint for each new category — shapes the image generation prompt
    "vehicles":  "Side view, full vehicle visible.",
    "nature":    "Full subject visible, centered.",
    "signs":     "The physical sign or object itself, not just a flat sign graphic.",
    "landmarks": "Full structure visible.",
    "food":      "Storefront or roadside view.",
    "weather":   "Dramatic sky scene.",
}

RARITIES = ["veryCommon", "common", "uncommon", "rare", "veryRare"]

STYLE = (
    "Flat vector illustration, clean thin outlines, bright colors. "
    "Plain solid white background — the illustration sits directly on white "
    "with absolutely no drop shadow, no border, no card, no frame, no vignette, "
    "no outline around the image edge. "
    "Square composition. No text, no labels, no letters."
)

# Per-tile prompt overrides for subjects that need extra specificity.
# Key = tile text, value = subject phrase (replaces "a {text.lower()}").
OVERRIDES: dict[str, str] = {}

GEMINI_MODEL = "gemini-2.5-flash-image"
GEMINI_URL   = (
    f"https://generativelanguage.googleapis.com/v1beta/models"
    f"/{GEMINI_MODEL}:generateContent"
)

PORT = 8765


def build_prompt(text: str, category: str) -> str:
    """Build the Gemini image generation prompt for a tile."""
    subject = OVERRIDES.get(text, f"a {text.lower()}")
    hint = CATEGORY_HINTS.get(category, "")
    # Strip trailing period and capitalize only the first character
    subject_clean = subject.rstrip(".")
    subject_cap = subject_clean[0].upper() + subject_clean[1:]
    parts = [f"{subject_cap}.", hint, STYLE]
    return " ".join(p for p in parts if p).strip()


# ── File I/O ─────────────────────────────────────────────────────────────────

def load_tiles() -> list[dict]:
    """Load all tiles from squares.json."""
    with open(SQUARES_JSON, encoding="utf-8") as f:
        return json.load(f)


def save_tiles(tiles: list[dict]) -> None:
    """Write tiles back to squares.json, preserving insertion order."""
    with open(SQUARES_JSON, "w", encoding="utf-8") as f:
        json.dump(tiles, f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")


def image_path(tile_id: str) -> Path:
    """Return the Path for a tile's PNG image."""
    return TILE_IMAGES / f"{tile_id}.png"


def save_image(tile_id: str, image_b64: str) -> None:
    """Decode base64 and write the image to TileImages/."""
    data = base64.b64decode(image_b64)
    image_path(tile_id).write_bytes(data)
