# Haptic Feedback — Design Spec

**Date:** 2026-05-25  
**Status:** Approved

---

## Overview

Add haptic feedback to key game moments in Road Trip Bingo. All haptics use SwiftUI's native `.sensoryFeedback()` modifier (iOS 17+), requiring a deployment target bump from iOS 16 to iOS 17. No new files are introduced and no `AppState` logic changes.

---

## Deployment Target

`project.yml` and `project.pbxproj` are updated:

- `iOS: "16.0"` → `"17.0"`

No `@available` guards are needed anywhere. `.sensoryFeedback()` becomes unconditionally available throughout the project.

---

## Haptic Palette

| Action | Feedback | Physical feel |
|---|---|---|
| Tile **marked** | `.impact(.light)` | Crisp, light tap |
| Tile **unmarked** | `.selection` | Subtle tick — softer than marking |
| **BINGO line** forms | `.success` | Double-pulse success pop |
| **Win screen** (local win only) | `.impact(.heavy)` | Solid thump — distinct from line completion |
| **Power-up activated** | `.impact(.medium)` | Satisfying mid-weight click |
| **Attack received** from opponent | `.warning` | Sharp warning pulse |

Opponent wins (the local player is not the winner) produce **no haptic**.

---

## Implementation

### 1. `BingoSquareView`

Add one modifier to the outermost view in `body`. The callback variant distinguishes marking from unmarking:

```swift
.sensoryFeedback(trigger: isMarked) { _, new in
    new ? .impact(.light) : .selection
}
```

This covers both regular tile taps and FREE PICK stamps, since `isMarked` is the canonical marked state passed into the view.

### 2. `GameView`

Add two thin `@State` counters for events that don't map to a single boolean flip, plus three `.sensoryFeedback` modifiers and their associated `.onChange` observers.

**New state:**

```swift
@State private var powerUpTrigger: UUID? = nil
@State private var threatCount: Int = 0
```

**`powerUpTrigger`** is set to `UUID()` in the `onActivateRandom` and `onRequestTargeted` closures passed to `PowerUpStripView`, capturing every power-up the local player activates.

**`threatCount`** is incremented inside an `.onChange(of: appState.pendingToast)` observer when the incoming toast has style `.threat`.

**Modifiers (attached to the ZStack root of `body`):**

```swift
// BINGO line complete
.sensoryFeedback(.success, trigger: appState.completedLine != nil)

// Power-up used by local player
.sensoryFeedback(.impact(.medium), trigger: powerUpTrigger)

// Attack received from opponent
.sensoryFeedback(.warning, trigger: threatCount)
```

**`onChange` additions:**

```swift
.onChange(of: appState.pendingToast) { _, toast in
    if toast?.style == .threat { threatCount += 1 }
}
```

### 3. `WinView`

Add one `@State` var that flips to `true` on appear only for local wins, driving a one-shot heavy impact:

```swift
@State private var didAppear = false
```

```swift
.sensoryFeedback(.impact(.heavy), trigger: didAppear)
.onAppear { if isLocalWin { didAppear = true } }
```

---

## Files Changed

| File | Change |
|---|---|
| `project.yml` | `iOS: "16.0"` → `"17.0"` |
| `RoadTripBingo.xcodeproj/project.pbxproj` | `IPHONEOS_DEPLOYMENT_TARGET = 16.0` → `17.0` (two occurrences) |
| `RoadTripBingo/Views/BingoSquareView.swift` | One `.sensoryFeedback` modifier |
| `RoadTripBingo/Views/GameView.swift` | Two `@State` vars, three modifiers, one `.onChange` |
| `RoadTripBingo/Views/WinView.swift` | One `@State` var, one modifier, one `.onAppear` addition |

---

## Out of Scope

- Token earn / close-call toast haptics (excluded by design)
- Haptics for opponent win screen
- Accessibility setting to disable haptics (can be added later; iOS respects system "Haptics" toggle automatically)
