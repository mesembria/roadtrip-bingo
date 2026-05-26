# Tile Manager — Pack-Aware Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `tools/tile_manager.py` so every pack has its own tab showing a unified "pack diff" view — exclusive tiles, rarity overrides, and exclusions — with editors for each modification type and four addition flows.

**Architecture:** Single-file Python SPA; backend gains pack I/O functions and five new API routes; the embedded HTML SPA gains a tab bar, per-pack screens, and all pack editing JS. Pack modifications are held in client memory until "Save Pack" sends a full-object `PUT`. Base tile operations remain per-operation as today.

**Tech Stack:** Python 3.11 stdlib (`http.server`, `pathlib`, `json`, `uuid`), `requests` (existing dep), vanilla HTML/CSS/JS embedded in the Python string, pytest for backend unit tests.

---

## File Map

| File | Change |
|------|--------|
| `tools/tile_manager.py` | Add `PACKS_DIR`, `PACKS_METADATA`, `discover_packs()`, `load_pack()`, `save_pack()`; five new HTTP handlers; extend `_serve_ui` injection; replace `<header>` with tab bar; add pack screens, CSS, and JS |
| `tools/test_tile_manager.py` | Add tests for `discover_packs()`, `load_pack()`, `save_pack()` |

---

## Task 1: Backend — pack I/O functions and API routes

**Files:**
- Modify: `tools/tile_manager.py`
- Modify: `tools/test_tile_manager.py`

- [ ] **Step 1: Write failing tests**

Add to `tools/test_tile_manager.py` (after the existing imports — `import pytest` is already there):

```python
# ── Pack I/O tests ────────────────────────────────────────────────────────────

def test_discover_packs(tmp_path):
    """discover_packs returns summary info sorted by filename."""
    pack_a = {
        "id": "alpha", "name": "Alpha", "description": "Desc A",
        "tiles": [{"id": "X", "text": "T", "emoji": "🎯", "category": "nature", "rarity": "common"}],
        "rarityOverrides": {},
        "excludedTileIDs": ["Y"],
    }
    pack_b = {
        "id": "beta", "name": "Beta", "description": "Desc B",
        "tiles": [],
        "rarityOverrides": {"UUID-1": "common", "UUID-2": "veryCommon"},
        "excludedTileIDs": [],
    }
    (tmp_path / "pack-alpha.json").write_text(json.dumps(pack_a))
    (tmp_path / "pack-beta.json").write_text(json.dumps(pack_b))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 2
    assert result[0]["id"] == "alpha"
    assert result[0]["tileCount"] == 1
    assert result[0]["overrideCount"] == 0
    assert result[0]["excludedCount"] == 1
    assert result[1]["id"] == "beta"
    assert result[1]["tileCount"] == 0
    assert result[1]["overrideCount"] == 2


def test_discover_packs_ignores_non_pack_json(tmp_path):
    (tmp_path / "squares.json").write_text("[]")
    (tmp_path / "pack-one.json").write_text(json.dumps(
        {"id": "one", "name": "One", "tiles": [], "rarityOverrides": {}, "excludedTileIDs": []}
    ))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.discover_packs()
    assert len(result) == 1
    assert result[0]["id"] == "one"


def test_load_pack(tmp_path):
    data = {"id": "farm-country", "name": "Farm Country", "tiles": [],
            "rarityOverrides": {}, "excludedTileIDs": []}
    (tmp_path / "pack-farm-country.json").write_text(json.dumps(data))
    with patch.object(tm, "PACKS_DIR", tmp_path):
        result = tm.load_pack("farm-country")
    assert result["name"] == "Farm Country"


def test_load_pack_missing_raises(tmp_path):
    with patch.object(tm, "PACKS_DIR", tmp_path):
        with pytest.raises(FileNotFoundError):
            tm.load_pack("nonexistent")


def test_save_pack_round_trips(tmp_path):
    initial = {"id": "test", "name": "Test", "tiles": [],
               "rarityOverrides": {}, "excludedTileIDs": []}
    (tmp_path / "pack-test.json").write_text(json.dumps(initial))
    updated = {"id": "test", "name": "Test", "tiles": [{"id": "T1", "text": "Cow",
               "emoji": "🐄", "category": "nature", "rarity": "veryCommon"}],
               "rarityOverrides": {"UUID-A": "common"}, "excludedTileIDs": ["UUID-B"]}
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("test", updated)
        result = tm.load_pack("test")
    assert result["tiles"][0]["id"] == "T1"
    assert result["rarityOverrides"]["UUID-A"] == "common"
    assert result["excludedTileIDs"] == ["UUID-B"]


def test_save_pack_writes_trailing_newline(tmp_path):
    data = {"id": "x", "name": "X", "tiles": [], "rarityOverrides": {}, "excludedTileIDs": []}
    (tmp_path / "pack-x.json").write_text("{}")
    with patch.object(tm, "PACKS_DIR", tmp_path):
        tm.save_pack("x", data)
        raw = (tmp_path / "pack-x.json").read_text()
    assert raw.endswith("\n")
```

- [ ] **Step 2: Run tests, confirm they fail**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
python3 -m pytest tools/test_tile_manager.py -v -k "pack" 2>&1 | tail -20
```

Expected: `AttributeError` or `ImportError` — `discover_packs`, `load_pack`, `save_pack` don't exist yet.

- [ ] **Step 3: Add `PACKS_DIR` constant and module-level `PACKS_METADATA`**

Find this block in `tools/tile_manager.py` (around line 20):

```python
TILE_IMAGES  = REPO_ROOT / "RoadTripBingo/Resources/TileImages"
```

Replace with:

```python
TILE_IMAGES  = REPO_ROOT / "RoadTripBingo/Resources/TileImages"
PACKS_DIR    = REPO_ROOT / "RoadTripBingo/Resources"
```

Then find:

```python
PORT = 8765
```

Replace with:

```python
PORT = 8765

# Populated at server startup; injected into the HTML SPA.
PACKS_METADATA: list[dict] = []
```

- [ ] **Step 4: Add `discover_packs()`, `load_pack()`, `save_pack()` after `save_image()`**

Find this line in `tile_manager.py`:

```python
# ── Gemini API ────────────────────────────────────────────────────────────────
```

Insert the three functions immediately before that line:

```python
# ── Pack I/O ──────────────────────────────────────────────────────────────────

def discover_packs() -> list[dict]:
    """Return summary info for every pack-*.json in PACKS_DIR, sorted by filename."""
    packs = []
    for path in sorted(PACKS_DIR.glob("pack-*.json")):
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


```

- [ ] **Step 5: Run tests, confirm they pass**

```bash
python3 -m pytest tools/test_tile_manager.py -v -k "pack" 2>&1 | tail -20
```

Expected: all 7 new pack tests PASS.

- [ ] **Step 6: Add routing for new pack endpoints**

In `do_GET`, find:

```python
        elif path.startswith("/api/image/"):
            self._serve_image(path[len("/api/image/"):])
        else:
            self.send_error_json(404, "Not found")
```

Replace with:

```python
        elif path.startswith("/api/image/"):
            self._serve_image(path[len("/api/image/"):])
        elif path == "/api/packs":
            self._handle_list_packs()
        elif path.startswith("/api/packs/"):
            pack_id = path[len("/api/packs/"):]
            self._handle_get_pack(pack_id)
        else:
            self.send_error_json(404, "Not found")
```

In `do_POST`, find:

```python
        elif path.startswith("/api/tiles/") and path.endswith("/image"):
            tile_id = path[len("/api/tiles/"):-len("/image")]
            self._handle_save_image(tile_id)
        else:
            self.send_error_json(404, "Not found")
```

Replace with:

```python
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
```

In `do_PUT`, find:

```python
        if path.startswith("/api/tiles/"):
            tile_id = path[len("/api/tiles/"):]
            self._handle_update_tile(tile_id)
        else:
            self.send_error_json(404, "Not found")
```

Replace with:

```python
        if path.startswith("/api/tiles/"):
            tile_id = path[len("/api/tiles/"):]
            self._handle_update_tile(tile_id)
        elif path.startswith("/api/packs/"):
            pack_id = path[len("/api/packs/"):]
            self._handle_put_pack(pack_id)
        else:
            self.send_error_json(404, "Not found")
```

- [ ] **Step 7: Add the five new handler methods**

Find `# ── Entry point` in `tile_manager.py` and insert immediately before it:

```python
    def _handle_list_packs(self):
        self.send_json(PACKS_METADATA)

    def _handle_get_pack(self, pack_id: str):
        try:
            self.send_json(load_pack(pack_id))
        except FileNotFoundError:
            self.send_error_json(404, f"Pack {pack_id!r} not found")

    def _handle_put_pack(self, pack_id: str):
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
        try:
            save_pack(pack_id, body)
        except FileNotFoundError:
            self.send_error_json(404, f"Pack {pack_id!r} not found")
            return
        self.send_json({"saved": pack_id})

    def _handle_add_pack_tile(self, pack_id: str):
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
        pack.setdefault("tiles", []).append(tile)
        save_pack(pack_id, pack)
        if "image_b64" in body:
            save_image(tile_id, body["image_b64"])
        self.send_json(tile, 201)

    def _handle_save_pack_tile_image(self, pack_id: str, tile_id: str):
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

```

- [ ] **Step 8: Populate `PACKS_METADATA` at startup and extend `_serve_ui` injection**

In `main()`, find:

```python
    TileManagerHandler.api_key = api_key
```

Replace with:

```python
    TileManagerHandler.api_key = api_key

    global PACKS_METADATA
    PACKS_METADATA = discover_packs()
    names = ", ".join(p["name"] for p in PACKS_METADATA)
    print(f"   Packs loaded: {names or '(none found)'}")
```

In `_serve_ui`, find:

```python
        html = HTML_APP.replace(
            "/* __INJECT__ */",
            f"const CATEGORIES = {json.dumps(CATEGORIES)};\n"
            f"    const RARITIES = {json.dumps(RARITIES)};",
        ).encode("utf-8")
```

Replace with:

```python
        html = HTML_APP.replace(
            "/* __INJECT__ */",
            f"const CATEGORIES = {json.dumps(CATEGORIES)};\n"
            f"    const RARITIES = {json.dumps(RARITIES)};\n"
            f"    const PACKS_META = {json.dumps(PACKS_METADATA)};",
        ).encode("utf-8")
```

- [ ] **Step 9: Manually verify API endpoints**

```bash
# Terminal 1 — start server
python3 tools/tile_manager.py

# Terminal 2 — verify endpoints
curl -s http://localhost:8765/api/packs | python3 -m json.tool
# Expected: JSON array of 6 pack objects, each with id, name, description, tileCount, overrideCount, excludedCount

curl -s http://localhost:8765/api/packs/farm-country | python3 -m json.tool
# Expected: full farm-country pack JSON with tiles array, rarityOverrides dict, excludedTileIDs array

curl -s http://localhost:8765/api/packs/no-such-pack
# Expected: {"error": "Pack 'no-such-pack' not found"}
```

- [ ] **Step 10: Run full test suite**

```bash
python3 -m pytest tools/test_tile_manager.py -v 2>&1 | tail -30
```

Expected: all tests PASS (existing + 7 new).

- [ ] **Step 11: Commit**

```bash
git add tools/tile_manager.py tools/test_tile_manager.py
git commit -m "feat: add pack I/O functions and API endpoints to tile manager"
```

---

## Task 2: HTML/CSS — tab bar and screen routing

**Files:**
- Modify: `tools/tile_manager.py` (HTML_APP string — CSS and HTML sections)

> All edits in this task are inside the `HTML_APP = """..."""` triple-quoted string. No Python escaping is needed since it uses triple quotes. JS string literals inside HTML use `"` and `'` normally. The only exception: JS inline onclick handlers that pass string literals must use `\\'` for single quotes within the onclick attribute value (the existing code does this pattern, e.g. `onclick="selectTile(\\'` + t.id + `\\')`).

- [ ] **Step 1: Add tab bar CSS**

Find this block in the `<style>` section of HTML_APP:

```css
html, body { height: 100%; overflow: hidden; background: var(--bg); color: var(--text); font-family: var(--font-ui); }
```

Replace with:

```css
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
```

- [ ] **Step 2: Add pack-specific CSS**

Find this in the `<style>` section:

```css
* { scrollbar-width: thin; scrollbar-color: var(--border2) transparent; }
```

Insert immediately before it:

```css
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
```

- [ ] **Step 3: Replace the `<header>` element with the tab bar**

Find this in the `<body>` section of HTML_APP:

```html
<div class="app">
  <header class="header">
    <div class="header-logo">Road Trip Bingo <span>/ Tile Manager</span></div>
    <div class="header-stats">
      <div class="stat"><span class="stat-val" id="stat-tiles">—</span><span class="stat-lbl">Tiles</span></div>
      <div class="stat"><span class="stat-val" id="stat-cats">—</span><span class="stat-lbl">Categories</span></div>
    </div>
  </header>
  <div class="body">
```

Replace with:

```html
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
```

- [ ] **Step 4: Close the new wrapper divs**

Find the closing tags of the existing body/app:

```html
  </div>
</div>
<script>
```

Replace with:

```html
  </div><!-- .body -->
  </div><!-- #screen-base -->
  <!-- Pack screens injected by JS on init -->
  </div><!-- .screens -->
</div><!-- .app -->
<script>
```

- [ ] **Step 5: Also remove the now-unused `.header`, `.body`, `.header-logo`, `.header-stats`, `.stat` CSS**

Find in `<style>`:

```css
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
```

Replace with:

```css
.app { display: flex; flex-direction: column; height: 100vh; }
.body { flex: 1; display: flex; overflow: hidden; }
```

- [ ] **Step 6: Add tab switching and pack screen init JS**

Find `/* __INJECT__ */` in the `<script>` section. It is immediately followed by the injected constants. After all the existing JS state variables (after `let sortAsc = true;`), add:

```javascript
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
  if (tabId !== 'base' && isDirty) {
    if (!confirm('You have unsaved pack changes. Leave anyway?')) return;
  }
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
    isDirty = false;
  } else {
    currentPackId = tabId;
    loadPackScreen(tabId);
  }
}
```

- [ ] **Step 7: Build pack tabs in `init()`**

Find the existing `init()` function:

```javascript
async function init() {
  populateCategoryDropdowns();
  populateRarityDropdowns();
  const tilesData = await fetch('/api/tiles').then(r => r.json());
  tiles = tilesData;
  renderTable();
  updateStats();
}
```

Replace with:

```javascript
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
        '<div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;color:var(--text3);padding:20px">' +
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
```

- [ ] **Step 8: Start server and verify tabs render**

```bash
python3 tools/tile_manager.py
# Open http://localhost:8765
# Expected: topbar with "Base Tiles" tab + 6 pack tabs
# Clicking Base Tiles tab shows the tile list (existing behavior)
# Clicking a pack tab shows an empty pack screen
```

- [ ] **Step 9: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: add tab bar and pack screen scaffolding to tile manager"
```

---

## Task 3: JS — pack screen data and diff list rendering

**Files:**
- Modify: `tools/tile_manager.py` (JS section of HTML_APP)

- [ ] **Step 1: Add `loadPackScreen()` and `renderPackDiffList()`**

Find the `function buildPackTabs()` section and insert after `buildPackTabs` and `toggleAddMenu`:

```javascript
// ── Pack screen data ──────────────────────────────────────────────────────────
async function loadPackScreen(packId) {
  isDirty = false;
  selectedMod = null;
  packFilterType = '';
  packSearchQuery = '';
  packData = await fetch('/api/packs/' + packId).then(r => r.json());
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
const RARITY_ORDER = { veryCommon: 0, common: 1, uncommon: 2, rare: 3, veryRare: 4 };
const RARITY_CLS   = { veryCommon: 'vc', common: 'c', uncommon: 'u', rare: 'r', veryRare: 'vr' };

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
  if (!listEl) return;
  const filtered = getFilteredMods();
  const all = getPackMods();

  countEl.textContent = all.length + ' modification' + (all.length !== 1 ? 's' : '');

  listEl.innerHTML = filtered.map(m => {
    const isSelected = selectedMod && selectedMod.type === m.type && selectedMod.id === m.id;
    const sel = isSelected ? ' selected' : '';

    if (m.type === 'exclusive') {
      const imgSrc = '/api/image/' + m.tile.id;
      const rarityBadge = '<span class="rarity ' + (RARITY_CLS[m.tile.rarity] || '') + '">' + esc(m.tile.rarity) + '</span>';
      return '<div class="diff-row exclusive' + sel + '" onclick="selectMod(\\'' + m.type + '\\',\\'' + m.id + '\\')">' +
        '<div class="diff-thumb"><img src="' + imgSrc + '" onerror="this.style.display=\\'none\\'"></div>' +
        '<div class="diff-name">' + esc(m.tile.text) + '</div>' +
        '<div><span class="diff-badge exclusive">EXCLUSIVE</span></div>' +
        '<div class="diff-detail">' + rarityBadge + '</div>' +
        '</div>';
    }

    if (m.type === 'override') {
      const name = m.baseTile ? esc(m.baseTile.text) : '<em style="color:var(--text3)">Unknown tile</em>';
      const fromR = m.baseTile ? m.baseTile.rarity : '?';
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
```

- [ ] **Step 2: Add `updatePackSummaryPanel()` and default right panel**

Add immediately after the block above:

```javascript
function updatePackSummaryPanel() {
  if (!packData || !currentPackId) return;
  const countsEl = document.getElementById('pack-counts-' + currentPackId);
  if (!countsEl) return;
  const exclusive = (packData.tiles || []).length;
  const overrides = Object.keys(packData.rarityOverrides || {}).length;
  const excluded  = (packData.excludedTileIDs || []).length;
  countsEl.innerHTML =
    '<strong style="color:var(--green)">' + exclusive + '</strong> exclusive tile' + (exclusive !== 1 ? 's' : '') + '<br>' +
    '<strong style="color:var(--amber)">' + overrides + '</strong> rarity override' + (overrides !== 1 ? 's' : '') + '<br>' +
    '<strong style="color:var(--red)">'   + excluded  + '</strong> exclusion'       + (excluded  !== 1 ? 's' : '');
}

function renderPackRightPanel() {
  if (!selectedMod || !packData || !currentPackId) return;
  const { type, id } = selectedMod;

  if (type === 'exclusive') {
    const tile = (packData.tiles || []).find(t => t.id === id);
    if (tile) showExclusiveEditor(tile);
    return;
  }
  if (type === 'override') {
    showOverrideEditor(id);
    return;
  }
  if (type === 'excluded') {
    showExcludedEditor(id);
    return;
  }
}
```

- [ ] **Step 3: Start server and verify diff list renders**

```bash
python3 tools/tile_manager.py
# Click the "Farm Country" tab
# Expected: diff list shows rows for Farm Country's exclusive tiles (EXCLUSIVE, green border),
#           rarity overrides (OVERRIDE, amber border), and exclusions (EXCLUDED, red, strikethrough)
# Search box and type filter should filter the list
```

- [ ] **Step 4: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: render pack diff list with filter and search"
```

---

## Task 4: JS — pack right panel (all three editors)

**Files:**
- Modify: `tools/tile_manager.py` (JS section of HTML_APP)

- [ ] **Step 1: Add exclusive tile editor**

Add after `renderPackRightPanel()`:

```javascript
// ── Right panel: exclusive tile editor ───────────────────────────────────────
function showExclusiveEditor(tile) {
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;
  const isNew = !tile.id;
  rightEl.innerHTML =
    '<div class="panel-header">' +
      '<div class="panel-title">' + esc(isNew ? 'New Exclusive Tile' : tile.text) + '</div>' +
      '<div class="panel-id">' + (isNew ? '(new)' : tile.id.substring(0, 8) + '…') + '</div>' +
    '</div>' +
    '<div class="panel-body" id="pack-panel-body">' +
      '<div>' +
        '<div class="section-label">Tile Image</div>' +
        '<div class="image-section">' +
          '<div class="image-current-wrap" id="pack-image-wrap">' +
            '<span class="img-placeholder" id="pack-img-placeholder" style="' + (isNew ? '' : 'display:none') + '">' + (tile.emoji || '🎯') + '</span>' +
            '<img id="pack-image-current" src="' + (isNew ? '' : '/api/image/' + tile.id + '?t=' + Date.now()) + '" ' +
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
              CATEGORIES.map(c => '<option value="' + c + '"' + (c === tile.category ? ' selected' : '') + '>' + c + '</option>').join('') +
            '</select></div>' +
            '<div class="field"><label class="field-label">Rarity</label><select class="field-input" id="pack-field-rarity" style="cursor:pointer">' +
              RARITIES.map(r => '<option value="' + r + '"' + (r === tile.rarity ? ' selected' : '') + '>' + r + '</option>').join('') +
            '</select></div>' +
          '</div>' +
        '</div>' +
      '</div>' +
    '</div>' +
    '<div class="panel-footer">' +
      (isNew ? '' : '<button class="btn-delete" onclick="removeExclusiveTile(\\'' + tile.id + '\\')">🗑 Remove from Pack</button>') +
      '<div class="footer-right">' +
        '<button class="btn-cancel" onclick="cancelPackEdit()">Cancel</button>' +
        '<button class="btn-save" onclick="saveExclusiveTile(' + (isNew ? 'null' : '\\'' + tile.id + '\\'') + ')">Save Changes</button>' +
      '</div>' +
    '</div>';

  // Store current tile for generation context
  window._packEditingTile = tile;
  window._packPendingImageB64 = null;
  window._packLastPrompt = null;
  window._packIsNewExclusive = isNew;
}

// ── Exclusive tile generation (mirrors base tile logic) ──────────────────────
function showPackPromptEditor() {
  const tile = window._packEditingTile || {};
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
    const r = await fetch('/api/generate', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({prompt}) });
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
  const b64 = window._packPendingImageB64;
  if (!b64) return;
  const tile = window._packEditingTile;
  if (!window._packIsNewExclusive && tile && tile.id) {
    const r = await fetch('/api/packs/' + currentPackId + '/tiles/' + tile.id + '/image', {
      method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({image_b64: b64})
    });
    if (!r.ok) { alert('Failed to save image'); return; }
    window._packPendingImageB64 = null;
  }
  const img = document.getElementById('pack-image-current');
  img.src = 'data:image/png;base64,' + b64;
  img.style.display = 'block';
  document.getElementById('pack-img-placeholder').style.display = 'none';
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
    // New exclusive tile
    const body = { text: name, emoji, category, rarity };
    if (window._packPendingImageB64) body.image_b64 = window._packPendingImageB64;
    const r = await fetch('/api/packs/' + currentPackId + '/tiles', {
      method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body)
    });
    if (!r.ok) { alert('Failed to save tile'); return; }
    const newTile = await r.json();
    packData.tiles = packData.tiles || [];
    packData.tiles.push(newTile);
    window._packPendingImageB64 = null;
    selectedMod = { type: 'exclusive', id: newTile.id };
  } else {
    // Update in-memory (pack is saved on "Save Pack")
    const tile = (packData.tiles || []).find(t => t.id === tileId);
    if (tile) { tile.text = name; tile.emoji = emoji; tile.category = category; tile.rarity = rarity; }
    markDirty();
  }
  updatePackSummaryPanel();
  renderPackDiffList();
}

function cancelPackEdit() {
  selectedMod = null;
  renderPackDiffList();
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (rightEl) rightEl.innerHTML = rightEl.innerHTML; // reset to default summary — see updatePackSummaryPanel
  updatePackSummaryPanel();
}

// ── Right panel: override editor ──────────────────────────────────────────────
function showOverrideEditor(uuid) {
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;
  const baseTile  = tiles.find(t => t.id === uuid);
  const newRarity = (packData.rarityOverrides || {})[uuid] || 'veryCommon';
  const fromRarity = baseTile ? baseTile.rarity : '?';
  const name = baseTile ? baseTile.text : 'Unknown tile (' + uuid.substring(0,8) + '…)';

  rightEl.innerHTML =
    '<div class="panel-header">' +
      '<div class="panel-title">' + esc(name) + '</div>' +
      '<div class="panel-id">Rarity Override</div>' +
    '</div>' +
    '<div class="panel-body">' +
      '<div>' +
        '<div class="section-label">Rarity Change</div>' +
        '<div class="rarity-from-to">' +
          '<div><div style="font-size:10px;color:var(--text3);margin-bottom:4px">BASE</div><span class="rarity ' + (RARITY_CLS[fromRarity]||'') + '">' + esc(fromRarity) + '</span></div>' +
          '<div class="arrow">→</div>' +
          '<div><div style="font-size:10px;color:var(--text3);margin-bottom:4px">IN THIS PACK</div>' +
            '<select class="field-input" id="override-rarity-sel" style="cursor:pointer">' +
              RARITIES.map(r => '<option value="' + r + '"' + (r === newRarity ? ' selected' : '') + '>' + r + '</option>').join('') +
            '</select>' +
          '</div>' +
        '</div>' +
      '</div>' +
      (baseTile ? '<div>' +
        '<div class="section-label">Base Tile Info</div>' +
        '<div class="override-base-info">' +
          '<div class="name">' + esc(baseTile.text) + ' ' + esc(baseTile.emoji || '') + '</div>' +
          '<div>' + esc(baseTile.category) + ' · base rarity: ' + esc(baseTile.rarity) + '</div>' +
        '</div>' +
      '</div>' : '') +
      '<div>' +
        '<button class="btn-remove" onclick="removeOverride(\\'' + uuid + '\\')">Remove Override</button>' +
      '</div>' +
    '</div>' +
    '<div class="panel-footer">' +
      '<div></div>' +
      '<div class="footer-right">' +
        '<button class="btn-cancel" onclick="cancelPackEdit()">Cancel</button>' +
        '<button class="btn-save" onclick="saveOverride(\\'' + uuid + '\\')">Save Changes</button>' +
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
  delete (packData.rarityOverrides || {})[uuid];
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
  const name = baseTile ? baseTile.text : 'Unknown tile (' + uuid.substring(0,8) + '…)';

  rightEl.innerHTML =
    '<div class="panel-header">' +
      '<div class="panel-title">' + esc(name) + '</div>' +
      '<div class="panel-id">Excluded from Pool</div>' +
    '</div>' +
    '<div class="panel-body">' +
      (baseTile ? '<div class="override-base-info">' +
        '<div class="name">' + esc(baseTile.text) + ' ' + esc(baseTile.emoji || '') + '</div>' +
        '<div>' + esc(baseTile.category) + ' · rarity: ' + esc(baseTile.rarity) + '</div>' +
      '</div>' : '') +
      '<div class="excluded-callout">This tile is hidden from all boards when this pack is active.</div>' +
      '<div>' +
        '<button class="btn-convert" onclick="convertExclusionToOverride(\\'' + uuid + '\\')">Convert to Override Instead</button>' +
        '<button class="btn-remove" onclick="removeExclusion(\\'' + uuid + '\\')">Remove Exclusion</button>' +
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
  selectedMod = { type: 'override', id: uuid };
  updatePackSummaryPanel();
  renderPackDiffList();
  showOverrideEditor(uuid);
}

function removeExclusiveTile(tileId) {
  if (!confirm('Remove this tile from the pack? The tile will be deleted.')) return;
  packData.tiles = (packData.tiles || []).filter(t => t.id !== tileId);
  markDirty();
  selectedMod = null;
  updatePackSummaryPanel();
  renderPackDiffList();
  resetPackRightPanel();
}

function resetPackRightPanel() {
  const rightEl = document.getElementById('pack-right-' + currentPackId);
  if (!rightEl) return;
  const pack = PACKS_META.find(p => p.id === currentPackId) || {};
  rightEl.innerHTML =
    '<div style="flex:1;display:flex;flex-direction:column;justify-content:center;padding:20px">' +
      '<div class="pack-summary">' +
        '<div class="pack-summary-name">' + esc(pack.name || '') + '</div>' +
        '<div class="pack-summary-counts" id="pack-counts-' + currentPackId + '">—</div>' +
        '<div class="pack-summary-hint">Select a modification to edit, or use + Add to create one.</div>' +
      '</div>' +
    '</div>';
  updatePackSummaryPanel();
}
```

- [ ] **Step 2: Verify right panels work**

```bash
python3 tools/tile_manager.py
# Open Farm Country tab
# Click an EXCLUSIVE row → exclusive tile editor appears with name/emoji/category/rarity fields
# Click an OVERRIDE row → from→to rarity UI with dropdown
# Click an EXCLUDED row → read-only info + callout + Remove/Convert buttons
# Click Cancel → returns to summary view
```

- [ ] **Step 3: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: add pack right panel editors (exclusive, override, excluded)"
```

---

## Task 5: JS — addition flows

**Files:**
- Modify: `tools/tile_manager.py` (JS section of HTML_APP)

- [ ] **Step 1: Add the four addition flow functions**

Add after `resetPackRightPanel()`:

```javascript
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

  // Build picker list of base tiles not already overridden or excluded by this pack
  const existingOverrides  = Object.keys(packData.rarityOverrides || {});
  const existingExcluded   = packData.excludedTileIDs || [];
  const alreadyHandled     = new Set([...existingOverrides, ...existingExcluded]);
  const candidates         = tiles.filter(t => !alreadyHandled.has(t.id));

  rightEl.innerHTML = buildTilePickerHTML('Override Rarity', candidates, 'confirmAddOverride', null);
}

async function confirmAddOverride(uuid) {
  const baseTile  = tiles.find(t => t.id === uuid);
  const rightEl   = document.getElementById('pack-right-' + currentPackId);
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

  // Candidates: base tiles not already exclusive in this pack
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
  renderTable(); // refresh base tiles tab list
  updateStats();

  // Add to pack (preserve UUID, send image if we have it)
  const body = { id: uuid, text: baseTile.text, emoji: baseTile.emoji || '', category: baseTile.category, rarity: baseTile.rarity };
  if (imageB64) body.image_b64 = imageB64;
  const addResp = await fetch('/api/packs/' + currentPackId + '/tiles', {
    method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body)
  });
  if (!addResp.ok) { alert('Tile deleted from base but failed to add to pack — check pack JSON manually'); return; }
  const newTile = await addResp.json();
  packData.tiles = packData.tiles || [];
  packData.tiles.push(newTile);

  selectedMod = { type: 'exclusive', id: uuid };
  updatePackSummaryPanel();
  renderPackDiffList();
  showExclusiveEditor(newTile);
}

// ── Shared tile picker HTML builder ──────────────────────────────────────────
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
```

- [ ] **Step 2: Verify all four addition flows**

```bash
python3 tools/tile_manager.py
# Open a pack tab. Click "+ Add ▾"
# "Create Exclusive Tile" → blank tile editor opens in right panel; save creates a new EXCLUSIVE row
# "Override Rarity" → tile picker → pick a base tile → from/to rarity picker → "Add Override" creates OVERRIDE row
# "Exclude Base Tile" → tile picker with red warning → pick a tile → EXCLUDED row appears
# "Move from Base" → tile picker with red warning → pick a tile → tile disappears from Base Tiles list, appears as EXCLUSIVE
```

- [ ] **Step 3: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: add all four pack modification addition flows"
```

---

## Task 6: JS — Save Pack and unsaved-changes guard

**Files:**
- Modify: `tools/tile_manager.py` (JS section of HTML_APP)

- [ ] **Step 1: Add `savePack()` function**

Add after `filterTilePicker`:

```javascript
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
  if (btn) btn.disabled = true;
  // Flash the button green briefly
  if (btn) {
    btn.textContent = 'Saved ✓';
    setTimeout(() => { btn.textContent = 'Save Pack'; }, 1500);
  }
}
```

- [ ] **Step 2: Verify Save Pack**

```bash
python3 tools/tile_manager.py
# Open Farm Country tab
# Change a rarity override (click OVERRIDE row, change rarity, Save Changes)
# "Save Pack" button should now be enabled
# Click "Save Pack"
# Button briefly says "Saved ✓" then returns to "Save Pack" (disabled)
# Reload the page, reopen Farm Country — change should persist
```

- [ ] **Step 3: Verify unsaved-changes guard**

```bash
# With the server still running:
# Make a pack change (e.g. change a rarity override) — don't click Save Pack
# Click a different tab — browser confirm dialog should appear: "You have unsaved pack changes. Leave anyway?"
# Cancel → stays on pack tab
# OK → switches tab, discards changes
```

- [ ] **Step 4: Run full test suite to confirm nothing broken**

```bash
python3 -m pytest tools/test_tile_manager.py -v 2>&1 | tail -20
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: save pack endpoint, dirty tracking, and unsaved-changes guard"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|-----------------|------|
| `GET /api/packs`, `GET /api/packs/<id>`, `PUT /api/packs/<id>` | Task 1 |
| `POST /api/packs/<id>/tiles`, `POST /api/packs/<id>/tiles/<uuid>/image` | Task 1 |
| `PACKS_META` injected into HTML | Task 1 |
| Tab bar with Base Tiles + per-pack tabs | Task 2 |
| Screens container with `active` class switching | Task 2 |
| Pack diff list with three row types (EXCLUSIVE/OVERRIDE/EXCLUDED) | Task 3 |
| Toolbar: search + type filter + `+ Add ▾` | Task 2 (HTML) + Task 3 (filter logic) |
| Right panel default summary | Task 3 |
| Right panel exclusive tile editor (image generation, metadata) | Task 4 |
| Right panel override editor (from→to rarity) | Task 4 |
| Right panel excluded editor (callout + Convert) | Task 4 |
| Create Exclusive Tile addition flow | Task 5 |
| Override Rarity addition flow | Task 5 |
| Exclude Base Tile addition flow | Task 5 |
| Move from Base addition flow (compound delete + add) | Task 5 |
| Remove exclusive, override, exclusion | Task 4 |
| Convert exclusion to override | Task 4 |
| Save Pack → `PUT /api/packs/<id>` (full object) | Task 6 |
| `isDirty` tracking + Save Pack button enable/disable | Task 6 |
| Unsaved-changes guard on tab switch | Task 6 |
| UUID preservation on Move from Base | Task 5 (body includes `id: uuid`) |

All spec requirements covered. No placeholders. Types consistent throughout (pack JSON keys match Swift model field names: `tiles`, `rarityOverrides`, `excludedTileIDs`). `tileId`/`uuid` naming consistent within each task.
