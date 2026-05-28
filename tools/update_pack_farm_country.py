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
