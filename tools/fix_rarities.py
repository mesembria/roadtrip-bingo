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
