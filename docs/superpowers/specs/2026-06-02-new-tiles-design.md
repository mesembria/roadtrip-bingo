# New Tiles Expansion — Design Spec

**Date:** 2026-06-02  
**Status:** Approved  
**Target audience:** 8–12 year olds on cross-country road trips  

---

## Overview

Add 35 new tiles to the global `squares.json` pool. These tiles become available to all existing packs (base, interstate, farm-country, mountains, desert-southwest, beach-coast, city).

The expansion covers three themes:
1. **Vehicle Variations** — specific color/configuration variants of common vehicle types
2. **License Plate Spotting** — tiles that send kids hunting for specific plate attributes
3. **"I Spy" Funny Observations** — new gameplay territory; humorous, relatable road trip moments

### Design Principles

- **Visually distinct from existing tiles and each other.** Every new tile must paint a clearly different image from its nearest neighbor in the pool. Variations should be interesting, not redundant.
- **Observable from a car window.** All tiles must be spottable by a kid in a moving vehicle without special equipment or conditions.
- **Age-appropriate.** Nothing scary, politically divisive, or requiring adult context to understand.
- **Same image style as existing tiles.** Descriptions are written for the existing AI image generator and follow the same "paintable scene" format.

### Note on existing dog tile

The existing pool already contains **"Dog in Car Window"** — *"A happy dog hanging its head out of a car window, ears and tongue flapping in the wind."* The new **Dog in Car** tile is its complement (dog inside the car, face against the glass). Both tiles are distinct and both belong in the pool.

---

## New Tiles

### Vehicle Variations — 13 tiles

All tiles go into `category: "vehicles"`.

| text | rarity | description |
|------|--------|-------------|
| Blue Pickup Truck | uncommon | A cobalt blue full-size pickup truck with chrome trim and a clean open bed, seen from a three-quarter angle on a country road |
| Jeep with Doors Off | uncommon | A Jeep Wrangler with no doors and no roof on a sunny day, passengers visible with wind-blown hair on a two-lane road |
| VW Beetle | uncommon | A cheerful round Volkswagen Beetle in bright yellow, seen from a three-quarter front angle showing its distinctive bug-eye headlights |
| Moving Truck | common | A large orange U-Haul moving truck with a tall cargo box, a bicycle wheel poking out the slightly-open back door, on a highway |
| RV Towing a Car | uncommon | A huge white motorhome with a small hatchback on a flat tow bar trailing behind it on an open highway — the classic "toad" |
| Camper Trailer | common | A pickup truck towing a long white travel trailer with a rounded front, a bike rack on the back, and a small AC unit on the roof |
| Refrigerated Semi Trailer | common | A white semi truck with a shiny aluminum refrigerated trailer, the boxy refrigeration unit visible and humming on the front wall of the trailer |
| Oversize Load | rare | A flatbed semi truck carrying an enormous piece of industrial machinery, flanked by two yellow "OVERSIZE LOAD" pilot cars with flashing amber lights |
| All-Pink Car | rare | A full-size sedan painted entirely bubblegum pink — hood, doors, roof, and bumpers all the same loud color — cruising on an ordinary highway among regular-colored cars |
| Hay Bale Truck | uncommon | A flatbed truck stacked three or four bales high with giant round hay bales wrapped in white plastic netting, slowly making its way down a country road |
| VW Microbus | uncommon | A retro Volkswagen van in a two-tone white-on-top and bright-blue-on-bottom paint scheme driving down a scenic highway |
| Motorcycle with Sidecar | rare | A motorcycle with an attached sidecar pod on the right side, a helmeted passenger visible inside the small compartment |
| Semi with Double Trailers | uncommon | An extra-long semi truck hauling two full-length trailers connected end-to-end, its very long silhouette snaking down the highway |

---

### License Plate Spotting — 7 tiles

All tiles go into `category: "vehicles"` (consistent with the existing "License Plate from Another State" tile).

| text | rarity | description |
|------|--------|-------------|
| Vanity Plate — Phrase | uncommon | A state license plate with a custom personal message spelled out in letters — like "SUNLVR" or "GOTHERE" — instead of a random code |
| Vanity Plate — Name | uncommon | A vanity license plate spelling out a real person's first name in full — like "SARAH" or "MIKEJR" — in bold block letters |
| Hawaiian License Plate | rare | A Hawaii state license plate featuring the state's distinctive pastel rainbow design, standing out among continental US plates |
| Canadian License Plate | rare | A Canadian province license plate from Ontario, British Columbia, or Quebec — clearly different colors, fonts, and format from any American state plate |
| Plate with 3 Letters in a Row | common | A license plate where you can spot three letters grouped consecutively — like "ABC" or "XYZ" — anywhere in the sequence |
| Plate with 3 Numbers in a Row | common | A license plate where you can spot three digits grouped consecutively — like "123" or "456" — anywhere in the sequence |
| Specialty / Scenic Plate | uncommon | A specialty license plate bearing a wildlife image, nature scene, or university logo — like a leaping dolphin, a mountain range, or a team mascot — instead of plain state text |

---

### "I Spy" Funny Observations — 15 tiles

Categories are assigned to match the nearest existing tile type in the pool. Tiles primarily about a vehicle use `vehicles`; animal moments use `nature`; food/commerce scenes use `food`; everything else uses `landmarks`.

| text | category | rarity | description |
|------|----------|--------|-------------|
| Trooper Pulling Someone Over | landmarks | uncommon | A state police car with its red and blue lights flashing, parked directly behind a car pulled over on the highway shoulder, the driver visible through their window looking nervous |
| 5+ Bumper Sticker Car | vehicles | common | A car whose entire rear bumper is plastered with five or more colorful bumper stickers — vacation spots, funny sayings, opinions, and slogans all crowded together |
| Star Wars Bumper Sticker | vehicles | uncommon | A car sporting a Star Wars bumper sticker — a Rebel Alliance symbol, a Darth Vader helmet, or the words "May the Force Be With You" — visible on the rear of the car |
| Kindness Bumper Sticker | vehicles | common | The rear of a car bearing an uplifting bumper sticker about kindness — "Be Kind", "Spread Kindness", or "Kindness is Free" in cheerful colorful letters |
| Luggage Piled on Roof Rack | vehicles | uncommon | A minivan with three suitcases, a duffel bag, and a bag of sports equipment crammed onto the roof rack, all held down with a web of bungee cords and rope |
| Rooftop Cargo Box | vehicles | common | A sleek hard-shell black rooftop cargo carrier box mounted on the roof rails of a family SUV, bulging with gear for a long road trip |
| Kids Making Faces at You | landmarks | uncommon | Children in the back seat of a passing car pressing their noses flat against the window glass and making silly faces at your car as the vehicles drive side by side |
| Sleeping Passenger | landmarks | common | The passenger in the car next to yours completely asleep — head lolling against the window, mouth slightly open — while the driver carries on |
| Lemonade Stand | food | uncommon | Two or three kids at a folding table at the end of a driveway with a hand-drawn "LEMONADE 50¢" sign, a big pitcher, and a stack of paper cups |
| Bikes on Rear Rack | vehicles | common | A minivan or SUV with two or three bicycles mounted on a rear-hanging bike rack, handlebars and wheel rims jutting out the back |
| Broken-Down Car, Hood Up | landmarks | uncommon | A car parked on the highway shoulder with its hood propped wide open and steam rising from the engine, the driver standing next to it with a phone to their ear |
| Car Packed to the Ceiling | vehicles | common | A car loaded so full of bags, pillows, boxes, and stuffed animals that you can barely see the passengers through the rear window |
| Dog in Car | nature | common | A dog sitting in the back seat of a car, its face pressed against the side window glass from the inside, nose fogging up the glass as it watches the world go by |
| Flags Flying from Truck Bed | vehicles | common | A pickup truck driving with a large American flag mounted in the truck bed, the flag billowing out nearly horizontal in the wind at highway speed |
| Rest Stop Dog Walk | nature | common | A happy dog on a leash at a highway rest area, straining excitedly toward a grassy patch while a sleepy traveler in pajama pants struggles to keep pace |

---

## Implementation Notes

### IDs
Each new tile needs a unique UUID. Generate with `uuidgen` or equivalent at implementation time.

### Images
Each tile needs a corresponding PNG in `RoadTripBingo/Resources/TileImages/<UUID>.png`. Images are generated from the `description` field using the existing AI image pipeline. No other changes are required for images to appear.

### Pack membership
These tiles go into `squares.json` only. No pack files need updating — packs reference tiles by ID and the game engine deals them from the pool. If specific packs should weight certain tiles (e.g., "Plate with 3 Letters in a Row" in the interstate pack), that's a follow-on task.

### Existing tile to keep
**"Dog in Car Window"** (ID: `EA3330C4-D621-407C-A610-A244A969D17D`) stays unchanged. The new **Dog in Car** tile is additive, not a replacement.

---

## Rarity Distribution Summary

| Rarity | Count |
|--------|-------|
| veryCommon | 0 |
| common | 14 |
| uncommon | 16 |
| rare | 5 |
| veryRare | 0 |
| **Total** | **35** |

The distribution skews common/uncommon, which is appropriate — these are observational tiles that kids should be able to find during a normal trip. The 5 rare tiles (Oversize Load, All-Pink Car, Motorcycle with Sidecar, Hawaiian Plate, Canadian Plate) are things that genuinely don't appear every day.
