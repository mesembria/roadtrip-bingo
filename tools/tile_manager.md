# Tile Manager

A browser-based tool for managing Road Trip Bingo tiles and tile packs. Runs a local HTTP server and opens the UI automatically.

---

## Quick Start

```bash
GEMINI_API_KEY=your_key python3 tools/tile_manager.py
```

Opens `http://localhost:8765` in your browser. Press **Ctrl+C** to stop.

> **Image generation is disabled** if `GEMINI_API_KEY` is not set. Everything else — editing metadata, managing packs, moving tiles — works without a key.

### Dependency

```bash
pip install requests
```

---

## Data Files

| File | Purpose |
|------|---------|
| `RoadTripBingo/Resources/squares.json` | Master list of base tiles |
| `RoadTripBingo/Resources/TileImages/{UUID}.png` | Tile images, named by tile ID |
| `RoadTripBingo/Resources/pack-{id}.json` | One file per tile pack |

---

## Base Tiles Tab

The left column lists all tiles from `squares.json`. Click any row to open its editor in the right panel.

### Filtering & Sorting

- **Search** — filters by name or category substring
- **Category dropdown** — narrows to one category
- **Name / Rarity column headers** — click to sort ascending; click again to sort descending

### Adding a Tile

1. Click **+ Add Tile** in the toolbar
2. Fill in Name, Category, and Rarity
3. Optionally generate an image (see [Image Generation](#image-generation))
4. Click **Save Changes** — a new UUID is assigned and the tile is appended to `squares.json`

### Editing a Tile

1. Click any row in the list
2. Edit Name, Category, or Rarity in the panel
3. Click **Save Changes** — writes the updated tile back to `squares.json`

Editing metadata and generating a new image are independent actions. Saving metadata does not affect the current image, and approving a new image does not require a metadata save.

### Deleting a Tile

Click **🗑 Delete Tile**, then click **Confirm Delete** within three seconds. Removes the tile from `squares.json` and deletes its image from `TileImages/`.

---

## Image Generation

Applies to both base tiles and pack exclusive tiles. The workflow is the same in both cases:

1. Click **❆ Generate New Image** — the prompt editor slides open
2. Edit the prompt if needed (auto-built from tile name + category)
3. Click **Run Generation** — calls Gemini 2.5 Flash; takes ~10–30 seconds
4. A preview appears — click **✓ Use This Image** to approve or **✕ Discard** to try again
5. For **existing** tiles the image is saved to disk immediately on approval
6. For **new** tiles (not yet saved) the image is held in memory and sent together with the tile metadata when you click **Save Changes**

> **Re-generating after approval**: clicking Generate New Image again after approving will show a confirmation before replacing the approved image (for new tiles only).

### Prompt Structure

```
{Subject}. {Category hint}. Flat vector illustration, clean thin outlines, bright colors. Plain solid white background — the illustration sits directly on white with absolutely no drop shadow, no border, no card, no frame, no vignette, no outline around the image edge. Square composition. No text, no labels, no letters.
```

Category hints:

| Category | Hint |
|----------|------|
| vehicles | Side view, full vehicle visible. |
| nature | Full subject visible, centered. |
| signs | The physical sign or object itself, not just a flat sign graphic. |
| landmarks | Full structure visible. |
| food | Storefront or roadside view. |
| weather | Dramatic sky scene. |

To add a new category, add it to both `CATEGORIES` and `CATEGORY_HINTS` at the top of `tile_manager.py`.

---

## Pack Tabs

Each `pack-{id}.json` file gets its own tab. Clicking a pack tab loads the pack's **diff view** — the set of ways this pack modifies the base tile pool.

### Three Modification Types

| Type | Color | Meaning |
|------|-------|---------|
| **EXCLUSIVE** | Green border | A tile that only appears when this pack is active |
| **OVERRIDE** | Amber border | A base tile whose rarity is changed for this pack |
| **EXCLUDED** | Red border, strikethrough | A base tile hidden from all boards when this pack is active |

### Filtering the Diff List

- **Search box** — filter by tile name
- **Type dropdown** — show only one modification type

### Saving Pack Changes

Pack modifications are held in memory until you click **Save Pack** (bottom of the diff list). The button is disabled when there are no unsaved changes and shows **Saved ✓** briefly after a successful save.

Switching to a different tab with unsaved changes shows a confirmation dialog.

> **Exception**: exclusive tile images and newly-created exclusive tiles are saved to disk immediately — they do not wait for Save Pack.

---

## Pack Addition Flows

Click **+ Add ▾** in the pack toolbar to open the menu.

### Create Exclusive Tile

Creates a brand-new tile that only exists in this pack.

1. A blank tile editor opens in the right panel
2. Optionally generate an image (see [Image Generation](#image-generation))
3. Fill in Name, Emoji, Category, Rarity
4. Click **Save Changes** — the tile is written to the pack JSON immediately and assigned a UUID; the image (if any) is saved to `TileImages/`

### Move from Base

Promotes a base tile to an exclusive tile in this pack. The tile is removed from `squares.json` and its UUID is preserved in the pack.

1. Pick a tile from the list
2. The tile disappears from Base Tiles immediately
3. The tile appears as EXCLUSIVE in the pack diff list
4. Its existing image (if any) is carried over automatically

> **This cannot be undone** from the UI — manually editing `squares.json` is required to reverse it.

### Override Rarity

Changes a base tile's rarity when this pack is active. Does not affect the tile in other packs or the base pool.

1. Pick a base tile from the list (tiles already overridden or excluded are omitted)
2. Choose the new rarity from the dropdown
3. Click **Add Override** — the change is held in memory until Save Pack

### Exclude Base Tile

Hides a base tile from all boards when this pack is active.

1. Pick a base tile from the list (tiles already overridden or excluded are omitted)
2. The exclusion is added immediately as an EXCLUDED row

An excluded tile can be converted to an override from its editor (click the tile, then **Convert to Override Instead**).

---

## Editing Existing Pack Modifications

Click any row in the diff list to open its editor.

### Exclusive tile editor

Same fields as base tile editing (Name, Emoji, Category, Rarity) plus image generation. Changes to metadata are held in memory until Save Pack. Image changes are saved to disk immediately on approval.

Click **🗑 Remove from Pack** to delete the exclusive tile from the pack (the tile is removed from the pack JSON on the next Save Pack; the image file is not deleted automatically).

### Override editor

Change the pack-specific rarity via the dropdown, then click **Save Changes** (held in memory until Save Pack). Click **Remove Override** to delete the override entirely.

### Excluded editor

Read-only info about the excluded tile. Use **Convert to Override Instead** or **Remove Exclusion** to restore the tile to the pool.

---

## Pack JSON Schema

```json
{
  "id": "farm-country",
  "name": "Farm Country",
  "description": "Barns, silos, and wide open fields.",
  "imageName": "pack-farm-country",
  "tiles": [
    {
      "id": "UUID-STRING",
      "text": "Grain Silo",
      "emoji": "🌾",
      "category": "landmarks",
      "rarity": "common"
    }
  ],
  "rarityOverrides": {
    "BASE-TILE-UUID": "rare"
  },
  "excludedTileIDs": [
    "ANOTHER-BASE-UUID"
  ]
}
```

Pack files are pre-created — the tool will not create new pack files. Add a new `pack-{id}.json` manually and restart the server to have it appear as a tab.

---

## Rarities

`veryCommon` · `common` · `uncommon` · `rare` · `veryRare`

These map directly to `SquareRarity` in the Swift app. Rarity controls how frequently a tile is dealt to boards (weighted random selection in `SquarePool`).

---

## API Reference (for debugging)

The server exposes a small REST API on `http://localhost:8765`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/tiles` | All base tiles as JSON array |
| `POST` | `/api/tiles` | Add a tile (`text`, `category`, `rarity` required; optional `image_b64`) |
| `PUT` | `/api/tiles/{id}` | Update tile metadata |
| `DELETE` | `/api/tiles/{id}` | Delete tile and its image |
| `GET` | `/api/image/{id}` | Serve tile PNG |
| `POST` | `/api/tiles/{id}/image` | Save image for existing base tile (`image_b64` required) |
| `GET` | `/api/packs` | Summary list of all packs |
| `GET` | `/api/packs/{id}` | Full pack JSON |
| `PUT` | `/api/packs/{id}` | Overwrite pack JSON (full object required) |
| `POST` | `/api/packs/{id}/tiles` | Add exclusive tile to pack |
| `POST` | `/api/packs/{id}/tiles/{uuid}/image` | Save image for existing exclusive tile |
| `POST` | `/api/generate` | Generate image via Gemini (`prompt` required); returns `image_b64` |

---

## Running Tests

```bash
python3 -m pytest tools/test_tile_manager.py -v
```

Tests cover all pure Python functions (`build_prompt`, tile I/O, image I/O, pack I/O, Gemini API wrapper). The embedded HTML/JS is not unit-tested.
