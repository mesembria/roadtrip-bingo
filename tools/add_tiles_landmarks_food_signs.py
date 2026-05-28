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
