# Tile Image Description Field

**Date:** 2026-05-30
**Status:** Approved

## Summary

Add an optional `description` field to each tile in the JSON data files. The description is the subject phrase used when generating tile images via `tile_manager.py`. It is purely a tooling concern — the iOS app never reads or uses it.

## Motivation

The current system stores per-tile prompt customizations in a `OVERRIDES` dict hardcoded in `tile_manager.py`. This is fragile: overrides are disconnected from the tile data, easy to lose, and not visible when editing tiles. Moving descriptions into the JSON keeps all tile information in one place.

## Data Schema

### squares.json and pack-*.json

Add an optional `"description"` key to any tile object:

```json
{
  "id": "95F10877-1BC5-4F38-A6B1-5C8469946794",
  "text": "Semi Truck",
  "emoji": "🚛",
  "category": "vehicles",
  "rarity": "veryCommon",
  "description": "A red Kenworth semi truck cab, side view, no trailer"
}
```

- **Present:** tile_manager uses the description value as the subject phrase when building the image generation prompt.
- **Absent:** tile_manager falls back to the tile's `text` field (the tile name).

The full image prompt is still assembled by tile_manager: `{description_or_name}. {category_hint} {STYLE}`. The `description` field never contains the STYLE string — that remains a separate constant in tile_manager.

### BingoSquare.swift

No changes required. Swift's `Codable` silently ignores unknown JSON keys during decoding. The app never writes these files back, so round-trip fidelity is not a concern.

## tile_manager.py Changes

### build_prompt()

The signature changes from `(text: str, category: str)` to `(tile: dict)`:

```python
def build_prompt(tile: dict) -> str:
    """Build the Gemini image generation prompt for a tile."""
    description = tile.get("description") or tile["text"]
    category = tile.get("category", "")
    hint = CATEGORY_HINTS.get(category, "")
    desc_clean = description.rstrip(".")
    desc_cap = desc_clean[0].upper() + desc_clean[1:]
    parts = [f"{desc_cap}.", hint, STYLE]
    return " ".join(p for p in parts if p).strip()
```

All call sites updated to pass the full tile dict.

### OVERRIDES removal

The `OVERRIDES: dict[str, str]` constant is removed. Any existing entries are migrated to `"description"` fields on the corresponding tiles in the JSON files before removal.

### CATEGORY_HINTS and STYLE

Unchanged. These remain as module-level constants and continue to be appended by `build_prompt()`.

## Tile Manager UI

The browser-based tile edit form gains a `description` textarea:

- Positioned between the tile name field and the category/rarity dropdowns
- Placeholder text shows the tile name (making the default behaviour obvious)
- Not required — leaving it blank is valid and means "use the tile name"
- Saved to JSON alongside other tile properties on form submit
- The tile list view does not display descriptions (they are generation-time detail, not game content)

## Behaviour Summary

| Scenario | Prompt subject used |
|---|---|
| `description` present | Value of `description` |
| `description` absent | Value of `text` (tile name) |

The constructed prompt format is unchanged: `{subject}. {category_hint} {STYLE}`
