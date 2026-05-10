# Road Trip Bingo — Design Spec

**Date:** 2026-05-10  
**Platform:** iPadOS 16+, landscape orientation  
**Tech:** SwiftUI + MultipeerConnectivity

---

## Overview

A multiplayer road trip bingo game for kids, each playing on their own iPad. Players get unique randomised bingo boards drawn from a shared pool of road trip items. First to complete a line wins. No accounts, no codes — nearby devices discover each other automatically.

---

## Players & Setup

- Target users: children in a car, competing against each other
- Each child has their own iPad
- 2–4 players per game (enforced: Start Game requires ≥2)
- Honor system: players mark squares themselves, no verification

---

## Screen Flow

```
Home → Lobby → Game → BINGO! → Play Again
                                    ↓
                               New Game (same players, new boards)
                               or Go Home
```

### Home Screen
- Player enters their name (persisted via `UserDefaults` for next session)
- Two buttons: **Create Game** (becomes host) and **Join Game**

### Lobby Screen — Host
- Advertises game via Multipeer under the name `"\(playerName)'s Game"`
- Shows connected players as they appear (name + green dot)
- **Start Game** button is disabled until ≥2 players are connected
- Host taps Start Game when ready

### Lobby Screen — Joiner
- Browses for nearby Multipeer sessions automatically (no code entry)
- Shows a list of discovered games; tap one to join
- After joining: shows all connected players and "Waiting for host to start…"

### Game Screen
- Full 5×5 bingo grid fills the screen (landscape)
- **Opponent strip** at top: one mini 5×5 dot-grid per opponent (blue dot = checked, gold = FREE, dark = unchecked), name and checked count below each
- Tap a square to mark it (filled blue + checkmark); tap again to unmark
- **BINGO!** button appears (animated) when any row, column, or diagonal is complete
- Tapping BINGO! broadcasts win and transitions all devices to the win screen

### BINGO! Screen
- Winner's device: full-screen celebration with confetti animation, winning line highlighted
- Other devices: overlay banner "Emma got BINGO!" with the winner's completed line shown
- All devices show a **Continue** button to proceed to Play Again

### Play Again Screen
- Shows win tally for the session ("Emma: 2 wins, Liam: 1 win")
- **New Game** (host only): deals fresh boards to all still-connected players
- **Go Home**: returns to Home screen, disconnects from session

---

## Architecture

Three layers with clean interfaces between them:

```
UI Layer       SwiftUI views + @StateObject / @ObservableObject view models
Game Layer     GameEngine — board state, win detection, square toggling
Network Layer  MultipeerSession — wraps MCSession, advertiser, browser
```

- `MultipeerSession` communicates upward via a delegate/callback; the game layer never imports MultipeerConnectivity directly
- The host is the sole source of truth for board assignment; after game start each device is authoritative over its own board
- All message types are encoded as JSON and sent as `Data` via `MCSession.send(_:toPeers:with:)`

---

## Data Model

```swift
struct BingoSquare: Codable, Identifiable {
    let id: UUID
    let text: String
    let emoji: String
    let category: SquareCategory
}

enum SquareCategory: String, Codable {
    case vehicles, nature, food, landmarks, weather, signs
}

struct BingoBoard {
    // 25 entries row-major; index 12 is always the FREE square (a sentinel BingoSquare
    // with id UUID.zero, text "FREE", emoji "⭐", category .landmarks).
    // The host inserts this sentinel when assembling boards before sending.
    let squares: [BingoSquare]
    var marked: Set<UUID>   // FREE square's UUID pre-inserted at game start
}

struct Player: Identifiable {
    let id: MCPeerID        // MCPeerID is Hashable; used as Identifiable.id
    let name: String
    var board: BingoBoard?
}

enum GameState {
    case lobby
    case playing
    case won(by: MCPeerID)
}

struct GameSession {
    let host: Player
    // `players` includes the host as the first entry.
    // All message recipients are derived from players.filter { $0.id != localPeerID }.
    var players: [Player]
    var state: GameState
}
```

---

## Square Pool

- Bundled as `squares.json` in the app target (~150 squares total)
- Distributed across 6 categories (~25 per category):
  - **Vehicles** — semi truck, RV, motorcycle, school bus, tractor, pickup truck, police car, fire truck, double-decker bus, helicopter, small plane, horse trailer, flatbed truck, dump truck, ambulance, convertible, food truck, mail truck, boat on trailer, construction vehicle
  - **Nature** — cow, horse, deer, barn, sunflower field, hay bale, wind turbine, mountain, river, lake, rainbow, double rainbow, cactus, cornfield, orchard, flock of birds, goat, sheep, pig, dog in car window
  - **Food & Stops** — McDonald's golden arches, Starbucks, Subway, gas station, rest stop, drive-through, billboard, roadside diner, fruit stand, ice cream stand
  - **Landmarks** — bridge, overpass, railroad crossing, state border sign, toll booth, welcome sign, water tower, church steeple, grain silo, sports stadium, fairground
  - **Weather** — dark clouds, fog, dust storm, snow on mountains, puddles, sun glare, thunderstorm, lightning
  - **Signs & Roads** — speed limit 75+, construction zone, detour sign, no passing zone, weigh station, mile marker ending in 0, highway interchange, rest area sign
- At game start the host shuffles the full pool and deals 24 unique squares to each player; the FREE space (center) is fixed and pre-marked

---

## Multiplayer Message Protocol

Four message types (JSON-encoded, sent reliably):

| Message | Sender | Payload | Purpose |
|---|---|---|---|
| `gameStarted` | host → all | `[peerID: [BingoSquare]]` | Delivers each player's 24 squares simultaneously |
| `squareToggled` | any → all | `squareId: UUID, isMarked: Bool` | Keeps opponent mini-grids in sync |
| `bingoAnnounced` | winner → all | `by: peerID` | Triggers win screen on all devices |
| `playAgain` | host → all | `[peerID: [BingoSquare]]` | Delivers fresh boards and restarts game (same structure as `gameStarted`) |

---

## Win Detection

Local on each device. After every tap, `GameEngine` checks all 12 lines:

- 5 rows (indices 0–4, 5–9, 10–14, 15–19, 20–24)
- 5 columns (indices 0,5,10,15,20 … 4,9,14,19,24)
- 2 diagonals (0,6,12,18,24 and 4,8,12,16,20)

A line is complete when all 5 squares in it are in `board.marked`. When any line completes, the BINGO! button becomes visible with a spring animation. The player must tap it to claim the win — no auto-win.

---

## Persistence

- Player name: `UserDefaults`
- Session win history (current session only): in-memory, shown on Play Again screen
- No long-term persistence of win history or custom square pools in v1

---

## Out of Scope (v1)

- Custom square pools / parent editing
- Sound effects or haptics (can add later)
- Portrait orientation support
- More than 4 players
- Reconnection handling if a player drops mid-game
