#!/usr/bin/env python3
"""Add 35 new tiles to squares.json (expansion: vehicle variants, license plates, I Spy)."""
import json
from pathlib import Path

REPO_ROOT    = Path(__file__).parent.parent
SQUARES_JSON = REPO_ROOT / "RoadTripBingo/Resources/squares.json"

NEW_TILES = [
    # ── Vehicle Variations ────────────────────────────────────────────────────
    {
        "id": "9B065D10-BFC4-4F13-B55E-4C381E93B5F1",
        "text": "Blue Pickup Truck",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A cobalt blue full-size pickup truck with chrome trim and a clean open bed, seen from a three-quarter angle on a country road",
    },
    {
        "id": "F13130B6-F91E-4AB0-8F5E-0D78012FED10",
        "text": "Jeep with Doors Off",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A Jeep Wrangler with no doors and no roof on a sunny day, passengers visible with wind-blown hair on a two-lane road",
    },
    {
        "id": "EE025CEB-CF0C-4B8B-B2C4-5DD5FABF484C",
        "text": "VW Beetle",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A cheerful round Volkswagen Beetle in bright yellow, seen from a three-quarter front angle showing its distinctive bug-eye headlights",
    },
    {
        "id": "49DCAF71-20F7-425E-83C3-BEA541E82C01",
        "text": "Moving Truck",
        "category": "vehicles",
        "rarity": "common",
        "description": "A large orange U-Haul moving truck with a tall cargo box, a bicycle wheel poking out the slightly-open back door, on a highway",
    },
    {
        "id": "9811541E-7462-4E55-9D72-1EC50E853487",
        "text": "RV Towing a Car",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A huge white motorhome with a small hatchback on a flat tow bar trailing behind it on an open highway — the classic toad",
    },
    {
        "id": "4A6F0A09-BEEE-4B22-9F08-DD3FA5E7861D",
        "text": "Camper Trailer",
        "category": "vehicles",
        "rarity": "common",
        "description": "A pickup truck towing a long white travel trailer with a rounded front, a bike rack on the back, and a small AC unit on the roof",
    },
    {
        "id": "8A6DDE7A-D898-4163-B368-7D8527BA7EDB",
        "text": "Refrigerated Semi Trailer",
        "category": "vehicles",
        "rarity": "common",
        "description": "A white semi truck with a shiny aluminum refrigerated trailer, the boxy refrigeration unit visible and humming on the front wall of the trailer",
    },
    {
        "id": "02F27115-3015-4E82-8D0B-64793ADF6E5E",
        "text": "Oversize Load",
        "category": "vehicles",
        "rarity": "rare",
        "description": "A flatbed semi truck carrying an enormous piece of industrial machinery, flanked by two yellow OVERSIZE LOAD pilot cars with flashing amber lights",
    },
    {
        "id": "391C52F2-7048-4306-A5DD-5B7E31F30754",
        "text": "All-Pink Car",
        "category": "vehicles",
        "rarity": "rare",
        "description": "A full-size sedan painted entirely bubblegum pink — hood, doors, roof, and bumpers all the same loud color — cruising on an ordinary highway among regular-colored cars",
    },
    {
        "id": "6095A398-03E7-408D-872B-6F4CA92CF523",
        "text": "Hay Bale Truck",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A flatbed truck stacked three or four bales high with giant round hay bales wrapped in white plastic netting, slowly making its way down a country road",
    },
    {
        "id": "43EFE221-9ED9-4310-8AD7-48D2E80EA9BD",
        "text": "VW Microbus",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A retro Volkswagen van in a two-tone white-on-top and bright-blue-on-bottom paint scheme driving down a scenic highway",
    },
    {
        "id": "482FB7B8-8EE6-40A8-969B-59C5B3D277FF",
        "text": "Motorcycle with Sidecar",
        "category": "vehicles",
        "rarity": "rare",
        "description": "A motorcycle with an attached sidecar pod on the right side, a helmeted passenger visible inside the small compartment",
    },
    {
        "id": "CFBE92A6-A1F6-4D30-B44F-7CDFB5384CD1",
        "text": "Semi with Double Trailers",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "An extra-long semi truck hauling two full-length trailers connected end-to-end, its very long silhouette snaking down the highway",
    },
    # ── License Plate Spotting ────────────────────────────────────────────────
    {
        "id": "12A965BC-8552-456E-90AF-0F6C857FF2A0",
        "text": "Vanity Plate — Phrase",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A state license plate with a custom personal message spelled out in letters — like SUNLVR or GOTHERE — instead of a random code",
    },
    {
        "id": "C2BCE873-5656-4822-B94C-FD561CEE650F",
        "text": "Vanity Plate — Name",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A vanity license plate spelling out a real person's first name in full — like SARAH or MIKEJR — in bold block letters",
    },
    {
        "id": "9C3F7FB1-5250-481F-BA08-DA080930F4F5",
        "text": "Hawaiian License Plate",
        "category": "vehicles",
        "rarity": "rare",
        "description": "A Hawaii state license plate featuring the state's distinctive pastel rainbow design, standing out among continental US plates",
    },
    {
        "id": "2471C006-1253-4783-B0D2-41AE387D3C85",
        "text": "Canadian License Plate",
        "category": "vehicles",
        "rarity": "rare",
        "description": "A Canadian province license plate from Ontario, British Columbia, or Quebec — clearly different colors, fonts, and format from any American state plate",
    },
    {
        "id": "CB459265-48C5-464C-BC93-0E1FA56736A1",
        "text": "Plate with 3 Letters in a Row",
        "category": "vehicles",
        "rarity": "common",
        "description": "A license plate where you can spot three letters grouped consecutively — like ABC or XYZ — anywhere in the sequence",
    },
    {
        "id": "3CDE83B2-AE06-430C-B480-40E5CFB51A8E",
        "text": "Plate with 3 Numbers in a Row",
        "category": "vehicles",
        "rarity": "common",
        "description": "A license plate where you can spot three digits grouped consecutively — like 123 or 456 — anywhere in the sequence",
    },
    {
        "id": "FA504171-203E-4FB2-A2BB-96B8F4EFF1D7",
        "text": "Specialty / Scenic Plate",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A specialty license plate bearing a wildlife image, nature scene, or university logo — like a leaping dolphin, a mountain range, or a team mascot — instead of plain state text",
    },
    # ── I Spy Funny Observations ──────────────────────────────────────────────
    {
        "id": "8220E083-8E42-44FF-A985-1CA60FA75961",
        "text": "Trooper Pulling Someone Over",
        "category": "landmarks",
        "rarity": "uncommon",
        "description": "A state police car with its red and blue lights flashing, parked directly behind a car pulled over on the highway shoulder, the driver visible through their window looking nervous",
    },
    {
        "id": "6ABE672F-877D-44D0-87D0-ED1876CC2A13",
        "text": "5+ Bumper Sticker Car",
        "category": "vehicles",
        "rarity": "common",
        "description": "A car whose entire rear bumper is plastered with five or more colorful bumper stickers — vacation spots, funny sayings, opinions, and slogans all crowded together",
    },
    {
        "id": "8170774F-790E-48F1-B6BE-2CBE00354839",
        "text": "Star Wars Bumper Sticker",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A car sporting a Star Wars bumper sticker — a Rebel Alliance symbol, a Darth Vader helmet, or the words May the Force Be With You — visible on the rear of the car",
    },
    {
        "id": "4154F951-8955-4AE1-B1AC-4F91CF49833C",
        "text": "Kindness Bumper Sticker",
        "category": "vehicles",
        "rarity": "common",
        "description": "The rear of a car bearing an uplifting bumper sticker about kindness — Be Kind, Spread Kindness, or Kindness is Free in cheerful colorful letters",
    },
    {
        "id": "68B1D9C5-D513-49B7-B5BC-5BC436A37618",
        "text": "Luggage Piled on Roof Rack",
        "category": "vehicles",
        "rarity": "uncommon",
        "description": "A minivan with three suitcases, a duffel bag, and a bag of sports equipment crammed onto the roof rack, all held down with a web of bungee cords and rope",
    },
    {
        "id": "9D79F99D-5077-4C25-A5DD-1B83877B1145",
        "text": "Rooftop Cargo Box",
        "category": "vehicles",
        "rarity": "common",
        "description": "A sleek hard-shell black rooftop cargo carrier box mounted on the roof rails of a family SUV, bulging with gear for a long road trip",
    },
    {
        "id": "51132CE8-299E-4E53-B4A9-FD6265EFC423",
        "text": "Kids Making Faces at You",
        "category": "landmarks",
        "rarity": "uncommon",
        "description": "Children in the back seat of a passing car pressing their noses flat against the window glass and making silly faces at your car as the vehicles drive side by side",
    },
    {
        "id": "76D9D3D6-CD19-47A5-9895-442B3B0D92A7",
        "text": "Sleeping Passenger",
        "category": "landmarks",
        "rarity": "common",
        "description": "The passenger in the car next to yours completely asleep — head lolling against the window, mouth slightly open — while the driver carries on",
    },
    {
        "id": "B2C2C8A7-9681-4917-9978-A0A051B20A3E",
        "text": "Lemonade Stand",
        "category": "food",
        "rarity": "uncommon",
        "description": "Two or three kids at a folding table at the end of a driveway with a hand-drawn LEMONADE 50 cents sign, a big pitcher, and a stack of paper cups",
    },
    {
        "id": "D15D9B6D-AB4A-425A-8B2D-F919BE3008C8",
        "text": "Bikes on Rear Rack",
        "category": "vehicles",
        "rarity": "common",
        "description": "A minivan or SUV with two or three bicycles mounted on a rear-hanging bike rack, handlebars and wheel rims jutting out the back",
    },
    {
        "id": "08A6045A-0A6C-4CA4-945D-B23A697B6D07",
        "text": "Broken-Down Car, Hood Up",
        "category": "landmarks",
        "rarity": "uncommon",
        "description": "A car parked on the highway shoulder with its hood propped wide open and steam rising from the engine, the driver standing next to it with a phone to their ear",
    },
    {
        "id": "B680DC17-B247-409A-8590-71132BA51CB5",
        "text": "Car Packed to the Ceiling",
        "category": "vehicles",
        "rarity": "common",
        "description": "A car loaded so full of bags, pillows, boxes, and stuffed animals that you can barely see the passengers through the rear window",
    },
    {
        "id": "F4F47AEE-19EB-4630-A6A0-BFCB228663DB",
        "text": "Dog in Car",
        "category": "nature",
        "rarity": "common",
        "description": "A dog sitting in the back seat of a car, its face pressed against the side window glass from the inside, nose fogging up the glass as it watches the world go by",
    },
    {
        "id": "9B64F835-F92E-4A5D-AE22-C323BED32157",
        "text": "Flags Flying from Truck Bed",
        "category": "vehicles",
        "rarity": "common",
        "description": "A pickup truck driving with a large American flag mounted in the truck bed, the flag billowing out nearly horizontal in the wind at highway speed",
    },
    {
        "id": "E2036612-8B10-4F94-B99D-B29FA56B4A30",
        "text": "Rest Stop Dog Walk",
        "category": "nature",
        "rarity": "common",
        "description": "A happy dog on a leash at a highway rest area, straining excitedly toward a grassy patch while a sleepy traveler in pajama pants struggles to keep pace",
    },
]


def main():
    with open(SQUARES_JSON, encoding="utf-8") as f:
        squares = json.load(f)

    existing_ids = {s["id"] for s in squares}

    for tile in NEW_TILES:
        assert tile["id"] not in existing_ids, f"Duplicate ID: {tile['id']} ({tile['text']})"

    squares.extend(NEW_TILES)

    with open(SQUARES_JSON, "w", encoding="utf-8") as f:
        json.dump(squares, f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")

    print(f"✓ Added {len(NEW_TILES)} tiles. Pool size now: {len(squares)}")


if __name__ == "__main__":
    main()
