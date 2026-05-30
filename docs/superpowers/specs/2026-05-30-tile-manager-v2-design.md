# Tile Manager v2 — Design Spec

**Date:** 2026-05-30
**Tool:** `tools/tile_manager.py`
**Supersedes:** `docs/superpowers/specs/2026-05-25-tile-manager-design.md`, `docs/superpowers/specs/2026-05-26-tile-manager-pack-design.md`

---

## Overview

A full redesign of the tile manager web tool around a new conceptual model: **tiles exist in a master pool; packs are curated lists of tiles**. The previous model treated the base pool as implicit and packs as modifiers (overrides, exclusions). The new model makes all pack membership explicit — a tile is either in a pack or it isn't.

The tool retains the same foundation: single Python file, `http.server`-based, embedded SPA, no new dependencies beyond `requests`.

---

## Conceptual Model Change

### Old model
- `squares.json` contains all base tiles — implicitly included in every pack unless excluded.
- Pack files modify the base pool: add exclusive tiles, override rarities for specific tiles, exclude specific tiles.

### New model
- All unique tiles (base + pack-exclusive) are the **master tile pool**.
- Each pack contains an **explicit curated list** of tiles with per-pack rarities.
- No tile is implicitly included in any pack. No exclusion concept.
- **Base** is just another pack from the manager's perspective — one that contains universal tiles (things you might see anywhere: police car, semi truck, etc.). It is not selectable by players in-game.
- A tile's **default rarity** is a convenience baseline — used to pre-fill the rarity picker when adding the tile to a pack. Packs set their own rarity per tile.

### Data model implications

The `rarityOverrides` and `excludedTileIDs` fields in pack JSON become obsolete. The concept of "exclusive tiles" (tiles that live only in a pack JSON) is also eliminated. **All tiles live in `squares.json`**. Packs reference any tile by UUID + per-pack rarity only.

**New pack JSON schema:**

```json
{
  "id": "mountains",
  "name": "Mountains",
  "description": "Snow caps, switchbacks, pine forests, and the thin air of elevation.",
  "imageName": "Mountains",
  "tiles": [
    { "id": "UUID-1", "rarity": "veryCommon" },
    { "id": "UUID-2", "rarity": "common" },
    { "id": "UUID-3", "rarity": "uncommon" }
  ]
}
```

Every entry in `tiles` is a `{id, rarity}` pair. All tile metadata (name, category, description, image) lives in `squares.json`. This makes packs lightweight references and `squares.json` the single source of truth for tile content.

> **Note:** Migrating existing packs to this format is handled by `tools/migrate_packs.py` (see Migration Script section). The migration must be run before the new tool is used. A companion `SquarePool` update in the Swift app is also in scope (see Swift App section).

---

## Architecture

Same foundation as the existing tool:
- Single Python file (`tools/tile_manager.py`)
- `http.server`-based server on port 8765
- Embedded single-page app (HTML/CSS/JS inline)
- File paths resolved relative to the script

### Updated API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/tiles` | All base tiles from `squares.json` |
| `POST` | `/api/tiles` | Add tile; auto-assigns UUID; saves to `squares.json` and optionally to pack JSONs |
| `PUT` | `/api/tiles/<uuid>` | Update tile metadata in `squares.json` and optionally in pack JSONs |
| `DELETE` | `/api/tiles/<uuid>` | Remove tile from `squares.json` and from all pack JSONs that reference it; delete image |
| `GET` | `/api/image/<uuid>` | Serve `TileImages/<uuid>.png` |
| `POST` | `/api/tiles/<uuid>/image` | Save approved image for a tile |
| `GET` | `/api/packs` | Summary list of all packs `{id, name, tileCount}` |
| `GET` | `/api/packs/<id>` | Full pack JSON |
| `PUT` | `/api/packs/<id>` | Replace entire pack JSON on disk (full object) |
| `POST` | `/api/generate` | Call Gemini with `{prompt}`; return `{image_b64}` — does not save |

**Removed endpoints:** `POST /api/packs/<id>/tiles` and `POST /api/packs/<id>/tiles/<uuid>/image` — exclusive tiles are now created via the base `POST /api/tiles` endpoint with pack membership included in the request body. The server writes to `squares.json` (or not, if pack-exclusive) and to the relevant pack JSON in one operation.

> Pack saves are always full-object: client holds the pack in memory and sends the whole thing on `PUT /api/packs/<id>`.

---

## UI Structure

### Tab Bar

Two top-level tabs:

- **All Tiles** — master tile list + tile detail panel
- **Pack View** — pack gallery sidebar + pack tile grid

---

## Tab 1 — All Tiles

Two-column layout, full viewport height.

### Left Column — Tile List (400px fixed)

**Toolbar:** search input · category filter dropdown · `+ Add` button.

**Column headers:** thumbnail · Name · Rarity · Packs.

**Rows:** 34×34 thumbnail · tile name · default rarity badge · pack membership dots (one coloured dot per pack the tile belongs to, using pack colours defined below).

Clicking a row selects it and loads the detail panel. Selected row: amber left border + subtle amber tint.

**Footer:** total tile count across all packs.

### Right Column — Detail Panel (flexible)

Two-column grid within the panel:

**Left sub-column — Image:**
- Section label: "Image"
- Large image display box (fills available width, square aspect ratio)
- Header bar: "Tile Image" label + "click to expand" hint
- Image fills the box. Clicking opens a lightbox (see below).
- Footer bar inside the box: prompt note ("Prompt: description + style") + "❆ Generate Again" button (or "❆ Generate Image" if no image exists yet).

**Right sub-column — Metadata, Description, Pack Membership:**

*Details section:*
- Name field (editable text)
- Category field (select)
- Default Rarity (chip row: V.Common · Common · Uncommon · Rare · V.Rare — one selected)

*Description section:*
- Editable textarea. Stored in `squares.json`. Used verbatim as the Gemini prompt subject (style constant appended at generation time — never shown).

*Pack Membership section:*
- One row per pack, sorted: included packs first, then excluded.
- Each row: pack colour bar · pack name · status text · toggle button.
  - **Included:** amber-tinted background, green status ("Included · {rarity}"), filled amber ✓ toggle.
  - **Not included:** neutral background, grey status ("Not included"), open ○ toggle.
- Clicking ○ on a not-included pack expands that row inline with a rarity chip picker (pre-filled with the tile's default rarity). Selecting a chip collapses the picker and marks the pack as pending-add.
- Clicking ✓ on an included pack marks it as pending-remove (row dims, status changes to "Will remove on save").
- All changes are pending until Save Changes.

**Panel footer:** 🗑 Delete Tile (left, red) · Cancel · Save Changes (right).

Save Changes writes:
- Tile metadata to `squares.json`
- Pack membership changes to each affected pack JSON

### Lightbox

Clicking the tile image opens a centred modal overlay showing the current approved image at larger size:
- Background dimmed to 85% black
- Inner box: 540px wide, square image at top, footer with tile name + "❆ Generate Again" button + ✕ close button
- Only available when an image exists — no lightbox from the "no image" placeholder
- Generation results (pending approve/discard) are resolved in the main panel, not the lightbox
- Click outside or ✕ to dismiss

---

## Tab 2 — Pack View

Two-column layout.

### Left Column — Pack Gallery (180px fixed)

Scrollable list of pack cards. Each card:
- Pack hero image (landscape crop, full card width)
- Pack name (Barlow Condensed bold)
- Tile count ("38 tiles")

Clicking a card loads that pack. Selected card: amber left border + subtle amber tint.

Pack colours (consistent with existing Swift theme):
| Pack | Colour |
|------|--------|
| Base | `#4A9060` (forest green) |
| Farm Country | `#4A9060` |
| Interstate | `#5B8DD9` (highway blue) |
| City | `#9060C8` (urban purple) |
| Mountains | `#7A9060` (pine green) |
| Beach & Coast | `#4090A8` (ocean teal) |
| Desert Southwest | `#C87840` (canyon orange) |

### Right Area — Pack Detail

**Toolbar:** pack name (Rye font, amber) · search input · list/grid view toggle · `+ Add Tile` button.

**Tile grid (default view):** `auto-fill, minmax(72px, 1fr)` grid. Each cell:
- Square tile image (fills cell)
- Rarity dot (coloured, top-right corner)
- Tile name (truncated, bottom)
- Hover: amber border
- Click: opens the All Tiles detail panel for that tile (switches to All Tiles tab with tile selected)

**Tile list (alternate view):** same row format as All Tiles tab but showing only this pack's tiles, with pack-specific rarity badge.

**Rarity breakdown bar (always visible, below grid/list):**
- Section label: "Rarity Breakdown — {n} tiles"
- Horizontal segmented bar, proportional to count per rarity tier
- Legend: coloured dots + "{n} very common", "{n} common", etc.

**`+ Add Tile` button:** opens a search-and-select panel in a right slide-in or inline overlay. Shows the full master tile list filtered to tiles NOT already in this pack. Click a tile to add it — inline rarity chip picker appears, same pattern as the All Tiles toggle flow. Confirm saves to pack JSON immediately.

---

## Generate Image Flow

Three states within the Image section of the detail panel:

**Idle (no image or image approved):**
- Image box shows current image or a "no image" placeholder.
- "❆ Generate Image" button (or "❆ Generate Again" if image exists).
- Clicking fires the generation request immediately — no prompt editor.
- Prompt sent to Gemini: `{description}. {STYLE_CONSTANT}`.

**Generating:**
- Image box replaced by spinner + "~15s" estimate.
- Save Changes disabled.
- Cancel button available.

**Result pending:**
- Generated image shown in the box (green border).
- "✓ Use This Image" and "✕ Discard · try again" buttons in the image box footer.
- Save Changes still disabled until resolved.
- "✕ Discard" returns to Idle state.

Image approval writes the file to `TileImages/<uuid>.png` immediately (does not wait for Save Changes).

### Prompt Construction

```python
STYLE = (
    "Flat vector illustration, clean thin outlines, bright but realistic colors. "
    "Use natural, true-to-life colors for each object and all parts should match "
    "the colors that object would actually have in real life. "
    "Plain solid white background — the illustration sits directly on white "
    "with absolutely no drop shadow, no border, no card, no frame, no vignette, "
    "no outline around the image edge. "
    "Square composition. No text, no labels, no letters."
)

def build_prompt(tile: dict) -> str:
    description = (tile.get("description") or tile["text"]).rstrip(".")
    return f"{description}. {STYLE}"
```

`CATEGORY_HINTS` is retained only to pre-fill the description field when creating a new tile. It is not used at generation time.

### New tile — description pre-fill

When creating a new tile, the description textarea is pre-filled with:
`"{tile name}. {CATEGORY_HINTS[category]}"`

For example: `"Suspension Bridge. Full structure visible."`

The user edits this freely. Whatever is in the field at save time is stored in `squares.json` and used for all future generations.

---

## Add Tile Flow

1. Click `+ Add` in the All Tiles toolbar.
2. Detail panel opens in new-tile mode (amber header "✦ New Tile").
3. Fields: Name (text) · Category (select) · Default Rarity (chips).
4. Description textarea is pre-filled once Name and Category are both set, using the category hint as a starter. User may edit freely.
5. Image section is greyed out until Name and Category are filled.
6. Pack Membership section is greyed out until Name and Category are filled. Once unlocked, works identically to the edit flow.
7. Generate Image available once description is non-empty. Save Changes is blocked while a generation result is unresolved.
8. Click **Create Tile**:
   - Assigns a new UUID.
   - Appends tile metadata to `squares.json`.
   - Writes image to `TileImages/<uuid>.png` (if approved).
   - Appends `{id, rarity}` to each included pack's `tiles` array and saves those pack JSONs.
9. New row appears highlighted in the tile list, selected.

---

## Save Model

| Action | When saved |
|--------|-----------|
| Tile metadata (name, category, rarity, description) | On Save Changes / Create Tile |
| Tile image | Immediately on "✓ Use This Image" approval |
| Pack membership changes | On Save Changes / Create Tile |
| Pack tile grid changes (Pack View + Add Tile) | Immediately on confirm in the add-tile picker |

No deferred "Save Pack" button — all saves are per-tile operations. The client does not hold unsaved pack state.

---

## Aesthetic

Unchanged from existing tool: dark Americana palette, Rye + Barlow Condensed fonts, amber accent, rarity colour system.

| Element | Value |
|---------|-------|
| Background | `#0D0D0B` |
| Surface | `#141410` / `#1C1C17` |
| Accent | `#E8A830` (amber) |
| Danger | `#C84040` (red) |
| Success | `#4A9060` (green) |
| V.Common | `#6BC88A` |
| Common | `#7BAAF0` |
| Uncommon | `#E8C060` |
| Rare | `#E87070` |
| V.Rare | `#C090F0` |

---

## Migration Script

A one-time Python script (`tools/migrate_packs.py`) run before the new tool is used. It converts all `pack-*.json` files from the old format to the new format:

1. For each pack, read `rarityOverrides`, `excludedTileIDs`, and `tiles` (exclusives).
2. Build the new `tiles` array:
   - All base tiles from `squares.json` that are **not** in `excludedTileIDs` → add as `{id, rarity}`, using the `rarityOverrides` value if present, otherwise the tile's default rarity from `squares.json`.
   - All existing exclusive tiles → first write their full metadata into `squares.json` (they become regular tiles), then add as `{id, rarity}`.
3. Remove `rarityOverrides` and `excludedTileIDs` from the pack JSON.
4. Write the updated pack JSON back to disk.

The script is idempotent (safe to run twice) and prints a summary of changes made per pack.

---

## Swift App — SquarePool Update

`SquarePool` currently loads `squares.json` as the base pool and applies pack modifications at deal time. It must be updated to load an explicit pack's tile list directly.

### New loading behaviour

When a pack is active, `SquarePool` loads the pack's `tiles` array and resolves each entry against `squares.json`:

```swift
// For each {id, rarity} in pack.tiles:
// 1. Look up the full tile in squares.json by id
// 2. Override the rarity with the pack's rarity value
// 3. Use the resolved tile in the deal pool
```

Tiles in `squares.json` that are not referenced by the active pack are not included in the pool.

When no pack is active (base game), `SquarePool` loads and uses `squares.json` directly with no pack filtering — this is the "Base" pack implicitly, but no pack file is needed for it. Alternatively, a `pack-base.json` can be introduced later to make the base pool explicit; this is not required for the initial migration.

### Backward compatibility

The old `rarityOverrides` and `excludedTileIDs` fields are simply ignored by the new loading code. Once the migration script has run, they will not be present in any pack file.

---

## Out of Scope

- Reviewing and re-curating existing pack content to match the new explicit model (content task, not tool task)
- Creating new pack JSON files from within the tool (edit files directly, restart server)
- Reordering tiles within a pack
- Undo beyond cancel (refreshing discards any unsaved metadata edits)
- Image management for pack hero JPGs
- Batch image generation
- Authentication or remote hosting
