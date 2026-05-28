# Tile Content Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all tile packs with child-friendly renames, category fixes, rarity adjustments, ~27 new base tiles, and new pack-specific tiles for Interstate, Farm Country, Mountains, and City packs.

**Architecture:** All changes are pure data edits to JSON files in `RoadTripBingo/Resources/`. Each task uses a standalone Python script that reads, mutates, and writes the target file — no Swift changes needed. Tile renames reuse existing UUIDs; new tiles get pre-computed UUID3 IDs (deterministic, based on tile name).

**Tech Stack:** Python 3 (stdlib only — json, uuid). XCTest suite (`SquarePoolTests`, `BingoSquareTests`) validates the data at the end.

---

## File Map

| File | What changes |
|---|---|
| `RoadTripBingo/Resources/squares.json` | Category fixes, renames/replacements, rarity adjustments, 27 new tiles |
| `RoadTripBingo/Resources/pack-interstate.json` | +2 pack-specific tiles |
| `RoadTripBingo/Resources/pack-farm-country.json` | Rename Irrigation Pivot, remove Grain Elevator |
| `RoadTripBingo/Resources/pack-mountains.json` | Rename Switchback Road, +5 pack-specific tiles |
| `RoadTripBingo/Resources/pack-city.json` | State Capitol → veryRare, +8 pack-specific tiles |
| `RoadTripBingoTests/BingoSquareTests.swift` | +2 regression tests |

---

## Reference: IDs of Tiles to Modify in squares.json

```
6BA6FFCC-5BC1-4A77-AD4C-E80BC54241EE  Billboard         (food → signs)
54125617-DEA9-4FFF-B967-ACEEBF3E60A5  Car Wash          (food → landmarks)
61F546BA-61C6-4A2A-A616-CFCF2866F011  County Courthouse (rename)
F8E12E7A-4A96-4990-8719-90423D457EE6  Double-Decker Bus (rename → Stretched Limousine)
F070E239-C059-456B-B908-11CB3902D05D  Chain Control Sign (rename → Tire Chains on Car)
7912F43E-141F-40A4-B209-125709247146  Tobacco Barn      (rename → Rusted Old Barn)
9ECF0037-9500-4C09-A8A7-F8DD573C4EAC  Limestone Cliffs  (rename → White Rock Cliffs)
E8A0F6BE-2AB6-49EA-A199-F43D7A1FBFA0  Mining Facility   (rename → Open-Pit Mine)
C44588F4-72FF-4691-8AB7-8B9C6DB664D9  Coal Truck        (rename → Garbage Truck)
5700EA4F-7F21-45B2-8E93-40F7A151A255  Rainbow           (rare → uncommon)
0D71D1E3-D56E-4584-B7DB-FD9EFA88B060  Hot Air Balloon   (rare → uncommon)
F448BB29-CAB1-4CCD-8C42-D3DD6B76292C  Ice Cream Truck   (rare → uncommon)
A6F7CA63-1204-4831-8F57-F7BBF95BED53  Yard Sale         (uncommon → veryCommon)
C06E05E6-15F9-4867-B8A5-47A82727CD13  RV                (uncommon → common)
ACE3CB99-BC1E-4874-AFB7-E4B5D5D8FAD1  Dollar General    (veryCommon → common)
3220B1AF-B3AE-493C-8313-180D7C3D3E69  Route 66 Sign     (uncommon → rare)
```

## Reference: New Tile UUIDs (pre-computed uuid3, namespace=URL)

```
# Vehicles (base)
20A927BB-05D8-376D-AE8F-A90B52EE40C8  License Plate from Another State
EAE4E491-F2D1-3CAD-AAAC-7BD22D9ADDF7  Lifted Truck
6000EE0A-EC7E-3B46-85A0-13219E8161E2  Golf Cart on Street
CA2AB532-9234-3BF6-A9D9-BC4EBC5D11FF  Military Convoy
E7462975-1FDB-3F94-AC1D-58582450B7AA  Converted School Bus RV
508ACF2E-4908-3685-B1C8-2C09D1B27A8E  Electric Car at Charging Station

# Nature (base)
7FB6AACA-0113-3B01-9404-EDECCBF8754C  Tumbleweed
5614C234-67B9-3416-873F-92CFE4975D44  Armadillo
EB0AD8DB-A599-37B7-BFCF-44EB7BE105B8  Vultures Circling
BC52173A-B9F4-3C6E-82FA-60E7FF155F96  Wild Horses
72CFDB3B-2AB7-39DA-9F52-22F2D3B04511  Alligator
FF64E7F2-26B5-3CB5-9635-3D4009CE5B0A  Roadrunner

# Landmarks (base)
A428A43F-2475-38C8-B037-4798F1191056  Giant Roadside Statue
435CFB62-75BB-3ADA-A4BF-97FC01AA5E87  Abandoned Building
4F969C82-F7E7-313B-AF55-624D19BB1A75  Rock Tunnel
1D810558-8870-3535-80AE-53575737D471  Rest Stop Playground

# Food (base)
14E85104-6013-3C95-84F2-F75E602B93ED  Buc-ee's
6EFCF38E-E745-36C1-9167-0B7EBFC7B00B  Fireworks Superstore
BB4DD049-66DD-3E9E-A8C5-CA75FB39B317  Sonic Drive-In
F9C61F3C-93EE-308F-8901-CB5D07F9AEAC  In-N-Out Burger
64300F49-5488-3674-8B12-1AEE577971AF  Pilot / Love's Truck Stop
3E9570E3-459A-3C2D-8226-E36AD595D8A4  Roadside Souvenir Shop

# Signs (base)
84ED3979-D624-3AB3-938E-B25330C459A4  Funny Town Name Sign
348BCF77-2B49-30ED-A0BE-03F2BBA04CE5  Radar Speed Sign
D62EEA67-E90F-3918-8CB5-D9DACAC5A70D  Next Gas Sign
02E74882-80DC-3850-8D78-01A503B62084  Amber Alert Highway Sign
BCA3B438-CE22-3867-815D-74B04002D7AD  Corn Maze Sign

# Pack-specific (Interstate)
9CB9371C-354F-3F5B-ACCF-914CFE365C29  State Trooper Car
D1676C11-21B1-32CB-9850-777B52120238  Welcome Center

# Pack-specific (Mountains)
A2C0272D-0B98-3147-B23F-8D25A6230917  Waterfall by Road
1AE6E43B-029D-3776-8BE2-29B18AB4D903  Mountain Goat
DC5571A7-8015-37E7-918F-10C9ED873906  Snowplow
96FBDFB3-BC29-3026-B150-7A28B1EDC3B8  Alpine Meadow
B360FA15-6DA3-38B1-91F9-1EB84E03C09B  Ski Slope Visible

# Pack-specific (City)
6213065F-B829-37B8-B10C-85A97907D061  Yellow Taxi
20D6D1E7-BA9F-3471-B7EB-A157D72C7244  Skyscraper
A60758E5-C8CE-3DE2-BAE7-8993CD7F963A  Street Food Cart
0ADD601C-7BE3-3CC8-A5B2-0CE9C608CC57  One-Way Street Sign
E85E47BC-8DFA-3E6B-BEF1-26FB174F1C90  Parking Garage
C0F193C0-8F50-3677-930B-2DBE16ADC811  City Mural
798C809A-F953-397E-9DC0-9FEAA60276CE  Subway Entrance
66852A88-CC90-3CC3-BF71-2A993BFAEEFA  Bike Share Station
```

---

### Task 1: Baseline — run tests

**Files:** none modified

- [ ] **Step 1: Run the existing square tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests \
       -only-testing:RoadTripBingoTests/BingoSquareTests \
  2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: all tests PASS. Fix any pre-existing failures before proceeding.

---

### Task 2: Add two regression tests

**Files:**
- Modify: `RoadTripBingoTests/BingoSquareTests.swift`

These tests will fail until Task 3 and Task 4 are complete — that's expected. We write them first so we have a clear target.

- [ ] **Step 1: Add the two tests**

Open `RoadTripBingoTests/BingoSquareTests.swift` and append inside the `final class BingoSquareTests` block (before the final `}`):

```swift
func test_load_billboardIsInSignsCategory() {
    let billboard = SquarePool.load().first { $0.text == "Billboard" }
    XCTAssertNotNil(billboard, "Billboard must exist in the pool")
    XCTAssertEqual(billboard?.category, .signs,
                   "Billboard was miscategorised as food; it must be in signs")
}

func test_load_licensePlateFromAnotherStateExists() {
    let tile = SquarePool.load().first { $0.text == "License Plate from Another State" }
    XCTAssertNotNil(tile, "License Plate from Another State must be in the pool")
    XCTAssertEqual(tile?.rarity, .veryCommon)
    XCTAssertEqual(tile?.category, .vehicles)
}
```

- [ ] **Step 2: Run — expect both new tests to FAIL**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/BingoSquareTests \
  2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: `test_load_billboardIsInSignsCategory` → FAIL, `test_load_licensePlateFromAnotherStateExists` → FAIL. The existing two tests still PASS.

---

### Task 3: squares.json — fix categories and rename/replace tiles

**Files:**
- Modify: `RoadTripBingo/Resources/squares.json`

- [ ] **Step 1: Run the fix script**

```python
#!/usr/bin/env python3
"""Task 3: fix categories and rename tiles in squares.json"""
import json

PATH = 'RoadTripBingo/Resources/squares.json'

with open(PATH) as f:
    squares = json.load(f)

CHANGES = {
    # Category fixes
    '6BA6FFCC-5BC1-4A77-AD4C-E80BC54241EE': {'category': 'signs'},
    '54125617-DEA9-4FFF-B967-ACEEBF3E60A5': {'category': 'landmarks'},
    # Renames (UUID kept, text/emoji updated)
    '61F546BA-61C6-4A2A-A616-CFCF2866F011': {'text': 'Courthouse with Clock Tower'},
    'F8E12E7A-4A96-4990-8719-90423D457EE6': {'text': 'Stretched Limousine', 'emoji': '🚗'},
    'F070E239-C059-456B-B908-11CB3902D05D': {'text': 'Tire Chains on Car', 'emoji': '⛓️'},
    '7912F43E-141F-40A4-B209-125709247146': {'text': 'Rusted Old Barn', 'emoji': '🏚️'},
    '9ECF0037-9500-4C09-A8A7-F8DD573C4EAC': {'text': 'White Rock Cliffs', 'emoji': '🪨'},
    'E8A0F6BE-2AB6-49EA-A199-F43D7A1FBFA0': {'text': 'Open-Pit Mine', 'emoji': '⛏️'},
    'C44588F4-72FF-4691-8AB7-8B9C6DB664D9': {'text': 'Garbage Truck', 'emoji': '🗑️'},
}

changed = 0
for sq in squares:
    if sq['id'] in CHANGES:
        for field, val in CHANGES[sq['id']].items():
            sq[field] = val
        changed += 1

assert changed == len(CHANGES), f"Expected {len(CHANGES)} changes, applied {changed}"

with open(PATH, 'w') as f:
    json.dump(squares, f, indent=2, ensure_ascii=False)

print(f"OK: applied {changed} changes")
```

Save as `tools/fix_categories_renames.py` and run:

```bash
python3 tools/fix_categories_renames.py
```

Expected output: `OK: applied 9 changes`

- [ ] **Step 2: Spot-check**

```bash
python3 -c "
import json
with open('RoadTripBingo/Resources/squares.json') as f:
    sq = json.load(f)
lookup = {s['id']: s for s in sq}
checks = [
    ('6BA6FFCC-5BC1-4A77-AD4C-E80BC54241EE', 'category', 'signs'),
    ('54125617-DEA9-4FFF-B967-ACEEBF3E60A5', 'category', 'landmarks'),
    ('F8E12E7A-4A96-4990-8719-90423D457EE6', 'text', 'Stretched Limousine'),
    ('C44588F4-72FF-4691-8AB7-8B9C6DB664D9', 'text', 'Garbage Truck'),
]
for uid, field, expected in checks:
    actual = lookup[uid][field]
    status = 'OK' if actual == expected else f'FAIL (got {actual!r})'
    print(f'{status}  {uid[:8]}  {field}={expected!r}')
"
```

Expected: all lines print `OK`.

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Resources/squares.json RoadTripBingoTests/BingoSquareTests.swift
git commit -m "content: fix Billboard/CarWash categories; rename 7 confusing tiles

- Billboard: food → signs
- Car Wash: food → landmarks
- Double-Decker Bus → Stretched Limousine
- Chain Control Sign → Tire Chains on Car
- Tobacco Barn → Rusted Old Barn
- Limestone Cliffs → White Rock Cliffs
- Mining Facility → Open-Pit Mine
- Coal Truck → Garbage Truck
- County Courthouse → Courthouse with Clock Tower

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4: squares.json — rarity adjustments

**Files:**
- Modify: `RoadTripBingo/Resources/squares.json`

- [ ] **Step 1: Run the rarity script**

```python
#!/usr/bin/env python3
"""Task 4: adjust rarities in squares.json"""
import json

PATH = 'RoadTripBingo/Resources/squares.json'

with open(PATH) as f:
    squares = json.load(f)

RARITY_CHANGES = {
    '5700EA4F-7F21-45B2-8E93-40F7A151A255': 'uncommon',    # Rainbow: rare → uncommon
    '0D71D1E3-D56E-4584-B7DB-FD9EFA88B060': 'uncommon',    # Hot Air Balloon: rare → uncommon
    'F448BB29-CAB1-4CCD-8C42-D3DD6B76292C': 'uncommon',    # Ice Cream Truck: rare → uncommon
    'A6F7CA63-1204-4831-8F57-F7BBF95BED53': 'veryCommon',  # Yard Sale: uncommon → veryCommon
    'C06E05E6-15F9-4867-B8A5-47A82727CD13': 'common',      # RV: uncommon → common
    'ACE3CB99-BC1E-4874-AFB7-E4B5D5D8FAD1': 'common',      # Dollar General: veryCommon → common
    '3220B1AF-B3AE-493C-8313-180D7C3D3E69': 'rare',         # Route 66 Sign: uncommon → rare
}

changed = 0
for sq in squares:
    if sq['id'] in RARITY_CHANGES:
        sq['rarity'] = RARITY_CHANGES[sq['id']]
        changed += 1

assert changed == len(RARITY_CHANGES), f"Expected {len(RARITY_CHANGES)}, applied {changed}"

with open(PATH, 'w') as f:
    json.dump(squares, f, indent=2, ensure_ascii=False)

print(f"OK: adjusted {changed} rarities")
```

Save as `tools/fix_rarities.py` and run:

```bash
python3 tools/fix_rarities.py
```

Expected: `OK: adjusted 7 rarities`

- [ ] **Step 2: Commit**

```bash
git add RoadTripBingo/Resources/squares.json
git commit -m "content: adjust 7 tile rarities for kid-friendliness

Rainbow/HotAirBalloon/IceCreamTruck: rare→uncommon (too frustrating for kids)
YardSale: uncommon→veryCommon (they're everywhere on weekends)
RV: uncommon→common (very common on any cross-country route)
DollarGeneral: veryCommon→common (still common but shouldn't be top-tier)
Route66Sign: uncommon→rare (only valid on one specific historic route)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5: squares.json — add new base tiles (vehicles + nature)

**Files:**
- Modify: `RoadTripBingo/Resources/squares.json`

- [ ] **Step 1: Run the add-vehicles-nature script**

```python
#!/usr/bin/env python3
"""Task 5: add new vehicle and nature tiles to squares.json"""
import json

PATH = 'RoadTripBingo/Resources/squares.json'

with open(PATH) as f:
    squares = json.load(f)

existing_ids = {s['id'] for s in squares}

NEW_TILES = [
    # --- vehicles ---
    {"id": "20A927BB-05D8-376D-AE8F-A90B52EE40C8", "text": "License Plate from Another State",
     "emoji": "🪪", "category": "vehicles", "rarity": "veryCommon"},
    {"id": "EAE4E491-F2D1-3CAD-AAAC-7BD22D9ADDF7", "text": "Lifted Truck",
     "emoji": "🛻", "category": "vehicles", "rarity": "common"},
    {"id": "6000EE0A-EC7E-3B46-85A0-13219E8161E2", "text": "Golf Cart on Street",
     "emoji": "⛳", "category": "vehicles", "rarity": "uncommon"},
    {"id": "CA2AB532-9234-3BF6-A9D9-BC4EBC5D11FF", "text": "Military Convoy",
     "emoji": "🪖", "category": "vehicles", "rarity": "rare"},
    {"id": "E7462975-1FDB-3F94-AC1D-58582450B7AA", "text": "Converted School Bus RV",
     "emoji": "🚌", "category": "vehicles", "rarity": "rare"},
    {"id": "508ACF2E-4908-3685-B1C8-2C09D1B27A8E", "text": "Electric Car at Charging Station",
     "emoji": "⚡", "category": "vehicles", "rarity": "uncommon"},
    # --- nature ---
    {"id": "7FB6AACA-0113-3B01-9404-EDECCBF8754C", "text": "Tumbleweed",
     "emoji": "🌾", "category": "nature", "rarity": "common"},
    {"id": "5614C234-67B9-3416-873F-92CFE4975D44", "text": "Armadillo",
     "emoji": "🐾", "category": "nature", "rarity": "uncommon"},
    {"id": "EB0AD8DB-A599-37B7-BFCF-44EB7BE105B8", "text": "Vultures Circling",
     "emoji": "🦅", "category": "nature", "rarity": "uncommon"},
    {"id": "BC52173A-B9F4-3C6E-82FA-60E7FF155F96", "text": "Wild Horses",
     "emoji": "🐎", "category": "nature", "rarity": "rare"},
    {"id": "72CFDB3B-2AB7-39DA-9F52-22F2D3B04511", "text": "Alligator",
     "emoji": "🐊", "category": "nature", "rarity": "rare"},
    {"id": "FF64E7F2-26B5-3CB5-9635-3D4009CE5B0A", "text": "Roadrunner",
     "emoji": "🐦", "category": "nature", "rarity": "rare"},
]

# Guard: no duplicate IDs
for t in NEW_TILES:
    assert t['id'] not in existing_ids, f"Duplicate ID: {t['id']} ({t['text']})"

squares.extend(NEW_TILES)

with open(PATH, 'w') as f:
    json.dump(squares, f, indent=2, ensure_ascii=False)

print(f"OK: added {len(NEW_TILES)} tiles. Pool size now: {len(squares)}")
```

Save as `tools/add_tiles_vehicles_nature.py` and run:

```bash
python3 tools/add_tiles_vehicles_nature.py
```

Expected: `OK: added 12 tiles. Pool size now: 183`

- [ ] **Step 2: Commit**

```bash
git add RoadTripBingo/Resources/squares.json
git commit -m "content: add 12 new base tiles (vehicles + nature)

Vehicles: License Plate from Another State (veryCommon), Lifted Truck,
Electric Car at Charging Station (uncommon), Golf Cart on Street (uncommon),
Military Convoy (rare), Converted School Bus RV (rare)

Nature: Tumbleweed, Armadillo, Vultures Circling (uncommon),
Wild Horses, Alligator, Roadrunner (rare)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 6: squares.json — add new base tiles (landmarks, food, signs)

**Files:**
- Modify: `RoadTripBingo/Resources/squares.json`

- [ ] **Step 1: Run the add-landmarks-food-signs script**

```python
#!/usr/bin/env python3
"""Task 6: add new landmark, food, and signs tiles to squares.json"""
import json

PATH = 'RoadTripBingo/Resources/squares.json'

with open(PATH) as f:
    squares = json.load(f)

existing_ids = {s['id'] for s in squares}

NEW_TILES = [
    # --- landmarks ---
    {"id": "A428A43F-2475-38C8-B037-4798F1191056", "text": "Giant Roadside Statue",
     "emoji": "🗿", "category": "landmarks", "rarity": "uncommon"},
    {"id": "435CFB62-75BB-3ADA-A4BF-97FC01AA5E87", "text": "Abandoned Building",
     "emoji": "🏚️", "category": "landmarks", "rarity": "common"},
    {"id": "4F969C82-F7E7-313B-AF55-624D19BB1A75", "text": "Rock Tunnel",
     "emoji": "⛰️", "category": "landmarks", "rarity": "uncommon"},
    {"id": "1D810558-8870-3535-80AE-53575737D471", "text": "Rest Stop Playground",
     "emoji": "🛝", "category": "landmarks", "rarity": "uncommon"},
    # --- food ---
    {"id": "14E85104-6013-3C95-84F2-F75E602B93ED", "text": "Buc-ee's",
     "emoji": "🦫", "category": "food", "rarity": "uncommon"},
    {"id": "6EFCF38E-E745-36C1-9167-0B7EBFC7B00B", "text": "Fireworks Superstore",
     "emoji": "🎆", "category": "food", "rarity": "common"},
    {"id": "BB4DD049-66DD-3E9E-A8C5-CA75FB39B317", "text": "Sonic Drive-In",
     "emoji": "🥤", "category": "food", "rarity": "uncommon"},
    {"id": "F9C61F3C-93EE-308F-8901-CB5D07F9AEAC", "text": "In-N-Out Burger",
     "emoji": "🍔", "category": "food", "rarity": "uncommon"},
    {"id": "64300F49-5488-3674-8B12-1AEE577971AF", "text": "Pilot / Love's Truck Stop",
     "emoji": "⛽", "category": "food", "rarity": "common"},
    {"id": "3E9570E3-459A-3C2D-8226-E36AD595D8A4", "text": "Roadside Souvenir Shop",
     "emoji": "🛍️", "category": "food", "rarity": "common"},
    # --- signs ---
    {"id": "84ED3979-D624-3AB3-938E-B25330C459A4", "text": "Funny Town Name Sign",
     "emoji": "🪧", "category": "signs", "rarity": "uncommon"},
    {"id": "348BCF77-2B49-30ED-A0BE-03F2BBA04CE5", "text": "Radar Speed Sign",
     "emoji": "📡", "category": "signs", "rarity": "common"},
    {"id": "D62EEA67-E90F-3918-8CB5-D9DACAC5A70D", "text": "Next Gas Sign",
     "emoji": "⛽", "category": "signs", "rarity": "common"},
    {"id": "02E74882-80DC-3850-8D78-01A503B62084", "text": "Amber Alert Highway Sign",
     "emoji": "⚠️", "category": "signs", "rarity": "uncommon"},
    {"id": "BCA3B438-CE22-3867-815D-74B04002D7AD", "text": "Corn Maze Sign",
     "emoji": "🌽", "category": "signs", "rarity": "rare"},
]

for t in NEW_TILES:
    assert t['id'] not in existing_ids, f"Duplicate ID: {t['id']} ({t['text']})"

squares.extend(NEW_TILES)

with open(PATH, 'w') as f:
    json.dump(squares, f, indent=2, ensure_ascii=False)

print(f"OK: added {len(NEW_TILES)} tiles. Pool size now: {len(squares)}")
```

Save as `tools/add_tiles_landmarks_food_signs.py` and run:

```bash
python3 tools/add_tiles_landmarks_food_signs.py
```

Expected: `OK: added 15 tiles. Pool size now: 198`

- [ ] **Step 2: Commit**

```bash
git add RoadTripBingo/Resources/squares.json
git commit -m "content: add 15 new base tiles (landmarks, food, signs)

Landmarks: Giant Roadside Statue, Abandoned Building, Rock Tunnel,
Rest Stop Playground (all uncommon/common)

Food: Buc-ee's, Sonic Drive-In, In-N-Out Burger (uncommon),
Fireworks Superstore, Pilot/Love's Truck Stop, Roadside Souvenir Shop (common)

Signs: Funny Town Name Sign, Amber Alert Highway Sign (uncommon),
Radar Speed Sign, Next Gas Sign (common), Corn Maze Sign (rare)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 7: Run tests — verify base pool is healthy

**Files:** none modified

- [ ] **Step 1: Run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests \
       -only-testing:RoadTripBingoTests/BingoSquareTests \
  2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: ALL tests PASS — including both new tests from Task 2.
If any fail, fix before continuing. Common issues: duplicate UUID (check the assert output from the scripts), invalid category string (must be one of `vehicles nature food landmarks weather signs`), invalid rarity string.

---

### Task 8: Update Interstate pack — add 2 pack-specific tiles

**Files:**
- Modify: `RoadTripBingo/Resources/pack-interstate.json`

- [ ] **Step 1: Run the update script**

```python
#!/usr/bin/env python3
"""Task 8: add State Trooper Car and Welcome Center to the Interstate pack"""
import json

PATH = 'RoadTripBingo/Resources/pack-interstate.json'

with open(PATH) as f:
    pack = json.load(f)

existing_ids = {t['id'] for t in pack['tiles']}

NEW_TILES = [
    {
        "id": "9CB9371C-354F-3F5B-ACCF-914CFE365C29",
        "text": "State Trooper Car",
        "emoji": "🚔",
        "category": "vehicles",
        "rarity": "uncommon"
    },
    {
        "id": "D1676C11-21B1-32CB-9850-777B52120238",
        "text": "Welcome Center",
        "emoji": "🗺️",
        "category": "landmarks",
        "rarity": "uncommon"
    },
]

for t in NEW_TILES:
    assert t['id'] not in existing_ids, f"Duplicate: {t['id']}"

pack['tiles'].extend(NEW_TILES)

with open(PATH, 'w') as f:
    json.dump(pack, f, indent=2, ensure_ascii=False)

print(f"OK: Interstate pack now has {len(pack['tiles'])} pack-specific tiles")
```

Save as `tools/update_pack_interstate.py` and run:

```bash
python3 tools/update_pack_interstate.py
```

Expected: `OK: Interstate pack now has 6 pack-specific tiles`

- [ ] **Step 2: Commit**

```bash
git add RoadTripBingo/Resources/pack-interstate.json
git commit -m "content: add State Trooper Car + Welcome Center to Interstate pack

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 9: Update Farm Country pack — rename Irrigation Pivot, remove Grain Elevator

**Files:**
- Modify: `RoadTripBingo/Resources/pack-farm-country.json`

- [ ] **Step 1: Run the update script**

```python
#!/usr/bin/env python3
"""Task 9: rename Irrigation Pivot, remove Grain Elevator from Farm Country pack"""
import json

PATH = 'RoadTripBingo/Resources/pack-farm-country.json'
IRRIGATION_PIVOT_ID = 'F1A00001-0000-0000-0000-000000000002'
GRAIN_ELEVATOR_ID   = 'CB998D77-472F-4201-8025-9790FE1B3C82'

with open(PATH) as f:
    pack = json.load(f)

renamed = False
for tile in pack['tiles']:
    if tile['id'] == IRRIGATION_PIVOT_ID:
        tile['text'] = 'Giant Circular Sprinkler'
        renamed = True

pack['tiles'] = [t for t in pack['tiles'] if t['id'] != GRAIN_ELEVATOR_ID]

assert renamed, "Irrigation Pivot tile not found — check ID"
assert not any(t['id'] == GRAIN_ELEVATOR_ID for t in pack['tiles']), \
    "Grain Elevator was not removed"

with open(PATH, 'w') as f:
    json.dump(pack, f, indent=2, ensure_ascii=False)

print(f"OK: Farm Country pack now has {len(pack['tiles'])} pack-specific tiles")
```

Save as `tools/update_pack_farm_country.py` and run:

```bash
python3 tools/update_pack_farm_country.py
```

Expected: `OK: Farm Country pack now has 4 pack-specific tiles`

- [ ] **Step 2: Commit**

```bash
git add RoadTripBingo/Resources/pack-farm-country.json
git commit -m "content: Farm Country pack — rename Irrigation Pivot, remove Grain Elevator

'Irrigation Pivot' → 'Giant Circular Sprinkler' (kids know what it looks like)
Removed Grain Elevator (consolidates with Grain Silo — kids can't tell them apart)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 10: Update Mountains pack — rename Switchback Road, add 5 tiles

**Files:**
- Modify: `RoadTripBingo/Resources/pack-mountains.json`

- [ ] **Step 1: Run the update script**

```python
#!/usr/bin/env python3
"""Task 10: rename Switchback Road, add 5 tiles to Mountains pack"""
import json

PATH = 'RoadTripBingo/Resources/pack-mountains.json'
SWITCHBACK_ID = 'F1A00001-0000-0000-0000-000000000010'

with open(PATH) as f:
    pack = json.load(f)

existing_ids = {t['id'] for t in pack['tiles']}

# Rename
renamed = False
for tile in pack['tiles']:
    if tile['id'] == SWITCHBACK_ID:
        tile['text'] = 'Zigzag Mountain Road'
        renamed = True
assert renamed, "Switchback Road tile not found"

NEW_TILES = [
    {
        "id": "A2C0272D-0B98-3147-B23F-8D25A6230917",
        "text": "Waterfall by Road",
        "emoji": "💦",
        "category": "nature",
        "rarity": "uncommon"
    },
    {
        "id": "1AE6E43B-029D-3776-8BE2-29B18AB4D903",
        "text": "Mountain Goat",
        "emoji": "🐐",
        "category": "nature",
        "rarity": "rare"
    },
    {
        "id": "DC5571A7-8015-37E7-918F-10C9ED873906",
        "text": "Snowplow",
        "emoji": "❄️",
        "category": "vehicles",
        "rarity": "uncommon"
    },
    {
        "id": "96FBDFB3-BC29-3026-B150-7A28B1EDC3B8",
        "text": "Alpine Meadow",
        "emoji": "🌄",
        "category": "nature",
        "rarity": "common"
    },
    {
        "id": "B360FA15-6DA3-38B1-91F9-1EB84E03C09B",
        "text": "Ski Slope Visible",
        "emoji": "⛷️",
        "category": "landmarks",
        "rarity": "uncommon"
    },
]

for t in NEW_TILES:
    assert t['id'] not in existing_ids, f"Duplicate: {t['id']}"

pack['tiles'].extend(NEW_TILES)

with open(PATH, 'w') as f:
    json.dump(pack, f, indent=2, ensure_ascii=False)

print(f"OK: Mountains pack now has {len(pack['tiles'])} pack-specific tiles")
```

Save as `tools/update_pack_mountains.py` and run:

```bash
python3 tools/update_pack_mountains.py
```

Expected: `OK: Mountains pack now has 7 pack-specific tiles`

- [ ] **Step 2: Commit**

```bash
git add RoadTripBingo/Resources/pack-mountains.json
git commit -m "content: Mountains pack — rename Switchback Road, add 5 tiles

'Switchback Road' → 'Zigzag Mountain Road' (kids know the visual, not the term)
Added: Waterfall by Road, Mountain Goat (rare), Snowplow, Alpine Meadow, Ski Slope Visible

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 11: Update City pack — State Capitol → veryRare, add 8 tiles

**Files:**
- Modify: `RoadTripBingo/Resources/pack-city.json`

- [ ] **Step 1: Run the update script**

```python
#!/usr/bin/env python3
"""Task 11: bump State Capitol to veryRare, add 8 tiles to City pack"""
import json

PATH = 'RoadTripBingo/Resources/pack-city.json'
STATE_CAPITOL_ID = 'A567E170-5E12-459A-B3E7-A552CB7D7388'

with open(PATH) as f:
    pack = json.load(f)

existing_ids = {t['id'] for t in pack['tiles']}

# Bump State Capitol rarity
bumped = False
for tile in pack['tiles']:
    if tile['id'] == STATE_CAPITOL_ID:
        tile['rarity'] = 'veryRare'
        bumped = True
assert bumped, "State Capitol tile not found"

NEW_TILES = [
    {
        "id": "6213065F-B829-37B8-B10C-85A97907D061",
        "text": "Yellow Taxi",
        "emoji": "🚕",
        "category": "vehicles",
        "rarity": "uncommon"
    },
    {
        "id": "20D6D1E7-BA9F-3471-B7EB-A157D72C7244",
        "text": "Skyscraper",
        "emoji": "🏙️",
        "category": "landmarks",
        "rarity": "veryCommon"
    },
    {
        "id": "A60758E5-C8CE-3DE2-BAE7-8993CD7F963A",
        "text": "Street Food Cart",
        "emoji": "🌭",
        "category": "food",
        "rarity": "uncommon"
    },
    {
        "id": "0ADD601C-7BE3-3CC8-A5B2-0CE9C608CC57",
        "text": "One-Way Street Sign",
        "emoji": "↗️",
        "category": "signs",
        "rarity": "common"
    },
    {
        "id": "E85E47BC-8DFA-3E6B-BEF1-26FB174F1C90",
        "text": "Parking Garage",
        "emoji": "🅿️",
        "category": "landmarks",
        "rarity": "common"
    },
    {
        "id": "C0F193C0-8F50-3677-930B-2DBE16ADC811",
        "text": "City Mural",
        "emoji": "🎨",
        "category": "landmarks",
        "rarity": "uncommon"
    },
    {
        "id": "798C809A-F953-397E-9DC0-9FEAA60276CE",
        "text": "Subway Entrance",
        "emoji": "🚇",
        "category": "landmarks",
        "rarity": "uncommon"
    },
    {
        "id": "66852A88-CC90-3CC3-BF71-2A993BFAEEFA",
        "text": "Bike Share Station",
        "emoji": "🚲",
        "category": "landmarks",
        "rarity": "common"
    },
]

for t in NEW_TILES:
    assert t['id'] not in existing_ids, f"Duplicate: {t['id']}"

pack['tiles'].extend(NEW_TILES)

with open(PATH, 'w') as f:
    json.dump(pack, f, indent=2, ensure_ascii=False)

print(f"OK: City pack now has {len(pack['tiles'])} pack-specific tiles")
```

Save as `tools/update_pack_city.py` and run:

```bash
python3 tools/update_pack_city.py
```

Expected: `OK: City pack now has 9 pack-specific tiles`

- [ ] **Step 2: Commit**

```bash
git add RoadTripBingo/Resources/pack-city.json
git commit -m "content: City pack — State Capitol→veryRare, add 8 tiles

State Capitol bumped to veryRare (the crown jewel of the city pack).
Added: Skyscraper (veryCommon), One-Way Street Sign + Parking Garage +
Bike Share Station (common), Yellow Taxi + Street Food Cart + City Mural +
Subway Entrance (uncommon)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 12: Final test run + integrity check

**Files:** none modified

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests \
       -only-testing:RoadTripBingoTests/BingoSquareTests \
       -only-testing:RoadTripBingoTests/TilePackTests \
  2>&1 | grep -E "(PASS|FAIL|error:|Test Suite)"
```

Expected: all tests PASS.

- [ ] **Step 2: Final pool integrity check**

```bash
python3 -c "
import json

BASE = 'RoadTripBingo/Resources/'
with open(BASE + 'squares.json') as f:
    sq = json.load(f)

valid_categories = {'vehicles','nature','food','landmarks','weather','signs'}
valid_rarities   = {'veryCommon','common','uncommon','rare','veryRare'}

errors = []
ids = [s['id'] for s in sq]
if len(ids) != len(set(ids)):
    errors.append('DUPLICATE IDs in squares.json')

for s in sq:
    if s['category'] not in valid_categories:
        errors.append(f'Bad category: {s[\"text\"]} → {s[\"category\"]}')
    if s['rarity'] not in valid_rarities:
        errors.append(f'Bad rarity: {s[\"text\"]} → {s[\"rarity\"]}')

packs = ['pack-interstate','pack-farm-country','pack-desert-southwest',
         'pack-mountains','pack-beach-coast','pack-city']
all_pack_tile_ids = set()
for p in packs:
    with open(BASE + p + '.json') as f:
        pack = json.load(f)
    for t in pack.get('tiles', []):
        if t['id'] in all_pack_tile_ids:
            errors.append(f'Duplicate pack tile ID across packs: {t[\"id\"]} ({t[\"text\"]})')
        all_pack_tile_ids.add(t['id'])
        if t['category'] not in valid_categories:
            errors.append(f'Bad category in {p}: {t[\"text\"]} → {t[\"category\"]}')
        if t['rarity'] not in valid_rarities:
            errors.append(f'Bad rarity in {p}: {t[\"text\"]} → {t[\"rarity\"]}')

if errors:
    for e in errors:
        print('ERROR:', e)
else:
    from collections import Counter
    rarity_dist = Counter(s['rarity'] for s in sq)
    print(f'OK: {len(sq)} base tiles, no integrity errors')
    print('Rarity distribution:', dict(sorted(rarity_dist.items())))
"
```

Expected output: `OK: 198 base tiles, no integrity errors` followed by the rarity distribution.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "content: complete tile content update — 27 new tiles, 4 pack expansions

Summary of all changes:
- Fixed Billboard (food→signs) and Car Wash (food→landmarks) categories
- Renamed 7 confusing tiles to kid-friendly names
- Replaced Double-Decker Bus with Stretched Limousine
- Adjusted 7 rarities (Rainbow, Hot Air Balloon, Ice Cream Truck easier;
  Yard Sale very common; RV common; Dollar General common; Route 66 rare)
- Added 27 new base tiles across vehicles/nature/landmarks/food/signs
- Interstate: +State Trooper Car, Welcome Center
- Farm Country: renamed Irrigation Pivot → Giant Circular Sprinkler, removed Grain Elevator
- Mountains: renamed Switchback Road → Zigzag Mountain Road, +5 tiles
- City: State Capitol→veryRare, +8 tiles (Skyscraper, Yellow Taxi, etc.)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```
