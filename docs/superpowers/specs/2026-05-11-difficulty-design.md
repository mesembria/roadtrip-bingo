# Difficulty & Rarity Design Spec

**Date:** 2026-05-11
**Feature:** Per-player difficulty levels driven by square rarity

---

## Overview

Each bingo square gets a `rarity` classification describing how likely a player is to spot it on a real road trip. Players choose a difficulty level in the lobby before the game starts. The host deals each player a board weighted toward their chosen difficulty. A Backseat player gets mostly easy-to-spot squares; a Navigator player gets a board stacked with rare sightings.

---

## Data Model

### SquareRarity

New enum added to `BingoSquare`:

```swift
enum SquareRarity: String, Codable, CaseIterable {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare
}

struct BingoSquare: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let emoji: String
    let category: SquareCategory
    let rarity: SquareRarity      // new
}
```

### BoardDifficulty

New enum stored per player in AppState:

```swift
enum BoardDifficulty: String, Codable, CaseIterable {
    case backseat   // Easy
    case shotgun    // Medium
    case navigator  // Hard

    var displayName: String {
        switch self {
        case .backseat:  return "Backseat"
        case .shotgun:   return "Shotgun"
        case .navigator: return "Navigator"
        }
    }
}
```

### squares.json

All 150 entries gain a `"rarity"` key. IDs are unchanged. The rarity values are hand-classified and committed as the permanent source of truth — the generation script (`makeSquares.swift`) is updated to emit the field but the JSON is not regenerated (which would change IDs).

---

## Rarity Classifications (all 150 squares)

### Vehicles
| Square | Rarity |
|---|---|
| Semi Truck | veryCommon |
| Pickup Truck | veryCommon |
| Motorcycle | veryCommon |
| School Bus | common |
| Police Car | common |
| Minivan | veryCommon |
| Sports Car | common |
| Tow Truck | common |
| Flatbed Truck | common |
| Dump Truck | common |
| Ambulance | uncommon |
| Fire Truck | uncommon |
| RV | uncommon |
| Food Truck | uncommon |
| Mail Truck | uncommon |
| Convertible | uncommon |
| Construction Vehicle | common |
| Boat on Trailer | uncommon |
| Horse Trailer | rare |
| Tank Truck | rare |
| Double-Decker Bus | rare |
| Ice Cream Truck | rare |
| Small Plane | rare |
| Helicopter | rare |
| Tractor | uncommon |

### Nature
| Square | Rarity |
|---|---|
| Cow | veryCommon |
| Red Barn | veryCommon |
| Hay Bale | veryCommon |
| Cornfield | veryCommon |
| Flock of Birds | veryCommon |
| Horse | common |
| Sheep | common |
| Pig | common |
| Goat | common |
| Dog in Car Window | common |
| Deer | uncommon |
| Sunflower Field | uncommon |
| Wind Turbine | uncommon |
| Mountain | uncommon |
| River | common |
| Lake | common |
| Cactus | uncommon |
| Orchard | uncommon |
| Vineyard | uncommon |
| Wildflowers | common |
| Waterfall | uncommon |
| Buffalo | rare |
| Hawk | uncommon |
| Rainbow | rare |
| Double Rainbow | veryRare |

### Food & Stops
| Square | Rarity |
|---|---|
| Gas Station | veryCommon |
| McDonald's | veryCommon |
| Subway | veryCommon |
| Dollar General | veryCommon |
| Rest Stop | veryCommon |
| Starbucks | common |
| Wendy's | common |
| Taco Bell | common |
| Chick-fil-A | common |
| Truck Stop | common |
| Billboard | veryCommon |
| Drive-Through | common |
| Motel Sign | common |
| Waffle House | uncommon |
| Dairy Queen | uncommon |
| Cracker Barrel | uncommon |
| Car Wash | uncommon |
| Roadside Diner | uncommon |
| Campground Sign | uncommon |
| RV Park | uncommon |
| Fruit Stand | rare |
| Fireworks Stand | rare |
| Roadside BBQ | rare |
| Outlet Mall | uncommon |
| Ice Cream Stand | rare |

### Landmarks
| Square | Rarity |
|---|---|
| Overpass | veryCommon |
| Bridge | veryCommon |
| Railroad Crossing | common |
| Water Tower | common |
| Church Steeple | common |
| Grain Silo | common |
| State Border Sign | uncommon |
| Welcome Sign | uncommon |
| Toll Booth | uncommon |
| Sports Stadium | uncommon |
| Fairground | uncommon |
| State Capitol | uncommon |
| Radio Tower | common |
| Airport | uncommon |
| Wind Farm | uncommon |
| Solar Farm | uncommon |
| National Park Sign | rare |
| Drive-In Theater | rare |
| Covered Bridge | rare |
| Lighthouse | rare |
| Monument | rare |
| Dam | rare |
| Ghost Town | veryRare |
| Roadside Attraction | rare |
| Mining Facility | rare |

### Weather
| Square | Rarity |
|---|---|
| Dark Clouds | veryCommon |
| Sun Glare | veryCommon |
| Overcast Sky | veryCommon |
| Puddles | common |
| Sprinkles | common |
| Fog | common |
| Dramatic Sunset | common |
| Windy Flags | common |
| Snow on Mountains | uncommon |
| Morning Mist | uncommon |
| Dramatic Clouds | common |
| Low-Hanging Moon | uncommon |
| Stars Visible | uncommon |
| Thunderstorm | uncommon |
| Lightning | uncommon |
| Hail | rare |
| Frost on Windows | rare |
| Wildfire Smoke | rare |
| Dust Devil | rare |
| Ice on Road Sign | rare |
| Flash Flood Sign | rare |
| Mirage | rare |
| Hot Haze Shimmer | uncommon |
| Dust Storm | veryRare |
| Tornado Warning Sign | veryRare |

### Signs & Roads
| Square | Rarity |
|---|---|
| Construction Zone | veryCommon |
| Speed Limit 75+ | veryCommon |
| Mile Marker ×0 | common |
| Rest Area Sign | common |
| Deer Crossing Sign | common |
| Highway Interchange | common |
| No Passing Zone | common |
| Detour Sign | uncommon |
| Weigh Station | uncommon |
| Low Clearance Sign | uncommon |
| Wrong Way Sign | uncommon |
| Divided Highway Sign | uncommon |
| Scenic Overlook Sign | uncommon |
| Historical Marker | uncommon |
| Adopt-a-Highway Sign | common |
| Road Narrows Sign | uncommon |
| Bridge Ices Sign | uncommon |
| Slippery When Wet | uncommon |
| Merging Traffic Sign | common |
| End Construction Sign | uncommon |
| State Highway Sign | common |
| Falling Rock Sign | rare |
| Chain Control Sign | rare |
| Runaway Truck Ramp | rare |
| No U-Turn Sign | uncommon |

---

## Network Protocol

One new message added to `MultipeerMessage`:

```swift
case difficultyChosen(byName: String, difficulty: BoardDifficulty)
```

| Message | Sender | Payload | Purpose |
|---|---|---|---|
| `difficultyChosen` | any → host | `byName: String, difficulty: BoardDifficulty` | Tells host a player's chosen difficulty |

- Sent immediately when a player changes their picker in the lobby
- The host is the only device that needs to store this (it deals the boards)
- Default is `.backseat` — no message is sent if a player never touches the picker
- Choice is locked when the host taps Start Game

AppState gains:
```swift
@Published var playerDifficulty: BoardDifficulty = .backseat   // local player's choice
var playerDifficulties: [String: BoardDifficulty] = [:]        // host only: name → difficulty
```

---

## Board Dealing — Weighted Mix

`SquarePool.dealBoards()` signature changes to accept a difficulty per player:

```swift
static func dealBoards(
    for players: [(name: String, difficulty: BoardDifficulty)],
    from pool: [BingoSquare]
) -> [String: [BingoSquare]]
```

For each player, 24 squares are sampled from a weighted draw across the 5 rarity tiers:

| Tier | Backseat | Shotgun | Navigator |
|---|---|---|---|
| Very Common | 40% | 20% | 5% |
| Common | 35% | 30% | 15% |
| Uncommon | 20% | 30% | 30% |
| Rare | 5% | 15% | 35% |
| Very Rare | 0% | 5% | 15% |

Concretely for a 24-square board:
- **Backseat:** ~10 very common, ~8 common, ~5 uncommon, ~1 rare, 0 very rare
- **Shotgun:** ~5 very common, ~7 common, ~7 uncommon, ~4 rare, ~1 very rare
- **Navigator:** ~1 very common, ~4 common, ~7 uncommon, ~8 rare, ~4 very rare

**Sampling algorithm:**
1. Separate pool into 5 buckets by rarity
2. For each player, build a 24-item draw list by taking `round(24 * weight)` from each bucket (adjust last bucket to hit exactly 24)
3. Shuffle within each bucket before drawing to prevent players getting the same squares
4. Insert FREE at index 12 as usual
5. Non-overlap between players is best-effort: the host draws from separate shuffled pools per rarity tier so duplicates are minimised, but not guaranteed when the pool is thin (e.g. only 5 very rare squares for 4 Navigator players)

---

## UI Changes

Only `LobbyView` changes. No other screens are affected.

**Both host and joiner** see a difficulty picker in the lobby, above the player list (host) or above "Waiting for host…" (joiner):

```
[Backseat]  [Shotgun]  [Navigator]
```

- Segmented-style three-button picker, Backseat selected by default
- Tapping a button updates `appState.playerDifficulty` locally and sends `difficultyChosen` to the host
- Host's picker updates their own `playerDifficulty` locally (no message needed — host deals their own board directly)

**Host lobby** — each connected player row shows their difficulty badge:
```
● Liam  ·  Backseat
● Zoe   ·  Navigator
```

Picker and badges disappear once the game screen is shown.

---

## Out of Scope

- Displaying difficulty on the game screen or win screen
- Per-category difficulty tuning
- Allowing difficulty change after Start Game is tapped
