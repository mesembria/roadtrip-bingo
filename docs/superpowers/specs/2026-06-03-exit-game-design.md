# Exit Game Design

**Date:** 2026-06-03  
**Status:** Approved

## Overview

Add the ability to exit a game in progress from `GameView` and `SpottingRaceView`. Behaviour differs by role:

| Role | What happens when they exit |
|---|---|
| Solo | Confirm dialog → go home (progress lost) |
| Multiplayer joiner | Confirm dialog → go home (game continues without them) |
| Multiplayer host | Confirm dialog (warns it ends the game for all) → broadcast `hostLeft` → go home; peers see an alert and are returned home |

## UI

- A small `✕` button sits in the **top-right corner of the grid/content area** (Variant B from mockup), visible during active gameplay in both `GameView` and `SpottingRaceView`.
- Tapping it shows a SwiftUI `.confirmationDialog` (or `.alert`) with "Keep Playing" (cancel) and "Exit Game" (destructive). The message body varies:
  - **Solo:** "Your progress will be lost."
  - **Joiner:** "You'll return to the home screen. The other players can keep going."
  - **Host:** "You're the host. Leaving will end the game for all players."
- Win and Play Again screens already provide a path home and are out of scope.

## Network Protocol

### New message case

```swift
case hostLeft   // no payload; only ever sent by the host
```

Added to `MultipeerMessage` with a `MessageType.hostLeft` raw value and trivial encode/decode (type key only).

### New AppState property

```swift
@Published var gameEndedByHost: Bool = false
```

- Set to `true` when a non-host peer receives `.hostLeft`.
- Reset to `false` inside `goHome()` so it never carries into a future session.

## AppState Logic

### `exitGame()`

```swift
func exitGame() {
    if isHost && multipeerSession != nil {
        multipeerSession?.send(.hostLeft)
    }
    goHome()
}
```

- Called only from the host's confirm action.
- Non-host players call `goHome()` directly.

### Handler for `.hostLeft`

```swift
case .hostLeft:
    gameEndedByHost = true
```

Setting the flag drives a SwiftUI `.alert` on `GameView`, `WinView`, and `PlayAgainView`. The user taps "OK" → `goHome()` is called.

### `goHome()` change

Add `gameEndedByHost = false` to the existing reset block.

## Files Touched

| File | Change |
|---|---|
| `Models/MultipeerMessage.swift` | Add `.hostLeft` case, encode, decode |
| `State/AppState.swift` | Add `gameEndedByHost`, `exitGame()`, handle `.hostLeft`, reset in `goHome()` |
| `Views/GameView.swift` | Add exit button (top-right of grid area), confirm dialog, `gameEndedByHost` alert |
| `Views/SpottingRaceView.swift` | Same exit button and alerts |
| `Views/WinView.swift` | Add `gameEndedByHost` alert (peer may be here when host exits) |
| `Views/PlayAgainView.swift` | Add `gameEndedByHost` alert (peer may be here when host exits) |
