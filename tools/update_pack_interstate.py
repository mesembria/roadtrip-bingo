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
