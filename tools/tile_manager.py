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
body::before {
  content: ''; position: fixed; inset: 0; pointer-events: none; z-index: 100; opacity: 0.025;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
  background-size: 128px;
}
.app { display: flex; flex-direction: column; height: 100vh; }
.header {
  flex-shrink: 0; display: flex; align-items: center; gap: 20px;
  padding: 0 20px; height: 52px; background: var(--surface); border-bottom: 1px solid var(--border);
}
.header-logo { font-family: var(--font-display); font-size: 17px; color: var(--amber); }
.header-logo span { color: var(--text3); font-size: 13px; font-family: var(--font-ui); font-weight: 400; margin-left: 10px; }
.header-stats { display: flex; gap: 20px; margin-left: auto; }
.stat { display: flex; flex-direction: column; align-items: flex-end; }
.stat-val { font-family: var(--font-mono); font-size: 15px; color: var(--text); line-height: 1; }
.stat-lbl { font-size: 10px; color: var(--text3); text-transform: uppercase; letter-spacing: 0.8px; margin-top: 1px; }
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
.col-head { flex-shrink: 0; display: grid; grid-template-columns: 44px 1fr 38px 96px 82px; padding: 5px 12px; border-bottom: 1px solid var(--border); background: var(--surface); }
.col-head span { font-size: 9px; text-transform: uppercase; letter-spacing: 1px; color: var(--text3); font-weight: 600; }
.table-body { flex: 1; overflow-y: auto; }
.table-body::-webkit-scrollbar { width: 4px; }
.table-body::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 2px; }
.row { display: grid; grid-template-columns: 44px 1fr 38px 96px 82px; padding: 6px 12px; align-items: center; border-bottom: 1px solid var(--border); cursor: pointer; transition: background 0.1s; border-left: 2px solid transparent; }
.row:hover { background: var(--surface2); }
.row.selected { background: var(--surface2); border-left-color: var(--amber); }
.row-thumb { width: 30px; height: 30px; background: var(--surface3); border-radius: 4px; overflow: hidden; display: flex; align-items: center; justify-content: center; }
.row-thumb img { width: 100%; height: 100%; object-fit: cover; }
.row-emoji-fb { font-size: 17px; }
.row-name { font-size: 13px; color: var(--text); padding: 0 8px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 500; }
.row-emoji { font-size: 16px; }
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
.field-emoji { width: 64px; font-size: 20px; text-align: center; }
.fields-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.panel-footer { flex-shrink: 0; display: flex; align-items: center; justify-content: space-between; padding: 12px 20px; border-top: 1px solid var(--border); background: var(--surface); }
.btn-delete { background: transparent; border: 1px solid var(--red-dim); border-radius: 4px; padding: 7px 14px; font-family: var(--font-ui); font-size: 13px; font-weight: 600; color: var(--red); cursor: pointer; letter-spacing: 0.3px; transition: all 0.15s; }
.btn-delete:hover { background: rgba(200,64,64,0.1); }
.footer-right { display: flex; gap: 8px; }
.btn-cancel { background: transparent; border: 1px solid var(--border2); border-radius: 4px; padding: 7px 14px; font-family: var(--font-ui); font-size: 13px; color: var(--text3); cursor: pointer; }
.btn-save { background: var(--amber); border: none; border-radius: 4px; padding: 7px 20px; font-family: var(--font-ui); font-size: 13px; font-weight: 700; color: var(--bg); cursor: pointer; letter-spacing: 0.3px; transition: opacity 0.15s; }
.btn-save:hover { opacity: 0.85; }
* { scrollbar-width: thin; scrollbar-color: var(--border2) transparent; }
</style>
</head>
<body>
<div class="app">
  <header class="header">
    <div class="header-logo">Road Trip Bingo <span>/ Tile Manager</span></div>
    <div class="header-stats">
      <div class="stat"><span class="stat-val" id="stat-tiles">—</span><span class="stat-lbl">Tiles</span></div>
      <div class="stat"><span class="stat-val" id="stat-images">—</span><span class="stat-lbl">Images</span></div>
      <div class="stat"><span class="stat-val" id="stat-cats">—</span><span class="stat-lbl">Categories</span></div>
    </div>
  </header>
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
        <span></span><span>Name</span><span></span><span>Category</span><span>Rarity</span>
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
              <div class="field"><label class="field-label">Emoji</label><input class="field-input field-emoji" id="field-emoji" type="text"></div>
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
  </div>
</div>
<script>
/* __INJECT__ */

// ── State ─────────────────────────────────────────────────────────────────────────────
let tiles = [];
let selectedId = null;
let isAddMode = false;
let pendingImageB64 = null;
let deleteConfirming = false;

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
}

function updateStats() {
  document.getElementById('stat-tiles').textContent = tiles.length;
  document.getElementById('stat-images').textContent = tiles.length;
  document.getElementById('stat-cats').textContent = CATEGORIES.length;
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
const RARITY_CLS = { veryCommon:'vc', common:'c', uncommon:'u', rare:'r', veryRare:'vr' };

function getFiltered() {
  const q = document.getElementById('search').value.toLowerCase();
  const cat = document.getElementById('filter-cat').value;
  return tiles.filter(t =>
    (!q || t.text.toLowerCase().includes(q) || t.category.includes(q)) &&
    (!cat || t.category === cat)
  );
}

function renderTable() {
  const filtered = getFiltered();
  document.getElementById('table-body').innerHTML = filtered.map(t => {
    const sel = t.id === selectedId ? ' selected' : '';
    return '<div class="row' + sel + '" onclick="selectTile(\\'' + t.id + '\\')">' +
      '<div class="row-thumb"><img src="/api/image/' + t.id + '" alt="" onerror="this.style.display=\\'none\\'"></div>' +
      '<div class="row-name">' + esc(t.text) + '</div>' +
      '<div class="row-emoji">' + t.emoji + '</div>' +
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
  resetDeleteConfirm();
  renderTable();
  showPanel(tile);
}

function showPanel(tile) {
  document.getElementById('panel-title').textContent = tile.text;
  document.getElementById('panel-id').textContent = tile.id.substring(0, 8) + '…';
  setCurrentImage('/api/image/' + tile.id + '?t=' + Date.now(), tile.emoji);
  document.getElementById('field-name').value = tile.text;
  document.getElementById('field-emoji').value = tile.emoji;
  document.getElementById('field-category').value = tile.category;
  document.getElementById('field-rarity').value = tile.rarity;
  document.getElementById('btn-delete').style.display = '';
  resetGenerationUI();
  document.getElementById('panel-empty').style.display = 'none';
  document.getElementById('panel-content').style.display = 'flex';
}

function setCurrentImage(src, fallbackEmoji) {
  const img = document.getElementById('image-current');
  const ph  = document.getElementById('img-placeholder');
  img.src = src;
  img.style.display = 'block';
  ph.textContent = fallbackEmoji;
  ph.style.display = 'none';
  img.onerror = () => { img.style.display = 'none'; ph.style.display = ''; };
}

// ── Add mode ───────────────────────────────────────────────────────────────────────────
function startAddMode() {
  selectedId = null;
  isAddMode = true;
  pendingImageB64 = null;
  resetDeleteConfirm();
  document.getElementById('panel-title').textContent = 'New Tile';
  document.getElementById('panel-id').textContent = '(new)';
  document.getElementById('image-current').style.display = 'none';
  document.getElementById('img-placeholder').textContent = '🎴';
  document.getElementById('img-placeholder').style.display = '';
  document.getElementById('field-name').value = '';
  document.getElementById('field-emoji').value = '';
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
  const name = document.getElementById('field-name').value.trim() || 'a tile';
  const cat  = document.getElementById('field-category').value;
  document.getElementById('prompt-textarea').value = buildPrompt(name, cat);
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
  if (!isAddMode && selectedId) {
    const r = await fetch('/api/tiles/' + selectedId + '/image', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({image_b64: pendingImageB64}),
    });
    if (!r.ok) { alert('Failed to save image'); return; }
  }
  setCurrentImage('data:image/png;base64,' + pendingImageB64, document.getElementById('field-emoji').value);
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
  const emoji    = document.getElementById('field-emoji').value.trim();
  const category = document.getElementById('field-category').value;
  const rarity   = document.getElementById('field-rarity').value;
  if (!name || !emoji) { alert('Name and emoji are required'); return; }

  if (isAddMode) {
    const body = {text: name, emoji, category, rarity};
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
    const r = await fetch('/api/tiles/' + selectedId, {
      method: 'PUT', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({text: name, emoji, category, rarity}),
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
        else:
            self.send_error_json(404, "Not found")

    def do_POST(self):
        if self.path == "/api/generate":
            self._handle_generate()
        elif self.path == "/api/tiles":
            self._handle_add_tile()
        elif self.path.startswith("/api/tiles/") and self.path.endswith("/image"):
            tile_id = self.path[len("/api/tiles/"):-len("/image")]
            self._handle_save_image(tile_id)
        else:
            self.send_error_json(404, "Not found")

    def do_PUT(self):
        if self.path.startswith("/api/tiles/"):
            tile_id = self.path[len("/api/tiles/"):]
            self._handle_update_tile(tile_id)
        else:
            self.send_error_json(404, "Not found")

    def do_DELETE(self):
        if self.path.startswith("/api/tiles/"):
            tile_id = self.path[len("/api/tiles/"):]
            self._handle_delete_tile(tile_id)
        else:
            self.send_error_json(404, "Not found")

    # ── Handlers ─────────────────────────────────────────────────────────────

    def _serve_ui(self):
        # Inject runtime config into the HTML so JS knows categories/rarities
        html = HTML_APP.replace(
            "/* __INJECT__ */",
            f"const CATEGORIES = {json.dumps(CATEGORIES)};\n"
            f"    const RARITIES = {json.dumps(RARITIES)};",
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
        required = {"text", "emoji", "category", "rarity"}
        missing = required - body.keys()
        if missing:
            self.send_error_json(400, f"Missing fields: {', '.join(sorted(missing))}")
            return
        new_id = str(uuid.uuid4()).upper()
        tile = {
            "id":       new_id,
            "text":     body["text"],
            "emoji":    body["emoji"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
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
                allowed = {"text", "emoji", "category", "rarity"}
                tile.update({k: v for k, v in body.items() if k in allowed})
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
        body = self.read_json_body()
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
