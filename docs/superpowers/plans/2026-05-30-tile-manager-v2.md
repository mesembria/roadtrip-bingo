# Tile Manager v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the tile manager tool with a two-tab SPA: "All Tiles" (master list + per-tile detail panel with pack membership toggles) and "Pack View" (pack gallery + tile grid). All tiles live in `squares.json`; packs are explicit `{id, rarity}` ref lists.

**Architecture:** Single Python file (`tools/tile_manager.py`), `http.server`-based, embedded SPA (HTML/CSS/JS inline). Python backend is updated first (testable via pytest), then the `HTML_APP` string is fully replaced with the new SPA. Run Data Migration plan (Plan 1) before this plan — the new tool expects the new pack format.

**Tech Stack:** Python 3 + pytest for backend; vanilla HTML/CSS/JS (no frameworks) for SPA.

**Prerequisite:** `tools/migrate_packs.py` has been run and all pack JSON files are in new format.

---

## File Map

| Status | Path | Change |
|--------|------|--------|
| Modify | `tools/tile_manager.py` | Update Python functions; replace HTML_APP entirely |
| Modify | `tools/test_tile_manager.py` | Update tests for changed build_prompt, discover_packs |
| Modify | `tools/tile_manager.md` | Rewrite documentation for new UI |

---

## Task 1: Python backend — update functions and HTTP handler

Update `build_prompt` (no category hints at generation), `discover_packs` (no overrideCount/excludedCount), `_handle_put_pack` (no old field validation), `_handle_generate` (accepts tile_id or description), `_handle_delete_tile` (removes from all packs), and remove obsolete pack-exclusive endpoints.

**Files:**
- Modify: `tools/tile_manager.py`
- Modify: `tools/test_tile_manager.py`

- [ ] **Step 1: Write the failing/updated tests for changed functions**

In `tools/test_tile_manager.py`, replace all content with:

```python
"""Tests for tile_manager Python functions."""
import base64, json, sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent))
import tile_manager as tm


# ── build_prompt ──────────────────────────────────────────────────────────────
# New behaviour: description + STYLE only. No category hints at generation time.

def test_build_prompt_uses_description():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red Kenworth semi truck cab, side view"}
    result = tm.build_prompt(tile)
    assert result.startswith("A red Kenworth semi truck cab, side view.")
    assert "Flat vector illustration" in result


def test_build_prompt_no_category_hint_in_result():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red Kenworth semi truck cab"}
    result = tm.build_prompt(tile)
    # Category hints (e.g., "Side view, full vehicle visible.") must NOT appear
    assert "Side view, full vehicle visible." not in result


def test_build_prompt_falls_back_to_text_when_no_description():
    tile = {"text": "Semi Truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")
    assert "Flat vector illustration" in result
    assert "Side view, full vehicle visible." not in result


def test_build_prompt_falls_back_to_text_when_description_is_empty():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": ""}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")


def test_build_prompt_strips_trailing_period_from_description():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": "A red truck."}
    result = tm.build_prompt(tile)
    assert "A red truck.." not in result


def test_build_prompt_capitalises_first_letter():
    tile = {"text": "semi truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi truck.")


def test_build_prompt_all_periods_falls_back_to_text():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": "..."}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")


# ── File I/O ──────────────────────────────────────────────────────────────────

def test_load_tiles(tmp_path):
    data = [{"id": "AAA", "text": "Cow", "emoji": "🐄",
             "category": "nature", "rarity": "veryCommon"}]
    squares = tmp_path / "squares.json"
    squares.write_text(json.dumps(data))
    with patch.object(tm, "SQUARES_JSON", squares):
        result = tm.load_tiles()
    assert len(result) == 1
    assert result[0]["text"] == "Cow"


def test_save_tiles_round_trips(tmp_path):
    squares = tmp_path / "squares.json"
    data = [{"id": "BBB", "text": "Horse", "emoji": "🐎",
             "category": "nature", "rarity": "common"}]
    with patch.object(tm, "SQUARES_JSON", squares):
        tm.save_tiles(data)
        loaded = tm.load_tiles()
    assert loaded[0]["id"] == "BBB"
    assert loaded[0]["rarity"] == "common"


def test_save_tiles_preserves_insertion_order(tmp_path):
    squares = tmp_path / "squares.json"
    data = [
        {"id": "1", "text": "Zebra",  "emoji": "🦓", "category": "nature", "rarity": "rare"},
        {"id": "2", "text": "Antler", "emoji": "🦌", "category": "nature", "rarity": "common"},
    ]
    with patch.object(tm, "SQUARES_JSON", squares):
        tm.save_tiles(data)
        loaded = tm.load_tiles()
    assert loaded[0]["id"] == "1"
    assert loaded[1]["id"] == "2"


def test_image_path(tmp_path):
    with patch.object(tm, "TILE_IMAGES", tmp_path):
        p = tm.image_path("MY-UUID")
    assert p == tmp_path / "MY-UUID.png"


def test_save_image(tmp_path):
    png_b64 = (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
        "+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    )
    with patch.object(tm, "TILE_IMAGES", tmp_path):
        tm.save_image("TEST-ID", png_b64)
        saved = (tmp_path / "TEST-ID.png").read_bytes()
    assert saved == base64.b64decode(png_b64)


# ── Pack I/O ──────────────────────────────────────────────────────────────────

def test_discover_packs(tmp_path):
    pack_a = {
        "id": "alpha", "name": "Alpha", "description": "Desc A",
        "tiles": [{"id": "X", "rarity": "common"}, {"id": "Y", "rarity": "rare"}],
    }
    pack_b = {
        "id": "beta", "name": "Beta", "description": "Desc B",
        "tiles": [],
    }
    (tmp_path / "pack-alpha.json").write_text(json.dumps(pack_a))
    (tmp_path / "pack-beta.json").write_text(json.dumps(pack_b))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 2
    assert result[0]["id"] == "alpha"
    assert result[0]["tileCount"] == 2
    assert "overrideCount" not in result[0]
    assert "excludedCount" not in result[0]
    assert result[1]["id"] == "beta"
    assert result[1]["tileCount"] == 0


def test_discover_packs_ignores_non_pack_json(tmp_path):
    (tmp_path / "squares.json").write_text("[]")
    (tmp_path / "pack-one.json").write_text(json.dumps(
        {"id": "one", "name": "One", "tiles": []}
    ))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 1
    assert result[0]["id"] == "one"


def test_load_pack(tmp_path):
    data = {"id": "farm-country", "name": "Farm Country",
            "tiles": [{"id": "UUID-1", "rarity": "common"}]}
    (tmp_path / "pack-farm-country.json").write_text(json.dumps(data))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.load_pack("farm-country")
    assert result["name"] == "Farm Country"
    assert result["tiles"][0]["id"] == "UUID-1"


def test_load_pack_missing_raises(tmp_path):
    with patch.object(tm, "PACKS_DIR", tmp_path):
        with pytest.raises(FileNotFoundError):
            tm.load_pack("nonexistent")


def test_save_pack_round_trips(tmp_path):
    initial = {"id": "test", "name": "Test", "tiles": []}
    (tmp_path / "pack-test.json").write_text(json.dumps(initial))
    updated = {"id": "test", "name": "Test",
               "tiles": [{"id": "UUID-1", "rarity": "veryCommon"}]}
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("test", updated)
        result = tm.load_pack("test")
    assert result["tiles"][0]["id"] == "UUID-1"
    assert result["tiles"][0]["rarity"] == "veryCommon"


def test_save_pack_writes_trailing_newline(tmp_path):
    data = {"id": "x", "name": "X", "tiles": []}
    (tmp_path / "pack-x.json").write_text("{}")
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("x", data)
        raw = (tmp_path / "pack-x.json").read_text()
    assert raw.endswith("\n")


# ── description_prefill ───────────────────────────────────────────────────────

def test_description_prefill_known_category():
    result = tm.description_prefill("Suspension Bridge", "landmarks")
    assert result.startswith("Suspension Bridge.")
    assert "Full structure visible." in result


def test_description_prefill_unknown_category():
    result = tm.description_prefill("Mystery Object", "unknown")
    assert result == "Mystery Object."


# ── generate_image ─────────────────────────────────────────────────────────────

def test_generate_image_extracts_base64():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "candidates": [{"content": {"parts": [{"inlineData": {"data": "abc123base64=="}}]}}]
    }
    mock_resp.raise_for_status = MagicMock()
    with patch("tile_manager.requests.post", return_value=mock_resp):
        result = tm.generate_image("A cow.", "fake-key")
    assert result == "abc123base64=="


def test_generate_image_raises_when_no_image_part():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "candidates": [{"content": {"parts": [{"text": "no image here"}]}}]
    }
    mock_resp.raise_for_status = MagicMock()
    with patch("tile_manager.requests.post", return_value=mock_resp):
        with pytest.raises(ValueError, match="No image"):
            tm.generate_image("A cow.", "fake-key")


def test_generate_image_passes_api_key_in_url():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "candidates": [{"content": {"parts": [{"inlineData": {"data": "x"}}]}}]
    }
    mock_resp.raise_for_status = MagicMock()
    with patch("tile_manager.requests.post", return_value=mock_resp) as mock_post:
        tm.generate_image("prompt", "my-secret-key")
    called_url = mock_post.call_args.args[0]
    assert "my-secret-key" in called_url
```

- [ ] **Step 2: Run tests to identify what needs changing**

```bash
python3 -m pytest tools/test_tile_manager.py -v 2>&1 | grep -E "PASSED|FAILED|ERROR"
```

Expected failures:
- `test_build_prompt_no_category_hint_in_result` — old `build_prompt` includes hint
- `test_build_prompt_falls_back_to_text_when_no_description` — still includes hint
- `test_discover_packs` — old version returns `overrideCount`/`excludedCount`
- `test_save_pack_round_trips` — may pass (save_pack is format-agnostic)
- `test_description_prefill_*` — function doesn't exist yet

- [ ] **Step 3: Update Python functions in tile_manager.py**

Replace `build_prompt` (keep function name, change body):

```python
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
```

Add `description_prefill` after `build_prompt`:

```python
def description_prefill(name: str, category: str) -> str:
    """Pre-fill text for the description field on a new tile.

    Combines the tile name with a category-specific layout hint.
    Used only by the UI — NOT used at image generation time.
    """
    hint = CATEGORY_HINTS.get(category, "")
    if hint:
        return f"{name}. {hint}"
    return f"{name}."
```

Replace `discover_packs`:

```python
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
python3 -m pytest tools/test_tile_manager.py -v 2>&1 | tail -30
```

Expected: PASS — all tests green.

- [ ] **Step 5: Update HTTP handler in tile_manager.py**

Replace the `do_POST` method:

```python
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
```

Replace `_handle_generate`:

```python
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
    elif "description" in body:
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
```

Replace `_handle_add_tile` (now accepts optional `packMembership`):

```python
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
```

Replace `_handle_update_tile` (now accepts optional `packMembership` changes):

```python
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
```

Replace `_handle_delete_tile` (now also removes from all packs):

```python
def _handle_delete_tile(self, tile_id: str):
    tiles = load_tiles()
    new_tiles = [t for t in tiles if t["id"] != tile_id]
    if len(new_tiles) == len(tiles):
        self.send_error_json(404, f"Tile {tile_id} not found")
        return
    save_tiles(new_tiles)
    # Remove from all packs that reference this tile
    for path in sorted(PACKS_DIR.glob("pack-*.json")):
        try:
            with open(path, encoding="utf-8") as f:
                pack = json.load(f)
            original_count = len(pack.get("tiles", []))
            pack["tiles"] = [r for r in pack.get("tiles", []) if r["id"] != tile_id]
            if len(pack["tiles"]) < original_count:
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(pack, f, indent=2, sort_keys=False, ensure_ascii=False)
                    f.write("\n")
        except Exception:
            pass
    img = image_path(tile_id)
    if img.exists():
        img.unlink()
    self.send_json({"deleted": tile_id})
```

Replace `_handle_put_pack` (remove old field validation):

```python
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
```

Replace the entire `do_GET` method with the version below. **Routing order matters** — the specific `/tiles-not-in-pack` and `/description-prefill` routes must come before the generic `/api/packs/` catch-all:

```python
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
        from urllib.parse import parse_qs, urlparse
        qs = parse_qs(urlparse(self.path).query)
        name     = qs.get("name",     [""])[0]
        category = qs.get("category", [""])[0]
        self.send_json({"prefill": description_prefill(name, category)})
    else:
        self.send_error_json(404, "Not found")
```

Delete `_handle_add_pack_tile` and `_handle_save_pack_tile_image` methods entirely (exclusive pack tiles no longer exist — tiles are always created via `POST /api/tiles`).

Add the `_handle_tiles_not_in_pack` method:

```python
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
```

Also update `_serve_ui` to inject `CATEGORY_HINTS` for client-side prefill:

```python
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
```

- [ ] **Step 6: Verify all Python tests still pass**

```bash
python3 -m pytest tools/test_tile_manager.py -v 2>&1 | tail -20
```

Expected: PASS — all tests green.

- [ ] **Step 7: Commit**

```bash
git add tools/tile_manager.py tools/test_tile_manager.py
git commit -m "feat: tile-manager v2 Python backend — new endpoints, no category hints at gen time"
```

---

## Task 2: Replace HTML_APP — complete SPA rewrite

Replace the `HTML_APP` string (everything between the `"""<!DOCTYPE html>` and the closing `"""` before the HTTP Server section) with the new SPA.

**Files:**
- Modify: `tools/tile_manager.py` (HTML_APP string only)

- [ ] **Step 1: Replace HTML_APP with the complete new SPA**

Find the line `HTML_APP = """<!DOCTYPE html>` in `tile_manager.py` and replace from there through the closing `"""` (line ~1666) with the following complete HTML:

```python
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
.picker-panel { width: 420px; height: 100%; background: var(--surface); border-left: 1px solid var(--border); display: flex; flex-direction: column; overflow: hidden; }
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
    <div class="topbar-logo">Road Trip Bingo <span>⬡ Tile Manager</span></div>
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
          <input id="tile-search" class="search-input" placeholder="Search tiles…" type="search">
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
            <button class="btn btn-red" id="delete-tile-btn" style="display:none">🗑 Delete Tile</button>
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
          <button class="gen-btn" id="lightbox-gen-btn">❆ Generate Again</button>
          <button class="btn" id="lightbox-close-btn">✕ Close</button>
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

  body.innerHTML = `
    <div class="image-section">
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
    boxInner = `<div class="image-spinner"><div class="spinner-ring"></div><span>Generating… ~15s</span></div>`;
  } else if (S.imgState === 'pending' && S.pendingB64) {
    boxInner = `<img src="data:image/png;base64,${S.pendingB64}" alt="Generated" style="width:100%;height:100%;object-fit:cover;display:block">
      <div class="image-box-footer">
        <div class="approve-row">
          <button class="approve-btn" id="approve-btn">✓ Use This Image</button>
          <button class="discard-btn" id="discard-btn">✕ Discard</button>
        </div>
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
        <option value="">— select —</option>${catOptions}
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

    // Inline rarity picker (shown when clicking ○ to add)
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
        // Undo the pending remove → back to included
        delete S.edit.packChanges[packId];
      } else if (isAdd) {
        // Cancel the pending add
        delete S.edit.packChanges[packId];
      } else if (isCurrentlyIn) {
        // Currently included → mark as will-remove
        S.edit.packChanges[packId] = { action: 'remove' };
      } else {
        // Not included → show inline rarity picker
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
    // Keep pendingB64 — it'll be sent with the tile data
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
  if (!pd || !packMeta) { col.innerHTML = '<div class="detail-empty">Loading…</div>'; return; }

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
      <input class="search-input" id="pack-search" placeholder="Search tiles…" style="max-width:200px" value="${esc(S.packSearch)}">
      <div style="flex:1"></div>
      <button class="btn btn-amber" id="pack-add-tile-btn">+ Add Tile</button>
    </div>
    <div class="pack-detail-body">
      <div class="pack-grid" id="pack-grid">${gridHtml}</div>
      <div class="rarity-bar-section">
        <div class="rarity-bar-label">Rarity Breakdown — ${total} tiles</div>
        <div class="rarity-bar">${barSegs}</div>
        <div class="rarity-legend">${legendItems}</div>
      </div>
    </div>`;

  document.getElementById('pack-search').addEventListener('input', e => {
    S.packSearch = e.target.value;
    renderPackDetail();
  });
  document.getElementById('pack-add-tile-btn').addEventListener('click', openAddTilePicker);

  // Grid cell click → switch to All Tiles tab with tile selected
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
        <button class="btn" id="picker-close-btn">✕</button>
      </div>
      <div class="picker-search">
        <input class="search-input" id="picker-search" placeholder="Search…" value="${esc(S.pickerSearch)}" style="width:100%">
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
```

- [ ] **Step 2: Start the server and verify the tool loads**

```bash
python3 tools/tile_manager.py
```

Expected: server starts, browser opens at `localhost:8765`, tool loads with "All Tiles" tab active showing the tile list.

- [ ] **Step 3: Smoke test All Tiles tab**

Manually verify in browser:
1. Tile list shows tiles with thumbnails, rarity badges, pack dots
2. Search input filters tiles
3. Category dropdown filters tiles
4. Clicking a tile loads the detail panel (right side)
5. Detail panel shows: image (or placeholder), name/category/rarity/description fields, pack membership rows
6. Pack membership rows show which packs the tile belongs to (green "Included" status + filled toggle)
7. Clicking a non-included pack shows inline rarity chip picker
8. Selecting a rarity chip from picker marks pack as pending-add (changes toggle to filled amber)
9. Clicking an included pack's toggle marks it as "Will remove on save" (dims the row)
10. "Save Changes" button saves and updates the list

- [ ] **Step 4: Smoke test image generation**

1. Select a tile with a description
2. Click "❆ Generate Again" — spinner appears
3. After ~15s, generated image appears with green border
4. Click "✓ Use This Image" — image saved, normal state returns
5. Click the image — lightbox opens showing full-size image
6. Close lightbox via ✕ or click outside

- [ ] **Step 5: Smoke test Add Tile flow**

1. Click "+ Add" in toolbar — detail panel opens in new-tile mode (amber "✦ New Tile" header)
2. Fill in Name and Category — description textarea auto-fills with name + category hint
3. Edit description freely
4. Click "❆ Generate Image" — generates with description + STYLE (no category hint appended separately)
5. Approve image
6. Toggle pack membership for at least one pack
7. Click "Create Tile" — tile appears in list

- [ ] **Step 6: Smoke test Pack View tab**

1. Click "Pack View" tab — pack gallery on left, pack detail on right
2. Click a pack — tile grid loads
3. Rarity breakdown bar shows proportions
4. Click a tile in pack grid — switches to All Tiles tab with that tile selected
5. "+ Add Tile" button — picker overlay slides in from right
6. Search in picker works
7. Click a tile in picker — rarity chip picker appears
8. Select rarity + "Add to Pack" — tile added, grid updates

- [ ] **Step 7: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: tile manager v2 — two-tab SPA, pack membership toggles, new generate flow"
```

---

## Task 3: Update tile_manager.md

**Files:**
- Modify: `tools/tile_manager.md`

- [ ] **Step 1: Replace tile_manager.md with updated documentation**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add tools/tile_manager.md
git commit -m "docs: tile-manager v2 documentation"
```
