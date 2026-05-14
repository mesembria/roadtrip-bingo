# Opponent Mark Feed

**Date:** 2026-05-14
**Status:** Approved

## Overview

When an opponent marks a tile, all other players see a small indicator card showing the tile thumbnail and the opponent's name. Cards fade out over 10 seconds and are capped at 3 visible at once. Marks-only (unmarks are silent).

## Data Model

### `RecentMark` (new — `Models/RecentMark.swift`)

```swift
struct RecentMark: Identifiable {
    let id: UUID
    let opponentName: String
    let tileName: String
    let tileID: UUID           // square UUID — used to load image via AmericanaTheme.tileImage(for:)
    let timestamp: Date
}
```

### `AppState` additions

```swift
@Published var recentOpponentMarks: [RecentMark] = []
private let maxRecentMarks = 3
```

## Data Flow

1. `MultipeerSession` receives a `squareToggled` message where `isMarked == true` for an opponent.
2. The existing handler updates `opponentMarked[name]`. Immediately after, look up `opponentBoards[name][position]` to get the tile's `name` and `tileImageName`.
3. Construct a `RecentMark` and append to `recentOpponentMarks`. If count exceeds `maxRecentMarks`, drop the oldest entry immediately (no animation).
4. Clear `recentOpponentMarks = []` at round start, alongside existing round-reset logic.

## Fade Mechanism

Each `RecentMarkCard` view owns `@State var opacity: Double = 1.0`. On `onAppear`, it fires `withAnimation(.linear(duration: 10)) { opacity = 0 }`. This drives a smooth 10-second opacity fade entirely in SwiftUI — no polling required in the view.

`AppState` runs a pruning loop: a stored `Task?` property. Whenever a mark is appended, if the task is `nil` (or already finished), a new `Task` is started. It loops every 1 second, removing entries whose `timestamp` is more than 10 seconds old, and exits (setting the stored reference to `nil`) when the array is empty. No concurrent pruning tasks are needed since appends always restart the loop from the same path.

## Views

### `RecentMarkCard` (new — `Views/RecentMarkCard.swift`)

Accepts `mark: RecentMark` and `isLandscape: Bool`.

**Landscape (pill layout, ~120×44pt):**
- `HStack`: 44×44pt tile image (loaded from NSCache, same pattern as `BingoSquareView`) + `VStack` of opponent name (small caps, green `#4a7c4e`, 9pt Georgia) and tile name (bold, 10pt Georgia)
- Full width of the sidebar (~120pt), constrained height

**Portrait (square layout, ~72pt wide):**
- `VStack`: green name band across top, tile image body, tile name in 10pt bold below
- Width ~72pt, height ~90pt

**Shared styling:** Parchment background `#f5efe0`, 2pt brown `#8B6914` border, 6pt corner radius, light drop shadow — matches existing tile aesthetic.

**Entry animation:** `.transition(.opacity.combined(with: .scale(scale: 0.8)))` so cards pop in softly.

### `OpponentMarkFeedView` (new — `Views/OpponentMarkFeedView.swift`)

Accepts `marks: [RecentMark]` and `isLandscape: Bool`.

- **Landscape:** `VStack(alignment: .leading, spacing: 4)` of `RecentMarkCard`s (vertical stack in sidebar)
- **Portrait:** `HStack(spacing: 8)` of `RecentMarkCard`s (horizontal strip)
- Uses `ForEach` with `.animation(.spring(response: 0.25), value: marks)` so additions/removals animate.

## Placement in `GameView`

### Landscape

In the left sidebar `VStack`, below the `ForEach` of `OpponentStrip` views and above the BINGO button:

```
[OpponentStrip × N]
[OpponentMarkFeedView]   ← new
[BINGO button]
```

### Portrait

Between the BINGO button and `PowerUpStrip` in the portrait `VStack`:

```
[OpponentHUD strip]
[BingoGridView]
[BINGO button]
[OpponentMarkFeedView]   ← new
[PowerUpStrip]
```

The feed row collapses to zero height when empty (`.frame(height: recentOpponentMarks.isEmpty ? 0 : 90).clipped()`) so it never creates a gap in the portrait layout when there are no active marks.

## Testing

- Unit test `AppState`: verify that appending beyond `maxRecentMarks` drops the oldest entry; verify `recentOpponentMarks` is cleared on round start.
- Unit test pruning: fast-forward time on `RecentMark.timestamp` and confirm entries are removed by the pruning loop.
- No view snapshot tests required; the fade is driven by SwiftUI animation which is not unit-testable.
