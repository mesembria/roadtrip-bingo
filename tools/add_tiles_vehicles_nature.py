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
