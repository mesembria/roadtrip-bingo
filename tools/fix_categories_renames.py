#!/usr/bin/env python3
"""Task 3: fix categories and rename tiles in squares.json"""
import json

PATH = 'RoadTripBingo/Resources/squares.json'

with open(PATH) as f:
    squares = json.load(f)

CHANGES = {
    # Category fixes
    '6BA6FFCC-5BC1-4A77-AD4C-E80BC54241EE': {'category': 'signs'},        # Billboard: food → signs
    '54125617-DEA9-4FFF-B967-ACEEBF3E60A5': {'category': 'landmarks'},    # Car Wash: food → landmarks
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
