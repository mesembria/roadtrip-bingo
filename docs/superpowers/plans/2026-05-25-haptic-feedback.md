# Haptic Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add haptic feedback to tile marking/unmarking, BINGO line formation, win screen, power-up activation, and attack-received events using SwiftUI's `.sensoryFeedback()` modifier.

**Architecture:** All haptics are declarative `.sensoryFeedback()` modifiers placed on existing views. `BingoSquareView` owns tile feedback directly. `GameView` adds two thin `@State` counter/trigger variables to drive power-up and attack haptics, plus a BINGO-line modifier observing existing state. `WinView` fires once on appear for local wins. No new files, no UIKit.

**Tech Stack:** SwiftUI `.sensoryFeedback()` (iOS 17+), requires deployment target bump from 16.0 → 17.0.

---

### Task 1: Bump deployment target to iOS 17

**Files:**
- Modify: `project.yml`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj` (lines 489 and 587)

- [ ] **Step 1: Update project.yml**

In `project.yml`, change line 6:

```yaml
    iOS: "16.0"
```

to:

```yaml
    iOS: "17.0"
```

- [ ] **Step 2: Update project.pbxproj**

In `RoadTripBingo.xcodeproj/project.pbxproj`, change both occurrences of:

```
IPHONEOS_DEPLOYMENT_TARGET = 16.0;
```

to:

```
IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```

Both are at lines 489 and 587.

- [ ] **Step 3: Build to verify no regressions**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | tail -10
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add project.yml RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "chore: bump deployment target to iOS 17 for sensoryFeedback"
```

---

### Task 2: Tile mark/unmark haptic in BingoSquareView

**Files:**
- Modify: `RoadTripBingo/Views/BingoSquareView.swift`

The `.sensoryFeedback(trigger:feedback:)` callback overload fires whenever `isMarked` changes and returns `.impact(.light)` for marking or `.selection` for unmarking. It is attached to the `Button` (not the hidden tile branch) so it only fires for tappable tiles.

- [ ] **Step 1: Add the modifier to the Button in `body`**

Locate the `Button` in `body`:

```swift
Button(action: { withAnimation(.spring(response: 0.2)) { onTap() } }) {
    Group {
        if square.id == BingoSquare.freeSquareID {
            freeCell
        } else {
            regularCell
        }
    }
}
.buttonStyle(.plain)
```

Replace it with:

```swift
Button(action: { withAnimation(.spring(response: 0.2)) { onTap() } }) {
    Group {
        if square.id == BingoSquare.freeSquareID {
            freeCell
        } else {
            regularCell
        }
    }
}
.buttonStyle(.plain)
.sensoryFeedback(trigger: isMarked) { _, new in
    new ? .impact(.light) : .selection
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | tail -10
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/BingoSquareView.swift
git commit -m "feat: haptic feedback on tile mark/unmark"
```

---

### Task 3: GameView haptics — power-up, attack, and BINGO line

**Files:**
- Modify: `RoadTripBingo/Views/GameView.swift`

Three haptic moments live in `GameView`:
1. **BINGO line:** `.success` when `completedLine` transitions from nil → value, observed directly on existing state.
2. **Power-up used:** `.impact(.medium)` driven by a `UUID?` state counter that is set every time the local player fires a power-up.
3. **Attack received:** `.warning` driven by an `Int` counter incremented inside the existing `pendingToast` observer when the toast style is `.threat`.

- [ ] **Step 1: Add the two new `@State` variables**

Find the existing `@State` block at the top of `GameView`:

```swift
@State private var targetingPowerUp: PowerUpType? = nil
@State private var toastMessage: String? = nil
@State private var activeToastID: UUID? = nil
@State private var toastStyle: ToastStyle = .earn
@State private var showModifierReveal = false
@State private var showChallenges = false
```

Replace it with:

```swift
@State private var targetingPowerUp: PowerUpType? = nil
@State private var toastMessage: String? = nil
@State private var activeToastID: UUID? = nil
@State private var toastStyle: ToastStyle = .earn
@State private var showModifierReveal = false
@State private var showChallenges = false
@State private var powerUpTrigger: UUID? = nil
@State private var threatCount: Int = 0
```

- [ ] **Step 2: Fire power-up haptic for random activations**

Find the `onActivateRandom` closure inside `powerUpStrip(isVertical:)`:

```swift
onActivateRandom: { powerUp in
    appState.activatePowerUp(powerUp)
},
```

Replace it with:

```swift
onActivateRandom: { powerUp in
    appState.activatePowerUp(powerUp)
    powerUpTrigger = UUID()
},
```

- [ ] **Step 3: Fire power-up haptic for targeted activations**

Find the `onSelect` closure inside the `TargetingOverlayView` block in `body`:

```swift
onSelect: { targetPlayer, targetIndex in
    appState.activatePowerUp(powerUp, targetPlayer: targetPlayer, targetIndex: targetIndex)
    withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = nil }
},
```

Replace it with:

```swift
onSelect: { targetPlayer, targetIndex in
    appState.activatePowerUp(powerUp, targetPlayer: targetPlayer, targetIndex: targetIndex)
    powerUpTrigger = UUID()
    withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = nil }
},
```

- [ ] **Step 4: Increment threat counter inside the existing pendingToast observer**

Find the existing `.onChange(of: appState.pendingToast)` block:

```swift
.onChange(of: appState.pendingToast) { toast in
    guard let toast else { return }
    toastStyle = toast.style
    withAnimation(.spring()) { toastMessage = toast.message }
```

Replace those first four lines with:

```swift
.onChange(of: appState.pendingToast) { toast in
    guard let toast else { return }
    toastStyle = toast.style
    if toast.style == .threat { threatCount += 1 }
    withAnimation(.spring()) { toastMessage = toast.message }
```

- [ ] **Step 5: Add the three `.sensoryFeedback` modifiers**

Find the closing of the last `.onChange` block (end of `body`):

```swift
        .onChange(of: appState.pendingToast) { toast in
            guard let toast else { return }
            toastStyle = toast.style
            if toast.style == .threat { threatCount += 1 }
            withAnimation(.spring()) { toastMessage = toast.message }
            activeToastID = toast.id
            appState.pendingToast = nil
            let id = toast.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard activeToastID == id else { return }
                withAnimation { toastMessage = nil }
            }
        }
    }
```

Replace the closing `}` of `body` to append three modifiers:

```swift
        .onChange(of: appState.pendingToast) { toast in
            guard let toast else { return }
            toastStyle = toast.style
            if toast.style == .threat { threatCount += 1 }
            withAnimation(.spring()) { toastMessage = toast.message }
            activeToastID = toast.id
            appState.pendingToast = nil
            let id = toast.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard activeToastID == id else { return }
                withAnimation { toastMessage = nil }
            }
        }
        .sensoryFeedback(.success, trigger: appState.completedLine != nil)
        .sensoryFeedback(.impact(.medium), trigger: powerUpTrigger)
        .sensoryFeedback(.warning, trigger: threatCount)
    }
```

- [ ] **Step 6: Build to verify**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | tail -10
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add RoadTripBingo/Views/GameView.swift
git commit -m "feat: haptic feedback for power-up, attack received, and BINGO line"
```

---

### Task 4: Win screen haptic in WinView

**Files:**
- Modify: `RoadTripBingo/Views/WinView.swift`

A `@State var didAppear` flips to `true` on `.onAppear` only for local wins. The `.sensoryFeedback` modifier fires once on that flip, delivering `.impact(.heavy)` — a solid thump distinct from the earlier `.success` pulse that fired when the line completed.

- [ ] **Step 1: Add the `didAppear` state variable**

Find the top of `WinView`:

```swift
struct WinView: View {
    let winnerName: String
    @EnvironmentObject var appState: AppState
    private var isLocalWin: Bool { winnerName == appState.playerName }
```

Replace it with:

```swift
struct WinView: View {
    let winnerName: String
    @EnvironmentObject var appState: AppState
    private var isLocalWin: Bool { winnerName == appState.playerName }
    @State private var didAppear = false
```

- [ ] **Step 2: Add the modifier and onAppear to the outermost ZStack**

Find the closing of `body`:

```swift
        VStack(spacing: 32) {
            // … all content …
        }.padding(48)
        }
    }
```

The outermost `ZStack` closes with `}` before the final `}` of `body`. The full body is:

```swift
    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            if isLocalWin { ConfettiView() }
            VStack(spacing: 32) {
                Text(isLocalWin ? "🏆" : "🎯").font(.system(size: 96))
                Text(isLocalWin ? "YOU GOT BINGO!" : "\(winnerName) got BINGO!")
                    .font(AmericanaTheme.rye(38))
                    .foregroundColor(isLocalWin ? AmericanaTheme.yellow : AmericanaTheme.ink)
                    .multilineTextAlignment(.center)
                if let line = appState.completedLine, isLocalWin, let board = appState.localBoard {
                    HStack(spacing: 8) {
                        ForEach(line, id: \.self) { pos in
                            winningTileCard(board.squares[pos])
                        }
                    }
                }
                Button(action: { appState.screen = .playAgain }) {
                    Text("Continue →")
                        .font(AmericanaTheme.barlowBold(17))
                        .padding(.horizontal, 48).padding(.vertical, 16)
                        .background(AmericanaTheme.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }.padding(48)
        }
    }
```

Replace the closing `}` of the `ZStack` with:

```swift
    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            if isLocalWin { ConfettiView() }
            VStack(spacing: 32) {
                Text(isLocalWin ? "🏆" : "🎯").font(.system(size: 96))
                Text(isLocalWin ? "YOU GOT BINGO!" : "\(winnerName) got BINGO!")
                    .font(AmericanaTheme.rye(38))
                    .foregroundColor(isLocalWin ? AmericanaTheme.yellow : AmericanaTheme.ink)
                    .multilineTextAlignment(.center)
                if let line = appState.completedLine, isLocalWin, let board = appState.localBoard {
                    HStack(spacing: 8) {
                        ForEach(line, id: \.self) { pos in
                            winningTileCard(board.squares[pos])
                        }
                    }
                }
                Button(action: { appState.screen = .playAgain }) {
                    Text("Continue →")
                        .font(AmericanaTheme.barlowBold(17))
                        .padding(.horizontal, 48).padding(.vertical, 16)
                        .background(AmericanaTheme.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }.padding(48)
        }
        .sensoryFeedback(.impact(.heavy), trigger: didAppear)
        .onAppear { if isLocalWin { didAppear = true } }
    }
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | tail -10
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Run existing tests to confirm no regressions**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test 2>&1 | grep -E "Test Suite|passed|failed|error:" | tail -20
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Views/WinView.swift
git commit -m "feat: haptic feedback on win screen for local wins"
```
