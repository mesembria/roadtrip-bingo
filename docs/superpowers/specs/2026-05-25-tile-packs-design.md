# Tile Packs Design

**Date:** 2026-05-25
**Status:** Draft

---

## Problem

Tile rarity is currently a single global value per tile. This ignores geographic context: a tractor is rare on a Kansas highway but mundane on a Kentucky farm road. Snow-capped mountains are common in Colorado and nearly impossible in Kansas. The current system treats all locations identically, which undermines immersion and game balance depending on where the family is actually driving.

---

## Solution Overview

A **tile pack** system that players activate before a session and can change between games. Each pack contributes three things: new location-exclusive tiles, rarity overrides for existing base tiles, and optional exclusions of base tiles that don't fit the context. Multiple active packs pool together. The base tile pool is always present as a floor.

---

## 1. Data Model

### `TilePack`

```swift
struct TilePack: Codable, Identifiable {
    let id: String                              // e.g. "farm-country"
    let name: String                            // "Farm Country"
    let description: String                     // short flavor text
    let imageName: String                       // asset catalog name for AI-generated image
    let tiles: [BingoSquare]                    // pack-exclusive tiles (new UUIDs)
    let rarityOverrides: [UUID: SquareRarity]   // base tile UUID → new rarity
    let excludedTileIDs: [UUID]                 // base tiles removed when this pack is active
}
```

Each pack is bundled as a JSON file named `pack-<id>.json` (e.g., `pack-farm-country.json`), loaded by a new `PackManager`.

### Conflict Resolution

When multiple packs are active:

- **Rarity overrides:** most-common-wins. For any base tile overridden by more than one active pack, the rarity furthest toward `veryCommon` is used (order: veryCommon > common > uncommon > rare > veryRare).
- **Exclusions:** union. If any active pack excludes a tile, that tile is excluded.
- **Pack-exclusive tiles:** appended from all active packs; no deduplication needed since exclusive tiles have unique UUIDs per pack.

### `PackManager`

```swift
enum PackManager {
    static func loadAll() -> [TilePack]        // loads all pack-*.json from bundle
    static func pack(id: String) -> TilePack?  // convenience lookup
}
```

---

## 2. Pool Construction

`SquarePool` gains a new `buildPool(base:activePacks:)` function. This replaces the bare `SquarePool.load()` call at game start.

**Steps:**

1. Start with the full base pool (`squares.json`)
2. Remove any base tile whose UUID appears in any active pack's `excludedTileIDs` (union of all active packs)
3. Apply rarity overrides: for each remaining base tile, collect all active pack overrides for its UUID; if any exist, use the most-common rarity
4. Append all pack-exclusive tiles from all active packs

The returned `[BingoSquare]` is passed into `dealBoards()` unchanged — no modifications to the draw or weighting logic. When `activePacks` is empty, `buildPool` returns the base pool unmodified.

```swift
static func buildPool(base: [BingoSquare], activePacks: [TilePack]) -> [BingoSquare]
```

`dealBoards()` and `dealReserve()` signatures are unchanged.

**Minimum pool check:** The pool must contain at least `players × 24 + reserve` tiles. The UI warns if the pool would run thin (see Section 3).

---

## 3. Pack Selection UI

> **Implementation note:** All visual design for this section — card layout, grid spacing, selection states, sheet presentation, Play Again integration — must be produced by the `frontend-design` skill before implementation.

### Access Points

Pack selection is available from two places:

- **Home screen:** a "Tile Packs" button near the Start Game area
- **Play Again screen:** a "Change Packs" button, enabling mid-session transitions (e.g., interstate → city)

### Pack Grid

The selection UI is presented as a sheet containing a **2-column grid** of pack cards. Each card shows:

- AI-generated image (top, fills most of the card)
- Pack name (bottom, below image)
- Selected state: highlighted border and a checkmark overlay when active

Multiple packs can be selected simultaneously. Tapping a selected pack deselects it. No minimum or maximum selection enforced in the data layer (though the pool size warning handles the empty-pool edge case).

**Rarity distribution bar:** Below the grid, a segmented horizontal bar shows the rarity breakdown of the combined active pool. Five color-coded segments represent the five rarity tiers (dark green → mid green → amber → red → deep red, from veryCommon to veryRare). A legend row beneath the bar shows the tile count per tier. The bar updates live as packs are toggled. This gives players an at-a-glance read on how easy or hard their current pool skews.

**Pool size indicator:** A line below the rarity bar shows the estimated tile count for the current selection. If the count would fall below the minimum needed for the current player count, a warning is shown inline (e.g., "Not enough tiles for 3 players — add another pack or deselect players").

### Multiplayer

Pack selection is the **host's responsibility**. The host's active pack IDs are included in the game-start broadcast (`MultipeerMessage`). All players receive the pack list and build an identical pool locally (all packs are bundled in the app on every device). Non-host players see the pack grid as read-only during a game.

### Persistence

Active pack IDs are stored in `UserDefaults` under key `"activePackIDs"` as `[String]`. The selection is restored on app launch and pre-populated on the Play Again screen.

---

## 4. Initial Pack Lineup

Six packs ship with v1. No emojis on pack names or cards.

### Interstate

**Description:** Highways, rest stops, weigh stations, and the endless white line.

**Exclusive tiles (examples):** Rest Area Sign, Weigh Station, Mile Marker, Rumble Strips, Highway Overpass, Welcome to State Sign

**Rarity overrides (examples):** Semi Truck → veryCommon, Flatbed Truck → veryCommon, Dump Truck → common

**Exclusions (examples):** none — interstate tiles are broadly compatible with the base pool

**Image prompt:**
> A wide, cinematic view of an empty American interstate highway stretching to the horizon under a big open sky with dramatic clouds. Photorealistic, golden hour lighting, warm tones, no people, no text. Shot from low to the ground looking down the road.

---

### City

**Description:** Traffic, towers, crosswalks, and the organized chaos of the American city.

**Exclusive tiles (examples):** Food Truck, One-Way Sign, Parking Garage, Skyscraper, Taxi Cab, Street Musician, Bike Lane

**Rarity overrides (examples):** Police Car → veryCommon, Ambulance → common, School Bus → veryCommon

**Exclusions (examples):** Tractor, Hay Bales, Grain Silo, Snow-Capped Mountain

**Image prompt:**
> A bustling American city street intersection from a pedestrian's eye view. Yellow taxis, crosswalk signals, tall glass buildings, urban energy. Photorealistic, warm afternoon light, vibrant but not overwhelming. No text or signs readable. No people faces visible.

---

### Farm Country

**Description:** Hay bales, open fields, livestock, and the quiet rhythm of rural America.

**Exclusive tiles (examples):** Hay Bales, Grain Silo, Combine Harvester, Horse Pasture, Irrigation Pivot, Barn, Livestock Trailer

**Rarity overrides (examples):** Tractor → veryCommon, Horse Trailer → common, Pickup Truck → veryCommon

**Exclusions (examples):** Skyscraper, Taxi Cab, Parking Garage, Subway Sign

**Image prompt:**
> A sweeping American farm landscape: golden wheat fields, a classic red barn, a grain silo, and a dirt road disappearing into the distance. Photorealistic, soft summer light, blue sky with a few clouds. No people, no text.

---

### Mountains

**Description:** Snow caps, switchbacks, pine forests, and the thin air of elevation.

**Exclusive tiles (examples):** Snow-Capped Peak, Switchback Road, Pine Forest, Rock Slide Warning Sign, Ski Resort Sign, Runaway Truck Ramp, Mountain Stream

**Rarity overrides (examples):** Snow-Capped Mountain → veryCommon (from rare), Deer → common, Motorcycle → common (mountain rides)

**Exclusions (examples):** Flat Plains, Irrigation Pivot, Grain Silo

**Image prompt:**
> A dramatic American mountain landscape: jagged snow-capped peaks, a winding two-lane highway hugging a cliff edge, evergreen forests below. Photorealistic, crisp morning light, deep blue sky. No people, no text or road signs.

---

### Beach & Coast

**Description:** Surf shops, piers, seagulls, and the salt-air side of the road.

**Exclusive tiles (examples):** Pier, Surf Shop, Seagull Flock, Convertible, Lifeguard Tower, Beach Parking Lot, Boat on Trailer

**Rarity overrides (examples):** Pickup Truck → common (beach trucks), Motorcycle → common (coastal rides)

**Exclusions (examples):** Snow-Capped Mountain, Grain Silo, Runaway Truck Ramp, Tractor

**Image prompt:**
> A classic American coastal highway alongside a wide sandy beach, ocean waves visible. A wooden pier extends into the water in the distance. Photorealistic, bright midday sun, a few palm trees. No people, no text or signs.

---

### Desert Southwest

**Description:** Saguaros, red rock, dust devils, and the vast silence of the American desert.

**Exclusive tiles (examples):** Saguaro Cactus, Red Rock Formation, Dust Devil, Trading Post Sign, Roadrunner, Dry Riverbed, Solar Farm

**Rarity overrides (examples):** Tumbleweed → veryCommon, Pickup Truck → common, Motorcycle → common

**Exclusions (examples):** Snow-Capped Mountain, Hay Bales, Grain Silo, Seagull Flock, Pier

**Image prompt:**
> A lonely two-lane desert highway cutting through a vast red-rock landscape in the American Southwest. Towering saguaro cacti on the roadside, distant mesas under a blazing blue sky. Photorealistic, harsh midday sun, long shadows. No people, no text.

---

## 5. `MultipeerMessage` Change

A new case carries the host's active pack IDs to all peers at game start:

```swift
case gameStarted(players: [...], activePackIDs: [String])
```

All devices call `PackManager.loadAll()`, filter to the received IDs, and pass the result into `buildPool(base:activePacks:)`.

---

## 6. Out of Scope

- User-created or downloaded packs (v1 ships with bundled packs only)
- Per-pack unlock gates or purchase flow
- Weighted pack mixing (one pack more dominant than another)
- GPS-based automatic pack suggestions
- Pack-level win history or challenge integration

---

## Open Questions

None — all design decisions resolved.
