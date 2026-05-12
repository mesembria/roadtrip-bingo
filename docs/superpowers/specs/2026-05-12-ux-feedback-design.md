# UX Feedback Improvements Design Spec

**Date:** 2026-05-12
**Feature:** Toast reasons, power-up discoverability, opponent action notifications

---

## Overview

Three feedback improvements to the existing token/power-up system:

1. Token earn toasts now include the reason ("+3🪙 Close call!")
2. Power-up strip shows short labels below each icon, plus a "?" help button for full descriptions
3. When an opponent uses a power-up on you, a red toast names them and the affected tile

---

## 1. Toast Messages with Earn Reason

### Change

`AppState.earnTokens` gains a `reason: String` parameter. The toast message is composed as `"+\(amount)🪙 \(reason)"`. No structural change to `ToastEvent`.

### Reason Strings

| Event | Reason string |
|---|---|
| Round start (2🪙 to all) | "Round start" |
| Win a round (5🪙) | "BINGO!" |
| Close call — 4-in-a-row (3🪙) | "Close call!" |
| First mark of round (1🪙) | "First mark" |
| Complete a pattern (2🪙) | "Pattern complete" |

### Signature

```swift
private func earnTokens(_ amount: Int, reason: String) {
    tokenBalance += amount
    pendingToast = ToastEvent(message: "+\(amount)🪙 \(reason)", style: .earn)
    multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
}
```

All five call sites in `AppState` pass the appropriate reason string.

---

## 2. Power-Up Strip Labels + Help Sheet

### A — Always-visible labels

`StripItem` gains a `label: String` field. The button layout becomes (top to bottom): emoji → label text → cost. Label is rendered in a small, slightly subdued font (e.g. 8pt, white at 0.7 opacity).

Labels:

| Power-up | Label |
|---|---|
| 🔀 | "Upgrade" |
| 💣 | "Sabotage" |
| ✅ | "Free Mark" |
| 💥 | "Erase" |

### C — Help button + cheat sheet

A "?" button sits in the strip, between the last power-up button and the balance badge. It matches the style of the other buttons (same background, same padding) but uses a fixed label `"?"` and never dims.

Tapping "?" sets `@State private var showHelp = false` → `true`, which triggers a `.sheet`. The sheet contains `PowerUpHelpView`.

### PowerUpHelpView

A new `View` (`PowerUpHelpView.swift`). Shows four rows, each with:

```
[emoji]  Name (bold)
         One-line description
         Tap: [random variant description] · Hold: [targeted description + cost]
```

Example rows:

| | |
|---|---|
| 🔀 | **Upgrade** — Swap one of your tiles for an easier one. Tap: replaces your hardest tile. Hold: you pick (7🪙). |
| 💣 | **Sabotage** — Make an opponent's unmarked tile harder. Tap: random tile. Hold: you pick (7🪙). |
| ✅ | **Free Mark** — Mark any of your tiles without spotting it. Always targeted (5🪙). |
| 💥 | **Erase** — Remove an opponent's mark. Tap: their most recent mark. Hold: you pick (7🪙). |

The sheet has a drag-to-dismiss handle and a "Got it" close button.

---

## 3. Opponent Action Notifications

### ToastStyle

`ToastEvent` gains a `style: ToastStyle` enum field:

```swift
enum ToastStyle { case earn, threat }

struct ToastEvent: Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}
```

`TokenToastView` switches background color by style: `.earn` → yellow (`Color.yellow`), `.threat` → red/orange (`Color.orange`).

### When notifications fire

Only `downgradeTile*` and `unmarkOpponent*` power-ups generate threat toasts. Upgrade and free mark affect only the activating player's own board, so opponents are not notified.

### Message format

`"[emoji] [name] [past-tense verb] '[tile.text]'"`

| Power-up | Example |
|---|---|
| downgradeTile* | "💣 Zoe downgraded 'Sleeping Baby'" |
| unmarkOpponent* | "💥 Liam erased 'Rest Stop'" |

### Implementation

In `AppState.receive(.powerUpUsed(...))`, before calling `applyPowerUpEffect`:

1. Check `targetPlayer == playerName`
2. Check `powerUp.affectsOpponent` (true for both downgrade and unmark)
3. Capture the tile name: `let tileName = localBoard?[targetIndex]?.text ?? "a tile"`
4. Call `applyPowerUpEffect`
5. Post the threat toast: `pendingToast = ToastEvent(message: "...", style: .threat)`

The toast fires after the effect is applied so the board state is already updated when the player reads the message.

---

## Data Model Changes

| Symbol | Change |
|---|---|
| `ToastStyle` | New enum, two cases: `.earn`, `.threat` |
| `ToastEvent` | Add `style: ToastStyle` field |
| `AppState.earnTokens` | Add `reason: String` parameter |
| `StripItem.label` | New `String` field |
| `PowerUpHelpView` | New SwiftUI View |
| `PowerUpStripView` | Add label rendering, "?" button, `@State showHelp` |
| `TokenToastView` | Switch background color by `toast.style` |

---

## Out of Scope

- Queuing multiple toasts (single-slot model unchanged — last one wins within the 1.5 s window)
- Sound or haptic feedback for threat toasts (future)
- Showing who earned tokens in the opponent HUD (balances already broadcast separately)
- Notification when an opponent earns tokens or uses a power-up that doesn't affect you
