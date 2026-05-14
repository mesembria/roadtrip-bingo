# Opponent Mark Feed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a fading strip of mini tile cards when opponents mark tiles — landscape sidebar (vertical stack) and portrait (horizontal strip above power-ups).

**Architecture:** New `RecentMark` model stored in `AppState.recentOpponentMarks` (capped at 3). Triggered from the `squareToggled` delegate handler. A pruning `Task` clears entries older than 10 seconds. Two new SwiftUI views (`RecentMarkCard`, `OpponentMarkFeedView`) render the strip; `GameView` inserts it into both layout branches.

**Tech Stack:** Swift, SwiftUI, existing `AmericanaTheme` (fonts, colors, `tileImage(for:)`), `AppState` observable, XCTest.

---

### Task 1: `RecentMark` model + pbxproj registration

**Files:**
- Create: `RoadTripBingo/Models/RecentMark.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create `RecentMark.swift`**

```swift
// RoadTripBingo/Models/RecentMark.swift
import Foundation

struct RecentMark: Identifiable {
    let id: UUID
    let opponentName: String
    let square: BingoSquare
    let timestamp: Date
}
```

- [ ] **Step 2: Register `RecentMark.swift` in `project.pbxproj`**

Open `RoadTripBingo.xcodeproj/project.pbxproj`. Make four edits:

**2a. Add PBXBuildFile entry** — inside `/* Begin PBXBuildFile section */`, after the last entry before `/* End PBXBuildFile section */`:
```
		A1B2C3D4E5F60002A1B2C302 /* RecentMark.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1B2C3D4E5F60001A1B2C301 /* RecentMark.swift */; };
```

**2b. Add PBXFileReference entry** — inside `/* Begin PBXFileReference section */`, after the last entry:
```
		A1B2C3D4E5F60001A1B2C301 /* RecentMark.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RecentMark.swift; sourceTree = "<group>"; };
```

**2c. Add to Models PBXGroup children** — find the `6DD0FC3F37D45333EFDF804D /* Models */` group. Inside its `children = (` list, add:
```
				A1B2C3D4E5F60001A1B2C301 /* RecentMark.swift */,
```

**2d. Add to PBXSourcesBuildPhase** — find the main target's `/* Sources */` build phase (the block containing `F5111507C220551AF21A652F /* AppState.swift in Sources */`). Add:
```
				A1B2C3D4E5F60002A1B2C302 /* RecentMark.swift in Sources */,
```

- [ ] **Step 3: Verify build compiles cleanly**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Models/RecentMark.swift RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: add RecentMark model"
```

---

### Task 2: AppState queue + pruning + tests

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`
- Modify: `RoadTripBingoTests/AppStateTests.swift`

- [ ] **Step 1: Write failing tests**

Add these four test methods to `AppStateTests.swift`, inside the `AppStateTests` class, after the last existing test:

```swift
func test_squareToggled_isMarked_appendsRecentMark() {
    let state = AppState()
    let targetSquare = BingoSquare(id: UUID(), text: "Red Car", emoji: "x",
                                   category: .vehicles, rarity: .common)
    state.opponentBoards["Emma"] = (0..<25).map { i in
        if i == 5  { return targetSquare }
        if i == 12 { return BingoSquare.free }
        return BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                           category: .nature, rarity: .veryCommon)
    }
    state.opponentMarked["Emma"] = [12]

    state.multipeerSession(makeSession(),
        didReceive: .squareToggled(position: 5, isMarked: true),
        from: "Emma")

    XCTAssertEqual(state.recentOpponentMarks.count, 1)
    XCTAssertEqual(state.recentOpponentMarks[0].opponentName, "Emma")
    XCTAssertEqual(state.recentOpponentMarks[0].square.text, "Red Car")
}

func test_squareToggled_notMarked_doesNotAppendRecentMark() {
    let state = AppState()
    let targetSquare = BingoSquare(id: UUID(), text: "Red Car", emoji: "x",
                                   category: .vehicles, rarity: .common)
    state.opponentBoards["Emma"] = (0..<25).map { i in
        if i == 5  { return targetSquare }
        if i == 12 { return BingoSquare.free }
        return BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                           category: .nature, rarity: .veryCommon)
    }
    state.opponentMarked["Emma"] = [5, 12]

    state.multipeerSession(makeSession(),
        didReceive: .squareToggled(position: 5, isMarked: false),
        from: "Emma")

    XCTAssertTrue(state.recentOpponentMarks.isEmpty)
}

func test_recentMarks_capped_at_three_drops_oldest() {
    let state = AppState()
    let squares: [BingoSquare] = (0..<25).map { i in
        i == 12 ? BingoSquare.free
                : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                              category: .nature, rarity: .veryCommon)
    }
    state.opponentBoards["Emma"] = squares
    state.opponentMarked["Emma"] = [12]

    for pos in [0, 1, 2, 3] {
        state.multipeerSession(makeSession(),
            didReceive: .squareToggled(position: pos, isMarked: true),
            from: "Emma")
    }

    XCTAssertEqual(state.recentOpponentMarks.count, 3)
    XCTAssertEqual(state.recentOpponentMarks[0].square.text, "Tile 1")
    XCTAssertEqual(state.recentOpponentMarks[2].square.text, "Tile 3")
}

func test_gameStarted_clearsRecentMarks() {
    let state = AppState()
    state.playerName = "Zoe"
    let stub = BingoSquare(id: UUID(), text: "Stub", emoji: "x",
                           category: .nature, rarity: .veryCommon)
    state.recentOpponentMarks = [RecentMark(id: UUID(), opponentName: "Emma",
                                             square: stub, timestamp: Date())]

    var boards: [String: [BingoSquare]] = [:]
    for name in ["Zoe", "Emma"] {
        boards[name] = (0..<25).map { i in
            i == 12 ? BingoSquare.free
                    : BingoSquare(id: UUID(), text: "\(name) \(i)", emoji: "x",
                                  category: .nature, rarity: .veryCommon)
        }
    }
    state.multipeerSession(makeSession(),
        didReceive: .gameStarted(boards: boards),
        from: "host")

    XCTAssertTrue(state.recentOpponentMarks.isEmpty)
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch' \
  test -only-testing:RoadTripBingoTests/AppStateTests 2>&1 | grep -E "FAIL|error:|passed|failed"
```
Expected: compile error `value of type 'AppState' has no member 'recentOpponentMarks'`

- [ ] **Step 3: Add properties to `AppState.swift`**

In the `// MARK: - Game` section (after `var reserveSquares: [BingoSquare] = []`), add:

```swift
    @Published var recentOpponentMarks: [RecentMark] = []
    private let maxRecentMarks = 3
    private var pruningTask: Task<Void, Never>?
```

- [ ] **Step 4: Add `appendRecentMark` and `startPruningIfNeeded` helpers to `AppState.swift`**

Add these two methods inside `AppState`, just before the `// MARK: - MultipeerSessionDelegate` comment:

```swift
    private func appendRecentMark(_ mark: RecentMark) {
        if recentOpponentMarks.count >= maxRecentMarks {
            recentOpponentMarks.removeFirst()
        }
        recentOpponentMarks.append(mark)
        startPruningIfNeeded()
    }

    private func startPruningIfNeeded() {
        guard pruningTask == nil else { return }
        pruningTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !self.recentOpponentMarks.isEmpty {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                let cutoff = Date().addingTimeInterval(-10)
                self.recentOpponentMarks.removeAll { $0.timestamp < cutoff }
            }
            self.pruningTask = nil
        }
    }
```

- [ ] **Step 5: Trigger `appendRecentMark` in `squareToggled` handler**

Find this block in `multipeerSession(_:didReceive:from:)` (around line 410):

```swift
        case .squareToggled(let position, let isMarked):
            var current = opponentMarked[peerName] ?? []
            if isMarked { current.insert(position) } else { current.remove(position) }
            opponentMarked[peerName] = current
```

Replace with:

```swift
        case .squareToggled(let position, let isMarked):
            var current = opponentMarked[peerName] ?? []
            if isMarked { current.insert(position) } else { current.remove(position) }
            opponentMarked[peerName] = current
            if isMarked, let square = opponentBoards[peerName]?[position] {
                appendRecentMark(RecentMark(id: UUID(), opponentName: peerName,
                                            square: square, timestamp: Date()))
            }
```

- [ ] **Step 6: Clear queue on round reset**

Add these three lines to `dealAndLaunchRound`, immediately after `opponentMarked = [:]` (around line 173):

```swift
        recentOpponentMarks = []
        pruningTask?.cancel()
        pruningTask = nil
```

Add the same three lines to the `gameStarted` case handler, immediately after `opponentMarked = [:]` (around line 400):

```swift
            recentOpponentMarks = []
            pruningTask?.cancel()
            pruningTask = nil
```

Add the same three lines to the `playAgain` case handler, immediately after `opponentMarked = [:]` (around line 427):

```swift
            recentOpponentMarks = []
            pruningTask?.cancel()
            pruningTask = nil
```

Add these three lines to `goHome()`, after `opponentMarked = [:]` (around line 97):

```swift
        recentOpponentMarks = []
        pruningTask?.cancel()
        pruningTask = nil
```

- [ ] **Step 7: Run tests — expect all four to pass**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch' \
  test -only-testing:RoadTripBingoTests/AppStateTests 2>&1 | grep -E "passed|failed|error:"
```
Expected: `Test Suite 'AppStateTests' passed`

- [ ] **Step 8: Commit**

```bash
git add RoadTripBingo/State/AppState.swift RoadTripBingoTests/AppStateTests.swift
git commit -m "feat: add opponent mark feed queue to AppState"
```

---

### Task 3: `RecentMarkCard` and `OpponentMarkFeedView` + pbxproj

**Files:**
- Create: `RoadTripBingo/Views/RecentMarkCard.swift`
- Create: `RoadTripBingo/Views/OpponentMarkFeedView.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create `RecentMarkCard.swift`**

```swift
// RoadTripBingo/Views/RecentMarkCard.swift
import SwiftUI

struct RecentMarkCard: View {
    let mark: RecentMark
    let isLandscape: Bool
    @State private var opacity: Double = 1.0

    var body: some View {
        Group {
            if isLandscape { landscapePill } else { portraitSquare }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.linear(duration: 10)) { opacity = 0 }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private var landscapePill: some View {
        HStack(spacing: 0) {
            tileImage
                .frame(width: 44, height: 44)
                .clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(mark.opponentName.uppercased())
                    .font(AmericanaTheme.barlowSemiBold(9))
                    .foregroundColor(AmericanaTheme.greenLight)
                    .lineLimit(1)
                Text(mark.square.text)
                    .font(AmericanaTheme.barlowBold(10))
                    .foregroundColor(AmericanaTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AmericanaTheme.parchment)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(Color(red: 0.545, green: 0.412, blue: 0.078), lineWidth: 2))
        .cornerRadius(6)
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 1, y: 1)
    }

    private var portraitSquare: some View {
        VStack(spacing: 0) {
            Text(mark.opponentName.uppercased())
                .font(AmericanaTheme.barlowSemiBold(9))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(AmericanaTheme.green)
            tileImage
                .frame(width: 68, height: 54)
                .clipped()
            Text(mark.square.text)
                .font(AmericanaTheme.barlowBold(9))
                .foregroundColor(AmericanaTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 3).padding(.vertical, 2)
        }
        .frame(width: 72)
        .background(AmericanaTheme.parchment)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(Color(red: 0.545, green: 0.412, blue: 0.078), lineWidth: 2))
        .cornerRadius(6)
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 1, y: 1)
    }

    @ViewBuilder private var tileImage: some View {
        if let img = AmericanaTheme.tileImage(for: mark.square) {
            img.resizable().scaledToFill()
        } else {
            AmericanaTheme.paper
        }
    }
}
```

- [ ] **Step 2: Create `OpponentMarkFeedView.swift`**

```swift
// RoadTripBingo/Views/OpponentMarkFeedView.swift
import SwiftUI

struct OpponentMarkFeedView: View {
    let marks: [RecentMark]
    let isLandscape: Bool

    var body: some View {
        if isLandscape {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(marks) { mark in
                    RecentMarkCard(mark: mark, isLandscape: true)
                }
            }
            .animation(.spring(response: 0.25), value: marks.count)
        } else {
            HStack(spacing: 8) {
                ForEach(marks) { mark in
                    RecentMarkCard(mark: mark, isLandscape: false)
                }
            }
            .frame(height: marks.isEmpty ? 0 : 90)
            .clipped()
            .animation(.spring(response: 0.25), value: marks.count)
        }
    }
}
```

- [ ] **Step 3: Register both new view files in `project.pbxproj`**

Open `RoadTripBingo.xcodeproj/project.pbxproj`. Make the following edits:

**3a. Add PBXBuildFile entries** (inside `/* Begin PBXBuildFile section */`):
```
		A1B2C3D4E5F60004A1B2C304 /* RecentMarkCard.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1B2C3D4E5F60003A1B2C303 /* RecentMarkCard.swift */; };
		A1B2C3D4E5F60006A1B2C306 /* OpponentMarkFeedView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1B2C3D4E5F60005A1B2C305 /* OpponentMarkFeedView.swift */; };
```

**3b. Add PBXFileReference entries** (inside `/* Begin PBXFileReference section */`):
```
		A1B2C3D4E5F60003A1B2C303 /* RecentMarkCard.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RecentMarkCard.swift; sourceTree = "<group>"; };
		A1B2C3D4E5F60005A1B2C305 /* OpponentMarkFeedView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpponentMarkFeedView.swift; sourceTree = "<group>"; };
```

**3c. Add to Views PBXGroup children** — find the `1FE6D976819296AC8120C9D8 /* Views */` group's `children = (` list. Add after `6F48F6E5624B667D40564DF2 /* OpponentStripView.swift */,`:
```
				A1B2C3D4E5F60003A1B2C303 /* RecentMarkCard.swift */,
				A1B2C3D4E5F60005A1B2C305 /* OpponentMarkFeedView.swift */,
```

**3d. Add to PBXSourcesBuildPhase** — find the main target's Sources phase (contains `2E8B64CFB6574C864BB4D4B2 /* OpponentStripView.swift in Sources */`). Add:
```
				A1B2C3D4E5F60004A1B2C304 /* RecentMarkCard.swift in Sources */,
				A1B2C3D4E5F60006A1B2C306 /* OpponentMarkFeedView.swift in Sources */,
```

- [ ] **Step 4: Verify build compiles cleanly**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Views/RecentMarkCard.swift \
        RoadTripBingo/Views/OpponentMarkFeedView.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: add RecentMarkCard and OpponentMarkFeedView"
```

---

### Task 4: Wire feed into `GameView`

**Files:**
- Modify: `RoadTripBingo/Views/GameView.swift`

- [ ] **Step 1: Add feed to portrait layout**

In `GameView.swift`, find the `portraitLayout(board:)` function. Replace its entire body with:

```swift
    private func portraitLayout(board: BingoBoard) -> some View {
        VStack(spacing: 8) {
            opponentHUD
            GeometryReader { geo in
                let gridSize = min(geo.size.width - 32, geo.size.height)
                BingoGridView(
                    board: board,
                    highlightedPositions: Set(appState.completedLine ?? []),
                    onTap: appState.toggleSquare(at:)
                )
                .frame(width: gridSize, height: gridSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            bingoButton
            OpponentMarkFeedView(marks: appState.recentOpponentMarks, isLandscape: false)
                .padding(.horizontal, 16)
            powerUpStrip(isVertical: false)
        }
        .padding(.vertical, 8)
    }
```

- [ ] **Step 2: Add feed to landscape layout's left sidebar**

In `landscapeLayout(board:)`, find the left sidebar `VStack`. Replace it with:

```swift
            VStack(spacing: 12) {
                if !appState.opponentMarked.isEmpty {
                    OpponentStripView(
                        opponentMarked: appState.opponentMarked,
                        tokenBalances: appState.tokenBalances,
                        isVertical: true
                    )
                }
                if !appState.recentOpponentMarks.isEmpty {
                    OpponentMarkFeedView(marks: appState.recentOpponentMarks, isLandscape: true)
                }
                Spacer()
                bingoButton
            }
            .frame(width: 130)
```

- [ ] **Step 3: Build and run tests to confirm nothing broke**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch' \
  test 2>&1 | grep -E "passed|failed|error:"
```
Expected: all test suites pass

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Views/GameView.swift
git commit -m "feat: wire opponent mark feed into GameView portrait and landscape layouts"
```
