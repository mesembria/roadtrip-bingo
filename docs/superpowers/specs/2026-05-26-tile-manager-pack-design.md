# Tile Manager — Pack-Aware Redesign

**Date:** 2026-05-26  
**Tool:** `tools/tile_manager.py`  
**Extends:** `docs/superpowers/specs/2026-05-25-tile-manager-design.md`  
**References:** `docs/superpowers/specs/2026-05-25-tile-packs-design.md`

---

## Overview

Extend the existing `tile_manager.py` single-file web tool to become the one-stop shop for all tile content — both base tiles and pack-specific modifications. The base tiles tab is unchanged. Each pack gets its own tab showing a unified "pack diff" view: every way that pack differs from the base pool, with modification type clearly indicated.

---

## Architecture

Same foundation: single Python file, `http.server`-based, embedded SPA, no new dependencies.

### New File Paths

```python
PACKS_DIR = "../RoadTripBingo/Resources"
# Pack files: {PACKS_DIR}/pack-{id}.json  (e.g. pack-farm-country.json)
```

Pack IDs are discovered at server startup by globbing `pack-*.json` in `PACKS_DIR`. The tab order follows the order packs are discovered (alphabetical by filename, matching the Swift `loadAll()` order).

### New API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/packs` | Returns array of `{id, name, description, tileCount, overrideCount, excludedCount}` — one entry per pack |
| `GET` | `/api/packs/<id>` | Returns full pack JSON (`tiles`, `rarityOverrides`, `excludedTileIDs`) |
| `PUT` | `/api/packs/<id>` | Replaces the entire pack JSON on disk; client sends the full pack object |
| `POST` | `/api/packs/<id>/tiles` | Add a new exclusive tile to the pack; same contract as `POST /api/tiles` but writes into the pack's `tiles` array |
| `POST` | `/api/packs/<id>/tiles/<uuid>/image` | Save approved image for an exclusive tile (same as base `POST /api/tiles/<uuid>/image`) |

**Pack saves are always full-object:** the client holds the complete pack in memory and sends the whole thing on save. No partial-update endpoints for packs. This avoids merge complexity and keeps the server stateless.

**Move from Base** is a compound operation handled entirely by the client:
1. Client calls `DELETE /api/tiles/<uuid>` to remove the tile from `squares.json` (and its image from disk)
2. Client calls `POST /api/packs/<id>/tiles` with the tile's data and existing UUID (preserved to avoid breaking saves)
3. If the tile had an image, client saves it to the pack tile via `POST /api/packs/<id>/tiles/<uuid>/image`

The server does not need a dedicated "move" endpoint.

### Existing Endpoints — Unchanged

All base-tile endpoints (`GET /api/tiles`, `POST /api/tiles`, `PUT /api/tiles/<uuid>`, `DELETE /api/tiles/<uuid>`, `GET /api/image/<uuid>`, `POST /api/generate`, `POST /api/tiles/<uuid>/image`) are unchanged.

---

## UI Structure

### Tab Bar

The top bar gains one tab per pack, appended after the existing "Base Tiles" tab. Each pack tab shows a coloured dot (pack-specific colour defined in client, one per known pack ID) and the pack name. The existing "Base Tiles" tab and its behaviour are unchanged.

Tab colours (consistent with `TilePacksView.swift` Americana theme):
- Base Tiles: `--text2` (neutral)
- Farm Country: `#4A9060` (forest green)
- Interstate: `#5B8DD9` (highway blue)
- City: `#9060C8` (urban purple)
- Mountains: `#7A9060` (pine green)
- Beach & Coast: `#4090A8` (ocean teal)
- Desert Southwest: `#C87840` (canyon orange)

Pack tabs are loaded dynamically from `/api/packs` — if a new pack JSON is added later, a new tab appears automatically on next server start.

### Pack Screen Layout

Each pack screen uses the same two-column layout as the base tiles screen:
- **Left column** (460px fixed): pack diff list
- **Right column** (flexible): contextual panel

---

## Pack Diff List (Left Column)

### Toolbar

From left to right:
- **Search input**: filters rows by tile name (case-insensitive substring match)
- **Type filter dropdown**: "All types" / "Exclusive" / "Override" / "Excluded"
- **`+ Add ▾` button**: opens a dropdown menu with four options (see Addition Flows below)

### Column Headers

`[thumb]` · Tile · Type · Detail

### Rows

Three row types, visually distinct:

**Exclusive tile** — tile that only appears when this pack is active (lives in pack's `tiles` array, not in `squares.json`):
- Left border: 3px solid `--green`
- Badge: `EXCLUSIVE` in green
- Thumbnail: served from `/api/image/<uuid>` (same endpoint as base tiles)
- Detail column: rarity badge

**Override** — base tile whose rarity is different in this pack (tile stays in `squares.json`; pack's `rarityOverrides` map changes its rarity):
- Left border: 3px solid `--amber`
- Badge: `OVERRIDE` in amber
- Detail column: `common → veryCommon` in amber text (from → to)
- No thumbnail (base tile image is shown in the right panel)

**Excluded** — base tile that is removed from the pool when this pack is active (tile stays in `squares.json`; pack's `excludedTileIDs` removes it):
- Left border: 3px solid `--red`
- Row text: dimmed (`--text2`)
- Tile name: strikethrough
- Badge: `EXCLUDED` in red
- No thumbnail

### Footer

`{n} modifications` (total across all types) · **Save Pack** button (right, green).

Save Pack sends a `PUT /api/packs/<id>` with the entire pack object. The button is disabled when there are no unsaved changes.

---

## Right Panel (Contextual)

### Default — Nothing Selected

Pack summary card:
- Pack name (Rye font, amber)
- `{n} exclusive tiles · {n} overrides · {n} exclusions`
- Hint text: "Select a modification to edit, or use + Add to create one"

### Exclusive Tile Selected

Full tile editor — identical to the base tile edit panel:
- Image section (thumbnail, generate new image)
- Metadata fields: Name, Emoji, Category, Rarity
- Footer: `🗑 Remove from Pack` (left, red) · Cancel · Save Changes (right)

**Remove from Pack:** removes the tile from the pack's `tiles` array and deletes its image. Does NOT move it to `squares.json`. Inline confirmation required.

### Override Selected

- **Rarity change display**: three cells in a row — `[from rarity badge]` → `[to rarity badge]` (current override). The "to" cell has a rarity select dropdown.
- **Base tile info** (read-only): name, emoji, category, current base rarity
- Horizontal rule
- `Remove Override` button (red, full-width). Inline confirmation.
- Footer: Cancel · Save Changes

### Excluded Selected

- **Base tile info** (read-only): name, emoji, category, rarity
- **Red callout box**: "This tile is hidden when this pack is active."
- `Convert to Override` link (amber): promotes the exclusion to an override, pre-filling the rarity dropdown with the tile's base rarity. Removes the tile from `excludedTileIDs`, adds it to `rarityOverrides`.
- `Remove Exclusion` button (red, full-width). Inline confirmation.
- Footer: Cancel · (Save Changes disabled — exclusions are saved with the pack, no field to change)

---

## Addition Flows (+ Add ▾ Dropdown)

### 1. Create Exclusive Tile

Opens the right panel in "new exclusive tile" mode:
- Blank name, emoji, category, rarity fields
- Same image generation flow as base tiles
- Save → `POST /api/packs/<id>/tiles`; new row appears as EXCLUSIVE type

### 2. Move from Base

Two-step inline picker in the right panel:
1. **Search/select panel**: search input + scrollable list of all base tiles. Each row shows thumbnail, name, category, rarity.
2. **Warning callout**: "This tile will be removed from the base pool and become exclusive to this pack. This cannot be undone without manually editing `squares.json`."
3. **Confirm Move** (red) · Cancel

On confirm:
- Client issues `DELETE /api/tiles/<uuid>` (removes from `squares.json`, deletes image from `TileImages/`)
- Client issues `POST /api/packs/<id>/tiles` with the tile data and preserved UUID, including the original `image_b64` if the image existed
- New EXCLUSIVE row appears; base tile disappears from Base Tiles tab list

### 3. Override Rarity

Two-step in the right panel:
1. **Search/select panel**: same base tile picker as Move from Base, but only tiles not already overridden or excluded by this pack.
2. **Rarity picker**: from/arrow/to display. "From" shows current base rarity (read-only). "To" is a rarity select. Defaults to one step more common than base.
3. **Add Override** (amber) · Cancel

On confirm: tile UUID and new rarity added to pack's `rarityOverrides` in client memory. New OVERRIDE row appears. Saved to disk on **Save Pack**.

### 4. Exclude Base Tile

Two-step in the right panel:
1. **Search/select panel**: only tiles not already excluded or overridden by this pack.
2. **Warning callout**: "When this pack is active, this tile won't appear on any board."
3. **Add Exclusion** (red) · Cancel

On confirm: tile UUID added to pack's `excludedTileIDs` in client memory. New EXCLUDED row appears. Saved to disk on **Save Pack**.

---

## Save Model

**Base tiles** save immediately (per-operation, as today).

**Pack modifications** are held in client memory and saved as a batch when the user clicks **Save Pack**. This reflects that overrides and exclusions are meaningless in isolation — the whole pack JSON is the unit of change.

Before navigating away from a pack tab with unsaved changes, a `window.confirm` dialog warns: "You have unsaved pack changes. Leave anyway?"

---

## Data Integrity Notes

- **UUID preservation on Move from Base:** the exclusive tile in the pack gets the same UUID as the base tile it replaced. This avoids any issues with existing saved game state that might reference the UUID.
- **Exclusions and overrides reference base tile UUIDs:** the server does no referential integrity checking. The tool trusts the operator.
- **Pack image generation:** exclusive tiles use the same `/api/generate` endpoint as base tiles — same Gemini flow, same prompt builder, same approve/discard pattern.

---

## Out of Scope

- Creating new pack JSON files from within the tool (packs are created by editing files directly; the tool manages the content of existing packs)
- Reordering exclusive tiles within a pack
- Exporting or importing packs
- Viewing the combined pool preview across multiple active packs
- Undo beyond the current unsaved session (refresh loses unsaved pack changes)
- Image management for the pack card images (the hero JPGs shown in `TilePacksView`)
