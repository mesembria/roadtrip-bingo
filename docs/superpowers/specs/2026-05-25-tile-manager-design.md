# Tile Manager — Design Spec

**Date:** 2026-05-25  
**Tool:** `tools/tile_manager.py`  
**Stack:** Python stdlib (`http.server`) + `requests` (already a dependency)

---

## Overview

A local web tool for managing Road Trip Bingo tiles. Run with `python3 tools/tile_manager.py`, open the printed URL in a browser. Reads and writes `squares.json` and `TileImages/` directly. No build step, no extra dependencies beyond `requests`.

---

## Architecture

Single Python file. An `http.server`-based server handles two kinds of requests:

- **Static routes**: `GET /` serves the embedded HTML/CSS/JS app (single-page, all inline).
- **API routes**: JSON endpoints for tile CRUD and image generation.

### API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/tiles` | Returns full `squares.json` array |
| `GET` | `/api/image/<uuid>` | Serves `TileImages/<uuid>.png` |
| `POST` | `/api/tiles` | Add new tile; auto-assigns UUID; saves to `squares.json` |
| `PUT` | `/api/tiles/<uuid>` | Update tile metadata in `squares.json` |
| `DELETE` | `/api/tiles/<uuid>` | Remove tile from `squares.json`; delete its image |
| `POST` | `/api/generate` | Call Gemini API with `{prompt}`; return `{image_b64}` — does NOT save |
| `POST` | `/api/tiles/<uuid>/image` | Save approved `{image_b64}` to `TileImages/<uuid>.png` |

The generate → save split means the image is never committed until the user explicitly approves it.

### API Key

Read from the `GEMINI_API_KEY` environment variable at startup. If absent, the server prints a warning and the Generate button is disabled in the UI.

```bash
GEMINI_API_KEY=your_key python3 tools/tile_manager.py
```

### File Paths

Resolved relative to the script's own location, so the tool works regardless of where it's invoked from:

- `../RoadTripBingo/Resources/squares.json`
- `../RoadTripBingo/Resources/TileImages/<uuid>.png`

---

## UI Layout

Two-column layout, full viewport height.

### Left — Tile Table (460px fixed width)

**Toolbar** (top): search input · category filter dropdown · `+ Add Tile` button.

**Column headers**: thumbnail · Name · Emoji · Category · Rarity.

**Rows** (scrollable): each row shows a 30×30 thumbnail served from `/api/image/<uuid>`, tile name, emoji, category, and a colour-coded rarity badge. Clicking a row selects it and opens the edit panel on the right. The selected row is highlighted with an amber left border.

**Footer**: live tile count and category count.

### Right — Edit Panel (flexible)

**Header**: tile name + truncated UUID.

**Body** (scrollable):

1. **Image section** — displays the current tile image (120×120, served from `/api/image/<uuid>`). Next to it: a "✦ Generate New Image" button.

2. **Prompt editor** (appears on Generate click):
   - Header: `Generation Prompt` label + `Edit before running` hint.
   - Editable textarea pre-filled with the auto-built prompt (name + category hint + style constant). User may freely edit before submitting.
   - `Run Generation` button · `Cancel` button.

3. **Loading state**: spinner + "Generating with Gemini 2.5 Flash…" while request is in flight.

4. **Generation result** (appears after load):
   - Preview of the generated image (full-size, loaded from returned base64).
   - `✓ Use This Image` — saves to disk, updates current image display.
   - `✕ Discard · Keep Original` — discards, restores original.

5. **Metadata fields**: Name (text input) · Emoji (text input) · Category (select) · Rarity (select).

**Footer**: `🗑 Delete Tile` (left) · `Cancel` · `Save Changes` (right).

---

## Prompt Building

Matches the existing `generate_tiles.py` logic exactly:

```python
OVERRIDES = { ... }   # per-tile subject overrides (copied from existing script)

STYLE = (
    "Flat vector illustration, clean thin outlines, bright colors. "
    "Plain solid white background — the illustration sits directly on white "
    "with absolutely no drop shadow, no border, no card, no frame, no vignette, "
    "no outline around the image edge. Square composition. No text, no labels, no letters."
)

CATEGORY_HINTS = {
    "vehicles":  "Side view, full vehicle visible.",
    "nature":    "Full subject visible, centered.",
    "signs":     "The physical sign or object itself, not just a flat sign graphic.",
    "landmarks": "Full structure visible.",
    "food":      "Storefront or roadside view.",
    "weather":   "Dramatic sky scene.",
}

def build_prompt(text, category):
    subject = OVERRIDES.get(text, f"a {text.lower()}")
    hint = CATEGORY_HINTS.get(category, "")
    return f"{subject.capitalize()}. {hint} {STYLE}"
```

The textarea in the UI is pre-filled with this output. Any edits the user makes are what gets sent to the API.

---

## Tile CRUD Flows

### Edit existing tile
1. Click row → panel loads tile data.
2. Edit any metadata fields.
3. Optionally regenerate image (prompt editor → run → approve/discard).
4. `Save Changes` → `PUT /api/tiles/<uuid>` with updated fields. If a new image was approved, it was already written to disk in step 3.

### Add new tile
1. Click `+ Add Tile` → panel opens in add mode (blank fields, no UUID shown).
2. Fill in Name, Emoji, Category, Rarity.
3. Optionally generate an image — the approved base64 is held in client memory, not yet on disk.
4. `Save` → `POST /api/tiles` with metadata fields and, if an image was approved, an `image_b64` field. Server assigns a permanent UUID, writes the entry to `squares.json`, and if `image_b64` is present, writes it to `TileImages/<uuid>.png`.
5. New row appears in the table, selected.

### Delete tile
1. Click `🗑 Delete Tile` → inline confirmation replaces the button ("Are you sure? This cannot be undone." + `Confirm Delete` / `Cancel`).
2. Confirm → `DELETE /api/tiles/<uuid>` — removes from `squares.json`, deletes image file.
3. Panel clears; row is removed from table.

---

## Aesthetic

Uses the game's own fonts (loaded from Google Fonts: `Rye`, `Barlow Condensed`, `JetBrains Mono`) and a dark Americana palette:

- Background: `#0D0D0B` (asphalt)
- Surface: `#141410` / `#1C1C17`
- Accent: `#E8A830` (amber / road-sign yellow)
- Danger: `#C84040` (stop-sign red)
- Success: `#4A9060` (forest green)
- Rarity badges: colour-coded (veryCommon → green, common → blue, uncommon → amber, rare → red)
- Subtle grain overlay via SVG noise filter

---

## Out of Scope

- Batch image generation (add tiles one at a time)
- Authentication / multi-user
- Undo history beyond the current session
- Deploying / hosting the tool remotely
