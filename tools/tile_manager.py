#!/usr/bin/env python3
"""
Road Trip Bingo — Tile Manager
Usage: GEMINI_API_KEY=your_key python3 tools/tile_manager.py
Opens a browser UI for managing tiles in squares.json and TileImages/.
"""

import base64, json, os, sys, uuid, webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse

try:
    import requests
except ImportError:
    raise SystemExit("requests is required: pip install requests")

# ── Paths (resolved relative to this script) ────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent
REPO_ROOT    = SCRIPT_DIR.parent
SQUARES_JSON = REPO_ROOT / "RoadTripBingo/Resources/squares.json"
TILE_IMAGES  = REPO_ROOT / "RoadTripBingo/Resources/TileImages"
PACKS_DIR    = REPO_ROOT / "RoadTripBingo/Resources"

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
    "Flat vector illustration, clean thin outlines, bright but realistic colors. "
    "Use natural, true-to-life colors for each object and all parts should match "
    "the colors that object would actually have in real life. "
    "Plain solid white background — the illustration sits directly on white "
    "with absolutely no drop shadow, no border, no card, no frame, no vignette, "
    "no outline around the image edge. "
    "Square composition. No text, no labels, no letters."
)

GEMINI_MODEL = "gemini-2.5-flash-image"
GEMINI_URL   = (
    f"https://generativelanguage.googleapis.com/v1beta/models"
    f"/{GEMINI_MODEL}:generateContent"
)

PORT = 8765

# Populated at server startup; injected into the HTML SPA.
PACKS_METADATA: list[dict] = []


def build_prompt(tile: dict) -> str:
    """Build the Gemini image generation prompt for a tile.

    Subject: tile['description'] if present/non-trivial, else tile['text'].
    CATEGORY_HINTS are NOT used at generation time (only for UI description pre-fill).
    STYLE is always appended — it is never shown in the UI.
    """
    raw = (tile.get("description") or "").rstrip(".")
    subject = raw if raw.strip() else tile.get("text", "")
    subject_clean = subject.rstrip(".")
    subject_cap = (subject_clean[0].upper() + subject_clean[1:]) if subject_clean else subject_clean
    return f"{subject_cap}. {STYLE}"


def description_prefill(name: str, category: str) -> str:
    """Pre-fill text for the description field on a new tile.

    Combines the tile name with a category-specific layout hint.
    Used only by the UI — NOT used at image generation time.
    """
    hint = CATEGORY_HINTS.get(category, "")
    if hint:
        return f"{name}. {hint}"
    return f"{name}."


# ── File I/O ─────────────────────────────────────────────────────────────────

def load_tiles() -> list[dict]:
    """Load all tiles from squares.json."""
    with open(SQUARES_JSON, encoding="utf-8") as f:
        return json.load(f)


def save_tiles(tiles: list[dict]) -> None:
    """Write tiles back to squares.json.

    Tile array order is preserved as-is. Keys within each tile object
    are sorted alphabetically for stable diffs.
    """
    with open(SQUARES_JSON, "w", encoding="utf-8") as f:
        json.dump(tiles, f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")


def image_path(tile_id: str) -> Path:
    """Return the Path for a tile's PNG image."""
    return TILE_IMAGES / f"{tile_id}.png"


def save_image(tile_id: str, image_b64: str) -> None:
    """Decode base64 and write the image to TileImages/."""
    data = base64.b64decode(image_b64)
    p = image_path(tile_id)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(data)


# ── Pack I/O ──────────────────────────────────────────────────────────────────

def discover_packs() -> list[dict]:
    """Return summary info for every pack-*.json in PACKS_DIR, sorted by filename."""
    packs = []
    for path in sorted(PACKS_DIR.glob("pack-*.json")):
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            packs.append({
                "id":          data["id"],
                "name":        data["name"],
                "description": data.get("description", ""),
                "tileCount":   len(data.get("tiles", [])),
            })
        except (json.JSONDecodeError, KeyError) as exc:
            print(f"   ⚠  Skipping {path.name}: {exc}", file=sys.stderr)
    return packs


def load_pack(pack_id: str) -> dict:
    """Load and return the full JSON for pack-{pack_id}.json. Raises FileNotFoundError if missing."""
    path = PACKS_DIR / f"pack-{pack_id}.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_pack(pack_id: str, pack_data: dict) -> None:
    """Write pack_data to pack-{pack_id}.json with 2-space indent and trailing newline."""
    path = PACKS_DIR / f"pack-{pack_id}.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(pack_data, f, indent=2, sort_keys=False, ensure_ascii=False)
        f.write("\n")


# ── Gemini API ────────────────────────────────────────────────────────────────

def generate_image(prompt: str, api_key: str) -> str:
    """Call Gemini to generate an image. Returns base64-encoded PNG. Raises on error."""
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }
    resp = requests.post(
        f"{GEMINI_URL}?key={api_key}",
        json=payload,
        timeout=90,
    )
    resp.raise_for_status()
    data = resp.json()
    parts = data["candidates"][0]["content"]["parts"]
    for part in parts:
        if "inlineData" in part:
            return part["inlineData"]["data"]
    raise ValueError(f"No image in Gemini response; parts received: {parts!r}")


# ── Embedded HTML app ────────────────────────────────────────────────────────
HTML_APP = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Tile Manager</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Rye&family=Barlow+Condensed:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --bg: #0D0D0B; --surface: #141410; --surface2: #1C1C17; --surface3: #242420;
  --border: #2E2E28; --border2: #3A3A32;
  --text: #E8E0CC; --text2: #9A9080; --text3: #5A5448;
  --amber: #E8A830; --amber-dim: #7A5A18; --amber-tint: rgba(232,168,48,0.08);
  --red: #C84040; --red-dim: #6A2020;
  --green: #4A9060; --green-dim: #1E4028;
  --vc: #6BC88A; --co: #7BAAF0; --un: #E8C060; --ra: #E87070; --vr: #C090F0;
  --font-display: 'Rye', serif;
  --font-ui: 'Barlow Condensed', sans-serif;
}
html, body { height: 100%; overflow: hidden; background: var(--bg); color: var(--text); font-family: var(--font-ui); font-size: 14px; }

/* ── Top bar ── */
.topbar { height: 44px; display: flex; align-items: stretch; background: var(--surface); border-bottom: 1px solid var(--border); flex-shrink: 0; }
.topbar-logo { display: flex; align-items: center; padding: 0 18px; gap: 8px; font-family: var(--font-display); font-size: 14px; color: var(--amber); border-right: 1px solid var(--border); white-space: nowrap; flex-shrink: 0; }
.topbar-logo span { color: var(--text3); font-size: 11px; font-family: var(--font-ui); }
.tab-bar { display: flex; align-items: stretch; }
.tab-btn { padding: 0 22px; background: none; border: none; border-bottom: 2px solid transparent; color: var(--text2); font-family: var(--font-ui); font-size: 13px; font-weight: 600; letter-spacing: 0.5px; cursor: pointer; text-transform: uppercase; }
.tab-btn:hover { color: var(--text); }
.tab-btn.active { color: var(--amber); border-bottom-color: var(--amber); }

/* ── Layout ── */
#app { display: flex; flex-direction: column; height: 100vh; }
.tab-pane { display: none; flex: 1; overflow: hidden; }
.tab-pane.active { display: flex; }
.split { display: flex; width: 100%; height: 100%; overflow: hidden; }

/* ── Tile list column ── */
.tile-list-col { width: 400px; flex-shrink: 0; display: flex; flex-direction: column; border-right: 1px solid var(--border); background: var(--surface); }
.list-toolbar { display: flex; align-items: center; gap: 8px; padding: 8px 12px; border-bottom: 1px solid var(--border); flex-shrink: 0; }
.search-input, .cat-filter { background: var(--surface2); border: 1px solid var(--border); color: var(--text); font-family: var(--font-ui); font-size: 13px; padding: 5px 8px; border-radius: 4px; }
.search-input { flex: 1; }
.cat-filter option { background: var(--surface2); }
.btn { padding: 5px 12px; border: 1px solid var(--border2); background: var(--surface2); color: var(--text); font-family: var(--font-ui); font-size: 13px; font-weight: 600; border-radius: 4px; cursor: pointer; white-space: nowrap; }
.btn:hover { border-color: var(--amber); color: var(--amber); }
.btn-amber { border-color: var(--amber); color: var(--amber); background: var(--surface2); }
.btn-amber:hover { background: var(--amber-tint); }
.btn-red { border-color: var(--red); color: var(--red); background: var(--surface2); }
.btn-red:hover { background: rgba(200,64,64,0.1); }
.btn-green { border-color: var(--green); color: var(--green); background: var(--surface2); }
.btn-green:hover { background: rgba(74,144,96,0.1); }
.col-headers { display: grid; grid-template-columns: 38px 1fr 90px 56px; gap: 0; padding: 4px 12px; border-bottom: 1px solid var(--border); background: var(--surface2); font-size: 11px; color: var(--text3); text-transform: uppercase; letter-spacing: 0.5px; flex-shrink: 0; }
.tile-list-body { flex: 1; overflow-y: auto; }
.tile-list-body::-webkit-scrollbar { width: 6px; }
.tile-list-body::-webkit-scrollbar-track { background: transparent; }
.tile-list-body::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 3px; }
.tile-row { display: grid; grid-template-columns: 38px 1fr 90px 56px; gap: 0; align-items: center; padding: 4px 12px; border-bottom: 1px solid var(--border); cursor: pointer; min-height: 46px; }
.tile-row:hover { background: var(--surface2); }
.tile-row.selected { background: var(--amber-tint); border-left: 3px solid var(--amber); padding-left: 9px; }
.tile-thumb { width: 34px; height: 34px; object-fit: cover; border-radius: 3px; background: var(--surface3); display: block; }
.thumb-placeholder { width: 34px; height: 34px; border-radius: 3px; background: var(--surface3); }
.tile-name { font-size: 13px; padding-right: 8px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rarity-badge { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; }
.pack-dots { display: flex; gap: 3px; flex-wrap: wrap; }
.pack-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.list-footer { padding: 6px 12px; font-size: 11px; color: var(--text3); border-top: 1px solid var(--border); flex-shrink: 0; }

/* ── Detail panel ── */
.detail-col { flex: 1; display: flex; flex-direction: column; overflow: hidden; background: var(--bg); }
.detail-empty { flex: 1; display: flex; align-items: center; justify-content: center; color: var(--text3); font-size: 13px; }
.detail-panel { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.detail-header { padding: 10px 16px; border-bottom: 1px solid var(--border); font-family: var(--font-display); font-size: 14px; color: var(--amber); flex-shrink: 0; }
.detail-body { flex: 1; overflow-y: auto; display: grid; grid-template-columns: 1fr 1fr; gap: 20px; padding: 16px; align-items: start; }
.detail-body::-webkit-scrollbar { width: 6px; }
.detail-body::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 3px; }
.detail-footer { padding: 10px 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; gap: 8px; flex-shrink: 0; background: var(--surface); }

/* ── Image section ── */
.image-section { display: flex; flex-direction: column; gap: 8px; }
.image-label { font-size: 11px; color: var(--text3); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 2px; }
.image-box { background: var(--surface2); border: 1px solid var(--border); border-radius: 6px; overflow: hidden; position: relative; aspect-ratio: 1; cursor: pointer; }
.image-box img { width: 100%; height: 100%; object-fit: cover; display: block; }
.image-box.pending { border-color: var(--green); }
.image-placeholder { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; color: var(--text3); font-size: 12px; }
.image-spinner { width: 100%; height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; color: var(--text2); font-size: 12px; }
.spinner-ring { width: 32px; height: 32px; border: 3px solid var(--border2); border-top-color: var(--amber); border-radius: 50%; animation: spin 0.8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.image-box-footer { position: absolute; bottom: 0; left: 0; right: 0; background: rgba(13,13,11,0.88); padding: 6px 10px; font-size: 11px; color: var(--text2); display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.gen-btn { background: none; border: none; color: var(--amber); font-family: var(--font-ui); font-size: 12px; font-weight: 600; cursor: pointer; white-space: nowrap; }
.gen-btn:hover { color: #fff; }
.gen-btn:disabled { color: var(--text3); cursor: default; }
.approve-row { display: flex; gap: 6px; }
.approve-btn { padding: 4px 10px; border-radius: 4px; border: 1px solid var(--green); background: var(--green-dim); color: var(--green); font-family: var(--font-ui); font-size: 12px; font-weight: 600; cursor: pointer; }
.discard-btn { padding: 4px 10px; border-radius: 4px; border: 1px solid var(--red-dim); background: transparent; color: var(--red); font-family: var(--font-ui); font-size: 12px; font-weight: 600; cursor: pointer; }

/* ── Meta section ── */
.meta-section { display: flex; flex-direction: column; gap: 14px; }
.field-group { display: flex; flex-direction: column; gap: 4px; }
.field-label { font-size: 11px; color: var(--text3); text-transform: uppercase; letter-spacing: 0.5px; }
.field-input { background: var(--surface2); border: 1px solid var(--border); color: var(--text); font-family: var(--font-ui); font-size: 13px; padding: 6px 8px; border-radius: 4px; width: 100%; }
.field-input:focus { outline: none; border-color: var(--amber-dim); }
.field-input::placeholder { color: var(--text3); }
.field-select { background: var(--surface2); border: 1px solid var(--border); color: var(--text); font-family: var(--font-ui); font-size: 13px; padding: 6px 8px; border-radius: 4px; width: 100%; }
.field-textarea { background: var(--surface2); border: 1px solid var(--border); color: var(--text); font-family: var(--font-ui); font-size: 12px; padding: 6px 8px; border-radius: 4px; width: 100%; resize: vertical; min-height: 80px; line-height: 1.5; }
.field-textarea:focus { outline: none; border-color: var(--amber-dim); }
.rarity-chips { display: flex; gap: 6px; flex-wrap: wrap; }
.rarity-chip { padding: 4px 10px; border-radius: 12px; border: 1px solid var(--border2); background: transparent; color: var(--text2); font-family: var(--font-ui); font-size: 12px; font-weight: 600; cursor: pointer; }
.rarity-chip.selected { border-color: currentColor; background: rgba(255,255,255,0.07); }

/* ── Pack membership section ── */
.pack-membership { display: flex; flex-direction: column; gap: 2px; }
.pack-row { display: flex; align-items: center; gap: 8px; padding: 6px 8px; border-radius: 4px; border: 1px solid transparent; }
.pack-row.included { background: var(--amber-tint); }
.pack-row.will-remove { opacity: 0.5; border-color: var(--red-dim); }
.pack-color-bar { width: 4px; height: 24px; border-radius: 2px; flex-shrink: 0; }
.pack-row-name { flex: 1; font-size: 13px; font-weight: 600; }
.pack-row-status { font-size: 11px; color: var(--text2); white-space: nowrap; }
.pack-row-status.included-status { color: var(--green); }
.pack-row-status.remove-status { color: var(--red); }
.pack-toggle-btn { width: 22px; height: 22px; border-radius: 50%; border: 2px solid var(--border2); background: none; cursor: pointer; flex-shrink: 0; display: flex; align-items: center; justify-content: center; font-size: 12px; }
.pack-toggle-btn.included { border-color: var(--amber); background: var(--amber); color: #000; }
.pack-toggle-btn.will-remove { border-color: var(--red); color: var(--red); }
.rarity-inline-picker { display: flex; gap: 4px; flex-wrap: wrap; padding: 4px 0 4px 12px; }
.rarity-inline-chip { padding: 3px 8px; border-radius: 10px; border: 1px solid var(--border2); background: transparent; color: var(--text2); font-family: var(--font-ui); font-size: 11px; font-weight: 600; cursor: pointer; }
.rarity-inline-chip:hover { border-color: currentColor; }
.rarity-inline-chip.selected { border-color: currentColor; background: rgba(255,255,255,0.07); }

/* ── Pack gallery (left col, Pack View) ── */
.pack-gallery-col { width: 180px; flex-shrink: 0; border-right: 1px solid var(--border); background: var(--surface); overflow-y: auto; }
.pack-card { cursor: pointer; border-bottom: 1px solid var(--border); }
.pack-card:hover { background: var(--surface2); }
.pack-card.selected { border-left: 3px solid var(--amber); background: var(--amber-tint); }
.pack-card-img { width: 100%; height: 80px; object-fit: cover; display: block; background: var(--surface3); }
.pack-card-info { padding: 6px 10px; }
.pack-card-name { font-family: var(--font-display); font-size: 12px; color: var(--amber); line-height: 1.3; }
.pack-card-count { font-size: 11px; color: var(--text3); margin-top: 2px; }

/* ── Pack detail (right area, Pack View) ── */
.pack-detail-col { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.pack-detail-toolbar { display: flex; align-items: center; gap: 10px; padding: 8px 16px; border-bottom: 1px solid var(--border); flex-shrink: 0; background: var(--surface); }
.pack-detail-name { font-family: var(--font-display); font-size: 16px; color: var(--amber); flex-shrink: 0; }
.pack-detail-body { flex: 1; overflow-y: auto; padding: 16px; }
.pack-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(72px, 1fr)); gap: 6px; }
.pack-grid-cell { position: relative; aspect-ratio: 1; border-radius: 4px; overflow: hidden; cursor: pointer; background: var(--surface2); border: 1px solid var(--border); }
.pack-grid-cell:hover { border-color: var(--amber); }
.pack-grid-cell img { width: 100%; height: 100%; object-fit: cover; display: block; }
.pack-grid-rarity-dot { position: absolute; top: 4px; right: 4px; width: 8px; height: 8px; border-radius: 50%; }
.pack-grid-name { position: absolute; bottom: 0; left: 0; right: 0; background: rgba(13,13,11,0.82); font-size: 10px; padding: 2px 4px; text-align: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pack-list { display: flex; flex-direction: column; gap: 0; }
.pack-list-row { display: grid; grid-template-columns: 38px 1fr 90px; align-items: center; padding: 6px 0; border-bottom: 1px solid var(--border); cursor: pointer; }
.pack-list-row:hover { background: var(--surface2); }
.rarity-bar-section { margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--border); }
.rarity-bar-label { font-size: 11px; color: var(--text3); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
.rarity-bar { display: flex; height: 8px; border-radius: 4px; overflow: hidden; background: var(--surface3); }
.rarity-bar-seg { height: 100%; transition: width 0.3s; }
.rarity-legend { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 8px; }
.rarity-legend-item { display: flex; align-items: center; gap: 4px; font-size: 11px; color: var(--text2); }
.rarity-legend-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }

/* ── Add-tile picker overlay ── */
.picker-overlay { position: fixed; inset: 0; background: rgba(13,13,11,0.7); z-index: 100; display: flex; align-items: flex-start; justify-content: flex-end; }
.picker-panel { width: 420px; height: 100%; background: var(--surface); border-left: 1px solid var(--border); display: flex; flex-direction: column; overflow: hidden; animation: slideInRight 0.2s ease; }
@keyframes slideInRight { from { transform: translateX(100%); } to { transform: translateX(0); } }
.picker-header { padding: 12px 16px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; }
.picker-title { font-family: var(--font-display); font-size: 14px; color: var(--amber); }
.picker-search { padding: 8px 12px; border-bottom: 1px solid var(--border); flex-shrink: 0; }
.picker-list { flex: 1; overflow-y: auto; }
.picker-tile-row { display: grid; grid-template-columns: 38px 1fr auto; align-items: center; gap: 8px; padding: 8px 12px; border-bottom: 1px solid var(--border); cursor: pointer; }
.picker-tile-row:hover { background: var(--surface2); }
.picker-rarity-picker { background: var(--surface2); padding: 8px 12px; border-bottom: 1px solid var(--amber-dim); }
.picker-rarity-label { font-size: 11px; color: var(--text2); margin-bottom: 6px; }

/* ── Lightbox ── */
.lightbox { position: fixed; inset: 0; background: rgba(13,13,11,0.85); z-index: 200; display: flex; align-items: center; justify-content: center; }
.lightbox.hidden { display: none; }
.lightbox-box { width: 540px; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }
.lightbox-img { width: 100%; aspect-ratio: 1; object-fit: contain; display: block; background: var(--surface2); }
.lightbox-footer { padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.lightbox-name { font-family: var(--font-display); font-size: 13px; color: var(--amber); }
</style>
</head>
<body>
<div id="app">
  <header class="topbar">
    <div class="topbar-logo">Road Trip Bingo <span>&#x2B21; Tile Manager</span></div>
    <nav class="tab-bar">
      <button class="tab-btn active" data-tab="tiles">All Tiles</button>
      <button class="tab-btn" data-tab="packs">Pack View</button>
    </nav>
  </header>

  <!-- All Tiles Tab -->
  <div class="tab-pane active" data-tab="tiles">
    <div class="split">
      <aside class="tile-list-col">
        <div class="list-toolbar">
          <input id="tile-search" class="search-input" placeholder="Search tiles&hellip;" type="search">
          <select id="cat-filter" class="cat-filter"><option value="">All Categories</option></select>
          <button class="btn btn-amber" id="add-tile-btn">+ Add</button>
        </div>
        <div class="col-headers">
          <span></span><span>Name</span><span>Rarity</span><span>Packs</span>
        </div>
        <div class="tile-list-body" id="tile-list-body"></div>
        <div class="list-footer" id="tile-list-footer"></div>
      </aside>
      <main class="detail-col" id="detail-col">
        <div class="detail-empty" id="detail-empty">Select a tile to edit</div>
        <div class="detail-panel" id="detail-panel" style="display:none">
          <div class="detail-header" id="detail-header">Tile</div>
          <div class="detail-body" id="detail-body"></div>
          <div class="detail-footer">
            <button class="btn btn-red" id="delete-tile-btn" style="display:none">&#x1F5D1; Delete Tile</button>
            <div style="flex:1"></div>
            <button class="btn" id="cancel-tile-btn">Cancel</button>
            <button class="btn btn-amber" id="save-tile-btn">Save Changes</button>
          </div>
        </div>
      </main>
    </div>
  </div>

  <!-- Pack View Tab -->
  <div class="tab-pane" data-tab="packs">
    <div class="split">
      <aside class="pack-gallery-col" id="pack-gallery"></aside>
      <main class="pack-detail-col" id="pack-detail-col">
        <div class="detail-empty">Select a pack</div>
      </main>
    </div>
  </div>

  <!-- Lightbox -->
  <div class="lightbox hidden" id="lightbox">
    <div class="lightbox-box" id="lightbox-box">
      <img class="lightbox-img" id="lightbox-img" src="" alt="">
      <div class="lightbox-footer">
        <span class="lightbox-name" id="lightbox-name"></span>
        <div style="display:flex;gap:8px;align-items:center">
          <button class="gen-btn" id="lightbox-gen-btn">&#x2746; Generate Again</button>
          <button class="btn" id="lightbox-close-btn">&#x2715; Close</button>
        </div>
      </div>
    </div>
  </div>
</div>

<script>
/* __INJECT__ */

// ── Constants ─────────────────────────────────────────────────────────────────

const PACK_COLORS = {
  'base': '#4A9060',
  'farm-country': '#4A9060',
  'interstate': '#5B8DD9',
  'city': '#9060C8',
  'mountains': '#7A9060',
  'beach-coast': '#4090A8',
  'desert-southwest': '#C87840',
};
const RARITY_COLORS = {
  veryCommon: '#6BC88A', common: '#7BAAF0',
  uncommon: '#E8C060', rare: '#E87070', veryRare: '#C090F0',
};
const RARITY_LABELS = {
  veryCommon: 'V.Common', common: 'Common',
  uncommon: 'Uncommon', rare: 'Rare', veryRare: 'V.Rare',
};

// ── State ─────────────────────────────────────────────────────────────────────

const S = {
  tiles: [],        // [{id, text, category, rarity, description}]
  packs: [],        // [{id, name, description, tileCount}] from /api/packs
  packData: {},     // {packId: {id, name, tiles: [{id, rarity}]}} lazily loaded

  activeTab: 'tiles',
  selectedTileId: null,
  selectedPackId: null,

  search: '',
  catFilter: '',
  packViewMode: 'grid', // 'grid' | 'list'
  packSearch: '',

  // Detail panel (All Tiles tab)
  isNewTile: false,
  edit: {           // pending edits for selected tile
    name: '', category: '', rarity: '', description: '',
    packChanges: {}, // packId -> {action:'add'|'remove', rarity?:string}
  },

  // Image generation
  imgState: 'idle', // 'idle' | 'generating' | 'pending'
  pendingB64: null,

  // Add-tile picker (Pack View)
  pickerPackId: null,
  pickerTiles: [],
  pickerSearch: '',
  pickerSelectedTileId: null,
  pickerSelectedRarity: '',
};

// ── Utilities ─────────────────────────────────────────────────────────────────

function esc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
async function api(method, path, body) {
  const opts = { method, headers: {} };
  if (body !== null && body !== undefined) {
    opts.body = JSON.stringify(body);
    opts.headers['Content-Type'] = 'application/json';
  }
  const r = await fetch(path, opts);
  if (!r.ok) {
    const e = await r.json().catch(() => ({ error: r.statusText }));
    throw new Error(e.error || r.statusText);
  }
  return r.json();
}
function rarityColor(r) { return RARITY_COLORS[r] || '#888'; }
function rarityLabel(r) { return RARITY_LABELS[r] || r; }
function packColor(id) { return PACK_COLORS[id] || '#888'; }
function tileById(id) { return S.tiles.find(t => t.id === id); }
function tilePackIds(tileId) {
  return Object.entries(S.packData)
    .filter(([,pd]) => pd && pd.tiles.some(r => r.id === tileId))
    .map(([id]) => id);
}
function tilePackRarity(tileId, packId) {
  const pd = S.packData[packId];
  const ref = pd && pd.tiles.find(r => r.id === tileId);
  return ref ? ref.rarity : null;
}

// ── Init ──────────────────────────────────────────────────────────────────────

async function init() {
  // Populate category filter
  const cf = document.getElementById('cat-filter');
  CATEGORIES.forEach(c => {
    const opt = document.createElement('option');
    opt.value = c; opt.textContent = c.charAt(0).toUpperCase() + c.slice(1);
    cf.appendChild(opt);
  });

  [S.tiles, S.packs] = await Promise.all([
    api('GET', '/api/tiles'),
    api('GET', '/api/packs'),
  ]);

  // Pre-load all pack data (so pack-dot membership is visible immediately)
  await Promise.all(S.packs.map(p => loadPackData(p.id)));

  renderTileList();
  renderPackGallery();

  // Wire up tab buttons
  document.querySelectorAll('.tab-btn').forEach(b => {
    b.addEventListener('click', () => switchTab(b.dataset.tab));
  });

  // Wire up tile list controls
  document.getElementById('tile-search').addEventListener('input', e => {
    S.search = e.target.value; renderTileList();
  });
  document.getElementById('cat-filter').addEventListener('change', e => {
    S.catFilter = e.target.value; renderTileList();
  });
  document.getElementById('add-tile-btn').addEventListener('click', openNewTile);
  document.getElementById('save-tile-btn').addEventListener('click', saveTile);
  document.getElementById('cancel-tile-btn').addEventListener('click', cancelEdit);
  document.getElementById('delete-tile-btn').addEventListener('click', deleteTile);

  // Lightbox
  document.getElementById('lightbox').addEventListener('click', e => {
    if (e.target === document.getElementById('lightbox')) closeLightbox();
  });
  document.getElementById('lightbox-close-btn').addEventListener('click', closeLightbox);
  document.getElementById('lightbox-gen-btn').addEventListener('click', () => {
    closeLightbox(); generateImage();
  });
}

async function loadPackData(packId) {
  if (S.packData[packId]) return S.packData[packId];
  const pd = await api('GET', `/api/packs/${packId}`);
  S.packData[packId] = pd;
  return pd;
}

// ── Tab switching ─────────────────────────────────────────────────────────────

function switchTab(tab) {
  S.activeTab = tab;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.dataset.tab === tab));
  if (tab === 'packs' && S.packs.length > 0 && !S.selectedPackId) {
    selectPack(S.packs[0].id);
  }
}

// ── Tile list ─────────────────────────────────────────────────────────────────

function filteredTiles() {
  let tiles = S.tiles;
  if (S.search) {
    const q = S.search.toLowerCase();
    tiles = tiles.filter(t => t.text.toLowerCase().includes(q) || (t.category||'').toLowerCase().includes(q));
  }
  if (S.catFilter) {
    tiles = tiles.filter(t => t.category === S.catFilter);
  }
  return tiles;
}

function renderTileList() {
  const body = document.getElementById('tile-list-body');
  const footer = document.getElementById('tile-list-footer');
  const tiles = filteredTiles();

  body.innerHTML = tiles.map(tile => {
    const packIds = tilePackIds(tile.id);
    const dots = packIds.map(pid => {
      const p = S.packs.find(x => x.id === pid);
      return `<span class="pack-dot" style="background:${packColor(pid)}" title="${p ? esc(p.name) : pid}"></span>`;
    }).join('');
    const sel = S.selectedTileId === tile.id ? ' selected' : '';
    const col = rarityColor(tile.rarity);
    return `<div class="tile-row${sel}" data-id="${esc(tile.id)}">
      <div><img class="tile-thumb" src="/api/image/${esc(tile.id)}" onerror="this.style.visibility='hidden'" loading="lazy"></div>
      <div class="tile-name">${esc(tile.text)}</div>
      <div><span class="rarity-badge" style="color:${col}">${esc(rarityLabel(tile.rarity))}</span></div>
      <div class="pack-dots">${dots}</div>
    </div>`;
  }).join('');

  footer.textContent = `${S.tiles.length} tiles total`;

  body.querySelectorAll('.tile-row').forEach(row => {
    row.addEventListener('click', () => selectTile(row.dataset.id));
  });
}

// ── Select / deselect tile ────────────────────────────────────────────────────

function selectTile(id) {
  S.selectedTileId = id;
  S.isNewTile = false;
  S.imgState = 'idle';
  S.pendingB64 = null;
  const tile = tileById(id);
  if (!tile) return;
  S.edit = {
    name: tile.text,
    category: tile.category || '',
    rarity: tile.rarity,
    description: tile.description || '',
    packChanges: {},
  };
  renderTileList();
  renderDetailPanel();
}

function cancelEdit() {
  if (S.isNewTile) {
    S.selectedTileId = null;
    S.isNewTile = false;
    hideDetailPanel();
    renderTileList();
    return;
  }
  if (S.selectedTileId) selectTile(S.selectedTileId);
}

function hideDetailPanel() {
  document.getElementById('detail-empty').style.display = '';
  document.getElementById('detail-panel').style.display = 'none';
}

function showDetailPanel() {
  document.getElementById('detail-empty').style.display = 'none';
  document.getElementById('detail-panel').style.display = '';
}

// ── Detail panel ──────────────────────────────────────────────────────────────

function renderDetailPanel() {
  showDetailPanel();
  const hdr = document.getElementById('detail-header');
  const body = document.getElementById('detail-body');
  const deleteBtn = document.getElementById('delete-tile-btn');
  const saveBtn = document.getElementById('save-tile-btn');

  hdr.textContent = S.isNewTile ? '✦ New Tile' : (tileById(S.selectedTileId)?.text || 'Tile');
  deleteBtn.style.display = S.isNewTile ? 'none' : '';
  saveBtn.textContent = S.isNewTile ? 'Create Tile' : 'Save Changes';
  // Disable save during active generation
  saveBtn.disabled = S.imgState === 'generating' || S.imgState === 'pending';

  const fieldsReady = S.isNewTile ? (S.edit.name && S.edit.category) : true;

  const imgSectionStyle = (!fieldsReady) ? ' style="opacity:0.4;pointer-events:none"' : '';
  body.innerHTML = `
    <div class="image-section"${imgSectionStyle}>
      ${renderImageSection(fieldsReady)}
    </div>
    <div class="meta-section">
      ${renderMetaSection()}
      ${renderPackMembershipSection(fieldsReady)}
    </div>`;

  // Wire image box click (lightbox for approved images)
  if (S.imgState === 'idle' && !S.isNewTile && S.selectedTileId) {
    document.querySelector('.image-box')?.addEventListener('click', () => {
      openLightbox(S.selectedTileId);
    });
  }
  // Wire generate button
  document.getElementById('gen-btn')?.addEventListener('click', generateImage);
  // Wire approve/discard
  document.getElementById('approve-btn')?.addEventListener('click', approveImage);
  document.getElementById('discard-btn')?.addEventListener('click', discardImage);
  // Wire meta fields
  wireMetaFields();
  // Wire pack membership toggles
  wirePackMembership();
}

function renderImageSection(fieldsReady) {
  const tileId = S.selectedTileId;
  const imgUrl = tileId ? `/api/image/${tileId}` : '';
  const genLabel = (tileId && !S.isNewTile) ? '❆ Generate Again' : '❆ Generate Image';
  const genDisabled = !fieldsReady || !S.edit.description || S.imgState === 'generating' ? 'disabled' : '';

  let boxInner = '';
  if (S.imgState === 'generating') {
    boxInner = `<div class="image-spinner"><div class="spinner-ring"></div><span>Generating&hellip; ~15s</span></div>`;
  } else if (S.imgState === 'pending' && S.pendingB64) {
    boxInner = `<img src="data:image/png;base64,${S.pendingB64}" alt="Generated" style="width:100%;height:100%;object-fit:cover;display:block">
      <div class="image-box-footer">
        <div class="approve-row">
          <button class="approve-btn" id="approve-btn">&#x2713; Use This Image</button>
          <button class="discard-btn" id="discard-btn">&#x2715; Discard</button>
        </div>
      </div>`;
  } else if (S.imgState === 'idle' && S.pendingB64 && S.isNewTile) {
    // New tile with an approved image staged — show it
    boxInner = `<img src="data:image/png;base64,${S.pendingB64}" alt="Staged image" style="width:100%;height:100%;object-fit:cover;display:block">
      <div class="image-box-footer">
        <span style="font-size:10px;color:var(--green)">Image staged ✓</span>
        <button class="gen-btn" id="gen-btn" ${genDisabled}>❆ Generate Again</button>
      </div>`;
  } else if (imgUrl && !S.isNewTile) {
    boxInner = `<img src="${imgUrl}" alt="Tile image" onerror="this.parentElement.innerHTML='<div class=image-placeholder>No image</div>'">
      <div class="image-box-footer">
        <span style="font-size:10px;color:var(--text3)">click to expand</span>
        <button class="gen-btn" id="gen-btn" ${genDisabled}>${genLabel}</button>
      </div>`;
  } else {
    boxInner = `<div class="image-placeholder">No image</div>
      <div class="image-box-footer">
        <span></span>
        <button class="gen-btn" id="gen-btn" ${genDisabled}>${genLabel}</button>
      </div>`;
  }

  const pendingClass = S.imgState === 'pending' ? ' pending' : '';
  return `<div class="image-label">Image</div>
    <div class="image-box${pendingClass}">${boxInner}</div>`;
}

function renderMetaSection() {
  const catOptions = CATEGORIES.map(c =>
    `<option value="${c}" ${S.edit.category === c ? 'selected' : ''}>${c.charAt(0).toUpperCase() + c.slice(1)}</option>`
  ).join('');
  const rarityChips = RARITIES.map(r => {
    const col = rarityColor(r);
    const sel = S.edit.rarity === r ? ' selected' : '';
    return `<button class="rarity-chip${sel}" data-rarity="${r}" style="color:${col};${sel ? `border-color:${col}` : ''}">${rarityLabel(r)}</button>`;
  }).join('');

  return `<div>
    <div class="field-group" style="margin-bottom:10px">
      <div class="field-label">Name</div>
      <input id="field-name" class="field-input" value="${esc(S.edit.name)}" placeholder="Tile name">
    </div>
    <div class="field-group" style="margin-bottom:10px">
      <div class="field-label">Category</div>
      <select id="field-cat" class="field-select">
        <option value="">&#x2014; select &#x2014;</option>${catOptions}
      </select>
    </div>
    <div class="field-group" style="margin-bottom:10px">
      <div class="field-label">Default Rarity</div>
      <div class="rarity-chips" id="rarity-chips">${rarityChips}</div>
    </div>
    <div class="field-group">
      <div class="field-label">Description <span style="color:var(--text3);font-size:10px">(used for image generation)</span></div>
      <textarea id="field-desc" class="field-textarea">${esc(S.edit.description)}</textarea>
    </div>
  </div>`;
}

function renderPackMembershipSection(fieldsReady) {
  if (!fieldsReady) {
    return `<div style="opacity:0.4">
      <div class="field-label" style="margin-bottom:8px">Pack Membership</div>
      <div style="font-size:12px;color:var(--text3)">Fill in name and category first</div>
    </div>`;
  }
  const tileId = S.selectedTileId;
  const rows = S.packs.map(pack => {
    const change = S.edit.packChanges[pack.id];
    const currentRarity = tilePackRarity(tileId, pack.id);
    const isCurrentlyIn = currentRarity !== null;
    const isAdd = change?.action === 'add';
    const isRemove = change?.action === 'remove';
    const isIncluded = (isCurrentlyIn && !isRemove) || isAdd;

    let statusText = '', statusClass = '', toggleClass = '', toggleContent = '';
    if (isRemove) {
      statusText = 'Will remove on save'; statusClass = 'remove-status';
      toggleClass = 'will-remove'; toggleContent = '✕';
    } else if (isIncluded) {
      const r = isAdd ? (change.rarity || S.edit.rarity) : currentRarity;
      statusText = `Included · ${rarityLabel(r)}`; statusClass = 'included-status';
      toggleClass = 'included'; toggleContent = '✓';
    } else {
      statusText = 'Not included'; statusClass = '';
      toggleClass = ''; toggleContent = '○';
    }

    const rowClass = isRemove ? 'pack-row will-remove' : isIncluded ? 'pack-row included' : 'pack-row';
    const col = packColor(pack.id);

    // Inline rarity picker (shown when clicking circle to add)
    const showPicker = change?.showPicker === true;
    const pickerHtml = showPicker ? renderInlineRarityPicker(pack.id, change?.rarity || S.edit.rarity) : '';

    return `<div data-pack-row="${esc(pack.id)}">
      <div class="${rowClass}">
        <span class="pack-color-bar" style="background:${col}"></span>
        <span class="pack-row-name">${esc(pack.name)}</span>
        <span class="pack-row-status ${statusClass}">${esc(statusText)}</span>
        <button class="pack-toggle-btn ${toggleClass}" data-pack-toggle="${esc(pack.id)}">${toggleContent}</button>
      </div>
      ${pickerHtml}
    </div>`;
  }).join('');

  return `<div>
    <div class="field-label" style="margin-bottom:8px">Pack Membership</div>
    <div class="pack-membership">${rows}</div>
  </div>`;
}

function renderInlineRarityPicker(packId, selectedRarity) {
  const chips = RARITIES.map(r => {
    const col = rarityColor(r);
    const sel = selectedRarity === r ? ' selected' : '';
    return `<button class="rarity-inline-chip${sel}" data-pack-rarity-pick="${esc(packId)}" data-rarity="${r}"
      style="color:${col};${sel?`border-color:${col}`:''}">
      ${rarityLabel(r)}</button>`;
  }).join('');
  return `<div class="rarity-inline-picker">${chips}</div>`;
}

// ── Wire meta field events ────────────────────────────────────────────────────

function wireMetaFields() {
  document.getElementById('field-name')?.addEventListener('input', e => {
    S.edit.name = e.target.value;
    // Pre-fill description on new tiles when name + category are both set
    if (S.isNewTile && S.edit.category && !S.edit.description) {
      const prefill = (CATEGORY_HINTS_MAP || {})[S.edit.category] || '';
      S.edit.description = prefill ? `${S.edit.name}. ${prefill}` : `${S.edit.name}.`;
      document.getElementById('field-desc').value = S.edit.description;
    }
    document.getElementById('detail-header').textContent = S.isNewTile ? '✦ New Tile' : S.edit.name;
    // Re-render image + pack section to unlock if both fields now set
    if (S.isNewTile) renderDetailPanel();
  });
  document.getElementById('field-cat')?.addEventListener('change', e => {
    S.edit.category = e.target.value;
    if (S.isNewTile && S.edit.name && !S.edit.description) {
      const prefill = (CATEGORY_HINTS_MAP || {})[S.edit.category] || '';
      S.edit.description = prefill ? `${S.edit.name}. ${prefill}` : `${S.edit.name}.`;
      document.getElementById('field-desc').value = S.edit.description;
    }
    if (S.isNewTile) renderDetailPanel();
  });
  document.getElementById('field-desc')?.addEventListener('input', e => {
    S.edit.description = e.target.value;
    // Enable/disable gen button
    const genBtn = document.getElementById('gen-btn');
    if (genBtn) genBtn.disabled = !S.edit.description || S.imgState === 'generating';
  });
  document.getElementById('rarity-chips')?.addEventListener('click', e => {
    const chip = e.target.closest('[data-rarity]');
    if (!chip) return;
    S.edit.rarity = chip.dataset.rarity;
    document.querySelectorAll('.rarity-chip').forEach(c => {
      const r = c.dataset.rarity;
      const col = rarityColor(r);
      const sel = r === S.edit.rarity;
      c.classList.toggle('selected', sel);
      c.style.borderColor = sel ? col : '';
    });
  });
}

// ── Wire pack membership events ───────────────────────────────────────────────

function wirePackMembership() {
  document.querySelectorAll('[data-pack-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
      const packId = btn.dataset.packToggle;
      const change = S.edit.packChanges[packId];
      const currentRarity = tilePackRarity(S.selectedTileId, packId);
      const isCurrentlyIn = currentRarity !== null;
      const isAdd = change?.action === 'add';
      const isRemove = change?.action === 'remove';

      if (isRemove) {
        // Undo the pending remove -> back to included
        delete S.edit.packChanges[packId];
      } else if (isAdd) {
        // Cancel the pending add
        delete S.edit.packChanges[packId];
      } else if (isCurrentlyIn) {
        // Currently included -> mark as will-remove
        S.edit.packChanges[packId] = { action: 'remove' };
      } else {
        // Not included -> show inline rarity picker
        S.edit.packChanges[packId] = {
          action: 'add',
          showPicker: true,
          rarity: S.edit.rarity,
        };
      }
      renderDetailPanel();
    });
  });

  document.querySelectorAll('[data-pack-rarity-pick]').forEach(chip => {
    chip.addEventListener('click', () => {
      const packId = chip.dataset.packRarityPick;
      const rarity = chip.dataset.rarity;
      S.edit.packChanges[packId] = { action: 'add', rarity, showPicker: false };
      renderDetailPanel();
    });
  });
}

// ── Save / Create tile ────────────────────────────────────────────────────────

async function saveTile() {
  if (!S.edit.name || !S.edit.category || !S.edit.rarity) {
    alert('Name, category, and rarity are required.');
    return;
  }
  const saveBtn = document.getElementById('save-tile-btn');
  saveBtn.disabled = true;
  try {
    if (S.isNewTile) {
      // Build pack membership array
      const packMembership = Object.entries(S.edit.packChanges)
        .filter(([,c]) => c.action === 'add')
        .map(([packId, c]) => ({ packId, rarity: c.rarity || S.edit.rarity }));
      const body = {
        text: S.edit.name,
        category: S.edit.category,
        rarity: S.edit.rarity,
        description: S.edit.description || undefined,
        packMembership,
      };
      if (S.pendingB64) body.image_b64 = S.pendingB64;
      const tile = await api('POST', '/api/tiles', body);
      S.tiles.push(tile);
      // Update pack data locally
      for (const { packId, rarity } of packMembership) {
        if (S.packData[packId]) {
          S.packData[packId].tiles.push({ id: tile.id, rarity });
        }
      }
      S.isNewTile = false;
      S.selectedTileId = tile.id;
      S.imgState = 'idle';
      S.pendingB64 = null;
      S.edit = { name: tile.text, category: tile.category, rarity: tile.rarity,
                 description: tile.description || '', packChanges: {} };
    } else {
      // Build pack membership changes array
      const packMembership = Object.entries(S.edit.packChanges).map(([packId, c]) => ({
        packId, action: c.action, rarity: c.rarity,
      }));
      const body = {
        text: S.edit.name, category: S.edit.category, rarity: S.edit.rarity,
        description: S.edit.description || '',
        packMembership,
      };
      const tile = await api('PUT', `/api/tiles/${S.selectedTileId}`, body);
      // Update local state
      const idx = S.tiles.findIndex(t => t.id === S.selectedTileId);
      if (idx !== -1) S.tiles[idx] = tile;
      // Rebuild pack data for affected packs
      for (const [packId, c] of Object.entries(S.edit.packChanges)) {
        const pd = S.packData[packId];
        if (!pd) continue;
        if (c.action === 'add') {
          pd.tiles = pd.tiles.filter(r => r.id !== S.selectedTileId);
          pd.tiles.push({ id: S.selectedTileId, rarity: c.rarity || tile.rarity });
        } else if (c.action === 'remove') {
          pd.tiles = pd.tiles.filter(r => r.id !== S.selectedTileId);
        }
      }
      S.edit.packChanges = {};
    }
    renderTileList();
    renderDetailPanel();
  } catch (err) {
    alert(`Save failed: ${err.message}`);
  } finally {
    saveBtn.disabled = false;
  }
}

// ── Delete tile ───────────────────────────────────────────────────────────────

let deleteConfirmTimeout = null;
async function deleteTile() {
  const btn = document.getElementById('delete-tile-btn');
  if (!btn) return;
  if (btn.dataset.confirming !== 'true') {
    btn.dataset.confirming = 'true';
    btn.textContent = '🗑 Confirm Delete';
    deleteConfirmTimeout = setTimeout(() => {
      btn.dataset.confirming = '';
      btn.textContent = '🗑 Delete Tile';
    }, 3000);
    return;
  }
  clearTimeout(deleteConfirmTimeout);
  btn.disabled = true;
  try {
    await api('DELETE', `/api/tiles/${S.selectedTileId}`);
    // Remove from local state
    S.tiles = S.tiles.filter(t => t.id !== S.selectedTileId);
    Object.values(S.packData).forEach(pd => {
      if (pd) pd.tiles = pd.tiles.filter(r => r.id !== S.selectedTileId);
    });
    S.selectedTileId = null;
    hideDetailPanel();
    renderTileList();
  } catch (err) {
    alert(`Delete failed: ${err.message}`);
    btn.disabled = false;
  }
}

// ── New tile ──────────────────────────────────────────────────────────────────

function openNewTile() {
  S.isNewTile = true;
  S.selectedTileId = null;
  S.imgState = 'idle';
  S.pendingB64 = null;
  S.edit = { name: '', category: '', rarity: 'common', description: '', packChanges: {} };
  renderTileList();
  renderDetailPanel();
}

// ── Image generation ──────────────────────────────────────────────────────────

async function generateImage() {
  if (S.imgState === 'generating') return;
  S.imgState = 'generating';
  S.pendingB64 = null;
  renderDetailPanel();
  try {
    let body;
    if (S.isNewTile || !S.selectedTileId) {
      body = { description: S.edit.description, name: S.edit.name };
    } else {
      body = { tile_id: S.selectedTileId };
    }
    const { image_b64 } = await api('POST', '/api/generate', body);
    S.pendingB64 = image_b64;
    S.imgState = 'pending';
  } catch (err) {
    S.imgState = 'idle';
    alert(`Generation failed: ${err.message}`);
  }
  renderDetailPanel();
}

async function approveImage() {
  if (!S.pendingB64) return;
  if (S.isNewTile) {
    // For new tiles, hold in memory until Create Tile
    S.imgState = 'idle';
    // Keep pendingB64 -- it will be sent with the tile data
    renderDetailPanel();
    return;
  }
  // For existing tiles, save immediately
  try {
    await api('POST', `/api/tiles/${S.selectedTileId}/image`, { image_b64: S.pendingB64 });
    S.imgState = 'idle';
    S.pendingB64 = null;
    renderDetailPanel();
  } catch (err) {
    alert(`Failed to save image: ${err.message}`);
  }
}

function discardImage() {
  S.imgState = 'idle';
  S.pendingB64 = null;
  renderDetailPanel();
}

// ── Lightbox ──────────────────────────────────────────────────────────────────

function openLightbox(tileId) {
  const tile = tileById(tileId);
  if (!tile) return;
  S.lightboxTileId = tileId;
  document.getElementById('lightbox-img').src = `/api/image/${tileId}`;
  document.getElementById('lightbox-name').textContent = tile.text;
  document.getElementById('lightbox').classList.remove('hidden');
}

function closeLightbox() {
  S.lightboxTileId = null;
  document.getElementById('lightbox').classList.add('hidden');
  document.getElementById('lightbox-img').src = '';
}

// ── Pack gallery (Pack View) ──────────────────────────────────────────────────

function renderPackGallery() {
  const gallery = document.getElementById('pack-gallery');
  gallery.innerHTML = S.packs.map(pack => {
    const sel = S.selectedPackId === pack.id ? ' selected' : '';
    return `<div class="pack-card${sel}" data-pack-id="${esc(pack.id)}">
      <img class="pack-card-img" src="/api/image/${esc(pack.id)}"
           onerror="this.style.display='none'" loading="lazy">
      <div class="pack-card-info">
        <div class="pack-card-name">${esc(pack.name)}</div>
        <div class="pack-card-count">${pack.tileCount} tiles</div>
      </div>
    </div>`;
  }).join('');
  gallery.querySelectorAll('.pack-card').forEach(card => {
    card.addEventListener('click', () => selectPack(card.dataset.packId));
  });
}

async function selectPack(packId) {
  S.selectedPackId = packId;
  S.packSearch = '';
  S.pickerPackId = null;
  renderPackGallery();
  await loadPackData(packId);
  renderPackDetail();
}

// ── Pack detail ───────────────────────────────────────────────────────────────

function renderPackDetail() {
  const col = document.getElementById('pack-detail-col');
  const pd = S.packData[S.selectedPackId];
  const packMeta = S.packs.find(p => p.id === S.selectedPackId);
  if (!pd || !packMeta) { col.innerHTML = '<div class="detail-empty">Loading&hellip;</div>'; return; }

  // Resolve tile refs against tile data
  const resolvedTiles = pd.tiles
    .map(ref => {
      const tile = tileById(ref.id);
      return tile ? { ...tile, packRarity: ref.rarity } : null;
    })
    .filter(Boolean);

  // Apply pack search
  const q = S.packSearch.toLowerCase();
  const displayTiles = q
    ? resolvedTiles.filter(t => t.text.toLowerCase().includes(q))
    : resolvedTiles;

  // Rarity breakdown
  const counts = {};
  RARITIES.forEach(r => counts[r] = 0);
  resolvedTiles.forEach(t => { counts[t.packRarity] = (counts[t.packRarity] || 0) + 1; });
  const total = resolvedTiles.length;

  const gridHtml = displayTiles.map(tile => `
    <div class="pack-grid-cell" data-tile-id="${esc(tile.id)}">
      <img src="/api/image/${esc(tile.id)}" alt="${esc(tile.text)}" onerror="this.style.display='none'" loading="lazy">
      <span class="pack-grid-rarity-dot" style="background:${rarityColor(tile.packRarity)}"></span>
      <div class="pack-grid-name">${esc(tile.text)}</div>
    </div>`).join('');

  const barSegs = RARITIES.map(r => {
    const pct = total > 0 ? (counts[r] / total * 100).toFixed(1) : 0;
    return `<div class="rarity-bar-seg" style="width:${pct}%;background:${rarityColor(r)}"></div>`;
  }).join('');

  const legendItems = RARITIES.map(r =>
    `<div class="rarity-legend-item">
      <span class="rarity-legend-dot" style="background:${rarityColor(r)}"></span>
      ${counts[r]} ${rarityLabel(r).toLowerCase()}
    </div>`
  ).join('');

  col.innerHTML = `
    <div class="pack-detail-toolbar">
      <span class="pack-detail-name">${esc(packMeta.name)}</span>
      <input class="search-input" id="pack-search" placeholder="Search tiles&hellip;" style="max-width:200px" value="${esc(S.packSearch)}">
      <div style="flex:1"></div>
      <button class="btn btn-amber" id="pack-add-tile-btn">+ Add Tile</button>
    </div>
    <div class="pack-detail-body">
      <div class="pack-grid" id="pack-grid">${gridHtml}</div>
      <div class="rarity-bar-section">
        <div class="rarity-bar-label">Rarity Breakdown &mdash; ${total} tiles</div>
        <div class="rarity-bar">${barSegs}</div>
        <div class="rarity-legend">${legendItems}</div>
      </div>
    </div>`;

  document.getElementById('pack-search').addEventListener('input', e => {
    S.packSearch = e.target.value;
    renderPackDetail();
  });
  document.getElementById('pack-add-tile-btn').addEventListener('click', openAddTilePicker);

  // Grid cell click -> switch to All Tiles tab with tile selected
  col.querySelectorAll('.pack-grid-cell').forEach(cell => {
    cell.addEventListener('click', () => {
      switchTab('tiles');
      selectTile(cell.dataset.tileId);
    });
  });
}

// ── Add tile picker ───────────────────────────────────────────────────────────

async function openAddTilePicker() {
  S.pickerPackId = S.selectedPackId;
  S.pickerSearch = '';
  S.pickerSelectedTileId = null;
  S.pickerSelectedRarity = RARITIES[0];
  try {
    S.pickerTiles = await api('GET', `/api/packs/${S.pickerPackId}/tiles-not-in-pack`);
  } catch (err) {
    alert(`Failed to load available tiles: ${err.message}`);
    return;
  }
  renderPicker();
}

function renderPicker() {
  // Remove existing picker if any
  document.getElementById('picker-overlay')?.remove();

  const q = S.pickerSearch.toLowerCase();
  const tiles = q
    ? S.pickerTiles.filter(t => t.text.toLowerCase().includes(q))
    : S.pickerTiles;

  const rows = tiles.map(tile => {
    const sel = S.pickerSelectedTileId === tile.id ? ' style="background:var(--surface2)"' : '';
    return `<div class="picker-tile-row" data-tile-id="${esc(tile.id)}"${sel}>
      <img class="tile-thumb" src="/api/image/${esc(tile.id)}" onerror="this.style.visibility='hidden'" loading="lazy">
      <span>${esc(tile.text)}</span>
      <span class="rarity-badge" style="color:${rarityColor(tile.rarity)}">${esc(rarityLabel(tile.rarity))}</span>
    </div>`;
  }).join('');

  const pickerChips = S.pickerSelectedTileId ? RARITIES.map(r => {
    const col = rarityColor(r);
    const sel = r === S.pickerSelectedRarity ? ' selected' : '';
    return `<button class="rarity-inline-chip${sel}" data-pick-rarity="${r}"
      style="color:${col};${sel?`border-color:${col}`:''}">
      ${rarityLabel(r)}</button>`;
  }).join('') : '';

  const pickerHtml = S.pickerSelectedTileId ? `
    <div class="picker-rarity-picker">
      <div class="picker-rarity-label">Select rarity for this pack:</div>
      <div style="display:flex;gap:6px;flex-wrap:wrap">${pickerChips}</div>
      <div style="margin-top:8px">
        <button class="btn btn-green" id="picker-confirm-btn">Add to Pack</button>
      </div>
    </div>` : '';

  const overlay = document.createElement('div');
  overlay.className = 'picker-overlay';
  overlay.id = 'picker-overlay';
  overlay.innerHTML = `
    <div class="picker-panel">
      <div class="picker-header">
        <span class="picker-title">Add Tile to Pack</span>
        <button class="btn" id="picker-close-btn">&#x2715;</button>
      </div>
      <div class="picker-search">
        <input class="search-input" id="picker-search" placeholder="Search&hellip;" value="${esc(S.pickerSearch)}" style="width:100%">
      </div>
      ${pickerHtml}
      <div class="picker-list" id="picker-list">${rows}</div>
    </div>`;
  document.body.appendChild(overlay);

  document.getElementById('picker-close-btn').addEventListener('click', closePicker);
  overlay.addEventListener('click', e => { if (e.target === overlay) closePicker(); });
  document.getElementById('picker-search').addEventListener('input', e => {
    S.pickerSearch = e.target.value; renderPicker();
  });
  document.querySelectorAll('.picker-tile-row').forEach(row => {
    row.addEventListener('click', () => {
      S.pickerSelectedTileId = row.dataset.tileId;
      const tile = S.pickerTiles.find(t => t.id === S.pickerSelectedTileId);
      S.pickerSelectedRarity = tile?.rarity || RARITIES[0];
      renderPicker();
    });
  });
  document.querySelectorAll('[data-pick-rarity]').forEach(chip => {
    chip.addEventListener('click', () => {
      S.pickerSelectedRarity = chip.dataset.pickRarity; renderPicker();
    });
  });
  document.getElementById('picker-confirm-btn')?.addEventListener('click', confirmAddTile);
}

async function confirmAddTile() {
  if (!S.pickerSelectedTileId) return;
  const packId = S.pickerPackId;
  try {
    const pd = S.packData[packId];
    pd.tiles.push({ id: S.pickerSelectedTileId, rarity: S.pickerSelectedRarity });
    await api('PUT', `/api/packs/${packId}`, pd);
    // Update local packs metadata tileCount
    const meta = S.packs.find(p => p.id === packId);
    if (meta) meta.tileCount = pd.tiles.length;
    closePicker();
    renderPackDetail();
    renderTileList(); // refresh pack dots
  } catch (err) {
    alert(`Failed to add tile: ${err.message}`);
  }
}

function closePicker() {
  document.getElementById('picker-overlay')?.remove();
  S.pickerPackId = null;
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', init);
</script>
</body>
</html>"""


# ── HTTP Server ───────────────────────────────────────────────────────────────

class TileManagerHandler(BaseHTTPRequestHandler):
    api_key: str = ""

    def log_message(self, fmt, *args):
        pass  # suppress default per-request logging

    # ── Helpers ───────────────────────────────────────────────────────────────

    def send_json(self, data: object, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_error_json(self, status: int, message: str) -> None:
        self.send_json({"error": message}, status)

    def read_json_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length))

    # ── Routing ───────────────────────────────────────────────────────────────

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            self._serve_ui()
        elif path == "/api/tiles":
            self.send_json(load_tiles())
        elif path.startswith("/api/image/"):
            self._serve_image(path[len("/api/image/"):])
        elif path == "/api/packs":
            self._handle_list_packs()
        # Specific pack sub-routes BEFORE the generic /api/packs/<id> handler
        elif path.startswith("/api/packs/") and path.endswith("/tiles-not-in-pack"):
            pack_id = path[len("/api/packs/"):-len("/tiles-not-in-pack")]
            self._handle_tiles_not_in_pack(pack_id)
        elif path.startswith("/api/packs/"):
            pack_id = path[len("/api/packs/"):]
            self._handle_get_pack(pack_id)
        elif path == "/api/description-prefill":
            qs = parse_qs(urlparse(self.path).query)
            name     = qs.get("name",     [""])[0]
            category = qs.get("category", [""])[0]
            self.send_json({"prefill": description_prefill(name, category)})
        else:
            self.send_error_json(404, "Not found")

    def do_POST(self):
        path = self.path.split("?")[0]
        if path == "/api/generate":
            self._handle_generate()
        elif path == "/api/tiles":
            self._handle_add_tile()
        elif path.startswith("/api/tiles/") and path.endswith("/image"):
            tile_id = path[len("/api/tiles/"):-len("/image")]
            self._handle_save_image(tile_id)
        else:
            self.send_error_json(404, "Not found")

    def do_PUT(self):
        path = self.path.split("?")[0]
        if path.startswith("/api/tiles/"):
            tile_id = path[len("/api/tiles/"):]
            self._handle_update_tile(tile_id)
        elif path.startswith("/api/packs/"):
            pack_id = path[len("/api/packs/"):]
            self._handle_put_pack(pack_id)
        else:
            self.send_error_json(404, "Not found")

    def do_DELETE(self):
        path = self.path.split("?")[0]
        if path.startswith("/api/tiles/"):
            tile_id = path[len("/api/tiles/"):]
            self._handle_delete_tile(tile_id)
        else:
            self.send_error_json(404, "Not found")

    # ── Handlers ─────────────────────────────────────────────────────────────

    def _serve_ui(self):
        html = HTML_APP.replace(
            "/* __INJECT__ */",
            f"const CATEGORIES = {json.dumps(CATEGORIES)};\n"
            f"    const RARITIES = {json.dumps(RARITIES)};\n"
            f"    const PACKS_META = {json.dumps(PACKS_METADATA)};\n"
            f"    const CATEGORY_HINTS_MAP = {json.dumps(CATEGORY_HINTS)};",
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html)))
        self.end_headers()
        self.wfile.write(html)

    def _serve_image(self, tile_id: str):
        path = image_path(tile_id)
        if not path.exists():
            self.send_error_json(404, "Image not found")
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _handle_generate(self):
        if not self.api_key:
            self.send_error_json(
                503,
                "GEMINI_API_KEY not set — start server with GEMINI_API_KEY=your_key",
            )
            return
        body = self.read_json_body()
        # Accepts {tile_id} for saved tiles or {description, name} for unsaved tiles
        if "tile_id" in body:
            tiles = load_tiles()
            tile = next((t for t in tiles if t["id"] == body["tile_id"]), None)
            if not tile:
                self.send_error_json(404, f"Tile {body['tile_id']!r} not found")
                return
            prompt = build_prompt(tile)
        elif body.get("description"):
            prompt = build_prompt({
                "description": body["description"],
                "text": body.get("name", ""),
            })
        else:
            self.send_error_json(400, "tile_id or description is required")
            return
        try:
            image_b64 = generate_image(prompt, self.api_key)
            self.send_json({"image_b64": image_b64})
        except Exception as exc:
            self.send_error_json(500, str(exc))

    def _handle_add_tile(self):
        body = self.read_json_body()
        required = {"text", "category", "rarity"}
        missing = required - body.keys()
        if missing:
            self.send_error_json(400, f"Missing fields: {', '.join(sorted(missing))}")
            return
        new_id = str(uuid.uuid4()).upper()
        tile = {
            "id":       new_id,
            "text":     body["text"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
        if body.get("description"):
            tile["description"] = body["description"]
        tiles = load_tiles()
        tiles.append(tile)
        save_tiles(tiles)
        if "image_b64" in body:
            save_image(new_id, body["image_b64"])
        # Add to packs: [{packId, rarity}]
        for membership in body.get("packMembership", []):
            pack_id = membership.get("packId")
            rarity  = membership.get("rarity", body["rarity"])
            if not pack_id:
                continue
            try:
                pack = load_pack(pack_id)
            except FileNotFoundError:
                continue
            pack.setdefault("tiles", []).append({"id": new_id, "rarity": rarity})
            save_pack(pack_id, pack)
        self.send_json(tile, 201)

    def _handle_update_tile(self, tile_id: str):
        body = self.read_json_body()
        tiles = load_tiles()
        for tile in tiles:
            if tile["id"] == tile_id:
                allowed = {"text", "category", "rarity", "description"}
                tile.update({k: v for k, v in body.items() if k in allowed})
                if "description" in tile and not tile["description"]:
                    del tile["description"]
                save_tiles(tiles)
                # Apply pack membership changes: [{packId, action, rarity?}]
                # action: 'add' | 'remove'
                for change in body.get("packMembership", []):
                    pack_id = change.get("packId")
                    action  = change.get("action")
                    if not pack_id or action not in ("add", "remove"):
                        continue
                    try:
                        pack = load_pack(pack_id)
                    except FileNotFoundError:
                        continue
                    if action == "add":
                        rarity = change.get("rarity", tile["rarity"])
                        # Remove existing ref for this tile if present, then add
                        pack["tiles"] = [r for r in pack.get("tiles", []) if r["id"] != tile_id]
                        pack["tiles"].append({"id": tile_id, "rarity": rarity})
                    else:  # remove
                        pack["tiles"] = [r for r in pack.get("tiles", []) if r["id"] != tile_id]
                    save_pack(pack_id, pack)
                self.send_json(tile)
                return
        self.send_error_json(404, f"Tile {tile_id} not found")

    def _handle_delete_tile(self, tile_id: str):
        tiles = load_tiles()
        new_tiles = [t for t in tiles if t["id"] != tile_id]
        if len(new_tiles) == len(tiles):
            self.send_error_json(404, f"Tile {tile_id} not found")
            return
        save_tiles(new_tiles)
        # Remove from all packs that reference this tile
        for pack_path in sorted(PACKS_DIR.glob("pack-*.json")):
            pack_id = pack_path.stem[len("pack-"):]   # e.g. "pack-mountains" → "mountains"
            try:
                pack = load_pack(pack_id)
                original_count = len(pack.get("tiles", []))
                pack["tiles"] = [r for r in pack.get("tiles", []) if r["id"] != tile_id]
                if len(pack["tiles"]) < original_count:
                    save_pack(pack_id, pack)
            except Exception:
                pass
        img = image_path(tile_id)
        if img.exists():
            img.unlink()
        self.send_json({"deleted": tile_id})

    def _handle_save_image(self, tile_id: str):
        tiles = load_tiles()
        if not any(t["id"] == tile_id for t in tiles):
            self.send_error_json(404, f"Tile {tile_id} not found")
            return
        body = self.read_json_body()
        image_b64 = body.get("image_b64", "")
        if not image_b64:
            self.send_error_json(400, "image_b64 is required")
            return
        save_image(tile_id, image_b64)
        self.send_json({"saved": tile_id})


    def _handle_list_packs(self):
        self.send_json(PACKS_METADATA)

    def _handle_get_pack(self, pack_id: str):
        if "/" in pack_id:
            self.send_error_json(404, "Not found")
            return
        try:
            self.send_json(load_pack(pack_id))
        except FileNotFoundError:
            self.send_error_json(404, f"Pack {pack_id!r} not found")

    def _handle_tiles_not_in_pack(self, pack_id: str):
        if "/" in pack_id:
            self.send_error_json(404, "Not found")
            return
        try:
            pack = load_pack(pack_id)
        except FileNotFoundError:
            self.send_error_json(404, f"Pack {pack_id!r} not found")
            return
        pack_tile_ids = {ref["id"] for ref in pack.get("tiles", [])}
        all_tiles = load_tiles()
        available = [t for t in all_tiles if t["id"] not in pack_tile_ids]
        self.send_json(available)

    def _handle_put_pack(self, pack_id: str):
        if "/" in pack_id:
            self.send_error_json(404, "Not found")
            return
        try:
            body = self.read_json_body()
        except Exception:
            self.send_error_json(400, "Invalid JSON body")
            return
        for field in ("id", "name", "tiles"):
            if field not in body:
                self.send_error_json(400, f"Missing required field: {field!r}")
                return
        if body["id"] != pack_id:
            self.send_error_json(400, "Pack 'id' in body does not match URL")
            return
        pack_path = PACKS_DIR / f"pack-{pack_id}.json"
        if not pack_path.exists():
            self.send_error_json(404, f"Pack {pack_id!r} not found")
            return
        save_pack(pack_id, body)
        self.send_json({"saved": pack_id})



# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        print("⚠  GEMINI_API_KEY not set — image generation will be disabled")
    TileManagerHandler.api_key = api_key

    global PACKS_METADATA
    PACKS_METADATA = discover_packs()
    names = ", ".join(p["name"] for p in PACKS_METADATA)
    print(f"   Packs loaded: {names or '(none found)'}")

    server = HTTPServer(("127.0.0.1", PORT), TileManagerHandler)
    url = f"http://localhost:{PORT}"
    print(f"✦  Tile Manager  →  {url}")
    print("   Press Ctrl+C to stop\n")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
