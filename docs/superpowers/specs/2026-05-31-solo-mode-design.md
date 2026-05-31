# Solo Mode — Design Spec
**Date:** 2026-05-31  
**Status:** Approved

## Overview

Add a single-player ("Solo") mode so one person can play Road Trip Bingo without needing another device. Solo skips the multiplayer lobby entirely, disables attack power-ups and opponent-dependent mechanics, and introduces a weighted score + personal best system to provide replayable tension.

---

## 1. Data Model

### `GameMode` enum
New file: `RoadTripBingo/Models/GameMode.swift`

```swift
enum GameMode: Equatable { case multiplayer, solo }
```

### AppState additions

| Property | Type | Notes |
|---|---|---|
| `gameMode` | `@Published GameMode` | Defaults to `.multiplayer` |
| `tokensEarnedThisRound` | `private(set) Int` | Gross tokens earned; incremented alongside `tokenBalance`. Reset each round. |
| `soloPersonalBest` | `Int` | Persisted to UserDefaults key `"soloPersonalBest"` via `didSet` |
| `lastSoloScore` | `@Published Int` | Set at win time; read by WinView |
| `lastSoloIsNewBest` | `@Published Bool` | Set at win time; drives "New personal best!" animation |

### Solo score formula
Computed at BINGO detection, before transitioning to `.win`:

```swift
let extraLines = max(0, GameEngine.completedLines(for: board).count - 1)
let soloScore  = tokensEarnedThisRound + extraLines * 10
```

Gross earnings are used (not net balance) so spending tokens on power-ups does not penalise the score. Challenge completions award tokens through the existing system and are naturally included. Each completed line beyond the winning BINGO scores +10 points.

---

## 2. Entry Point & Navigation

### HomeView
Add a third button below "Join Game":

```
[ Create Game  → ]   ← green filled
[ Join Game    → ]   ← green outlined
[ Play Solo    → ]   ← parchment/brown outlined (secondary)
```

Same name-required guard as the other buttons. Tapping calls `appState.startSoloGame()`.

### `startSoloGame()`
New method on AppState:
1. Sets `gameMode = .solo`
2. Resets round-scoped tracking (`tokensEarnedThisRound`, `marksThisRound`, etc.)
3. Deals a local board via `SquarePool` (same path as host-side deal in multiplayer)
4. Does **not** touch `MultipeerSession`
5. Transitions `screen = .game`

### Navigation map (solo)
```
.home → startSoloGame() → .game → .win → startSoloGame() (Play Again)
                                        → .home            (Done)
```

- `.playAgain` screen is **not used** in solo — the win screen handles both actions inline.
- Quitting mid-game resets `gameMode = .multiplayer` and transitions to `.home`.

---

## 3. GameView Adaptations

### Round modifier pool
AppState re-rolls `RoundModifier.random()` until it gets a solo-compatible result (keeping `RoundModifier` free of AppState knowledge). These modifiers are **excluded** when `gameMode == .solo`:

| Modifier | Reason excluded |
|---|---|
| `.fogOfWar` | Triggered by opponent marks — does nothing solo |
| `.shiftingTiles` | Triggered by opponent marks — does nothing solo |
| `.shuffleBoard` | Triggered by opponent marks — does nothing solo |
| `.sniper` | Reduces attack power-up costs — attack powers don't exist solo |

Remaining modifiers work unchanged: `.hotStreak`, `.doubleDown`, `.noPowers`, `.patternWin(_)`.

### Power-up strip
`PowerUpStripView` filters `PowerUpType.allCases` by `!type.affectsOpponent` when `gameMode == .solo`. This removes the four attack powers automatically using the existing `affectsOpponent` property:
- Removed: `downgradeTileRandom`, `downgradeTileTargeted`, `unmarkOpponentRandom`, `unmarkOpponentTargeted`
- Kept: `upgradeTileRandom`, `upgradeTileTargeted`, `freeMark`

### Opponent UI
Hidden when `gameMode == .solo`:
- `OpponentStripView` (left sidebar, opponent token/board display)
- `OpponentMarkFeedView` (fading mini-cards for opponent marks)

The left sidebar space collapses; the board expands to fill.

### Daily challenges
Two challenges are filtered from `activeChallenges` when `gameMode == .solo`:

| Challenge | Reason |
|---|---|
| `.pacifist` | Attack powers always disabled solo → trivially auto-satisfied on every win |
| `.menace` | Requires 3 attack power uses → impossible solo |

All other challenges work as-is. Notable: `.speedDemon` ("mark 5 tiles before any opponent marks 5") is satisfied when you mark 5 tiles — with an empty `opponentMarkCounts`, the `allSatisfy` check is vacuously true. This is acceptable as a solo challenge.

---

## 4. Solo Win Screen

`WinView` branches on `gameMode == .solo`. In solo, replace the winner-name banner and win-history display with a score breakdown:

```
🏆  BINGO!

        Score Breakdown
  Tokens earned      42
  Extra lines  ×2    20
  ──────────────────────
  Total              62

  ★ New personal best!     ← or "Your best: 87"
```

- Header: Rye font, AmericanaTheme colours
- Breakdown table: BarlowSemiBold
- "New personal best! 🏆" animates in with a brief scale pulse (`.scaleEffect` + `.animation`) when `lastSoloIsNewBest == true`

**Personal best update** (in AppState at win time):
```swift
if soloScore > soloPersonalBest {
    soloPersonalBest = soloScore
    lastSoloIsNewBest = true
}
lastSoloScore = soloScore
```

---

## 5. Play Again & Exit

Solo `WinView` shows two buttons:

```
[ Play Again  → ]   ← green filled (primary)
[ Done        → ]   ← parchment/brown outlined (secondary)
```

- **Play Again** — calls `appState.startSoloGame()`. Resets board, tokens, and round tracking; deals fresh tiles; transitions to `screen = .game`. Stays in solo mode.
- **Done** — resets `gameMode = .multiplayer`, clears game state, transitions to `screen = .home`.

The existing `PlayAgainView` is multiplayer-specific and is **not used** in solo. The solo win screen handles both actions inline within `WinView`.

---

## Out of Scope

- Ghost/AI opponent (could be a future mode)
- Timer-based pressure
- Leaderboards or Game Center integration
- Solo-specific tile packs or difficulty settings
