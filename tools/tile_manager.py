#!/usr/bin/env python3
"""
Road Trip Bingo — Tile Manager
Usage: GEMINI_API_KEY=your_key python3 tools/tile_manager.py
Opens a browser UI for managing tiles in squares.json and TileImages/.
"""

import base64, json, os, sys, uuid, webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

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

    Uses tile['description'] as the subject phrase if present and non-empty;
    falls back to tile['text'] (the tile name) otherwise.
    STYLE is always appended; CATEGORY_HINTS adds a layout hint per category.
    """
    description = tile.get("description") or tile["text"]
    category = tile.get("category", "")
    hint = CATEGORY_HINTS.get(category, "")
    desc_clean = description.rstrip(".")
    desc_cap = desc_clean[0].upper() + desc_clean[1:]
    parts = [f"{desc_cap}.", hint, STYLE]
    return " ".join(p for p in parts if p).strip()


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
                "id":            data["id"],
                "name":          data["name"],
                "description":   data.get("description", ""),
                "tileCount":     len(data.get("tiles", [])),
                "overrideCount": len(data.get("rarityOverrides", {})),
                "excludedCount": len(data.get("excludedTileIDs", [])),
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
<link href="https://fonts.googleapis.com/css2?family=Rye&family=Barlow+Condensed:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --bg: #0D0D0B; --surface: #141410; --surface2: #1C1C17; --surface3: #242420;
  --border: #2E2E28; --border2: #3A3A32;
  --text: #E8E0CC; --text2: #9A9080; --text3: #5A5448;
  --amber: #E8A830; --amber-dim: #7A5A18;
  --red: #C84040; --red-dim: #6A2020;
  --green: #4A9060; --green-dim: #1E4028;
  --font-display: 'Rye', serif;
  --font-ui: 'Barlow Condensed', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}
html, body { height: 100%; overflow: hidden; background: var(--bg); color: var(--text); font-family: var(--font-ui); }
.topbar { flex-shrink: 0; height: 44px; display: flex; align-items: stretch; background: var(--surface); border-bottom: 1px solid var(--border); }
.topbar-logo { display: flex; align-items: center; padding: 0 18px; gap: 8px; font-family: var(--font-display); font-size: 15px; color: var(--amber); border-right: 1px solid var(--border); white-space: nowrap; flex-shrink: 0; }
.topbar-logo span { color: var(--text3); font-size: 12px; font-family: var(--font-ui); font-weight: 400; }
.tabs { display: flex; align-items: stretch; overflow-x: auto; flex: 1; }
.tabs::-webkit-scrollbar { display: none; }
.tab { display: flex; align-items: center; gap: 7px; padding: 0 16px; font-size: 13px; font-weight: 600; color: var(--text3); cursor: pointer; border-right: 1px solid var(--border); border-bottom: 3px solid transparent; white-space: nowrap; transition: color .12s, background .12s; user-select: none; }
.tab:hover { color: var(--text2); background: var(--surface2); }
.tab.active { color: var(--amber); border-bottom-color: var(--amber); background: var(--bg); }
.tab-dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
.topbar-stat { display: flex; flex-direction: column; align-items: flex-end; justify-content: center; padding: 0 18px; border-left: 1px solid var(--border); flex-shrink: 0; }
.topbar-stat .val { font-family: var(--font-mono); font-size: 15px; line-height: 1; }
.topbar-stat .lbl { font-size: 9px; color: var(--text3); text-transform: uppercase; letter-spacing: .8px; margin-top: 2px; }
.screens { flex: 1; overflow: hidden; position: relative; }
.screen { display: none; position: absolute; inset: 0; flex-direction: row; }
.screen.active { display: flex; }
body::before {
  content: ''; position: fixed; inset: 0; pointer-events: none; z-index: 100; opacity: 0.025;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
  background-size: 128px;
}
.app { display: flex; flex-direction: column; height: 100vh; }
.body { flex: 1; display: flex; overflow: hidden; }
.left { width: 460px; flex-shrink: 0; display: flex; flex-direction: column; border-right: 1px solid var(--border); }
.toolbar { flex-shrink: 0; display: flex; gap: 8px; align-items: center; padding: 10px 12px; background: var(--surface); border-bottom: 1px solid var(--border); }
.search-wrap { flex: 1; position: relative; }
.search-wrap svg { position: absolute; left: 9px; top: 50%; transform: translateY(-50%); color: var(--text3); width: 13px; height: 13px; }
.search { width: 100%; background: var(--bg); border: 1px solid var(--border2); border-radius: 4px; padding: 6px 10px 6px 28px; font-family: var(--font-ui); font-size: 13px; color: var(--text); outline: none; transition: border-color 0.15s; }
.search:focus { border-color: var(--amber-dim); }
.search::placeholder { color: var(--text3); }
.cat-select { background: var(--bg); border: 1px solid var(--border2); border-radius: 4px; padding: 6px 8px; font-family: var(--font-ui); font-size: 13px; color: var(--text2); outline: none; cursor: pointer; }
.btn-add { background: var(--amber); border: none; border-radius: 4px; padding: 6px 12px; font-family: var(--font-ui); font-size: 13px; font-weight: 700; color: var(--bg); cursor: pointer; white-space: nowrap; letter-spacing: 0.3px; transition: opacity 0.15s; }
.btn-add:hover { opacity: 0.85; }
.col-head { flex-shrink: 0; display: grid; grid-template-columns: 44px 1fr 96px 82px; padding: 5px 12px; border-bottom: 1px solid var(--border); background: var(--surface); }
.col-head span { font-size: 9px; text-transform: uppercase; letter-spacing: 1px; color: var(--text3); font-weight: 600; }
.col-head span.sortable { cursor: pointer; user-select: none; }
.col-head span.sortable:hover { color: var(--text2); }
.col-head span.sort-active { color: var(--amber); }
.table-body { flex: 1; overflow-y: auto; }
.table-body::-webkit-scrollbar { width: 4px; }
.table-body::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 2px; }
.row { display: grid; grid-template-columns: 44px 1fr 96px 82px; padding: 6px 12px; align-items: center; border-bottom: 1px solid var(--border); cursor: pointer; transition: background 0.1s; border-left: 2px solid transparent; }
.row:hover { background: var(--surface2); }
.row.selected { background: var(--surface2); border-left-color: var(--amber); }
.row-thumb { width: 30px; height: 30px; background: var(--surface3); border-radius: 4px; overflow: hidden; display: flex; align-items: center; justify-content: center; }
.row-thumb img { width: 100%; height: 100%; object-fit: cover; }
.row-name { font-size: 13px; color: var(--text); padding: 0 8px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 500; }
.row-cat { font-size: 11px; color: var(--text2); font-weight: 500; }
.rarity { font-size: 10px; font-family: var(--font-mono); font-weight: 500; padding: 2px 6px; border-radius: 3px; width: fit-content; }
.rarity.vc  { color: #4A9060; background: rgba(74,144,96,0.12); }
.rarity.c   { color: #4870A8; background: rgba(72,112,168,0.12); }
.rarity.u   { color: #B87830; background: rgba(184,120,48,0.12); }
.rarity.r   { color: #C84040; background: rgba(200,64,64,0.12); }
.rarity.vr  { color: #9060C8; background: rgba(144,96,200,0.12); }
.table-footer { flex-shrink: 0; padding: 6px 12px; border-top: 1px solid var(--border); background: var(--surface); font-size: 10px; color: var(--text3); letter-spacing: 0.5px; }
.right { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.panel-empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 12px; color: var(--text3); }
.panel-empty svg { width: 48px; height: 48px; opacity: 0.3; }
.panel-content { flex: 1; display: none; flex-direction: column; overflow: hidden; }
.panel-header { flex-shrink: 0; display: flex; align-items: center; justify-content: space-between; padding: 10px 20px; border-bottom: 1px solid var(--border); background: var(--surface); }
.panel-title { font-size: 16px; font-weight: 700; color: var(--text); letter-spacing: 0.3px; }
.panel-id { font-family: var(--font-mono); font-size: 10px; color: var(--text3); }
.panel-body { flex: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; gap: 22px; }
.panel-body::-webkit-scrollbar { width: 4px; }
.panel-body::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 2px; }
.section-label { font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: var(--text3); font-weight: 600; margin-bottom: 10px; display: flex; align-items: center; gap: 8px; }
.section-label::after { content: ''; flex: 1; height: 1px; background: var(--border); }
.image-section { display: flex; gap: 16px; align-items: flex-start; }
.image-current-wrap { width: 110px; height: 110px; flex-shrink: 0; background: var(--surface2); border-radius: 8px; border: 1px solid var(--border2); display: flex; align-items: center; justify-content: center; overflow: hidden; }
.image-current-wrap img { width: 100%; height: 100%; object-fit: cover; display: block; }
.img-placeholder { font-size: 52px; }
.image-controls { flex: 1; display: flex; flex-direction: column; gap: 10px; }
.image-hint { font-size: 12px; color: var(--text2); line-height: 1.5; }
.btn-generate { background: transparent; border: 1px solid var(--amber-dim); border-radius: 5px; padding: 9px 14px; font-family: var(--font-ui); font-size: 13px; font-weight: 600; color: var(--amber); cursor: pointer; letter-spacing: 0.3px; transition: background 0.15s, border-color 0.15s; display: flex; align-items: center; gap: 7px; }
.btn-generate:hover { background: rgba(232,168,48,0.1); border-color: var(--amber); }
.prompt-editor { background: var(--surface2); border: 1px solid var(--border2); border-radius: 6px; overflow: hidden; display: none; margin-top: 12px; animation: slideDown 0.18s ease; }
.prompt-editor.visible { display: block; }
@keyframes slideDown { from { opacity: 0; transform: translateY(-6px); } to { opacity: 1; transform: none; } }
.prompt-editor-header { display: flex; align-items: center; justify-content: space-between; padding: 8px 12px; border-bottom: 1px solid var(--border); }
.prompt-editor-label { font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: var(--amber); font-weight: 600; }
.prompt-editor-hint  { font-size: 10px; color: var(--text3); }
.prompt-textarea { width: 100%; background: transparent; border: none; outline: none; padding: 10px 12px; font-family: var(--font-mono); font-size: 11px; color: var(--text2); line-height: 1.6; resize: none; min-height: 90px; }
.prompt-actions { display: flex; gap: 8px; padding: 8px 12px; border-top: 1px solid var(--border); }
.btn-run { background: var(--amber); border: none; border-radius: 4px; padding: 7px 14px; font-family: var(--font-ui); font-size: 13px; font-weight: 700; color: var(--bg); cursor: pointer; transition: opacity 0.15s; }
.btn-run:hover { opacity: 0.85; }
.btn-cancel-prompt { background: transparent; border: 1px solid var(--border2); border-radius: 4px; padding: 7px 12px; font-family: var(--font-ui); font-size: 13px; color: var(--text3); cursor: pointer; }
.gen-loading { display: none; align-items: center; gap: 10px; padding: 8px 0; margin-top: 8px; }
.gen-loading.visible { display: flex; }
.spinner { width: 18px; height: 18px; border: 2px solid var(--border2); border-top-color: var(--amber); border-radius: 50%; animation: spin 0.7s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.gen-loading span { font-size: 12px; color: var(--text2); }
.gen-result { background: var(--green-dim,#1E4028); border: 1px solid var(--green); border-radius: 6px; padding: 12px; display: none; margin-top: 12px; animation: slideDown 0.18s ease; }
.gen-result.visible { display: block; }
.gen-result-label { font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: var(--green); font-weight: 600; margin-bottom: 10px; }
.gen-result-inner { display: flex; gap: 12px; align-items: center; }
.gen-preview-wrap { width: 80px; height: 80px; flex-shrink: 0; background: var(--surface3); border-radius: 6px; border: 1px solid var(--border2); overflow: hidden; }
.gen-preview-wrap img { width: 100%; height: 100%; object-fit: cover; display: block; }
.gen-actions { flex: 1; display: flex; flex-direction: column; gap: 6px; }
.btn-approve { background: var(--green); border: none; border-radius: 4px; padding: 8px 12px; font-family: var(--font-ui); font-size: 13px; font-weight: 600; color: white; cursor: pointer; transition: opacity 0.15s; }
.btn-approve:hover { opacity: 0.85; }
.btn-discard { background: transparent; border: 1px solid var(--border2); border-radius: 4px; padding: 8px 12px; font-family: var(--font-ui); font-size: 13px; color: var(--text3); cursor: pointer; }
.field { display: flex; flex-direction: column; gap: 5px; }
.field-label { font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text3); font-weight: 600; }
.field-input { background: var(--surface2); border: 1px solid var(--border2); border-radius: 5px; padding: 8px 11px; font-family: var(--font-ui); font-size: 14px; color: var(--text); outline: none; transition: border-color 0.15s; width: 100%; }
.field-input:focus { border-color: var(--amber-dim); }
.fields-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.panel-footer { flex-shrink: 0; display: flex; align-items: center; justify-content: space-between; padding: 12px 20px; border-top: 1px solid var(--border); background: var(--surface); }
.btn-delete { background: transparent; border: 1px solid var(--red-dim); border-radius: 4px; padding: 7px 14px; font-family: var(--font-ui); font-size: 13px; font-weight: 600; color: var(--red); cursor: pointer; letter-spacing: 0.3px; transition: all 0.15s; }
.btn-delete:hover { background: rgba(200,64,64,0.1); }
.footer-right { display: flex; gap: 8px; }
.btn-cancel { background: transparent; border: 1px solid var(--border2); border-radius: 4px; padding: 7px 14px; font-family: var(--font-ui); font-size: 13px; color: var(--text3); cursor: pointer; }
.btn-save { background: var(--amber); border: none; border-radius: 4px; padding: 7px 20px; font-family: var(--font-ui); font-size: 13px; font-weight: 700; color: var(--bg); cursor: pointer; letter-spacing: 0.3px; transition: opacity 0.15s; }
.btn-save:hover { opacity: 0.85; }
/* ── Pack diff list ─────────────────────────────── */
.pack-left { width: 460px; flex-shrink: 0; display: flex; flex-direction: column; border-right: 1px solid var(--border); overflow: hidden; }
.pack-right { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.diff-toolbar { flex-shrink: 0; display: flex; gap: 8px; align-items: center; padding: 10px 12px; background: var(--surface); border-bottom: 1px solid var(--border); }
.type-select { background: var(--bg); border: 1px solid var(--border2); border-radius: 4px; padding: 6px 8px; font-family: var(--font-ui); font-size: 13px; color: var(--text2); outline: none; cursor: pointer; }
.btn-add-split { position: relative; display: inline-block; }
.btn-add-split button { background: var(--amber); border: none; border-radius: 4px; padding: 6px 12px; font-family: var(--font-ui); font-size: 13px; font-weight: 700; color: var(--bg); cursor: pointer; letter-spacing: 0.3px; transition: opacity .15s; }
.btn-add-split button:hover { opacity: 0.85; }
.add-menu { display: none; position: absolute; right: 0; top: calc(100% + 4px); background: var(--surface2); border: 1px solid var(--border2); border-radius: 6px; overflow: hidden; z-index: 50; min-width: 180px; box-shadow: 0 4px 16px rgba(0,0,0,0.4); }
.add-menu.open { display: block; }
.add-menu-item { display: block; width: 100%; text-align: left; padding: 9px 14px; font-family: var(--font-ui); font-size: 13px; font-weight: 500; color: var(--text); background: transparent; border: none; cursor: pointer; transition: background .1s; }
.add-menu-item:hover { background: var(--surface3); }
.diff-col-head { flex-shrink: 0; display: grid; grid-template-columns: 44px 1fr 90px 1fr; padding: 5px 12px; border-bottom: 1px solid var(--border); background: var(--surface); }
.diff-col-head span { font-size: 9px; text-transform: uppercase; letter-spacing: 1px; color: var(--text3); font-weight: 600; }
.diff-list { flex: 1; overflow-y: auto; }
.diff-list::-webkit-scrollbar { width: 4px; }
.diff-list::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 2px; }
.diff-row { display: grid; grid-template-columns: 44px 1fr 90px 1fr; padding: 6px 12px; align-items: center; border-bottom: 1px solid var(--border); cursor: pointer; transition: background .1s; border-left: 3px solid transparent; }
.diff-row:hover { background: var(--surface2); }
.diff-row.selected { background: var(--surface2); }
.diff-row.exclusive { border-left-color: var(--green); }
.diff-row.override { border-left-color: var(--amber); }
.diff-row.excluded { border-left-color: var(--red); opacity: 0.7; }
.diff-row.selected.exclusive { background: rgba(74,144,96,0.08); }
.diff-row.selected.override  { background: rgba(232,168,48,0.08); }
.diff-row.selected.excluded  { background: rgba(200,64,64,0.08); }
.diff-thumb { width: 30px; height: 30px; background: var(--surface3); border-radius: 4px; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 14px; }
.diff-thumb img { width: 100%; height: 100%; object-fit: cover; }
.diff-name { font-size: 13px; font-weight: 500; color: var(--text); padding: 0 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.diff-name.strikethrough { text-decoration: line-through; color: var(--text2); }
.diff-badge { font-size: 9px; font-weight: 700; padding: 2px 6px; border-radius: 3px; letter-spacing: .8px; width: fit-content; }
.diff-badge.exclusive { color: var(--green); background: rgba(74,144,96,0.15); }
.diff-badge.override  { color: var(--amber); background: rgba(232,168,48,0.15); }
.diff-badge.excluded  { color: var(--red);   background: rgba(200,64,64,0.15); }
.diff-detail { font-size: 11px; color: var(--text2); padding: 0 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.diff-detail.override-arrow { color: var(--amber); }
.diff-footer { flex-shrink: 0; display: flex; align-items: center; justify-content: space-between; padding: 6px 12px; border-top: 1px solid var(--border); background: var(--surface); }
.diff-footer-count { font-size: 10px; color: var(--text3); letter-spacing: .5px; }
.btn-save-pack { background: var(--green); border: none; border-radius: 4px; padding: 6px 18px; font-family: var(--font-ui); font-size: 13px; font-weight: 700; color: white; cursor: pointer; transition: opacity .15s; }
.btn-save-pack:hover { opacity: 0.85; }
.btn-save-pack:disabled { opacity: 0.35; cursor: default; }
/* Pack right panel states */
.pack-summary { padding: 24px 20px; display: flex; flex-direction: column; gap: 8px; }
.pack-summary-name { font-family: var(--font-display); font-size: 20px; color: var(--amber); }
.pack-summary-counts { font-size: 13px; color: var(--text2); line-height: 2; }
.pack-summary-hint { font-size: 12px; color: var(--text3); margin-top: 8px; }
.rarity-from-to { display: flex; align-items: center; gap: 12px; padding: 14px 0; }
.rarity-from-to .arrow { font-size: 18px; color: var(--text3); }
.override-base-info { background: var(--surface2); border: 1px solid var(--border2); border-radius: 6px; padding: 12px; font-size: 12px; color: var(--text2); display: flex; flex-direction: column; gap: 4px; }
.override-base-info .name { font-size: 14px; font-weight: 600; color: var(--text); }
.excluded-callout { background: rgba(200,64,64,0.08); border: 1px solid rgba(200,64,64,0.25); border-radius: 6px; padding: 12px; font-size: 12px; color: var(--red); }
.btn-remove { background: transparent; border: 1px solid var(--red-dim); border-radius: 4px; padding: 8px 14px; font-family: var(--font-ui); font-size: 13px; font-weight: 600; color: var(--red); cursor: pointer; width: 100%; letter-spacing: .3px; transition: all .15s; }
.btn-remove:hover { background: rgba(200,64,64,0.1); }
.btn-convert { background: transparent; border: 1px solid var(--amber-dim); border-radius: 4px; padding: 8px 14px; font-family: var(--font-ui); font-size: 13px; font-weight: 600; color: var(--amber); cursor: pointer; width: 100%; letter-spacing: .3px; transition: all .15s; margin-bottom: 8px; }
.btn-convert:hover { background: rgba(232,168,48,0.1); }
/* Base tile picker (used by addition flows) */
.tile-picker { display: flex; flex-direction: column; overflow: hidden; flex: 1; }
.tile-picker-search { background: var(--bg); border: 1px solid var(--border2); border-radius: 4px; padding: 7px 10px; font-family: var(--font-ui); font-size: 13px; color: var(--text); outline: none; margin: 12px 20px 8px; }
.tile-picker-search:focus { border-color: var(--amber-dim); }
.tile-picker-list { flex: 1; overflow-y: auto; }
.tile-picker-row { display: flex; align-items: center; gap: 10px; padding: 7px 20px; cursor: pointer; border-bottom: 1px solid var(--border); transition: background .1s; }
.tile-picker-row:hover { background: var(--surface2); }
.tile-picker-row .name { font-size: 13px; font-weight: 500; color: var(--text); flex: 1; }
.tile-picker-row .cat  { font-size: 11px; color: var(--text2); }
.warning-callout { background: rgba(200,64,64,0.08); border: 1px solid rgba(200,64,64,0.25); border-radius: 6px; padding: 12px 20px; font-size: 12px; color: var(--red); margin: 0 20px 12px; line-height: 1.5; }
.warning-callout.amber { background: rgba(232,168,48,0.08); border-color: rgba(232,168,48,0.25); color: var(--amber); }
.picker-actions { display: flex; gap: 8px; padding: 12px 20px; border-top: 1px solid var(--border); flex-shrink: 0; }
.picker-rarity-wrap { padding: 12px 20px; }
.picker-rarity-label { font-size: 10px; text-transform: uppercase; letter-spacing: .8px; color: var(--text3); font-weight: 600; margin-bottom: 10px; }
* { scrollbar-width: thin; scrollbar-color: var(--border2) transparent; }
</style>
</head>
<body>
<div class="app">
  <div class="topbar">
    <div class="topbar-logo">Road Trip Bingo <span>/ Tile Manager</span></div>
    <div class="tabs" id="tabs">
      <div class="tab active" id="tab-base" onclick="switchTab('base')">
        <div class="tab-dot" style="background:var(--text2)"></div>
        Base Tiles
      </div>
      <!-- Pack tabs injected by JS on init -->
    </div>
    <div class="topbar-stat">
      <span class="val" id="stat-tiles">—</span>
      <span class="lbl">Tiles</span>
    </div>
  </div>
  <div class="screens">
  <div class="screen active" id="screen-base">
  <div class="body">
    <div class="left">
      <div class="toolbar">
        <div class="search-wrap">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
          <input class="search" id="search" type="text" placeholder="Search tiles…">
        </div>
        <select class="cat-select" id="filter-cat"></select>
        <button class="btn-add" onclick="startAddMode()">+ Add Tile</button>
      </div>
      <div class="col-head">
        <span></span><span id="sort-name" class="sortable" onclick="toggleSort('name')">Name</span><span>Category</span><span id="sort-rarity" class="sortable" onclick="toggleSort('rarity')">Rarity</span>
      </div>
      <div class="table-body" id="table-body"></div>
      <div class="table-footer" id="table-footer">Loading…</div>
    </div>
    <div class="right">
      <div class="panel-empty" id="panel-empty">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6h16M4 10h16M4 14h16M4 18h16"/></svg>
        <p>Select a tile to edit</p>
      </div>
      <div class="panel-content" id="panel-content">
        <div class="panel-header">
          <div class="panel-title" id="panel-title"></div>
          <div class="panel-id" id="panel-id"></div>
        </div>
        <div class="panel-body">
          <div>
            <div class="section-label">Tile Image</div>
            <div class="image-section">
              <div class="image-current-wrap" id="image-wrap">
                <span class="img-placeholder" id="img-placeholder"></span>
                <img id="image-current" src="" alt="" style="display:none" onerror="this.style.display='none';document.getElementById('img-placeholder').style.display=''">
              </div>
              <div class="image-controls">
                <div class="image-hint">Current image. Generate a new one with Gemini, then approve or discard before saving.</div>
                <button class="btn-generate" id="btn-generate" onclick="showPromptEditor()">❆ Generate New Image</button>
              </div>
            </div>
            <div class="prompt-editor" id="prompt-editor">
              <div class="prompt-editor-header">
                <span class="prompt-editor-label">Generation Prompt</span>
                <span class="prompt-editor-hint">Edit before running</span>
              </div>
              <textarea class="prompt-textarea" id="prompt-textarea" rows="5"></textarea>
              <div class="prompt-actions">
                <button class="btn-run" onclick="runGeneration()">Run Generation</button>
                <button class="btn-cancel-prompt" onclick="hidePromptEditor()">Cancel</button>
              </div>
            </div>
            <div class="gen-loading" id="gen-loading">
              <div class="spinner"></div>
              <span>Generating with Gemini 2.5 Flash…</span>
            </div>
            <div class="gen-result" id="gen-result">
              <div class="gen-result-label">✓ Image generated — approve or discard</div>
              <div class="gen-result-inner">
                <div class="gen-preview-wrap"><img id="gen-preview-img" src="" alt="generated"></div>
                <div class="gen-actions">
                  <button class="btn-approve" onclick="approveImage()">✓ Use This Image</button>
                  <button class="btn-discard" onclick="discardImage()">✕ Discard · Keep Original</button>
                </div>
              </div>
            </div>
          </div>
          <div>
            <div class="section-label">Metadata</div>
            <div style="display:flex;flex-direction:column;gap:12px">
              <div class="field"><label class="field-label">Name</label><input class="field-input" id="field-name" type="text"></div>
              <div class="field"><label class="field-label">Image Description <span style="color:var(--text3);font-weight:400;text-transform:none;letter-spacing:0">(optional — defaults to tile name)</span></label><textarea class="field-input" id="field-description" rows="2" style="resize:vertical;font-size:13px;line-height:1.5" placeholder="e.g. A red Kenworth semi truck cab, side view, no trailer"></textarea></div>
              <div class="fields-row">
                <div class="field"><label class="field-label">Category</label><select class="field-input" id="field-category" style="cursor:pointer"></select></div>
                <div class="field"><label class="field-label">Rarity</label><select class="field-input" id="field-rarity" style="cursor:pointer"></select></div>
              </div>
            </div>
          </div>
        </div>
        <div class="panel-footer">
          <button class="btn-delete" id="btn-delete" onclick="deleteTile()">🗑 Delete Tile</button>
          <div class="footer-right">
            <button class="btn-cancel" onclick="cancelEdit()">Cancel</button>
            <button class="btn-save" onclick="saveTile()">Save Changes</button>
          </div>
        </div>
      </div>
    </div>
  </div><!-- .body -->
  </div><!-- #screen-base -->
  <!-- Pack screens injected by JS on init -->
  </div><!-- .screens -->
</div><!-- .app -->
<script>
/* __INJECT__ */

// ── State ─────────────────────────────────────────────────────────────────────────────
let tiles = [];
let selectedId = null;
let isAddMode = false;
let pendingImageB64 = null;
let deleteConfirming = false;
let lastUsedPrompt = null;  // preserved across discard so user can iterate on a custom prompt
let sortKey = null;   // 'name' | 'rarity' | null
let sortAsc = true;

// ── Pack tab colors (by pack id) ─────────────────────────────────────────────
const PACK_COLORS = {
  'farm-country':     '#4A9060',
  'interstate':       '#5B8DD9',
  'city':             '#9060C8',
  'mountains':        '#7A9060',
  'beach-coast':      '#4090A8',
  'desert-southwest': '#C87840',
};

// ── Pack screen state ─────────────────────────────────────────────────────────
let currentPackId   = null;  // which pack tab is active (null = base tiles)
let packData        = null;  // full pack object in client memory
let selectedMod     = null;  // {type: 'exclusive'|'override'|'excluded', id: uuid}
let isDirty         = false; // unsaved pack changes
let packFilterType  = '';    // '' | 'exclusive' | 'override' | 'excluded'
let packSearchQuery = '';    // search filter for diff list

// ── Tab switching ─────────────────────────────────────────────────────────────
function switchTab(tabId) {
  // No-op if already on this tab
  if (document.getElementById('tab-' + tabId)?.classList.contains('active')) return;
  if (isDirty) {
    if (!confirm('You have unsaved pack changes. Leave anyway?')) return;
  }
  // Reset all pack state before switching (prevents stale state across tabs)
  packData        = null;
  selectedMod     = null;
  packFilterType  = '';
  packSearchQuery = '';
  isDirty         = false;
  // Deactivate all tabs and screens
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  // Activate selected
  const tabEl    = document.getElementById('tab-' + tabId);
  const screenEl = document.getElementById('screen-' + tabId);
  if (tabEl)    tabEl.classList.add('active');
  if (screenEl) screenEl.classList.add('active');

  if (tabId === 'base') {
    currentPackId = null;
  } else {
    currentPackId = tabId;
    loadPackScreen(tabId);
  }
}

// ── Prompt building (mirrors server-side logic) ──────────────────────────────────────
const CATEGORY_HINTS_JS = {
  vehicles:  'Side view, full vehicle visible.',
  nature:    'Full subject visible, centered.',
  signs:     'The physical sign or object itself, not just a flat sign graphic.',
  landmarks: 'Full structure visible.',
  food:      'Storefront or roadside view.',
  weather:   'Dramatic sky scene.',
};
const STYLE_JS = 'Flat vector illustration, clean thin outlines, bright colors. Plain solid white background — the illustration sits directly on white with absolutely no drop shadow, no border, no card, no frame, no vignette, no outline around the image edge. Square composition. No text, no labels, no letters.';

function buildPrompt(name, category) {
  const hint = CATEGORY_HINTS_JS[category] || '';
  return ['A ' + name.toLowerCase() + '.', hint, STYLE_JS].filter(Boolean).join(' ').replace(/\\s+/g, ' ').trim();
}

// ── Init ────────────────────────────────────────────────────────────────────────────────
async function init() {
  populateCategoryDropdowns();
  populateRarityDropdowns();
  const tilesData = await fetch('/api/tiles').then(r => r.json());
  tiles = tilesData;
  renderTable();
  updateStats();
  buildPackTabs();
}

function buildPackTabs() {
  const tabsEl    = document.getElementById('tabs');
  const screensEl = document.querySelector('.screens');
  PACKS_META.forEach(pack => {
    // Tab
    const color = PACK_COLORS[pack.id] || 'var(--text2)';
    const tab = document.createElement('div');
    tab.className = 'tab';
    tab.id = 'tab-' + pack.id;
    tab.innerHTML = '<div class="tab-dot" style="background:' + color + '"></div>' + esc(pack.name);
    tab.onclick = () => switchTab(pack.id);
    tabsEl.appendChild(tab);
    // Screen skeleton (content populated when first visited)
    const screen = document.createElement('div');
    screen.className = 'screen';
    screen.id = 'screen-' + pack.id;
    // NOTE: .add-menu-item clicks do NOT close the menu via the click-outside handler
    // (they're inside .btn-add-split so closest('.btn-add-split') is truthy).
    // Task 5 action functions (startAddExclusive etc.) must call toggleAddMenu explicitly to close.
    screen.innerHTML =
      '<div class="pack-left">' +
        '<div class="diff-toolbar">' +
          '<div class="search-wrap" style="flex:1">' +
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="position:absolute;left:9px;top:50%;transform:translateY(-50%);color:var(--text3);width:13px;height:13px"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>' +
            '<input class="search" type="text" placeholder="Search modifications…" oninput="onPackSearch(this.value)">' +
          '</div>' +
          '<select class="type-select" onchange="onPackTypeFilter(this.value)">' +
            '<option value="">All types</option>' +
            '<option value="exclusive">Exclusive</option>' +
            '<option value="override">Override</option>' +
            '<option value="excluded">Excluded</option>' +
          '</select>' +
          '<div class="btn-add-split" id="add-split-' + pack.id + '">' +
            '<button onclick="toggleAddMenu(\\'' + pack.id + '\\')">+ Add ▾</button>' +
            '<div class="add-menu" id="add-menu-' + pack.id + '">' +
              '<button class="add-menu-item" onclick="startAddExclusive()">Create Exclusive Tile</button>' +
              '<button class="add-menu-item" onclick="startMoveFromBase()">Move from Base</button>' +
              '<button class="add-menu-item" onclick="startAddOverride()">Override Rarity</button>' +
              '<button class="add-menu-item" onclick="startExcludeBase()">Exclude Base Tile</button>' +
            '</div>' +
          '</div>' +
        '</div>' +
        '<div class="diff-col-head"><span></span><span>Tile</span><span>Type</span><span>Detail</span></div>' +
        '<div class="diff-list" id="diff-list-' + pack.id + '"></div>' +
        '<div class="diff-footer">' +
          '<span class="diff-footer-count" id="diff-count-' + pack.id + '">—</span>' +
          '<button class="btn-save-pack" id="btn-save-' + pack.id + '" disabled onclick="savePack()">Save Pack</button>' +
        '</div>' +
      '</div>' +
      '<div class="pack-right" id="pack-right-' + pack.id + '">' +
        '<div style="flex:1;display:flex;flex-direction:column;justify-content:center;padding:20px">' +
          '<div class="pack-summary">' +
            '<div class="pack-summary-name">' + esc(pack.name) + '</div>' +
            '<div class="pack-summary-counts" id="pack-counts-' + pack.id + '">Loading…</div>' +
            '<div class="pack-summary-hint">Select a modification to edit, or use + Add to create one.</div>' +
          '</div>' +
        '</div>' +
      '</div>';
    screensEl.appendChild(screen);
  });
  // Close add menus when clicking outside
  document.addEventListener('click', e => {
    if (!e.target.closest('.btn-add-split')) {
      document.querySelectorAll('.add-menu').forEach(m => m.classList.remove('open'));
    }
  });
}

function toggleAddMenu(packId) {
  const menu = document.getElementById('add-menu-' + packId);
  menu.classList.toggle('open');
}

// ── Pack screen data ──────────────────────────────────────────────────────────
async function loadPackScreen(packId) {
  selectedMod     = null;
  packFilterType  = '';
  packSearchQuery = '';
  isDirty         = false;
  try {
    const r = await fetch('/api/packs/' + packId);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    packData = await r.json();
  } catch (err) {
    packData = null;
    const listEl = document.getElementById('diff-list-' + packId);
    if (listEl) listEl.innerHTML = '<div style="padding:24px;text-align:center;color:var(--red);font-size:13px">Failed to load pack: ' + esc(err.message) + '</div>';
    return;
  }
  renderPackDiffList();
  updatePackSummaryPanel();
}

function onPackSearch(val) {
  packSearchQuery = val.toLowerCase();
  renderPackDiffList();
}

function onPackTypeFilter(val) {
  packFilterType = val;
  renderPackDiffList();
}

function markDirty() {
  isDirty = true;
  const btn = document.getElementById('btn-save-' + currentPackId);
  if (btn) btn.disabled = false;
}

// ── Render diff list ──────────────────────────────────────────────────────────
function getPackMods() {
  if (!packData) return [];
  const mods = [];
  // Exclusive tiles
  (packData.tiles || []).forEach(t => {
    mods.push({ type: 'exclusive', id: t.id, tile: t });
  });
  // Rarity overrides
  Object.entries(packData.rarityOverrides || {}).forEach(([uuid, newRarity]) => {
    const baseTile = tiles.find(t => t.id === uuid);
    mods.push({ type: 'override', id: uuid, baseTile, newRarity });
  });
  // Exclusions
  (packData.excludedTileIDs || []).forEach(uuid => {
    const baseTile = tiles.find(t => t.id === uuid);
    mods.push({ type: 'excluded', id: uuid, baseTile });
  });
  return mods;
}

function getFilteredMods() {
  return getPackMods().filter(m => {
    if (packFilterType && m.type !== packFilterType) return false;
    if (!packSearchQuery) return true;
    const name = m.type === 'exclusive'
      ? (m.tile.text || '').toLowerCase()
      : (m.baseTile ? m.baseTile.text : '').toLowerCase();
    return name.includes(packSearchQuery);
  });
}

function renderPackDiffList() {
  if (!currentPackId || !packData) return;
  const listEl  = document.getElementById('diff-list-' + currentPackId);
  const countEl = document.getElementById('diff-count-' + currentPackId);
  if (!listEl || !countEl) return;
  const filtered = getFilteredMods();
  const all      = getPackMods();

  countEl.textContent = all.length + ' modification' + (all.length !== 1 ? 's' : '');

  listEl.innerHTML = filtered.map(m => {
    const isSelected = selectedMod && selectedMod.type === m.type && selectedMod.id === m.id;
    const sel = isSelected ? ' selected' : '';

    if (m.type === 'exclusive') {
      const imgSrc     = '/api/image/' + m.tile.id;
      const rarityBadge = '<span class="rarity ' + (RARITY_CLS[m.tile.rarity] || '') + '">' + esc(m.tile.rarity) + '</span>';
      return '<div class="diff-row exclusive' + sel + '" onclick="selectMod(\\'' + m.type + '\\',\\'' + m.id + '\\')">' +
        '<div class="diff-thumb"><img src="' + imgSrc + '" onerror="this.style.display=\\'none\\'"></div>' +
        '<div class="diff-name">' + esc(m.tile.text) + '</div>' +
        '<div><span class="diff-badge exclusive">EXCLUSIVE</span></div>' +
        '<div class="diff-detail">' + rarityBadge + '</div>' +
        '</div>';
    }

    if (m.type === 'override') {
      const name   = m.baseTile ? esc(m.baseTile.text) : '<em style="color:var(--text3)">Unknown tile</em>';
      const fromR  = m.baseTile ? m.baseTile.rarity : '?';
      const detail = '<span style="color:var(--text2)">' + esc(fromR) + '</span> → <span style="color:var(--amber)">' + esc(m.newRarity) + '</span>';
      return '<div class="diff-row override' + sel + '" onclick="selectMod(\\'' + m.type + '\\',\\'' + m.id + '\\')">' +
        '<div class="diff-thumb" style="font-size:12px;color:var(--text3)">—</div>' +
        '<div class="diff-name">' + name + '</div>' +
        '<div><span class="diff-badge override">OVERRIDE</span></div>' +
        '<div class="diff-detail override-arrow">' + detail + '</div>' +
        '</div>';
    }

    // excluded
    const name = m.baseTile ? esc(m.baseTile.text) : '<em style="color:var(--text3)">Unknown tile</em>';
    return '<div class="diff-row excluded' + sel + '" onclick="selectMod(\\'' + m.type + '\\',\\'' + m.id + '\\')">' +
      '<div class="diff-thumb" style="font-size:12px;color:var(--text3)">—</div>' +
      '<div class="diff-name strikethrough">' + name + '</div>' +
      '<div><span class="diff-badge excluded">EXCLUDED</span></div>' +
      '<div class="diff-detail"></div>' +
      '</div>';
  }).join('');

  if (filtered.length === 0) {
    listEl.innerHTML = '<div style="padding:24px;text-align:center;color:var(--text3);font-size:13px">' +
      (all.length === 0 ? 'No modifications — use + Add to begin.' : 'No results for current filter.') +
      '</div>';
  }
}

function selectMod(type, id) {
  selectedMod = { type, id };
  renderPackDiffList();
  renderPackRightPanel();
}

function updatePackSummaryPanel() {
  if (!packData || !currentPackId) return;
  const countsEl = document.getElementById('pack-counts-' + currentPackId);
  if (!countsEl) return;
  const exclusive = (packData.tiles || []).length;
  const overrides = Object.keys(packData.rarityOverrides || {}).length;
  const excluded  = (packData.excludedTileIDs || []).length;
  countsEl.innerHTML =
    '<strong style="color:var(--green)">'  + exclusive + '</strong> exclusive tile' + (exclusive !== 1 ? 's' : '') + '<br>' +
    '<strong style="color:var(--amber)">'  + overrides + '</strong> rarity override' + (overrides !== 1 ? 's' : '') + '<br>' +
    '<strong style="color:var(--red)">'    + excluded  + '</strong> exclusion'        + (excluded  !== 1 ? 's' : '');
}

function renderPackRightPanel() {
  if (!selectedMod || !packData || !currentPackId) return;
  const { type, id } = selectedMod;
  if (type === 'exclusive') {
    const tile = (packData.tiles || []).find(t => t.id === id);
    if (tile) showExclusiveEditor(tile);
    return;
  }
  if (type === 'override') { showOverrideEditor(id); return; }
  if (type === 'excluded')  { showExcludedEditor(id); return; }
}

// ── Right panel: exclusive tile editor ───────────────────────────────────────
function showExclusiveEditor(tile) {
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;
  const isNew = !tile.id;
  rightEl.innerHTML =
    '<div class="panel-header">' +
      '<div class="panel-title">' + esc(isNew ? 'New Exclusive Tile' : tile.text) + '</div>' +
      '<div class="panel-id">' + (isNew ? '(new)' : esc(tile.id.substring(0, 8)) + '…') + '</div>' +
    '</div>' +
    '<div class="panel-body" id="pack-panel-body">' +
      '<div>' +
        '<div class="section-label">Tile Image</div>' +
        '<div class="image-section">' +
          '<div class="image-current-wrap" id="pack-image-wrap">' +
            '<span class="img-placeholder" id="pack-img-placeholder" style="' + (isNew ? '' : 'display:none') + '">' + esc(tile.emoji || '🎯') + '</span>' +
            '<img id="pack-image-current" src="' + (isNew ? '' : '/api/image/' + esc(tile.id) + '?t=' + Date.now()) + '" ' +
              'alt="" style="' + (isNew ? 'display:none' : '') + '" ' +
              'onerror="this.style.display=\\'none\\';document.getElementById(\\'pack-img-placeholder\\').style.display=\\'\\';">' +
          '</div>' +
          '<div class="image-controls">' +
            '<div class="image-hint">Exclusive tile image. Generate with Gemini, then approve or discard.</div>' +
            '<button class="btn-generate" id="pack-btn-generate" onclick="showPackPromptEditor()">❆ Generate New Image</button>' +
          '</div>' +
        '</div>' +
        '<div class="prompt-editor" id="pack-prompt-editor">' +
          '<div class="prompt-editor-header"><span class="prompt-editor-label">Generation Prompt</span><span class="prompt-editor-hint">Edit before running</span></div>' +
          '<textarea class="prompt-textarea" id="pack-prompt-textarea" rows="5"></textarea>' +
          '<div class="prompt-actions">' +
            '<button class="btn-run" onclick="runPackGeneration()">Run Generation</button>' +
            '<button class="btn-cancel-prompt" onclick="hidePackPromptEditor()">Cancel</button>' +
          '</div>' +
        '</div>' +
        '<div class="gen-loading" id="pack-gen-loading"><div class="spinner"></div><span>Generating with Gemini 2.5 Flash…</span></div>' +
        '<div class="gen-result" id="pack-gen-result">' +
          '<div class="gen-result-label">✓ Image generated — approve or discard</div>' +
          '<div class="gen-result-inner">' +
            '<div class="gen-preview-wrap"><img id="pack-gen-preview-img" src="" alt="generated"></div>' +
            '<div class="gen-actions">' +
              '<button class="btn-approve" onclick="approvePackImage()">✓ Use This Image</button>' +
              '<button class="btn-discard" onclick="discardPackImage()">✕ Discard · Keep Original</button>' +
            '</div>' +
          '</div>' +
        '</div>' +
      '</div>' +
      '<div>' +
        '<div class="section-label">Metadata</div>' +
        '<div style="display:flex;flex-direction:column;gap:12px">' +
          '<div class="field"><label class="field-label">Name</label><input class="field-input" id="pack-field-name" type="text" value="' + esc(tile.text || '') + '"></div>' +
          '<div class="field"><label class="field-label">Emoji</label><input class="field-input" id="pack-field-emoji" type="text" value="' + esc(tile.emoji || '') + '"></div>' +
          '<div class="fields-row">' +
            '<div class="field"><label class="field-label">Category</label><select class="field-input" id="pack-field-category" style="cursor:pointer">' +
              CATEGORIES.map(c => '<option value="' + c + '"' + (c === tile.category ? ' selected' : '') + '>' + esc(c) + '</option>').join('') +
            '</select></div>' +
            '<div class="field"><label class="field-label">Rarity</label><select class="field-input" id="pack-field-rarity" style="cursor:pointer">' +
              RARITIES.map(r => '<option value="' + r + '"' + (r === tile.rarity ? ' selected' : '') + '>' + esc(r) + '</option>').join('') +
            '</select></div>' +
          '</div>' +
        '</div>' +
      '</div>' +
    '</div>' +
    '<div class="panel-footer">' +
      (isNew ? '' : '<button class="btn-delete" onclick="removeExclusiveTile(\\'' + esc(tile.id) + '\\')">🗑 Remove from Pack</button>') +
      '<div class="footer-right">' +
        '<button class="btn-cancel" onclick="cancelPackEdit()">Cancel</button>' +
        '<button class="btn-save" onclick="saveExclusiveTile(' + (isNew ? 'null' : '\\'' + esc(tile.id) + '\\'') + ')">Save Changes</button>' +
      '</div>' +
    '</div>';

  window._packEditingTile      = tile;
  window._packPendingImageB64  = null;
  window._packLastPrompt       = null;
  window._packIsNewExclusive   = isNew;
}

// ── Exclusive tile image generation ──────────────────────────────────────────
function showPackPromptEditor() {
  // Warn if user already approved an image — re-generating will replace it
  if (window._packPendingImageB64 && window._packIsNewExclusive) {
    if (!confirm('You already approved an image for this tile. Generating a new one will replace it. Continue?')) return;
    window._packPendingImageB64 = null;
    // Reset the displayed image back to placeholder
    const img = document.getElementById('pack-image-current');
    const ph  = document.getElementById('pack-img-placeholder');
    if (img) { img.src = ''; img.style.display = 'none'; }
    if (ph)  { ph.style.display = ''; }
  }
  if (!window._packLastPrompt) {
    const name = document.getElementById('pack-field-name').value.trim() || 'a tile';
    const cat  = document.getElementById('pack-field-category').value;
    window._packLastPrompt = buildPrompt(name, cat);
  }
  document.getElementById('pack-prompt-textarea').value = window._packLastPrompt;
  document.getElementById('pack-prompt-editor').classList.add('visible');
  document.getElementById('pack-btn-generate').style.display = 'none';
  document.getElementById('pack-gen-result').classList.remove('visible');
}

function hidePackPromptEditor() {
  document.getElementById('pack-prompt-editor').classList.remove('visible');
  document.getElementById('pack-btn-generate').style.display = '';
}

async function runPackGeneration() {
  const prompt = document.getElementById('pack-prompt-textarea').value.trim();
  if (!prompt) { alert('Enter a prompt before running.'); return; }
  window._packLastPrompt = prompt;
  document.getElementById('pack-prompt-editor').classList.remove('visible');
  document.getElementById('pack-gen-loading').classList.add('visible');
  try {
    const r = await fetch('/api/generate', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({prompt}),
    });
    const data = await r.json();
    if (!r.ok) throw new Error(data.error || 'Generation failed');
    window._packPendingImageB64 = data.image_b64;
    document.getElementById('pack-gen-preview-img').src = 'data:image/png;base64,' + data.image_b64;
    document.getElementById('pack-gen-loading').classList.remove('visible');
    document.getElementById('pack-gen-result').classList.add('visible');
  } catch (err) {
    document.getElementById('pack-gen-loading').classList.remove('visible');
    document.getElementById('pack-btn-generate').style.display = '';
    alert('Generation failed: ' + err.message);
  }
}

async function approvePackImage() {
  const b64  = window._packPendingImageB64;
  const tile = window._packEditingTile;
  if (!b64) return;
  if (!window._packIsNewExclusive && tile && tile.id) {
    const r = await fetch('/api/packs/' + currentPackId + '/tiles/' + tile.id + '/image', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({image_b64: b64}),
    });
    if (!r.ok) { alert('Failed to save image'); return; }
  }
  // Only clear the pending image for existing tiles — the image was just saved to disk above.
  // For new tiles, keep _packPendingImageB64 so saveExclusiveTile(null) can include it in the
  // POST body when the tile is created. saveExclusiveTile clears it after use.
  if (!window._packIsNewExclusive) {
    window._packPendingImageB64 = null;
  }
  const img = document.getElementById('pack-image-current');
  const ph  = document.getElementById('pack-img-placeholder');
  img.src = 'data:image/png;base64,' + b64;
  img.style.display = 'block';
  if (ph) ph.style.display = 'none';
  document.getElementById('pack-gen-result').classList.remove('visible');
  document.getElementById('pack-btn-generate').style.display = '';
}

function discardPackImage() {
  window._packPendingImageB64 = null;
  document.getElementById('pack-gen-result').classList.remove('visible');
  document.getElementById('pack-btn-generate').style.display = '';
}

async function saveExclusiveTile(tileId) {
  const name     = document.getElementById('pack-field-name').value.trim();
  const emoji    = document.getElementById('pack-field-emoji').value.trim();
  const category = document.getElementById('pack-field-category').value;
  const rarity   = document.getElementById('pack-field-rarity').value;
  if (!name) { alert('Name is required'); return; }

  if (!tileId) {
    // New exclusive tile — POST to server immediately
    const body = {text: name, emoji, category, rarity};
    if (window._packPendingImageB64) body.image_b64 = window._packPendingImageB64;
    const r = await fetch('/api/packs/' + currentPackId + '/tiles', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
    if (!r.ok) { alert('Failed to save tile'); return; }
    const newTile = await r.json();
    packData.tiles = packData.tiles || [];
    packData.tiles.push(newTile);
    window._packPendingImageB64 = null;
    selectedMod = {type: 'exclusive', id: newTile.id};
    window._packEditingTile    = newTile;
    window._packIsNewExclusive = false;
  } else {
    // Edit existing exclusive tile — update in-memory; full pack saved on Save Pack
    const tile = (packData.tiles || []).find(t => t.id === tileId);
    if (!tile) { alert('Tile not found in pack — it may have been removed.'); return; }
    tile.text = name; tile.emoji = emoji; tile.category = category; tile.rarity = rarity;
    markDirty();
  }
  updatePackSummaryPanel();
  renderPackDiffList();
}

function cancelPackEdit() {
  selectedMod = null;
  renderPackDiffList();
  resetPackRightPanel();
}

function removeExclusiveTile(tileId) {
  if (!confirm('Remove this tile from the pack? The change will be saved when you click Save Pack.')) return;
  packData.tiles = (packData.tiles || []).filter(t => t.id !== tileId);
  markDirty();
  selectedMod = null;
  updatePackSummaryPanel();
  renderPackDiffList();
  resetPackRightPanel();
}

// ── Right panel: override editor ──────────────────────────────────────────────
function showOverrideEditor(uuid) {
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;
  const baseTile  = tiles.find(t => t.id === uuid);
  const newRarity = (packData.rarityOverrides || {})[uuid] || 'veryCommon';
  const fromRarity = baseTile ? baseTile.rarity : '?';
  const name = baseTile ? baseTile.text : 'Unknown tile (' + uuid.substring(0, 8) + '…)';

  rightEl.innerHTML =
    '<div class="panel-header">' +
      '<div class="panel-title">' + esc(name) + '</div>' +
      '<div class="panel-id">Rarity Override</div>' +
    '</div>' +
    '<div class="panel-body">' +
      '<div>' +
        '<div class="section-label">Rarity Change</div>' +
        '<div class="rarity-from-to">' +
          '<div><div style="font-size:10px;color:var(--text3);margin-bottom:4px">BASE</div><span class="rarity ' + (RARITY_CLS[fromRarity] || '') + '">' + esc(fromRarity) + '</span></div>' +
          '<div class="arrow">→</div>' +
          '<div><div style="font-size:10px;color:var(--text3);margin-bottom:4px">IN THIS PACK</div>' +
            '<select class="field-input" id="override-rarity-sel" style="cursor:pointer">' +
              RARITIES.map(r => '<option value="' + r + '"' + (r === newRarity ? ' selected' : '') + '>' + esc(r) + '</option>').join('') +
            '</select>' +
          '</div>' +
        '</div>' +
      '</div>' +
      (baseTile ?
        '<div>' +
          '<div class="section-label">Base Tile Info</div>' +
          '<div class="override-base-info">' +
            '<div class="name">' + esc(baseTile.text) + ' ' + esc(baseTile.emoji || '') + '</div>' +
            '<div>' + esc(baseTile.category) + ' · base rarity: ' + esc(baseTile.rarity) + '</div>' +
          '</div>' +
        '</div>' : '') +
      '<div>' +
        '<button class="btn-remove" onclick="removeOverride(\\'' + esc(uuid) + '\\')">Remove Override</button>' +
      '</div>' +
    '</div>' +
    '<div class="panel-footer">' +
      '<div></div>' +
      '<div class="footer-right">' +
        '<button class="btn-cancel" onclick="cancelPackEdit()">Cancel</button>' +
        '<button class="btn-save" onclick="saveOverride(\\'' + esc(uuid) + '\\')">Save Changes</button>' +
      '</div>' +
    '</div>';
}

function saveOverride(uuid) {
  const newRarity = document.getElementById('override-rarity-sel').value;
  packData.rarityOverrides = packData.rarityOverrides || {};
  packData.rarityOverrides[uuid] = newRarity;
  markDirty();
  renderPackDiffList();
  showOverrideEditor(uuid);
}

function removeOverride(uuid) {
  if (!confirm('Remove this rarity override?')) return;
  if (packData.rarityOverrides) delete packData.rarityOverrides[uuid];
  markDirty();
  selectedMod = null;
  updatePackSummaryPanel();
  renderPackDiffList();
  resetPackRightPanel();
}

// ── Right panel: excluded editor ──────────────────────────────────────────────
function showExcludedEditor(uuid) {
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;
  const baseTile = tiles.find(t => t.id === uuid);
  const name = baseTile ? baseTile.text : 'Unknown tile (' + uuid.substring(0, 8) + '…)';

  rightEl.innerHTML =
    '<div class="panel-header">' +
      '<div class="panel-title">' + esc(name) + '</div>' +
      '<div class="panel-id">Excluded from Pool</div>' +
    '</div>' +
    '<div class="panel-body">' +
      (baseTile ?
        '<div class="override-base-info">' +
          '<div class="name">' + esc(baseTile.text) + ' ' + esc(baseTile.emoji || '') + '</div>' +
          '<div>' + esc(baseTile.category) + ' · rarity: ' + esc(baseTile.rarity) + '</div>' +
        '</div>' : '') +
      '<div class="excluded-callout">This tile is hidden from all boards when this pack is active.</div>' +
      '<div style="display:flex;flex-direction:column;gap:8px;margin-top:12px">' +
        '<button class="btn-convert" onclick="convertExclusionToOverride(\\'' + esc(uuid) + '\\')">Convert to Override Instead</button>' +
        '<button class="btn-remove" onclick="removeExclusion(\\'' + esc(uuid) + '\\')">Remove Exclusion</button>' +
      '</div>' +
    '</div>' +
    '<div class="panel-footer"><div></div><div class="footer-right"><button class="btn-cancel" onclick="cancelPackEdit()">Cancel</button></div></div>';
}

function removeExclusion(uuid) {
  if (!confirm('Remove this exclusion? The tile will return to the pool.')) return;
  packData.excludedTileIDs = (packData.excludedTileIDs || []).filter(id => id !== uuid);
  markDirty();
  selectedMod = null;
  updatePackSummaryPanel();
  renderPackDiffList();
  resetPackRightPanel();
}

function convertExclusionToOverride(uuid) {
  const baseTile = tiles.find(t => t.id === uuid);
  packData.excludedTileIDs = (packData.excludedTileIDs || []).filter(id => id !== uuid);
  packData.rarityOverrides = packData.rarityOverrides || {};
  packData.rarityOverrides[uuid] = baseTile ? baseTile.rarity : 'common';
  markDirty();
  selectedMod = {type: 'override', id: uuid};
  updatePackSummaryPanel();
  renderPackDiffList();
  showOverrideEditor(uuid);
}

// ── Shared reset ──────────────────────────────────────────────────────────────
function resetPackRightPanel() {
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;
  const pack = PACKS_META.find(p => p.id === currentPackId) || {};
  rightEl.innerHTML =
    '<div style="flex:1;display:flex;flex-direction:column;justify-content:center;padding:20px">' +
      '<div class="pack-summary">' +
        '<div class="pack-summary-name">' + esc(pack.name || '') + '</div>' +
        '<div class="pack-summary-counts" id="pack-counts-' + esc(currentPackId) + '">—</div>' +
        '<div class="pack-summary-hint">Select a modification to edit, or use + Add to create one.</div>' +
      '</div>' +
    '</div>';
  updatePackSummaryPanel();
}

// ── Addition flow: Create Exclusive Tile ──────────────────────────────────────
function startAddExclusive() {
  document.querySelectorAll('.add-menu').forEach(m => m.classList.remove('open'));
  selectedMod = null;
  renderPackDiffList();
  showExclusiveEditor({ text: '', emoji: '', category: CATEGORIES[0] || 'nature', rarity: 'common' });
  window._packIsNewExclusive = true;
  window._packEditingTile = {};
}

// ── Addition flow: Override Rarity ────────────────────────────────────────────
function startAddOverride() {
  document.querySelectorAll('.add-menu').forEach(m => m.classList.remove('open'));
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;

  const existingOverrides  = Object.keys(packData.rarityOverrides || {});
  const existingExcluded   = packData.excludedTileIDs || [];
  const alreadyHandled     = new Set([...existingOverrides, ...existingExcluded]);
  const candidates         = tiles.filter(t => !alreadyHandled.has(t.id));

  rightEl.innerHTML = buildTilePickerHTML('Override Rarity', candidates, 'confirmAddOverride', null);
}

async function confirmAddOverride(uuid) {
  const baseTile   = tiles.find(t => t.id === uuid);
  const rightEl    = document.getElementById('pack-right-' + currentPackId);
  const fromRarity = baseTile ? baseTile.rarity : 'common';
  const defaultTo  = RARITIES[Math.max(0, RARITIES.indexOf(fromRarity) - 1)] || 'veryCommon';

  rightEl.innerHTML =
    '<div class="panel-header"><div class="panel-title">Override Rarity</div><div class="panel-id">' + esc(baseTile ? baseTile.text : uuid) + '</div></div>' +
    '<div class="panel-body">' +
      '<div class="section-label">Choose New Rarity</div>' +
      '<div class="rarity-from-to">' +
        '<div><div style="font-size:10px;color:var(--text3);margin-bottom:4px">BASE</div><span class="rarity ' + (RARITY_CLS[fromRarity]||'') + '">' + esc(fromRarity) + '</span></div>' +
        '<div class="arrow">→</div>' +
        '<div><div style="font-size:10px;color:var(--text3);margin-bottom:4px">IN THIS PACK</div>' +
          '<select class="field-input" id="new-override-rarity" style="cursor:pointer">' +
            RARITIES.map(r => '<option value="' + r + '"' + (r === defaultTo ? ' selected' : '') + '>' + r + '</option>').join('') +
          '</select>' +
        '</div>' +
      '</div>' +
    '</div>' +
    '<div class="picker-actions">' +
      '<button class="btn-run" onclick="finaliseAddOverride(\\'' + uuid + '\\')">Add Override</button>' +
      '<button class="btn-cancel-prompt" onclick="resetPackRightPanel()">Cancel</button>' +
    '</div>';
}

function finaliseAddOverride(uuid) {
  const newRarity = document.getElementById('new-override-rarity').value;
  packData.rarityOverrides = packData.rarityOverrides || {};
  packData.rarityOverrides[uuid] = newRarity;
  markDirty();
  selectedMod = { type: 'override', id: uuid };
  updatePackSummaryPanel();
  renderPackDiffList();
  showOverrideEditor(uuid);
}

// ── Addition flow: Exclude Base Tile ──────────────────────────────────────────
function startExcludeBase() {
  document.querySelectorAll('.add-menu').forEach(m => m.classList.remove('open'));
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;

  const existingOverrides = Object.keys(packData.rarityOverrides || {});
  const existingExcluded  = packData.excludedTileIDs || [];
  const alreadyHandled    = new Set([...existingOverrides, ...existingExcluded]);
  const candidates        = tiles.filter(t => !alreadyHandled.has(t.id));

  rightEl.innerHTML = buildTilePickerHTML('Exclude Base Tile', candidates, 'confirmExclude',
    'When this pack is active, the selected tile will not appear on any board.');
}

function confirmExclude(uuid) {
  packData.excludedTileIDs = packData.excludedTileIDs || [];
  packData.excludedTileIDs.push(uuid);
  markDirty();
  selectedMod = { type: 'excluded', id: uuid };
  updatePackSummaryPanel();
  renderPackDiffList();
  showExcludedEditor(uuid);
}

// ── Addition flow: Move from Base ─────────────────────────────────────────────
function startMoveFromBase() {
  document.querySelectorAll('.add-menu').forEach(m => m.classList.remove('open'));
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;

  const packTileIds = new Set((packData.tiles || []).map(t => t.id));
  const candidates  = tiles.filter(t => !packTileIds.has(t.id));

  rightEl.innerHTML = buildTilePickerHTML(
    'Move from Base',
    candidates,
    'confirmMoveFromBase',
    'This tile will be removed from the base pool and become exclusive to this pack. This cannot be undone without manually editing squares.json.'
  );
}

async function confirmMoveFromBase(uuid) {
  const baseTile = tiles.find(t => t.id === uuid);
  if (!baseTile) { alert('Tile not found'); return; }

  // Disable the picker immediately to prevent double-clicks during async ops
  const pickerList = document.getElementById('tile-picker-list');
  if (pickerList) pickerList.style.pointerEvents = 'none';

  // Read the image before deleting
  let imageB64 = null;
  try {
    const imgResp = await fetch('/api/image/' + uuid);
    if (imgResp.ok) {
      const blob = await imgResp.blob();
      imageB64 = await new Promise(resolve => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result.split(',')[1]);
        reader.readAsDataURL(blob);
      });
    }
  } catch (_) {}

  // Delete from base
  const delResp = await fetch('/api/tiles/' + uuid, { method: 'DELETE' });
  if (!delResp.ok) { alert('Failed to remove tile from base'); return; }
  tiles = tiles.filter(t => t.id !== uuid);
  renderTable();
  updateStats();

  // Add to pack (preserve UUID, send image if we have it)
  const body = { id: uuid, text: baseTile.text, emoji: baseTile.emoji || '', category: baseTile.category, rarity: baseTile.rarity };
  if (imageB64) body.image_b64 = imageB64;
  const addResp = await fetch('/api/packs/' + currentPackId + '/tiles', {
    method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body)
  });
  if (!addResp.ok) { alert('Tile deleted from base but failed to add to pack — check pack JSON manually'); resetPackRightPanel(); return; }
  const newTile = await addResp.json();
  packData.tiles = packData.tiles || [];
  packData.tiles.push(newTile);

  selectedMod = { type: 'exclusive', id: uuid };
  updatePackSummaryPanel();
  renderPackDiffList();
  showExclusiveEditor(newTile);
}

// ── Shared tile picker HTML builder ───────────────────────────────────────────
function buildTilePickerHTML(title, candidates, confirmFn, warningText) {
  const rows = candidates.map(t =>
    '<div class="tile-picker-row" onclick="' + confirmFn + '(\\'' + t.id + '\\')">' +
      '<div class="diff-thumb" style="font-size:14px">' + esc(t.emoji || '') + '</div>' +
      '<div class="name">' + esc(t.text) + '</div>' +
      '<div class="cat">' + esc(t.category) + ' · ' + esc(t.rarity) + '</div>' +
    '</div>'
  ).join('');

  return '<div class="panel-header"><div class="panel-title">' + esc(title) + '</div></div>' +
    '<div class="tile-picker">' +
      '<input class="tile-picker-search" type="text" placeholder="Filter tiles…" oninput="filterTilePicker(this)">' +
      (warningText ? '<div class="warning-callout">' + esc(warningText) + '</div>' : '') +
      '<div class="tile-picker-list" id="tile-picker-list">' + rows + '</div>' +
    '</div>' +
    '<div class="picker-actions"><button class="btn-cancel-prompt" onclick="resetPackRightPanel()">Cancel</button></div>';
}

function filterTilePicker(input) {
  const q = input.value.toLowerCase();
  document.querySelectorAll('.tile-picker-row').forEach(row => {
    const text = row.querySelector('.name').textContent.toLowerCase();
    row.style.display = text.includes(q) ? '' : 'none';
  });
}

// ── Save Pack ─────────────────────────────────────────────────────────────────
async function savePack() {
  if (!packData || !currentPackId) return;
  const r = await fetch('/api/packs/' + currentPackId, {
    method: 'PUT',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(packData),
  });
  if (!r.ok) {
    const err = await r.json().catch(() => ({}));
    alert('Failed to save pack: ' + (err.error || r.status));
    return;
  }
  isDirty = false;
  const btn = document.getElementById('btn-save-' + currentPackId);
  if (btn) {
    btn.disabled = true;
    btn.textContent = 'Saved ✓';
    setTimeout(() => { btn.textContent = 'Save Pack'; }, 1500);
  }
}

function updateStats() {
  document.getElementById('stat-tiles').textContent = tiles.length;
}

// ── Dropdowns ─────────────────────────────────────────────────────────────────────────
function populateCategoryDropdowns() {
  const filter = document.getElementById('filter-cat');
  filter.innerHTML = '<option value="">All categories</option>' +
    CATEGORIES.map(c => '<option value="' + c + '">' + c + '</option>').join('');
  const edit = document.getElementById('field-category');
  edit.innerHTML = CATEGORIES.map(c => '<option value="' + c + '">' + c + '</option>').join('');
}

function populateRarityDropdowns() {
  const sel = document.getElementById('field-rarity');
  sel.innerHTML = RARITIES.map(r => '<option value="' + r + '">' + r + '</option>').join('');
}

// ── Table ──────────────────────────────────────────────────────────────────────────────
const RARITY_CLS   = { veryCommon:'vc', common:'c', uncommon:'u', rare:'r', veryRare:'vr' };
const RARITY_ORDER = { veryCommon:0, common:1, uncommon:2, rare:3, veryRare:4 };

function toggleSort(key) {
  if (sortKey === key) { sortAsc = !sortAsc; } else { sortKey = key; sortAsc = true; }
  renderTable();
}

function getFiltered() {
  const q = document.getElementById('search').value.toLowerCase();
  const cat = document.getElementById('filter-cat').value;
  const result = tiles.filter(t =>
    (!q || t.text.toLowerCase().includes(q) || t.category.includes(q)) &&
    (!cat || t.category === cat)
  );
  if (sortKey === 'name') {
    result.sort((a, b) => sortAsc ? a.text.localeCompare(b.text) : b.text.localeCompare(a.text));
  } else if (sortKey === 'rarity') {
    result.sort((a, b) => sortAsc
      ? (RARITY_ORDER[a.rarity] ?? 99) - (RARITY_ORDER[b.rarity] ?? 99)
      : (RARITY_ORDER[b.rarity] ?? 99) - (RARITY_ORDER[a.rarity] ?? 99));
  }
  return result;
}

function renderTable() {
  // Update sort header indicators
  ['name', 'rarity'].forEach(k => {
    const el = document.getElementById('sort-' + k);
    const label = k === 'name' ? 'Name' : 'Rarity';
    const isActive = sortKey === k;
    el.textContent = isActive ? label + ' ' + (sortAsc ? '▲' : '▼') : label;
    el.classList.toggle('sort-active', isActive);
  });

  const filtered = getFiltered();
  document.getElementById('table-body').innerHTML = filtered.map(t => {
    const sel = t.id === selectedId ? ' selected' : '';
    return '<div class="row' + sel + '" onclick="selectTile(\\'' + t.id + '\\')">' +
      '<div class="row-thumb"><img src="/api/image/' + t.id + '" alt="" onerror="this.style.display=\\'none\\'"></div>' +
      '<div class="row-name">' + esc(t.text) + '</div>' +
      '<div class="row-cat">' + esc(t.category) + '</div>' +
      '<div class="rarity ' + (RARITY_CLS[t.rarity] || '') + '">' + esc(t.rarity) + '</div>' +
      '</div>';
  }).join('');
  document.getElementById('table-footer').textContent =
    filtered.length + ' of ' + tiles.length + ' tiles · ' + CATEGORIES.length + ' categories';
}

function esc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ── Select ───────────────────────────────────────────────────────────────────────────────
function selectTile(id) {
  const tile = tiles.find(t => t.id === id);
  if (!tile) return;
  selectedId = id;
  isAddMode = false;
  pendingImageB64 = null;
  lastUsedPrompt = null;
  resetDeleteConfirm();
  renderTable();
  showPanel(tile);
}

function showPanel(tile) {
  document.getElementById('panel-title').textContent = tile.text;
  document.getElementById('panel-id').textContent = tile.id.substring(0, 8) + '…';
  setCurrentImage('/api/image/' + tile.id + '?t=' + Date.now());
  document.getElementById('field-name').value = tile.text;
  document.getElementById('field-description').value = tile.description || '';
  document.getElementById('field-category').value = tile.category;
  document.getElementById('field-rarity').value = tile.rarity;
  document.getElementById('btn-delete').style.display = '';
  resetGenerationUI();
  document.getElementById('panel-empty').style.display = 'none';
  document.getElementById('panel-content').style.display = 'flex';
}

function setCurrentImage(src) {
  const img = document.getElementById('image-current');
  const ph  = document.getElementById('img-placeholder');
  img.src = src;
  img.style.display = 'block';
  ph.style.display = 'none';
  img.onerror = () => { img.style.display = 'none'; ph.style.display = ''; };
}

// ── Add mode ───────────────────────────────────────────────────────────────────────────
function startAddMode() {
  selectedId = null;
  isAddMode = true;
  pendingImageB64 = null;
  lastUsedPrompt = null;
  resetDeleteConfirm();
  document.getElementById('panel-title').textContent = 'New Tile';
  document.getElementById('panel-id').textContent = '(new)';
  document.getElementById('image-current').style.display = 'none';
  document.getElementById('img-placeholder').style.display = '';
  document.getElementById('field-name').value = '';
  document.getElementById('field-description').value = '';
  document.getElementById('field-category').value = CATEGORIES[0] || '';
  document.getElementById('field-rarity').value = RARITIES[0] || 'veryCommon';
  document.getElementById('btn-delete').style.display = 'none';
  resetGenerationUI();
  document.getElementById('panel-empty').style.display = 'none';
  document.getElementById('panel-content').style.display = 'flex';
  renderTable();
}

// ── Generation ──────────────────────────────────────────────────────────────────────────
function resetGenerationUI() {
  document.getElementById('prompt-editor').classList.remove('visible');
  document.getElementById('gen-loading').classList.remove('visible');
  document.getElementById('gen-result').classList.remove('visible');
  document.getElementById('btn-generate').style.display = '';
}

function showPromptEditor() {
  // Re-use the last prompt the user ran (or typed) so they can iterate on it.
  // Fall back to the auto-built prompt only on first open for this tile.
  if (!lastUsedPrompt) {
    const name = document.getElementById('field-name').value.trim() || 'a tile';
    const cat  = document.getElementById('field-category').value;
    lastUsedPrompt = buildPrompt(name, cat);
  }
  document.getElementById('prompt-textarea').value = lastUsedPrompt;
  document.getElementById('prompt-editor').classList.add('visible');
  document.getElementById('btn-generate').style.display = 'none';
  document.getElementById('gen-result').classList.remove('visible');
}

function hidePromptEditor() {
  document.getElementById('prompt-editor').classList.remove('visible');
  document.getElementById('btn-generate').style.display = '';
}

async function runGeneration() {
  const prompt = document.getElementById('prompt-textarea').value.trim();
  if (!prompt) { alert('Enter a prompt before running generation.'); return; }
  lastUsedPrompt = prompt;  // remember for next attempt
  document.getElementById('prompt-editor').classList.remove('visible');
  document.getElementById('gen-loading').classList.add('visible');
  try {
    const r = await fetch('/api/generate', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({prompt}),
    });
    const data = await r.json();
    if (!r.ok) throw new Error(data.error || 'Generation failed');
    pendingImageB64 = data.image_b64;
    document.getElementById('gen-preview-img').src = 'data:image/png;base64,' + pendingImageB64;
    document.getElementById('gen-loading').classList.remove('visible');
    document.getElementById('gen-result').classList.add('visible');
  } catch (err) {
    document.getElementById('gen-loading').classList.remove('visible');
    document.getElementById('btn-generate').style.display = '';
    alert('Generation failed: ' + err.message);
  }
}

async function approveImage() {
  if (!pendingImageB64) return;
  const b64 = pendingImageB64;  // capture before any async/null
  if (!isAddMode && selectedId) {
    const r = await fetch('/api/tiles/' + selectedId + '/image', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({image_b64: b64}),
    });
    if (!r.ok) { alert('Failed to save image'); return; }
    // Image is now on disk; clear pending so stale data can't leak into future flows
    pendingImageB64 = null;
  }
  setCurrentImage('data:image/png;base64,' + b64);
  document.getElementById('gen-result').classList.remove('visible');
  document.getElementById('btn-generate').style.display = '';
}

function discardImage() {
  pendingImageB64 = null;
  document.getElementById('gen-result').classList.remove('visible');
  document.getElementById('btn-generate').style.display = '';
}

// ── Save ──────────────────────────────────────────────────────────────────────────────────
async function saveTile() {
  const name     = document.getElementById('field-name').value.trim();
  const category = document.getElementById('field-category').value;
  const rarity   = document.getElementById('field-rarity').value;
  if (!name) { alert('Name is required'); return; }

  if (isAddMode) {
    const description = document.getElementById('field-description').value.trim();
    const body = {text: name, category, rarity};
    if (description) body.description = description;
    if (pendingImageB64) body.image_b64 = pendingImageB64;
    const r = await fetch('/api/tiles', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
    if (!r.ok) { alert('Failed to save tile'); return; }
    const newTile = await r.json();
    tiles.push(newTile);
    selectedId = newTile.id;
    isAddMode = false;
    pendingImageB64 = null;
  } else {
    const description = document.getElementById('field-description').value.trim();
    const r = await fetch('/api/tiles/' + selectedId, {
      method: 'PUT', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({text: name, category, rarity, description}),
    });
    if (!r.ok) { alert('Failed to update tile'); return; }
    const updated = await r.json();
    const idx = tiles.findIndex(t => t.id === selectedId);
    if (idx >= 0) tiles[idx] = updated;
  }

  document.getElementById('panel-title').textContent = name;
  document.getElementById('panel-id').textContent = selectedId ? selectedId.substring(0, 8) + '…' : '(new)';
  document.getElementById('btn-delete').style.display = '';
  renderTable();
  updateStats();
}

// ── Delete ───────────────────────────────────────────────────────────────────────────────
function resetDeleteConfirm() {
  deleteConfirming = false;
  const btn = document.getElementById('btn-delete');
  btn.textContent = '🗑 Delete Tile';
  btn.style.background = '';
  btn.style.color = '';
  btn.style.borderColor = '';
}

async function deleteTile() {
  if (!deleteConfirming) {
    deleteConfirming = true;
    const btn = document.getElementById('btn-delete');
    btn.textContent = 'Confirm Delete';
    btn.style.background = 'var(--red)';
    btn.style.color = 'white';
    btn.style.borderColor = 'var(--red)';
    setTimeout(resetDeleteConfirm, 3000);
    return;
  }
  const r = await fetch('/api/tiles/' + selectedId, {method: 'DELETE'});
  if (!r.ok) { alert('Failed to delete tile'); return; }
  tiles = tiles.filter(t => t.id !== selectedId);
  selectedId = null;
  isAddMode = false;
  renderTable();
  updateStats();
  document.getElementById('panel-content').style.display = 'none';
  document.getElementById('panel-empty').style.display = '';
  resetDeleteConfirm();
}

function cancelEdit() {
  if (isAddMode) {
    isAddMode = false;
    selectedId = null;
    document.getElementById('panel-content').style.display = 'none';
    document.getElementById('panel-empty').style.display = '';
    renderTable();
  } else if (selectedId) {
    selectTile(selectedId);
  }
}

// ── Event listeners ───────────────────────────────────────────────────────────────────
document.getElementById('search').addEventListener('input', renderTable);
document.getElementById('filter-cat').addEventListener('change', renderTable);
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
        path = self.path.split("?")[0]  # strip query string
        if path in ("/", "/index.html"):
            self._serve_ui()
        elif path == "/api/tiles":
            self.send_json(load_tiles())
        elif path.startswith("/api/image/"):
            self._serve_image(path[len("/api/image/"):])
        elif path == "/api/packs":
            self._handle_list_packs()
        elif path.startswith("/api/packs/"):
            pack_id = path[len("/api/packs/"):]
            self._handle_get_pack(pack_id)
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
        elif path.startswith("/api/packs/"):
            pack_path = path[len("/api/packs/"):]
            if pack_path.endswith("/tiles"):
                pack_id = pack_path[: -len("/tiles")]
                self._handle_add_pack_tile(pack_id)
            elif "/tiles/" in pack_path and pack_path.endswith("/image"):
                parts = pack_path.split("/tiles/", 1)
                pack_id = parts[0]
                tile_id = parts[1][: -len("/image")]
                self._handle_save_pack_tile_image(pack_id, tile_id)
            else:
                self.send_error_json(404, "Not found")
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
        # Inject runtime config into the HTML so JS knows categories/rarities
        html = HTML_APP.replace(
            "/* __INJECT__ */",
            f"const CATEGORIES = {json.dumps(CATEGORIES)};\n"
            f"    const RARITIES = {json.dumps(RARITIES)};\n"
            f"    const PACKS_META = {json.dumps(PACKS_METADATA)};",
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
        prompt = body.get("prompt", "").strip()
        if not prompt:
            self.send_error_json(400, "prompt is required")
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
        self.send_json(tile, 201)

    def _handle_update_tile(self, tile_id: str):
        body = self.read_json_body()
        tiles = load_tiles()
        for tile in tiles:
            if tile["id"] == tile_id:
                allowed = {"text", "category", "rarity", "description"}
                tile.update({k: v for k, v in body.items() if k in allowed})
                # Remove description key entirely when client sends empty string
                if "description" in tile and not tile["description"]:
                    del tile["description"]
                save_tiles(tiles)
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

    def _handle_put_pack(self, pack_id: str):
        if "/" in pack_id:
            self.send_error_json(404, "Not found")
            return
        try:
            body = self.read_json_body()
        except Exception:
            self.send_error_json(400, "Invalid JSON body")
            return
        for field in ("id", "name", "tiles", "rarityOverrides", "excludedTileIDs"):
            if field not in body:
                self.send_error_json(400, f"Missing required field: {field!r}")
                return
        if body["id"] != pack_id:
            self.send_error_json(400, "Pack 'id' in body does not match URL")
            return
        # Ensure pack file already exists — pack files are pre-bundled, not created here.
        pack_path = PACKS_DIR / f"pack-{pack_id}.json"
        if not pack_path.exists():
            self.send_error_json(404, f"Pack {pack_id!r} not found")
            return
        save_pack(pack_id, body)
        self.send_json({"saved": pack_id})

    def _handle_add_pack_tile(self, pack_id: str):
        if "/" in pack_id:
            self.send_error_json(404, "Not found")
            return
        try:
            pack = load_pack(pack_id)
        except FileNotFoundError:
            self.send_error_json(404, f"Pack {pack_id!r} not found")
            return
        try:
            body = self.read_json_body()
        except Exception:
            self.send_error_json(400, "Invalid JSON body")
            return
        required = {"text", "emoji", "category", "rarity"}
        missing = required - body.keys()
        if missing:
            self.send_error_json(400, f"Missing fields: {', '.join(sorted(missing))}")
            return
        # Preserve provided UUID (Move from Base preserves the original tile ID).
        tile_id = body.get("id") or str(uuid.uuid4()).upper()
        tile = {
            "id":       tile_id,
            "text":     body["text"],
            "emoji":    body["emoji"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
        if body.get("description"):
            tile["description"] = body["description"]
        pack.setdefault("tiles", []).append(tile)
        save_pack(pack_id, pack)
        if "image_b64" in body:
            save_image(tile_id, body["image_b64"])
        self.send_json(tile, 201)

    def _handle_save_pack_tile_image(self, pack_id: str, tile_id: str):
        if "/" in pack_id or "/" in tile_id:
            self.send_error_json(404, "Not found")
            return
        try:
            pack = load_pack(pack_id)
        except FileNotFoundError:
            self.send_error_json(404, f"Pack {pack_id!r} not found")
            return
        if not any(t["id"] == tile_id for t in pack.get("tiles", [])):
            self.send_error_json(404, f"Tile {tile_id!r} not in pack {pack_id!r}")
            return
        try:
            body = self.read_json_body()
        except Exception:
            self.send_error_json(400, "Invalid JSON body")
            return
        image_b64 = body.get("image_b64", "")
        if not image_b64:
            self.send_error_json(400, "image_b64 is required")
            return
        save_image(tile_id, image_b64)
        self.send_json({"saved": tile_id})


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
