# UX Feedback Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add earn-reason toast messages, always-visible power-up labels, a "?" help sheet, and opponent-action threat toasts.

**Architecture:** Three SwiftUI view changes (`PowerUpStripView`, `TokenToastView`, `GameView`) plus one new view (`PowerUpHelpView`) plus one AppState change (`earnTokens` reason + opponent notification). `ToastStyle` is added to the model layer so views can colour-code earn vs threat toasts.

**Tech Stack:** SwiftUI, iOS 16+, `@State`, `.sheet`, `@Environment(\.dismiss)`, `xcodegen` for project file generation after new files.

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Modify | `RoadTripBingo/State/AppState.swift` | Add `ToastStyle`, update `ToastEvent`, update `earnTokens`, add opponent toast |
| Modify | `RoadTripBingo/Views/TokenToastView.swift` | Colour-switch by `ToastStyle` |
| Modify | `RoadTripBingo/Views/GameView.swift` | Track `toastStyle`, pass to `TokenToastView` |
| Modify | `RoadTripBingo/Views/PowerUpStripView.swift` | Add labels, "?" button, `showHelp` state, `.sheet` |
| Create | `RoadTripBingo/Views/PowerUpHelpView.swift` | Cheat-sheet overlay with four power-up rows |
| Create | `RoadTripBingoTests/ToastTests.swift` | Unit tests for `ToastStyle` + `ToastEvent` |
| Create | `RoadTripBingoTests/AppStateTests.swift` | Integration test for opponent toast firing |

---

## Task 1: ToastStyle + earnTokens reasons + TokenToastView colour

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`
- Modify: `RoadTripBingo/Views/TokenToastView.swift`
- Modify: `RoadTripBingo/Views/GameView.swift`
- Create: `RoadTripBingoTests/ToastTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `RoadTripBingoTests/ToastTests.swift`:

```swift
import XCTest
@testable import RoadTripBingo

final class ToastTests: XCTestCase {

    func test_toastStyle_earn_notEqualThreat() {
        XCTAssertNotEqual(ToastStyle.earn, ToastStyle.threat)
    }

    func test_toastEvent_earn_hasEarnStyle() {
        let event = ToastEvent(message: "+2🪙 Round start", style: .earn)
        XCTAssertEqual(event.style, .earn)
    }

    func test_toastEvent_threat_hasThreatStyle() {
        let event = ToastEvent(message: "💣 Liam downgraded 'Barn'", style: .threat)
        XCTAssertEqual(event.style, .threat)
    }

    func test_toastEvent_message_preserved() {
        let event = ToastEvent(message: "+3🪙 Close call!", style: .earn)
        XCTAssertEqual(event.message, "+3🪙 Close call!")
    }
}
```

- [ ] **Step 2: Run xcodegen to pick up the new test file**

```bash
cd /Users/pmoore/Source/roadtrip-bingo && xcodegen generate
```

Expected: `Generating project at path: /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo.xcodeproj`

- [ ] **Step 3: Run tests to confirm they fail**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|ToastTests|PASSED|FAILED" | head -20
```

Expected: compile errors — `ToastStyle` and `ToastEvent(style:)` not yet defined.

- [ ] **Step 4: Add `ToastStyle` and update `ToastEvent` in `AppState.swift`**

Replace the current `ToastEvent` block at the top of `AppState.swift` (lines 4–7):

```swift
// OLD:
struct ToastEvent: Equatable {
    let id = UUID()
    let message: String
}
```

With:

```swift
enum ToastStyle: Equatable { case earn, threat }

struct ToastEvent: Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}
```

- [ ] **Step 5: Update `earnTokens` signature and body**

Replace `earnTokens` (currently at line 194–198):

```swift
// OLD:
private func earnTokens(_ amount: Int) {
    tokenBalance += amount
    pendingToast = ToastEvent(message: "+\(amount)🪙")
    multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
}
```

With:

```swift
private func earnTokens(_ amount: Int, reason: String) {
    tokenBalance += amount
    pendingToast = ToastEvent(message: "+\(amount)🪙 \(reason)", style: .earn)
    multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
}
```

- [ ] **Step 6: Update all seven `earnTokens` call sites in `AppState.swift`**

In `toggleSquare` (first-mark bonus):
```swift
// OLD: earnTokens(1)
earnTokens(1, reason: "First mark")
```

In `callBingo` (win bonus):
```swift
// OLD: earnTokens(5)
earnTokens(5, reason: "BINGO!")
```

In `dealAndLaunchRound` (host round-start bonus):
```swift
// OLD: earnTokens(2)
earnTokens(2, reason: "Round start")
```

In `checkBonuses` — close-call branch:
```swift
// OLD: earnTokens(3)
earnTokens(3, reason: "Close call!")
```

In `checkBonuses` — pattern-complete branch:
```swift
// OLD: earnTokens(2)
earnTokens(2, reason: "Pattern complete")
```

In the `gameStarted` delegate case (joiner round-start):
```swift
// OLD: earnTokens(2)   // round-start bonus for joiner
earnTokens(2, reason: "Round start")
```

In the `playAgain` delegate case (joiner play-again round-start):
```swift
// OLD: earnTokens(2)   // round-start bonus for joiner
earnTokens(2, reason: "Round start")
```

- [ ] **Step 7: Update `TokenToastView.swift` to colour by style**

Replace the entire file:

```swift
import SwiftUI

struct TokenToastView: View {
    let message: String
    let style: ToastStyle

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(style == .earn
                ? Color.yellow.opacity(0.95)
                : Color.orange.opacity(0.95))
            .foregroundColor(.black)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.25), radius: 8)
    }
}
```

- [ ] **Step 8: Update `GameView.swift` to track `toastStyle` and pass it**

Add one `@State` property after the existing two (lines 6–7):

```swift
// After:
@State private var activeToastID: UUID? = nil
// Add:
@State private var toastStyle: ToastStyle = .earn
```

In the `.onChange` closure, add `toastStyle = toast.style` after setting `toastMessage`:

```swift
.onChange(of: appState.pendingToast) { toast in
    guard let toast else { return }
    toastStyle = toast.style                           // ← add this line
    withAnimation(.spring()) { toastMessage = toast.message }
    activeToastID = toast.id
    appState.pendingToast = nil
    let id = toast.id
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        guard activeToastID == id else { return }
        withAnimation { toastMessage = nil }
    }
}
```

Change `TokenToastView(message: msg)` to pass the style:

```swift
// OLD:
TokenToastView(message: msg)
// NEW:
TokenToastView(message: msg, style: toastStyle)
```

- [ ] **Step 9: Run tests — expect all four ToastTests to pass**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|ToastTests|PASSED|FAILED" | head -20
```

Expected: `Test Suite 'ToastTests' passed`; no errors.

- [ ] **Step 10: Commit**

```bash
git add RoadTripBingo/State/AppState.swift \
        RoadTripBingo/Views/TokenToastView.swift \
        RoadTripBingo/Views/GameView.swift \
        RoadTripBingoTests/ToastTests.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: add toast earn reasons and threat style"
```

---

## Task 2: Power-up strip labels

**Files:**
- Modify: `RoadTripBingo/Views/PowerUpStripView.swift`

No new files. No xcodegen needed.

- [ ] **Step 1: Add `label` to `StripItem` and update `items` array**

Replace the `StripItem` struct and `items` array in `PowerUpStripView.swift`:

```swift
// OLD:
private struct StripItem {
    let emoji: String
    let randomVariant: PowerUpType?
    let targetedVariant: PowerUpType

    var displayCost: Int { randomVariant?.cost ?? targetedVariant.cost }
}

private let items: [StripItem] = [
    StripItem(emoji: "🔀", randomVariant: .upgradeTileRandom,    targetedVariant: .upgradeTileTargeted),
    StripItem(emoji: "💣", randomVariant: .downgradeTileRandom,  targetedVariant: .downgradeTileTargeted),
    StripItem(emoji: "✅", randomVariant: nil,                   targetedVariant: .freeMark),
    StripItem(emoji: "💥", randomVariant: .unmarkOpponentRandom, targetedVariant: .unmarkOpponentTargeted),
]
```

With:

```swift
private struct StripItem {
    let emoji: String
    let label: String
    let randomVariant: PowerUpType?
    let targetedVariant: PowerUpType

    var displayCost: Int { randomVariant?.cost ?? targetedVariant.cost }
}

private let items: [StripItem] = [
    StripItem(emoji: "🔀", label: "Upgrade",   randomVariant: .upgradeTileRandom,    targetedVariant: .upgradeTileTargeted),
    StripItem(emoji: "💣", label: "Sabotage",  randomVariant: .downgradeTileRandom,  targetedVariant: .downgradeTileTargeted),
    StripItem(emoji: "✅", label: "Free Mark", randomVariant: nil,                   targetedVariant: .freeMark),
    StripItem(emoji: "💥", label: "Erase",     randomVariant: .unmarkOpponentRandom, targetedVariant: .unmarkOpponentTargeted),
]
```

- [ ] **Step 2: Update the button `VStack` in `buttons` to include the label**

Replace the `VStack` inside `buttons` (the `VStack(spacing: 2) { ... }` block):

```swift
// OLD:
VStack(spacing: 2) {
    Text(item.emoji).font(.system(size: 22))
    Text("\(item.displayCost)🪙")
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(.white.opacity(0.8))
}
```

With:

```swift
VStack(spacing: 2) {
    Text(item.emoji).font(.system(size: 22))
    Text(item.label)
        .font(.system(size: 8, weight: .semibold))
        .foregroundColor(.white.opacity(0.7))
    Text("\(item.displayCost)🪙")
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(.white.opacity(0.8))
}
```

- [ ] **Step 3: Build to verify — no tests, just compile check**

```bash
xcodebuild build -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|SUCCEEDED|FAILED" | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Views/PowerUpStripView.swift
git commit -m "feat: add always-visible labels to power-up strip"
```

---

## Task 3: Power-up help sheet

**Files:**
- Create: `RoadTripBingo/Views/PowerUpHelpView.swift`
- Modify: `RoadTripBingo/Views/PowerUpStripView.swift`

- [ ] **Step 1: Create `PowerUpHelpView.swift`**

```swift
import SwiftUI

struct PowerUpHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private struct HelpItem: Identifiable {
        let id = UUID()
        let emoji: String
        let name: String
        let description: String
        let tapDetail: String?
        let holdDetail: String
    }

    private let items: [HelpItem] = [
        HelpItem(
            emoji: "🔀", name: "Upgrade",
            description: "Swap one of your tiles for an easier one.",
            tapDetail: "replaces your hardest tile (3🪙)",
            holdDetail: "you pick the tile (7🪙)"
        ),
        HelpItem(
            emoji: "💣", name: "Sabotage",
            description: "Make an opponent's unmarked tile harder.",
            tapDetail: "random tile (3🪙)",
            holdDetail: "you pick the tile (7🪙)"
        ),
        HelpItem(
            emoji: "✅", name: "Free Mark",
            description: "Mark any of your tiles without spotting it.",
            tapDetail: nil,
            holdDetail: "you pick the tile (5🪙)"
        ),
        HelpItem(
            emoji: "💥", name: "Erase",
            description: "Remove a mark from an opponent's board.",
            tapDetail: "their most recent mark (4🪙)",
            holdDetail: "you pick the tile (7🪙)"
        ),
    ]

    var body: some View {
        NavigationStack {
            List(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.emoji).font(.title2)
                        Text(item.name).font(.headline)
                    }
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let tap = item.tapDetail {
                        Text("Tap: \(tap) · Hold: \(item.holdDetail)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Hold: \(item.holdDetail)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Power-Ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run xcodegen to add `PowerUpHelpView.swift` to the project**

```bash
cd /Users/pmoore/Source/roadtrip-bingo && xcodegen generate
```

Expected: `Generating project at path: /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo.xcodeproj`

- [ ] **Step 3: Add `@State private var showHelp`, "?" button, and `.sheet` to `PowerUpStripView.swift`**

Add the state property before `var body`:

```swift
// After `private let items: [StripItem] = [...]`, before `var body`:
@State private var showHelp = false
```

Replace `var body` to add `helpButton` and `.sheet`:

```swift
// OLD:
var body: some View {
    Group {
        if isVertical {
            VStack(spacing: 6) { buttons; balanceBadge }
        } else {
            HStack(spacing: 6) { buttons; balanceBadge }
        }
    }
    .padding(8)
    .background(Color.white.opacity(0.07))
    .cornerRadius(12)
}
```

With:

```swift
var body: some View {
    Group {
        if isVertical {
            VStack(spacing: 6) { buttons; helpButton; balanceBadge }
        } else {
            HStack(spacing: 6) { buttons; helpButton; balanceBadge }
        }
    }
    .padding(8)
    .background(Color.white.opacity(0.07))
    .cornerRadius(12)
    .sheet(isPresented: $showHelp) { PowerUpHelpView() }
}
```

Add `helpButton` after `balanceBadge`:

```swift
private var helpButton: some View {
    Text("?")
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.white.opacity(0.7))
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(Color.white.opacity(0.12))
        .cornerRadius(8)
        .onTapGesture { showHelp = true }
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|SUCCEEDED|FAILED" | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Views/PowerUpHelpView.swift \
        RoadTripBingo/Views/PowerUpStripView.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: add power-up help sheet and ? button"
```

---

## Task 4: Opponent action notifications

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`
- Create: `RoadTripBingoTests/AppStateTests.swift`

- [ ] **Step 1: Write failing tests**

Create `RoadTripBingoTests/AppStateTests.swift`:

```swift
import XCTest
@testable import RoadTripBingo

final class AppStateTests: XCTestCase {

    private func makeBoard(targetText: String, atIndex targetIdx: Int) -> BingoBoard {
        var squares: [BingoSquare] = (0..<25).map { i in
            i == 12
                ? BingoSquare.free
                : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "🐄",
                              category: .nature, rarity: .veryCommon)
        }
        squares[targetIdx] = BingoSquare(id: UUID(), text: targetText, emoji: "👶",
                                         category: .nature, rarity: .common)
        return BingoBoard(squares: squares)
    }

    private func makeSession() -> MultipeerSession {
        MultipeerSession(displayName: "test-helper")
    }

    func test_powerUpUsed_downgrade_targeted_postsThreatsToast() {
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Sleeping Baby", atIndex: 3)

        let replacement = BingoSquare(id: UUID(), text: "Hard Thing", emoji: "🔥",
                                      category: .nature, rarity: .veryRare)
        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .downgradeTileTargeted,
                                     targetPlayer: "Zoe", targetIndex: 3,
                                     replacementSquare: replacement),
            from: "Liam")

        XCTAssertEqual(state.pendingToast?.message, "💣 Liam downgraded 'Sleeping Baby'")
        XCTAssertEqual(state.pendingToast?.style, .threat)
    }

    func test_powerUpUsed_unmark_targeted_postsThreatsToast() {
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Rest Stop", atIndex: 7)

        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .unmarkOpponentTargeted,
                                     targetPlayer: "Zoe", targetIndex: 7,
                                     replacementSquare: nil),
            from: "Liam")

        XCTAssertEqual(state.pendingToast?.message, "💥 Liam erased 'Rest Stop'")
        XCTAssertEqual(state.pendingToast?.style, .threat)
    }

    func test_powerUpUsed_upgrade_doesNotPostThreatsToast() {
        // Upgrade affects activating player's own board — not an opponent-targeting action
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Irrelevant", atIndex: 3)

        let replacement = BingoSquare(id: UUID(), text: "Easy", emoji: "🌱",
                                      category: .nature, rarity: .veryCommon)
        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .upgradeTileTargeted,
                                     targetPlayer: nil, targetIndex: 3,
                                     replacementSquare: replacement),
            from: "Liam")

        XCTAssertNil(state.pendingToast)
    }

    func test_powerUpUsed_downgrade_notTargetingMe_doesNotPostThreatsToast() {
        // Liam is targeting "Emma", not "Zoe"
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Irrelevant", atIndex: 3)
        state.opponentBoards["Emma"] = makeBoard(targetText: "Emma Tile", atIndex: 3).squares

        let replacement = BingoSquare(id: UUID(), text: "Hard", emoji: "🔥",
                                      category: .nature, rarity: .veryRare)
        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .downgradeTileTargeted,
                                     targetPlayer: "Emma", targetIndex: 3,
                                     replacementSquare: replacement),
            from: "Liam")

        XCTAssertNil(state.pendingToast)
    }
}
```

- [ ] **Step 2: Run xcodegen to add `AppStateTests.swift`**

```bash
cd /Users/pmoore/Source/roadtrip-bingo && xcodegen generate
```

Expected: `Generating project at path: /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo.xcodeproj`

- [ ] **Step 3: Run tests to confirm they fail**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|AppStateTests|PASSED|FAILED" | head -20
```

Expected: `test_powerUpUsed_downgrade_targeted_postsThreatsToast` fails — `pendingToast` is nil.

- [ ] **Step 4: Update the `powerUpUsed` delegate case in `AppState.swift`**

Replace the existing `.powerUpUsed` case in `multipeerSession(_:didReceive:from:)`:

```swift
// OLD:
case .powerUpUsed(let byName, let powerUp, let targetPlayer, let targetIndex, let replacementSquare):
    applyPowerUpEffect(powerUp, byName: byName,
                       targetPlayer: targetPlayer,
                       targetIndex: targetIndex,
                       replacementSquare: replacementSquare)
    if let board = localBoard {
        completedLine = GameEngine.winningLine(for: board)
    }
```

With:

```swift
case .powerUpUsed(let byName, let powerUp, let targetPlayer, let targetIndex, let replacementSquare):
    // Capture tile name before effect mutates the board
    var threatMessage: String? = nil
    if targetPlayer == playerName, powerUp.affectsOpponent,
       let idx = targetIndex, let board = localBoard, idx < board.squares.count {
        let tileName = board.squares[idx].text
        let verb: String
        let emoji: String
        switch powerUp {
        case .downgradeTileRandom, .downgradeTileTargeted:
            verb = "downgraded"; emoji = "💣"
        default:
            verb = "erased"; emoji = "💥"
        }
        threatMessage = "\(emoji) \(byName) \(verb) '\(tileName)'"
    }

    applyPowerUpEffect(powerUp, byName: byName,
                       targetPlayer: targetPlayer,
                       targetIndex: targetIndex,
                       replacementSquare: replacementSquare)
    if let board = localBoard {
        completedLine = GameEngine.winningLine(for: board)
    }
    if let msg = threatMessage {
        pendingToast = ToastEvent(message: msg, style: .threat)
    }
```

- [ ] **Step 5: Run tests — all four `AppStateTests` should pass**

```bash
xcodebuild test -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E "error:|AppStateTests|ToastTests|PASSED|FAILED" | head -30
```

Expected: `Test Suite 'AppStateTests' passed` and `Test Suite 'ToastTests' passed`; no errors.

- [ ] **Step 6: Commit**

```bash
git add RoadTripBingo/State/AppState.swift \
        RoadTripBingoTests/AppStateTests.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: show threat toast when opponent uses power-up on you"
```
