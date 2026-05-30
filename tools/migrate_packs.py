"""
migrate_packs.py

Converts all pack-*.json files from old format to new format.

Old format:
  {
    "tiles": [{"id": "UUID", "text": "Name", "emoji": "...", "category": "...", "rarity": "..."}],
    "rarityOverrides": {"UUID": "rarity"},
    "excludedTileIDs": ["UUID"]
  }

New format:
  {
    "tiles": [{"id": "UUID", "rarity": "rarity"}]
  }

Seeding strategy:
  - Exclusive tiles (old tiles with 'text' key): promote full metadata to squares.json,
    add {id, rarity} ref to pack
  - Rarity-overridden tiles (rarityOverrides): add {id, rarity} ref (only if tile exists
    in base or promoted set)
  - Excluded tiles: silently dropped
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
SQUARES_JSON = REPO_ROOT / "RoadTripBingo/Resources/squares.json"
PACKS_DIR = REPO_ROOT / "RoadTripBingo/Resources"


def load_squares() -> list[dict]:
    """Load all tiles from squares.json."""
    with open(SQUARES_JSON, "r", encoding="utf-8") as f:
        return json.load(f)


def save_squares(squares: list[dict], dry_run: bool = False) -> None:
    """Write tiles to squares.json with 2-space indent, sorted keys, trailing newline."""
    if dry_run:
        print(f"[dry-run] Would write {len(squares)} squares to {SQUARES_JSON}")
        return
    with open(SQUARES_JSON, "w", encoding="utf-8") as f:
        json.dump(squares, f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")


def is_old_format(pack_data: dict) -> bool:
    """True if pack has rarityOverrides key, excludedTileIDs key, or any tile with 'text'."""
    if "rarityOverrides" in pack_data:
        return True
    if "excludedTileIDs" in pack_data:
        return True
    for tile in pack_data.get("tiles", []):
        if "text" in tile:
            return True
    return False


def migrate_pack(pack_data: dict, base_ids: set[str]) -> tuple[dict, list[dict]]:
    """Convert one pack. Returns (new_pack, promoted_tiles).

    - If is_old_format returns False, return (pack_data, []) unchanged.
    - Exclusive tiles (tiles with 'text'): if not in base_ids, add to promoted_tiles.
      Always add {id, rarity} ref.
    - Rarity overrides: add {id, rarity} ref ONLY if the tile's id is in base_ids
      OR in the set of IDs just promoted from this pack.
    - Excluded tiles: silently ignored.
    - New pack has only keys: id, name, description, imageName, tiles.
    """
    if not is_old_format(pack_data):
        return (pack_data, [])

    promoted_tiles: list[dict] = []
    promoted_ids: set[str] = set()
    new_tile_refs: list[dict] = []

    # Process exclusive tiles (tiles with 'text' key)
    for tile in pack_data.get("tiles", []):
        tile_id = tile["id"]
        rarity = tile.get("rarity", "common")
        # Promote to squares.json if not already in base
        if tile_id not in base_ids:
            promoted_tiles.append(tile)
            promoted_ids.add(tile_id)
        # Always add as ref in the pack
        new_tile_refs.append({"id": tile_id, "rarity": rarity})

    # Process rarity overrides — only include if tile is in base or just promoted
    known_ids = base_ids | promoted_ids
    for tile_id, rarity in pack_data.get("rarityOverrides", {}).items():
        if tile_id in known_ids:
            new_tile_refs.append({"id": tile_id, "rarity": rarity})

    # Build new pack with only the allowed keys
    new_pack: dict = {}
    for key in ("id", "name", "description", "imageName"):
        if key in pack_data:
            new_pack[key] = pack_data[key]
    new_pack["tiles"] = new_tile_refs

    return (new_pack, promoted_tiles)


def _save_pack(pack_data: dict, path: Path, dry_run: bool = False) -> None:
    """Write pack to file with 2-space indent, sort_keys=False, trailing newline."""
    if dry_run:
        print(f"[dry-run] Would write pack '{pack_data.get('id', '?')}' to {path}")
        return
    with open(path, "w", encoding="utf-8") as f:
        json.dump(pack_data, f, indent=2, sort_keys=False, ensure_ascii=False)
        f.write("\n")


def run_migration(dry_run: bool = False) -> None:
    """Run migration on all pack-*.json files in PACKS_DIR.

    - Load squares.json to get base_ids.
    - For each pack (sorted by filename):
        - If not old format: print skip message, continue.
        - Otherwise: migrate, update base_ids with newly promoted IDs.
    - After all packs: if any tiles were promoted, extend squares list and save_squares.
    - Print per-pack summary and final squares.json summary.
    """
    squares = load_squares()
    base_ids: set[str] = {s["id"] for s in squares}

    all_promoted: list[dict] = []
    pack_files = sorted(PACKS_DIR.glob("pack-*.json"))

    for pack_path in pack_files:
        with open(pack_path, "r", encoding="utf-8") as f:
            pack_data = json.load(f)

        if not is_old_format(pack_data):
            print(f"[skip] {pack_path.name} — already in new format")
            continue

        new_pack, promoted = migrate_pack(pack_data, base_ids)

        # Update base_ids so subsequent packs see promoted tiles
        for tile in promoted:
            base_ids.add(tile["id"])
        all_promoted.extend(promoted)

        _save_pack(new_pack, pack_path, dry_run=dry_run)

        ref_count = len(new_pack.get("tiles", []))
        promo_count = len(promoted)
        print(
            f"[migrated] {pack_path.name} — {ref_count} tile refs, "
            f"{promo_count} promoted to squares.json"
        )

    if all_promoted:
        squares.extend(all_promoted)
        save_squares(squares, dry_run=dry_run)
        print(
            f"\n[squares.json] Added {len(all_promoted)} promoted tiles — "
            f"total now {len(squares)}"
        )
    else:
        print("\n[squares.json] No changes needed")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Migrate pack-*.json files from old format to new ref format."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would happen without writing files.",
    )
    args = parser.parse_args()
    run_migration(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
