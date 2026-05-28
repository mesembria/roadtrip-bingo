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
