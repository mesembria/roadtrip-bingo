# Tile Manager v2

A browser-based tool for managing Road Trip Bingo tiles and tile packs.

---

## Quick Start

```bash
GEMINI_API_KEY=your_key python3 tools/tile_manager.py
```

Opens `http://localhost:8765` in your browser. Press **Ctrl+C** to stop.

> **Image generation is disabled** if `GEMINI_API_KEY` is not set. Everything else — editing metadata, managing pack membership, adding tiles — works without a key.

### Dependency

```bash
pip install requests
```

---

## Data Model

All tiles live in `squares.json` as the single source of truth. Packs are curated reference lists: each pack contains only `{id, rarity}` pairs — no full tile objects. All tile metadata (name, category, description, image) lives in `squares.json`.

| File | Purpose |
|------|---------|
| `RoadTripBingo/Resources/squares.json` | Master tile pool — all tiles |
| `RoadTripBingo/Resources/TileImages/{UUID}.png` | Tile images, named by tile UUID |
| `RoadTripBingo/Resources/pack-{id}.json` | One file per pack: `{id, name, tiles: [{id, rarity}]}` |

**Pack JSON schema:**

```json
{
  "id": "mountains",
  "name": "Mountains",
  "description": "Snow caps and switchbacks.",
  "imageName": "Mountains",
  "tiles": [
    {"id": "UUID-1", "rarity": "veryCommon"},
    {"id": "UUID-2", "rarity": "uncommon"}
  ]
}
```

---

## All Tiles Tab

Left panel: all tiles from `squares.json`. Right panel: detail editor for the selected tile.

### Tile List

- **Search** — filter by name or category
- **Category dropdown** — narrow to one category
- **Pack dots** — coloured dot per pack the tile belongs to

### Editing a Tile

1. Click any tile row to open its detail panel
2. Edit Name, Category, Default Rarity, or Description
3. Manage Pack Membership (see below)
4. Click **Save Changes**

### Pack Membership

The detail panel shows one row per pack. Each row shows:
- **Included (green "✓")**: tile is in this pack. Clicking the toggle marks it as "will remove on save".
- **Not included (open "○")**: clicking reveals an inline rarity chip picker. Select a rarity to stage an add.

All pack changes are pending until **Save Changes** is clicked.

### Adding a Tile

1. Click **+ Add** in the toolbar
2. Fill in Name and Category — the Description field auto-fills with the tile name + category hint
3. Edit the description freely (this is what's used for image generation)
4. Optionally generate an image (see Image Generation below)
5. Set Pack Membership if desired
6. Click **Create Tile**

### Deleting a Tile

Click **🗑 Delete Tile**, then click **🗑 Confirm Delete** within 3 seconds. Removes the tile from `squares.json`, deletes its image, and removes it from all packs.

---

## Image Generation

1. Click **❆ Generate Image** (or **❆ Generate Again** if an image already exists)
2. Gemini generates an image from the tile's description + style constant (~15 seconds)
3. Preview appears — click **✓ Use This Image** to save, or **✕ Discard** to try again
4. For existing tiles: image is saved to disk immediately on approval
5. For new tiles: image is held until **Create Tile**

Click the current image to open it in a lightbox (full-size view).

### Prompt Construction

```
{description}. Flat vector illustration, clean thin outlines…
```

The description field is used verbatim as the prompt subject. The style instructions are always appended invisibly — they are not shown in the UI. The category hint is pre-filled into the description when creating a new tile; after that it is just part of the description and can be edited freely.

---

## Pack View Tab

Left panel: pack gallery. Right panel: tile grid for the selected pack.

- Click a pack card to load its tile grid
- **Grid view**: tile images with rarity dot overlay
- **Rarity Breakdown** bar shows proportions below the grid
- Click any tile in the grid to jump to that tile in the All Tiles tab

### Adding a Tile to a Pack

1. Click **+ Add Tile** in the pack toolbar
2. Search and select a tile from the available pool (tiles NOT already in this pack)
3. Choose a pack-specific rarity
4. Click **Add to Pack** — saved immediately

---

## Running Tests

```bash
python3 -m pytest tools/test_tile_manager.py -v
```

---

## API Reference

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/tiles` | All tiles from squares.json |
| `POST` | `/api/tiles` | Create tile; body: `{text, category, rarity, description?, image_b64?, packMembership?}` |
| `PUT` | `/api/tiles/{id}` | Update tile; body: `{text, category, rarity, description?, packMembership?}` |
| `DELETE` | `/api/tiles/{id}` | Delete tile and remove from all packs |
| `GET` | `/api/image/{id}` | Serve tile PNG |
| `POST` | `/api/tiles/{id}/image` | Save approved image: `{image_b64}` |
| `GET` | `/api/packs` | Pack summary list `[{id, name, tileCount}]` |
| `GET` | `/api/packs/{id}` | Full pack JSON |
| `PUT` | `/api/packs/{id}` | Replace full pack JSON |
| `GET` | `/api/packs/{id}/tiles-not-in-pack` | Tiles not yet in this pack |
| `POST` | `/api/generate` | Generate image: `{tile_id}` or `{description, name}`; returns `{image_b64}` |
| `GET` | `/api/description-prefill?name=X&category=Y` | Pre-fill text for new tile description |
