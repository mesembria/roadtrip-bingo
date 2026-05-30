# Tile Image Description Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional `description` field to each tile in the JSON data files, used as the subject phrase when generating tile images via `tile_manager.py`.

**Architecture:** All changes are confined to `tools/tile_manager.py`. The Python `build_prompt()` function is updated to read `description` from the tile dict; the embedded JS `buildPrompt()` mirrors it. The HTML edit form gains a description textarea for both base tiles and exclusive pack tiles. No Swift changes are needed.

**Tech Stack:** Python 3, pytest, vanilla JS (embedded in the Python HTTP server)

---

## File Map

| File | Change |
|---|---|
| `tools/tile_manager.py` | Remove `OVERRIDES`, update `STYLE`, update `build_prompt()`, update three API handlers, update embedded HTML/JS |
| `tools/test_tile_manager.py` | New — pytest tests for `build_prompt()` |

---

### Task 1: Update STYLE constant and remove OVERRIDES

**Files:**
- Modify: `tools/tile_manager.py:43-53`

- [ ] **Step 1: Replace the STYLE constant**

Find this block (lines 43–53):
```python
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
```

Replace it with:
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
```

- [ ] **Step 2: Commit**

```bash
git add tools/tile_manager.py
git commit -m "refactor: update STYLE constant, remove OVERRIDES dict"
```

---

### Task 2: Update Python build_prompt() — TDD

**Files:**
- Create: `tools/test_tile_manager.py`
- Modify: `tools/tile_manager.py:67-75`

- [ ] **Step 1: Write the failing tests**

Create `tools/test_tile_manager.py`:
```python
"""Tests for tile_manager.build_prompt()."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import tile_manager as tm


def test_uses_description_when_present():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red Kenworth semi truck cab, side view"}
    result = tm.build_prompt(tile)
    assert result.startswith("A red Kenworth semi truck cab, side view.")
    assert "Side view, full vehicle visible." in result
    assert "Flat vector illustration" in result


def test_falls_back_to_text_when_no_description():
    tile = {"text": "Semi Truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")
    assert "Side view, full vehicle visible." in result


def test_falls_back_to_text_when_description_is_empty_string():
    tile = {"text": "Semi Truck", "category": "vehicles", "description": ""}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi Truck.")


def test_strips_trailing_period_from_description():
    tile = {"text": "Semi Truck", "category": "vehicles",
            "description": "A red truck."}
    result = tm.build_prompt(tile)
    assert "A red truck.." not in result


def test_capitalises_first_letter():
    tile = {"text": "semi truck", "category": "vehicles"}
    result = tm.build_prompt(tile)
    assert result.startswith("Semi truck.")


def test_unknown_category_omits_hint():
    tile = {"text": "Mystery", "category": "unknown_cat"}
    result = tm.build_prompt(tile)
    # Only subject + STYLE, no hint
    assert result.count(".") >= 1
    assert "Flat vector illustration" in result
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
python -m pytest tools/test_tile_manager.py -v 2>&1 | head -40
```

Expected: several `FAILED` or `TypeError` (wrong number of args).

- [ ] **Step 3: Replace build_prompt() in tile_manager.py**

Find this block (lines 67–75):
```python
def build_prompt(text: str, category: str) -> str:
    """Build the Gemini image generation prompt for a tile."""
    subject = OVERRIDES.get(text, f"a {text.lower()}")
    hint = CATEGORY_HINTS.get(category, "")
    # Strip trailing period and capitalize only the first character
    subject_clean = subject.rstrip(".")
    subject_cap = subject_clean[0].upper() + subject_clean[1:]
    parts = [f"{subject_cap}.", hint, STYLE]
    return " ".join(p for p in parts if p).strip()
```

Replace it with:
```python
def build_prompt(tile: dict) -> str:
    """Build the Gemini image generation prompt for a tile.

    Uses tile['description'] as the subject phrase if present and non-empty;
    falls back to tile['text'] (the tile name) otherwise.
    STYLE is always appended; CATEGORY_HINTS adds a layout hint per category.
    """
    description = tile.get("description") or tile["text"]
    category = tile.get("category", "")
    hint = CATEGORY_HINTS.get(category, "")
    desc_clean = description.rstrip(".")
    desc_cap = desc_clean[0].upper() + desc_clean[1:]
    parts = [f"{desc_cap}.", hint, STYLE]
    return " ".join(p for p in parts if p).strip()
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
python -m pytest tools/test_tile_manager.py -v
```

Expected output:
```
PASSED tools/test_tile_manager.py::test_uses_description_when_present
PASSED tools/test_tile_manager.py::test_falls_back_to_text_when_no_description
PASSED tools/test_tile_manager.py::test_falls_back_to_text_when_description_is_empty_string
PASSED tools/test_tile_manager.py::test_strips_trailing_period_from_description
PASSED tools/test_tile_manager.py::test_capitalises_first_letter
PASSED tools/test_tile_manager.py::test_unknown_category_omits_hint
6 passed
```

- [ ] **Step 5: Commit**

```bash
git add tools/tile_manager.py tools/test_tile_manager.py
git commit -m "feat: build_prompt reads tile description field, falls back to tile name"
```

---

### Task 3: Persist description through API handlers

**Files:**
- Modify: `tools/tile_manager.py` — `_handle_add_tile`, `_handle_update_tile`, `_handle_add_pack_tile`

- [ ] **Step 1: Update _handle_add_tile to include description**

Find this block in `_handle_add_tile`:
```python
        new_id = str(uuid.uuid4()).upper()
        tile = {
            "id":       new_id,
            "text":     body["text"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
```

Replace with:
```python
        new_id = str(uuid.uuid4()).upper()
        tile = {
            "id":       new_id,
            "text":     body["text"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
        if body.get("description"):
            tile["description"] = body["description"]
```

- [ ] **Step 2: Update _handle_update_tile to allow description**

Find this block in `_handle_update_tile`:
```python
                allowed = {"text", "category", "rarity"}
                tile.update({k: v for k, v in body.items() if k in allowed})
```

Replace with:
```python
                allowed = {"text", "category", "rarity", "description"}
                tile.update({k: v for k, v in body.items() if k in allowed})
                # Remove description key entirely when client sends empty string
                if "description" in tile and not tile["description"]:
                    del tile["description"]
```

- [ ] **Step 3: Update _handle_add_pack_tile to include description**

Find this block in `_handle_add_pack_tile`:
```python
        tile = {
            "id":       tile_id,
            "text":     body["text"],
            "emoji":    body["emoji"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
```

Replace with:
```python
        tile = {
            "id":       tile_id,
            "text":     body["text"],
            "emoji":    body["emoji"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
        if body.get("description"):
            tile["description"] = body["description"]
```

- [ ] **Step 4: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: API handlers persist description field on tiles"
```

---

### Task 4: Add description field to base tile HTML form

**Files:**
- Modify: `tools/tile_manager.py` — HTML form markup, `showPanel()`, `saveTile()`, `startAddMode()`

This task edits the embedded HTML string and JavaScript inside `tile_manager.py`.

- [ ] **Step 1: Add description textarea to the Metadata section of the base tile form**

Find this exact block in the HTML string (inside the `<div class="panel-body">` Metadata section):
```python
            <div>
            <div class="section-label">Metadata</div>
            <div style="display:flex;flex-direction:column;gap:12px">
              <div class="field"><label class="field-label">Name</label><input class="field-input" id="field-name" type="text"></div>
              <div class="fields-row">
                <div class="field"><label class="field-label">Category</label><select class="field-input" id="field-category" style="cursor:pointer"></select></div>
                <div class="field"><label class="field-label">Rarity</label><select class="field-input" id="field-rarity" style="cursor:pointer"></select></div>
              </div>
            </div>
          </div>
```

Replace with:
```python
            <div>
            <div class="section-label">Metadata</div>
            <div style="display:flex;flex-direction:column;gap:12px">
              <div class="field"><label class="field-label">Name</label><input class="field-input" id="field-name" type="text"></div>
              <div class="field"><label class="field-label">Image Description <span style="color:var(--text3);font-weight:400;text-transform:none;letter-spacing:0">(optional — defaults to tile name)</span></label><textarea class="field-input" id="field-description" rows="2" style="resize:vertical;font-size:13px;line-height:1.5" placeholder="e.g. A red Kenworth semi truck cab, side view, no trailer"></textarea></div>
              <div class="fields-row">
                <div class="field"><label class="field-label">Category</label><select class="field-input" id="field-category" style="cursor:pointer"></select></div>
                <div class="field"><label class="field-label">Rarity</label><select class="field-input" id="field-rarity" style="cursor:pointer"></select></div>
              </div>
            </div>
          </div>
```

- [ ] **Step 2: Populate description field in showPanel()**

Find this block in `showPanel()`:
```javascript
  document.getElementById('field-name').value = tile.text;
  document.getElementById('field-category').value = tile.category;
  document.getElementById('field-rarity').value = tile.rarity;
```

Replace with:
```javascript
  document.getElementById('field-name').value = tile.text;
  document.getElementById('field-description').value = tile.description || '';
  document.getElementById('field-category').value = tile.category;
  document.getElementById('field-rarity').value = tile.rarity;
```

- [ ] **Step 3: Clear description field in startAddMode()**

Find this block in `startAddMode()`:
```javascript
  document.getElementById('field-name').value = '';
  document.getElementById('field-category').value = CATEGORIES[0] || '';
  document.getElementById('field-rarity').value = RARITIES[0] || 'veryCommon';
```

Replace with:
```javascript
  document.getElementById('field-name').value = '';
  document.getElementById('field-description').value = '';
  document.getElementById('field-category').value = CATEGORIES[0] || '';
  document.getElementById('field-rarity').value = RARITIES[0] || 'veryCommon';
```

- [ ] **Step 4: Send description in saveTile() — add mode**

Find this block in `saveTile()` (add mode branch):
```javascript
    const body = {text: name, category, rarity};
    if (pendingImageB64) body.image_b64 = pendingImageB64;
```

Replace with:
```javascript
    const description = document.getElementById('field-description').value.trim();
    const body = {text: name, category, rarity};
    if (description) body.description = description;
    if (pendingImageB64) body.image_b64 = pendingImageB64;
```

- [ ] **Step 5: Send description in saveTile() — edit mode**

Find this block in `saveTile()` (else/edit branch):
```javascript
    const r = await fetch('/api/tiles/' + selectedId, {
      method: 'PUT', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({text: name, category, rarity}),
    });
```

Replace with:
```javascript
    const description = document.getElementById('field-description').value.trim();
    const r = await fetch('/api/tiles/' + selectedId, {
      method: 'PUT', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({text: name, category, rarity, description}),
    });
```

- [ ] **Step 6: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: add description textarea to base tile edit form"
```

---

### Task 5: Update JS buildPrompt() and showPromptEditor() to use description

**Files:**
- Modify: `tools/tile_manager.py` — JS `STYLE_JS`, `buildPrompt()`, `showPromptEditor()`

- [ ] **Step 1: Update STYLE_JS constant**

Find this line:
```javascript
const STYLE_JS = 'Flat vector illustration, clean thin outlines, bright colors. Plain solid white background — the illustration sits directly on white with absolutely no drop shadow, no border, no card, no frame, no vignette, no outline around the image edge. Square composition. No text, no labels, no letters.';
```

Replace with:
```javascript
const STYLE_JS = 'Flat vector illustration, clean thin outlines, bright but realistic colors. Use natural, true-to-life colors for each object and all parts should match the colors that object would actually have in real life. Plain solid white background — the illustration sits directly on white with absolutely no drop shadow, no border, no card, no frame, no vignette, no outline around the image edge. Square composition. No text, no labels, no letters.';
```

- [ ] **Step 2: Update buildPrompt() to accept a tile object**

Find this block:
```javascript
function buildPrompt(name, category) {
  const hint = CATEGORY_HINTS_JS[category] || '';
  return ['A ' + name.toLowerCase() + '.', hint, STYLE_JS].filter(Boolean).join(' ').replace(/\\s+/g, ' ').trim();
}
```

Replace with:
```javascript
function buildPrompt(tile) {
  const subject = (tile.description || tile.text || 'a tile').replace(/\\.+$/, '');
  const subjectCap = subject.charAt(0).toUpperCase() + subject.slice(1);
  const hint = CATEGORY_HINTS_JS[tile.category] || '';
  return [subjectCap + '.', hint, STYLE_JS].filter(Boolean).join(' ').replace(/\\s+/g, ' ').trim();
}
```

- [ ] **Step 3: Update showPromptEditor() to pass the tile object**

Find this block inside `showPromptEditor()`:
```javascript
  if (!lastUsedPrompt) {
    const name = document.getElementById('field-name').value.trim() || 'a tile';
    const cat  = document.getElementById('field-category').value;
    lastUsedPrompt = buildPrompt(name, cat);
  }
```

Replace with:
```javascript
  if (!lastUsedPrompt) {
    lastUsedPrompt = buildPrompt({
      text:        document.getElementById('field-name').value.trim() || 'a tile',
      description: document.getElementById('field-description').value.trim(),
      category:    document.getElementById('field-category').value,
    });
  }
```

- [ ] **Step 4: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: JS buildPrompt uses tile description field"
```

---

### Task 6: Add description field to exclusive pack tile editor

**Files:**
- Modify: `tools/tile_manager.py` — `showExclusiveEditor()`, `showPackPromptEditor()`, `saveExclusiveTile()`

- [ ] **Step 1: Add description textarea to showExclusiveEditor() HTML**

Find this block in the `showExclusiveEditor()` Metadata section:
```javascript
          '<div class="field"><label class="field-label">Name</label><input class="field-input" id="pack-field-name" type="text" value="' + esc(tile.text || '') + '"></div>' +
          '<div class="field"><label class="field-label">Emoji</label><input class="field-input" id="pack-field-emoji" type="text" value="' + esc(tile.emoji || '') + '"></div>' +
```

Replace with:
```javascript
          '<div class="field"><label class="field-label">Name</label><input class="field-input" id="pack-field-name" type="text" value="' + esc(tile.text || '') + '"></div>' +
          '<div class="field"><label class="field-label">Image Description <span style="color:var(--text3);font-weight:400;text-transform:none;letter-spacing:0">(optional — defaults to tile name)</span></label><textarea class="field-input" id="pack-field-description" rows="2" style="resize:vertical;font-size:13px;line-height:1.5" placeholder="e.g. A red Kenworth semi truck cab, side view, no trailer">' + esc(tile.description || '') + '</textarea></div>' +
          '<div class="field"><label class="field-label">Emoji</label><input class="field-input" id="pack-field-emoji" type="text" value="' + esc(tile.emoji || '') + '"></div>' +
```

- [ ] **Step 2: Update showPackPromptEditor() to use description**

Find this block inside `showPackPromptEditor()`:
```javascript
  if (!window._packLastPrompt) {
    const name = document.getElementById('pack-field-name').value.trim() || 'a tile';
    const cat  = document.getElementById('pack-field-category').value;
    window._packLastPrompt = buildPrompt(name, cat);
  }
```

Replace with:
```javascript
  if (!window._packLastPrompt) {
    window._packLastPrompt = buildPrompt({
      text:        document.getElementById('pack-field-name').value.trim() || 'a tile',
      description: (document.getElementById('pack-field-description') || {}).value || '',
      category:    document.getElementById('pack-field-category').value,
    });
  }
```

- [ ] **Step 3: Send description in saveExclusiveTile() — new tile branch**

Find this block in `saveExclusiveTile()` (new tile branch):
```javascript
    const body = {text: name, emoji, category, rarity};
    if (window._packPendingImageB64) body.image_b64 = window._packPendingImageB64;
```

Replace with:
```javascript
    const descriptionEl = document.getElementById('pack-field-description');
    const description = descriptionEl ? descriptionEl.value.trim() : '';
    const body = {text: name, emoji, category, rarity};
    if (description) body.description = description;
    if (window._packPendingImageB64) body.image_b64 = window._packPendingImageB64;
```

- [ ] **Step 4: Update description on existing tile in saveExclusiveTile() — edit branch**

Find this block in `saveExclusiveTile()` (edit existing tile branch):
```javascript
    tile.text = name; tile.emoji = emoji; tile.category = category; tile.rarity = rarity;
    markDirty();
```

Replace with:
```javascript
    const descEl = document.getElementById('pack-field-description');
    const desc = descEl ? descEl.value.trim() : '';
    tile.text = name; tile.emoji = emoji; tile.category = category; tile.rarity = rarity;
    if (desc) { tile.description = desc; } else { delete tile.description; }
    markDirty();
```

- [ ] **Step 5: Commit**

```bash
git add tools/tile_manager.py
git commit -m "feat: add description field to exclusive pack tile editor"
```

---

### Task 7: Manual smoke test

- [ ] **Step 1: Run the tile manager**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
GEMINI_API_KEY=dummy python3 tools/tile_manager.py
```

(Use a dummy key — image generation will fail gracefully, but the UI should load.)

- [ ] **Step 2: Verify base tile description field**

1. Open http://localhost:8765 in a browser
2. Select any tile from the list
3. Confirm the **Image Description** textarea appears between Name and Category/Rarity
4. Confirm it is empty for tiles without a `description` key in JSON
5. Type a description and click **Save Changes**
6. Re-select the same tile — confirm the description persists (is loaded back)
7. Inspect `RoadTripBingo/Resources/squares.json` — confirm the tile now has a `"description"` key

- [ ] **Step 3: Verify prompt uses description**

1. With a tile selected that has a description, click **❆ Generate New Image**
2. Confirm the prompt textarea shows `{description}. {category hint} {STYLE}` — not the tile name
3. Select a tile with no description — confirm the prompt starts with the tile name

- [ ] **Step 4: Verify pack tile description field**

1. Switch to a pack tab (e.g., Interstate)
2. Select an exclusive tile and confirm the **Image Description** textarea appears
3. Enter a description, click **Save Changes**, then **Save Pack**
4. Inspect the pack JSON file and confirm the `description` field is present

- [ ] **Step 5: Clear description removes key from JSON**

1. Select a tile that has a description
2. Clear the description textarea
3. Save
4. Confirm the `"description"` key is absent from the tile in JSON (not present as `""`)

- [ ] **Step 6: Stop server and run all tests one final time**

Press Ctrl+C to stop the server, then:

```bash
python -m pytest tools/test_tile_manager.py -v
```

Expected: `6 passed`

- [ ] **Step 7: Final commit if any cleanup needed**

```bash
git add tools/tile_manager.py tools/test_tile_manager.py
git commit -m "chore: post-smoke-test cleanup (if any)"
```
