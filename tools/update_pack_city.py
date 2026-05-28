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
