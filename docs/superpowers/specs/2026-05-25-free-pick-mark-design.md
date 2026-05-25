# Free Pick Mark — Design Spec

**Date:** 2026-05-25
**Status:** Approved

## Overview

When a player uses the `freeMark` power-up to mark a tile, the tile currently displays the same "SPOTTED!" stamp as a normally-tapped tile. This feature gives free-marked tiles a distinct visual: a green "FREE PICK!" stamp in the same Americana stamp aesthetic (Rye font, bordered box, −12° rotation).

## Scope

- Visual distinction applies to the **local player's board only**.
- Opponent mini-grids (`MiniGridView`) are 10×10pt coloured squares with no stamp text — no change needed there.

## Data Model — `BingoBoard`

Add one new property:

```swift
var freeMarked: Set<UUID>  // subset of `marked`; tracks tiles marked via the freeMark power-up
```

Mutations:

| Method | Change |
|---|---|
| `markFree(at:)` | **New.** Inserts into both `marked` and `freeMarked`. |
| `unmark(at:)` | Also removes from `freeMarked`. |
| `replaceSquare(at:)` | Also removes old ID from `freeMarked`. |

`mark(at:)` and all other methods are unchanged. `GameEngine` reads `board.marked` and requires no changes — all marked tiles (normal and free) remain in that set.

## AppState

One call site changes in `applyPowerUpEffect`, `.freeMark` case:

```swift
// Before
localBoard?.mark(at: idx)

// After
localBoard?.markFree(at: idx)
```

No changes to `MultipeerMessage`, the sync path, or any other power-up handling. Remote peers call `applyPowerUpEffect` when they receive `.powerUpUsed`, so `markFree` propagates automatically.

## View Layer

### `BingoSquareView`

New parameter:

```swift
isFreeMarked: Bool
```

Overlay priority (mutually exclusive; only one renders at a time):

1. `isFreeMarked` → `freePickOverlay`
2. `isMarked && !isFreeMarked` → existing `spottedOverlay`

`freePickOverlay` mirrors `spottedOverlay` exactly, with two differences:
- Text: `"FREE PICK!"` instead of `"SPOTTED!"`
- Color: `AmericanaTheme.green` instead of `AmericanaTheme.red`

### `BingoGridView`

Passes the new parameter to `BingoSquareView`:

```swift
isFreeMarked: board.freeMarked.contains(board.squares[position].id)
```

## Files Changed

| File | Change |
|---|---|
| `Models/BingoBoard.swift` | Add `freeMarked`, `markFree(at:)`, update `unmark` and `replaceSquare` |
| `State/AppState.swift` | Call `markFree` instead of `mark` in `.freeMark` case |
| `Views/BingoGridView.swift` | Pass `isFreeMarked` to `BingoSquareView` |
| `Views/BingoSquareView.swift` | Add `isFreeMarked` param and `freePickOverlay` |

## Files Not Changed

- `Game/GameEngine.swift`
- `Models/MultipeerMessage.swift`
- `Views/OpponentStripView.swift`
- All other views and models
