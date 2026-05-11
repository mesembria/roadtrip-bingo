# Token & Power-Up System Design Spec

**Date:** 2026-05-11
**Feature:** Competitive token economy with in-game power-ups

---

## Overview

Players earn coins (🪙) during the game by hitting milestones and winning rounds. Coins are spent on power-ups that can improve your own board or disrupt opponents'. The system resets each session — no persistent progression. The design goal is to keep all players competitive: tokens flow toward everyone, not just the leader.

---

## Token Economy

### Earning

| Event | Tokens | Notes |
|---|---|---|
| Win a round | 5🪙 | Awarded to the player who calls BINGO |
| Round start | 2🪙 | All players receive this at the start of each new round |
| Close call (4-in-a-row) | 3🪙 | Self-detected; awarded once per pattern per round |
| First mark of a round | 1🪙 | Self-detected; first player to mark anything earns this |
| Complete a pattern (row/col/diag) | 2🪙 | Self-detected; awarded per unique pattern, not duplicated |

### Spending

Power-up costs range from 3–7🪙 (see Power-up Catalogue below).

### Balance Sync

Tokens are self-reported. Each player tracks their own balance and broadcasts it via `tokenEarned` whenever it changes. All peers update their HUD display from these broadcasts. Consistent with the honor-system design of the rest of the game.

### Reset

| State | Resets when |
|---|---|
| `tokenBalance`, `tokenBalances` | New game starts (`goHome()` / `gameStarted` received) |
| `opponentBoards`, `reserveSquares` | New game starts |
| `firstMarkClaimedThisRound` | New game starts AND at the start of each new round |
| `patternsAwardedThisRound` | New game starts AND at the start of each new round |

---

## Power-up Catalogue

All four power-up types are available. Each has a random variant (cheap, host picks target) and a targeted variant (costs more, player picks the tile):

| Power-up | Emoji | Random cost | Targeted cost |
|---|---|---|---|
| Upgrade your tile | 🔀 | 3🪙 | 7🪙 |
| Downgrade opponent's tile | 💣 | 3🪙 | 7🪙 |
| Free mark | ✅ | — | 5🪙 (always targeted) |
| Unmark opponent's tile | 💥 | 4🪙 | 7🪙 |

**Upgrade your tile (🔀):** Swap one of your board tiles for a lower-rarity (easier) square drawn from your reserve hand. Random variant picks the highest-rarity tile on your board; targeted lets you choose which tile to replace.

**Downgrade opponent's tile (💣):** Swap one of an opponent's unmarked tiles for a higher-rarity (harder) square from their reserve hand. Random variant picks the lowest-rarity unmarked tile; targeted lets you pick the specific tile.

**Free mark (✅):** Mark any tile on your board without spotting it. Always targeted — always costs 5🪙.

**Unmark opponent's tile (💥):** Remove a mark from an opponent's board. Random variant picks their most recently marked tile; targeted lets you choose.

---

## Data Model

### AppState additions

```swift
// Every player tracks own balance
@Published var tokenBalance: Int = 0

// All peers track everyone's balance for the HUD (updated via broadcast)
@Published var tokenBalances: [String: Int] = [:]

// All players store opponent boards (transmitted in gameStarted payload)
var opponentBoards: [String: [BingoSquare]] = [:]

// Reserve squares dealt at game start (6 per player, difficulty-weighted)
var reserveSquares: [BingoSquare] = []

// Achievement guard flags — reset at the start of each round
var firstMarkClaimedThisRound: Bool = false
var patternsAwardedThisRound: Set<String> = []   // pattern IDs already rewarded this round
```

### PowerUpType enum

```swift
enum PowerUpType: String, Codable, CaseIterable {
    case upgradeTileRandom
    case upgradeTileTargeted
    case downgradeTileRandom
    case downgradeTileTargeted
    case freeMark               // always targeted
    case unmarkOpponentRandom
    case unmarkOpponentTargeted

    var cost: Int {
        switch self {
        case .upgradeTileRandom, .downgradeTileRandom: return 3
        case .unmarkOpponentRandom:                    return 4
        case .freeMark:                                return 5
        case .upgradeTileTargeted, .downgradeTileTargeted, .unmarkOpponentTargeted: return 7
        }
    }

    var isTargeted: Bool {
        switch self {
        case .upgradeTileTargeted, .downgradeTileTargeted,
             .freeMark, .unmarkOpponentTargeted: return true
        default: return false
        }
    }

    var affectsOpponent: Bool {
        switch self {
        case .downgradeTileRandom, .downgradeTileTargeted,
             .unmarkOpponentRandom, .unmarkOpponentTargeted: return true
        default: return false
        }
    }
}
```

---

## Network Protocol

Three new `MultipeerMessage` cases:

```swift
case tokenEarned(byName: String, newBalance: Int)
case powerUpUsed(
    byName: String,
    powerUp: PowerUpType,
    targetPlayer: String?,       // nil for random variants
    targetIndex: Int?,           // nil for random variants
    replacementSquare: BingoSquare?  // included for upgrade/downgrade ops
)
case reserveDealt(toName: String, squares: [BingoSquare])
```

| Message | Sender | When |
|---|---|---|
| `tokenEarned` | any → all | Immediately after balance changes |
| `powerUpUsed` | any → all | When a power-up is activated; all peers apply the effect locally |
| `reserveDealt` | host → all | Sent alongside `gameStarted`; one message per player |

**Effect application:** All peers have all board data (`opponentBoards`), so any peer can apply any power-up effect locally upon receiving `powerUpUsed`. No round-trip to the host is needed.

**Reserve pool:** Host deals 6 extra squares per player (difficulty-weighted, same algorithm as `dealBoards`) and sends them via `reserveDealt`. The `toName` field lets each device store only their own reserve — opponents' reserves are not shared.

---

## UI

### Persistent strip — portrait

```
[ 🔀 3🪙 ]  [ 💣 3🪙 ]  [ ✅ 5🪙 ]  [ 💥 4🪙 ]      🪙 12
```

Displayed as a horizontal strip below the 5×5 grid. Buttons dim when balance is insufficient.

### Trailing sidebar — landscape

In landscape orientation, the strip rotates to a vertical column on the trailing edge of the screen. The grid stays full-height. The opponent HUD spans the full width at the top.

```
[ Opponent HUD — full width ]
[                ] [ 🔀 3🪙 ]
[  5×5 Grid      ] [ 💣 3🪙 ]
[  (full height) ] [ ✅ 5🪙 ]
[                ] [ 💥 4🪙 ]
[                ] [ 🪙 12  ]
```

### Interaction model

- **Tap** a power-up button → executes the random variant immediately, no confirmation
- **Long-press** → enters targeting mode: cost badge updates to the targeted price, then the targeting overlay appears

### Targeting overlay

Slides up from the bottom over the grid:

- **Self-targeting power-ups (🔀, ✅):** Shows the player's own 5×5 grid. Tap a tile to target it.
- **Opponent-targeting power-ups (💣, 💥):** Shows a mini-grid per opponent, labelled with their name.
  - For 💣: only unmarked tiles are tappable (no point downgrading an already-marked tile)
  - For 💥: only marked tiles are tappable
- Cancel by tapping outside the overlay or swiping down

### Opponent HUD

Token balances are added to the existing opponent strip:

```
● Zoe · 7 ✓ · 🪙 12      ● Liam · 4 ✓ · 🪙 5
```

Updates whenever a `tokenEarned` message arrives.

### Earning feedback

A small "+N🪙" toast appears near the strip when tokens are earned — non-blocking, fades after 1.5 s.

---

## Out of Scope

- Persistent token balances across sessions
- Token gifting between players
- Power-up history or undo
- Animating the opponent's board when a power-up hits them (sound/haptic only)
- Per-category power-ups or stacking effects
