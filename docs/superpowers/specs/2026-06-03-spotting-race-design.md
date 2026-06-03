# Spotting Race — Design Spec
**Date:** 2026-06-03  
**Status:** Approved for implementation planning

---

## Overview

Spotting Race is a new game type for Road Trip Bingo. All players share the same rolling grid of tiles; the first player to tap a tile claims it and scores points based on its rarity. Rounds are time-limited. The player with the highest score when the timer expires wins.

This is a parallel game type — not a round modifier — that sits alongside Classic Bingo throughout the app.

---

## Architecture

### New enum: `GameType`

```swift
enum GameType: Equatable, Codable {
    case bingo
    case spottingRace
}
```

Persisted in `UserDefaults` (`"gameType"`). Orthogonal to the existing `GameMode` (`.solo` / `.multiplayer`).

### New model: `SpottingRaceTile`

```swift
struct SpottingRaceTile: Identifiable {
    let id: UUID          // slot identity (stable across replacement, for SwiftUI animation)
    let square: BingoSquare
    let expiresAt: Date
    var claimedBy: String?       // nil = unclaimed
    var lockedBy: String?        // nil = free; set during soft-claim window
    var lockTimestamp: Date?     // used for conflict resolution
}
```

Slot identity is separate from tile identity so SwiftUI can animate the slot while the contents change.

### `AppState` additions

- `var gameType: GameType = .bingo` (published, persisted)
- `var spottingRaceTiles: [SpottingRaceTile] = []` — the 6 active slots
- `var mySpottingScore: Int = 0`
- `var opponentSpottingScores: [String: Int] = [:]`
- `var spottingRoundEndTime: Date? = nil`
- `var tilePool: [BingoSquare] = []` — shuffled queue the host draws from

New methods: `startSpottingRaceSolo()`, `startSpottingRaceGame()` (host), parallel to existing `startSoloGame()` / `startGame()`.

### `ContentView` routing

```swift
case .game:
    switch appState.gameType {
    case .bingo:        GameView()
    case .spottingRace: SpottingRaceView()
    }
```

No new `AppScreen` cases. Both modes share `.home → .lobby → .game → .win`.

### What is unchanged

`MultipeerSession`, `BingoSquare`, `SquarePool`, `PackManager`, `AmericanaTheme`, `BingoBoard`, `GameEngine`, `PowerUpType` — untouched.

---

## Home Screen

A **game mode picker** is added to the right panel of `HomeView`, above the existing action buttons. Two tappable cards: **Classic Bingo** and **Spotting Race**. Selecting a mode updates `appState.gameType` immediately and persists it.

The existing **Solo**, **Create Game**, and **Join Game** buttons are unchanged; they carry the selected `gameType` into the flow.

### Lobby

The lobby is mode-agnostic. `GameType` is embedded in the two messages that launch a round:

```swift
case gameStarted(boards: [String: [BingoSquare]], activePackIDs: [String], gameType: GameType)
case playAgain(boards: [String: [BingoSquare]], activePackIDs: [String], gameType: GameType)
```

Joining peers read `gameType` and set `appState.gameType` before transitioning to `.game`.

**Spotting Race launch:** For `gameType == .spottingRace`, no per-player boards are dealt. The host builds the tile pool, populates the 6 initial slots, and broadcasts them to peers via 6 immediate `tileReplaced` messages (one per slot) right after `gameStarted`. The `boards` field in `gameStarted` is sent as `[:]` when game type is Spotting Race.

**Classic Bingo launch:** Unchanged — boards are dealt and sent as today.

---

## Round Parameters

| Parameter | Value | Notes |
|---|---|---|
| Round duration | **5 minutes** | Configurable in a future settings screen |
| Tile lifetime | **60 seconds** | Per-slot expiry; paused during soft-claim window |
| Grid size | **6 tiles (3 × 2)** | Always populated while pool has tiles |
| Rarity distribution | **Weighted draw** | See Rarity section below |

---

## Tile Pool & Rarity Distribution

The host builds a pool using the existing `SquarePool.buildPool(base:activePacks:)`. The pool is shuffled and held as a draw queue **on the host device only** — peers never see the full pool. They receive individual tiles via `tileReplaced` messages as slots are filled or refreshed. In solo mode, `AppState` acts as its own host.

When a slot needs refilling, a tile is drawn with weighted probability by rarity:

| Rarity | Weight | Score |
|---|---|---|
| Very Common | 25% | +0 pts |
| Common | 30% | +1 pt |
| Uncommon | 25% | +2 pts |
| Rare | 15% | +4 pts |
| Very Rare | 5% | +7 pts |

Weights are applied at draw time (weighted `randomElement`). No guaranteed slot reservation in MVP. Weights are easy to tune without architectural change.

---

## Rolling Window

- 6 slots always populated (or fewer if the pool is exhausted — slots stay empty rather than crashing).
- Each tile has a 60-second `expiresAt`. The host runs a 1-second timer loop (same pattern as `AppState`'s existing pruning task). When a tile expires, the host draws a replacement and broadcasts `tileReplaced`.
- When a tile is claimed, the slot is replaced immediately after the 2-second stamp hold.
- The host is the sole authority on expiry and replacement. All clients receive `tileReplaced` messages and animate the new tile in identically.

---

## Claim Flow

### Soft-claim (tap → 2-second undo window)

1. **Player taps a tile.** Locally: stamp drops immediately (green "Spotted" for self). `lockTile` is broadcast.
2. **Opponent receives `lockTile`.** Dark overlay appears on their grid ("🔒 Philippe / Claiming…"). Tile is non-tappable.
3. **During the 2-second window.** Player sees stamp + countdown ring (top-right of image zone) + Undo chip (in band). Tile expiry is paused.
4. **Undo:** Player taps Undo → `releaseTile` broadcast → lock lifts everywhere → expiry resumes.
5. **Window expires:** `claimTile` broadcast → score credited → 2-second stamp hold begins → `tileReplaced` sent by host after hold.

### Conflict resolution (simultaneous taps)

- Both players send `lockTile` with a `timestamp`.
- On receiving a peer's `lockTile`: if local timestamp is earlier, ignore the peer's lock (you win). If peer's timestamp is earlier, cancel local soft-claim and show the red ✕ denial flash.
- At co-located MultipeerConnectivity range (~15–25ms latency) this is effectively instantaneous and fair.

### New `MultipeerMessage` cases

```swift
case lockTile(slotID: UUID, squareID: UUID, byName: String, timestamp: Date)
case releaseTile(slotID: UUID, byName: String)
case claimTile(slotID: UUID, squareID: UUID, byName: String, timestamp: Date)
case tileReplaced(slotID: UUID, replacement: BingoSquare, expiresAt: Date)
case spottingRoundEnded(scores: [String: Int])
```

---

## Tile Visual States

All six states are documented in `docs/mockups/spotting-race-tile-states-v4.html`.

| State | Image zone | Label band |
|---|---|---|
| Unclaimed | Cream, emoji centred, dots top-left, pts top-right | Dark wood, tile name, fuse bar |
| Tapped (undo window) | Green wash, green stamp −12° drops immediately, countdown ring top-right | Dark green, Undo chip, fuse paused |
| Claimed (you) | Green wash, green stamp stays | Dark green, tile name dimmed |
| Opp. soft-claim | Darkened, dark overlay: 🔒 + name + "Claiming…" | Dark, tile name italic, not tappable |
| Claimed (opponent) | Amber wash, amber stamp +9°: "Taken / +N pts / [Name]" | Dark amber, tile name dimmed |
| Claim denied | Solid red overlay, white ✕ | Dark red, "Already Taken" |
| Expiring (<3s) | Normal, red border pulse | Fuse fill danger/flickering |
| New tile | Slide-up animation, full fuse | Full tile name |

**Rarity indicator:** 1–5 colour-coded dots, top-left of image zone. Point value (`+N`), top-right.

**Stamp hold:** Both claimed states (you and opponent) hold for **2 seconds** before the slot fades out and the replacement slides in. This ensures both players can clearly read who claimed what.

**Opponent claim toast:** When an opponent finalises a claim, a toast fires: *"Sarah claimed 🦅 Bald Eagle · +4 pts"*. Uses the existing `ToastEvent` infrastructure with a new `.opponentClaim` style.

---

## Scoring

### Multiplayer
- Each player accumulates their own score independently.
- Score = sum of `square.rarity.scoreBonus` for all tiles claimed.
- Scores are broadcast via `claimTile` messages; each device maintains `opponentSpottingScores`.
- At round end, the host sends `spottingRoundEnded(scores:)` with canonical final scores to resolve any last-millisecond races.
- Winner is the highest scorer. Win credited to `winHistory[playerName]` (unified with Classic Bingo).
- **No token economy** in Spotting Race. No power-ups in v1.

### Solo
- Same score accumulation as multiplayer (sum of rarity bonuses).
- Score multiplier: `1.0 + (tilesClaimedCount / 20.0)`, capped at `2.0`. More tiles claimed = higher multiplier, rewarding an engaged full-round session.
- Final score compared against `soloSpottingRaceBest` in `UserDefaults`.

---

## Win Screen

Reuses the existing `.win(winnerName:)` screen flow. A new branch in `WinView` for Spotting Race shows:

- **Multiplayer:** "Time's Up!" heading, scores side-by-side with winner highlighted, tiles-claimed count, Play Again / Done buttons.
- **Solo:** Score breakdown (tiles claimed × rarity bonus × multiplier), personal best comparison, Play Again / Done.

---

## Scope Exclusions (v1)

- Power-ups — designed to be added in a future iteration.
- Score threshold win condition — future alternative to time limit.
- Configurable round duration / tile lifetime — future settings screen.
- Prize slot (guaranteed Rare/Very Rare anchor) — revisit after playtesting.
