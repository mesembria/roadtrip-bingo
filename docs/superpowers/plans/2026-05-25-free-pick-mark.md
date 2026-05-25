# Free Pick Mark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the `freeMark` power-up marks a tile, show a green "FREE PICK!" stamp instead of the red "SPOTTED!" stamp.

**Architecture:** Add `freeMarked: Set<UUID>` to `BingoBoard` as a subset of `marked`, wire `AppState` to call a new `markFree(at:)` method, and render a distinct overlay in `BingoSquareView` when a tile is in `freeMarked`.

**Tech Stack:** Swift, SwiftUI, XCTest

---

## File Map

| File | Change |
|---|---|
| `RoadTripBingo/Models/BingoBoard.swift` | Add `freeMarked`, `markFree(at:)`, update `unmark` and `replaceSquare` |
| `RoadTripBingo/State/AppState.swift` | Call `markFree` instead of `mark` in `.freeMark` case |
| `RoadTripBingo/Views/BingoGridView.swift` | Pass `isFreeMarked` to `BingoSquareView` |
| `RoadTripBingo/Views/BingoSquareView.swift` | Add `isFreeMarked` param and `freePickOverlay` |
| `RoadTripBingoTests/BingoBoardTests.swift` | Add four tests for the new `freeMarked` behaviour |

---

### Task 1: Extend BingoBoard with freeMarked tracking

**Files:**
- Modify: `RoadTripBingo/Models/BingoBoard.swift`
- Test: `RoadTripBingoTests/BingoBoardTests.swift`

- [ ] **Step 1: Write the four failing tests**

Open `RoadTripBingoTests/BingoBoardTests.swift` and add these tests at the end of the class (before the closing `}`). The `makeBoard()` helper already exists in that file — use it.

```swift
// MARK: - markFree / freeMarked

func test_markFree_addsToBothMarkedAndFreeMarked() {
    var board = makeBoard()
    board.markFree(at: 0)
    XCTAssertTrue(board.isMarked(at: 0))
    XCTAssertTrue(board.freeMarked.contains(board.squares[0].id))
}

func test_mark_doesNotAddToFreeMarked() {
    var board = makeBoard()
    board.mark(at: 0)
    XCTAssertTrue(board.isMarked(at: 0))
    XCTAssertFalse(board.freeMarked.contains(board.squares[0].id))
}

func test_unmark_removesFromFreeMarked() {
    var board = makeBoard()
    board.markFree(at: 0)
    board.unmark(at: 0)
    XCTAssertFalse(board.isMarked(at: 0))
    XCTAssertFalse(board.freeMarked.contains(board.squares[0].id))
}

func test_replaceSquare_removesOldIDFromFreeMarked() {
    var board = makeBoard()
    board.markFree(at: 0)
    let newSquare = BingoSquare(id: UUID(), text: "New", emoji: "⭐", category: .vehicles, rarity: .rare)
    board.replaceSquare(at: 0, with: newSquare)
    XCTAssertFalse(board.isMarked(at: 0))
    // freeMarked must not contain either the old or new ID
    XCTAssertTrue(board.freeMarked.isEmpty)
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/BingoBoardTests \
  2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: compile error — `value of type 'BingoBoard' has no member 'markFree'` and `has no member 'freeMarked'`.

- [ ] **Step 3: Implement the changes in BingoBoard**

Replace the entire contents of `RoadTripBingo/Models/BingoBoard.swift` with:

```swift
import Foundation

struct BingoBoard {
    // 25 squares row-major. Index 12 must always be BingoSquare.free.
    var squares: [BingoSquare]   // var (was let) to support tile replacement
    var marked: Set<UUID>
    var freeMarked: Set<UUID>    // subset of `marked`; tiles marked via the freeMark power-up

    init(squares: [BingoSquare]) {
        precondition(squares.count == 25, "Board must have exactly 25 squares")
        precondition(squares[12].id == BingoSquare.freeSquareID, "Index 12 must be the FREE square")
        self.squares = squares
        self.marked = [BingoSquare.freeSquareID]
        self.freeMarked = []
    }

    mutating func toggle(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
    }

    // Force-marks a square without toggling. No-op on the FREE square.
    mutating func mark(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.insert(id)
    }

    // Force-marks a square as a free pick (via the freeMark power-up).
    // Inserts into both `marked` and `freeMarked`. No-op on the FREE square.
    mutating func markFree(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.insert(id)
        freeMarked.insert(id)
    }

    // Force-unmarks a square. No-op on the FREE square.
    mutating func unmark(at position: Int) {
        guard (0..<25).contains(position) else { return }
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.remove(id)
        freeMarked.remove(id)
    }

    // Replaces the tile at position with newSquare, clearing its old mark.
    // No-op if position is 12 (the FREE square must not be replaced).
    mutating func replaceSquare(at position: Int, with newSquare: BingoSquare) {
        guard (0..<25).contains(position), position != 12 else { return }
        let oldID = squares[position].id
        marked.remove(oldID)
        freeMarked.remove(oldID)
        squares[position] = newSquare
    }

    func isMarked(at position: Int) -> Bool {
        marked.contains(squares[position].id)
    }

    mutating func shuffleUnmarkedPositions() {
        let unmarkedIndices = (0..<25).filter { $0 != 12 && !isMarked(at: $0) }
        let shuffledTiles = unmarkedIndices.map { squares[$0] }.shuffled()
        for (i, idx) in unmarkedIndices.enumerated() {
            squares[idx] = shuffledTiles[i]
        }
    }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/BingoBoardTests \
  2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: `Test Suite 'BingoBoardTests' passed`

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Models/BingoBoard.swift RoadTripBingoTests/BingoBoardTests.swift
git commit -m "feat: add freeMarked tracking to BingoBoard"
```

---

### Task 2: Wire AppState to use markFree

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift:520-528`

- [ ] **Step 1: Update the freeMark case in applyPowerUpEffect**

In `AppState.swift`, find the `.freeMark` case inside `applyPowerUpEffect` (around line 520). It currently reads:

```swift
case .freeMark:
    guard let idx = targetIndex else { return }
    if byName == playerName {
        localBoard?.mark(at: idx)
    } else {
        if let board = opponentBoards[byName], idx < board.count {
            opponentMarked[byName, default: []].insert(board[idx].id)
        }
    }
```

Change `localBoard?.mark(at: idx)` to `localBoard?.markFree(at: idx)`:

```swift
case .freeMark:
    guard let idx = targetIndex else { return }
    if byName == playerName {
        localBoard?.markFree(at: idx)
    } else {
        if let board = opponentBoards[byName], idx < board.count {
            opponentMarked[byName, default: []].insert(board[idx].id)
        }
    }
```

- [ ] **Step 2: Build to confirm no errors**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "error:|warning:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Run all tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test 2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: all test suites pass.

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: wire freeMark power-up to markFree"
```

---

### Task 3: Pass isFreeMarked through BingoGridView

**Files:**
- Modify: `RoadTripBingo/Views/BingoGridView.swift:67-73`
- Modify: `RoadTripBingo/Views/BingoSquareView.swift` (add param only — overlay in Task 4)

- [ ] **Step 1: Add the isFreeMarked parameter to BingoSquareView**

In `BingoSquareView.swift`, the struct currently has these properties:

```swift
let square: BingoSquare
let isMarked: Bool
let isHighlighted: Bool
var isHidden: Bool = false
let onTap: () -> Void
```

Add `isFreeMarked` after `isMarked`:

```swift
let square: BingoSquare
let isMarked: Bool
let isFreeMarked: Bool
let isHighlighted: Bool
var isHidden: Bool = false
let onTap: () -> Void
```

- [ ] **Step 2: Pass isFreeMarked from BingoGridView**

In `BingoGridView.swift`, the `BingoSquareView` initialiser call currently reads:

```swift
BingoSquareView(
    square: board.squares[position],
    isMarked: board.isMarked(at: position),
    isHighlighted: highlightedPositions.contains(position),
    isHidden: hiddenPositions.contains(position),
    onTap: { onTap(position) }
)
```

Add `isFreeMarked`:

```swift
BingoSquareView(
    square: board.squares[position],
    isMarked: board.isMarked(at: position),
    isFreeMarked: board.freeMarked.contains(board.squares[position].id),
    isHighlighted: highlightedPositions.contains(position),
    isHidden: hiddenPositions.contains(position),
    onTap: { onTap(position) }
)
```

- [ ] **Step 3: Build to confirm no errors**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Views/BingoGridView.swift RoadTripBingo/Views/BingoSquareView.swift
git commit -m "feat: thread isFreeMarked into BingoSquareView"
```

---

### Task 4: Render the FREE PICK! overlay in BingoSquareView

**Files:**
- Modify: `RoadTripBingo/Views/BingoSquareView.swift`

- [ ] **Step 1: Add the freePickOverlay and update the overlay logic**

In `BingoSquareView.swift`, the overlay block in `regularCell` currently reads:

```swift
// SPOTTED! overlay
if isMarked {
    spottedOverlay
        .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
}
```

Replace it with:

```swift
// Mark overlay — FREE PICK! takes priority over SPOTTED!
if isFreeMarked {
    freePickOverlay
        .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
} else if isMarked {
    spottedOverlay
        .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
}
```

- [ ] **Step 2: Add the freePickOverlay computed property**

In `BingoSquareView.swift`, the `spottedOverlay` computed property currently reads:

```swift
private var spottedOverlay: some View {
    ZStack {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.55))
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AmericanaTheme.red, lineWidth: 2)
            Text("SPOTTED!")
                .font(AmericanaTheme.rye(13))
                .foregroundColor(AmericanaTheme.red)
        }
        .padding(8)
        .rotationEffect(.degrees(-12))
    }
}
```

Add `freePickOverlay` directly below it:

```swift
private var freePickOverlay: some View {
    ZStack {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.55))
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AmericanaTheme.green, lineWidth: 2)
            Text("FREE PICK!")
                .font(AmericanaTheme.rye(13))
                .foregroundColor(AmericanaTheme.green)
        }
        .padding(8)
        .rotationEffect(.degrees(-12))
    }
}
```

- [ ] **Step 3: Build to confirm no errors**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Run all tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test 2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: all test suites pass.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Views/BingoSquareView.swift
git commit -m "feat: show FREE PICK! stamp for free-marked tiles"
```
