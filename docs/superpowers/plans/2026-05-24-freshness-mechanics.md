# Freshness Mechanics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add round modifiers (random rule twists per round) and daily challenges (persistent cross-round goals) to keep multi-day play sessions fresh.

**Architecture:** Three phases — (1) refactor `opponentMarked` to UUID-based tracking and persist win history, (2) round modifier system with models, AppState logic, and Americana UI, (3) daily challenge system with protocol-driven evaluation, `DailyState` persistence, and UI. The `frontend-design` skill is invoked before implementing each new visual component.

**Tech Stack:** Swift 5.9 / SwiftUI, MultipeerConnectivity, UserDefaults (persistence). Build: `xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`. Tests: replace `-scheme RoadTripBingo` with `-scheme RoadTripBingoTests`.

> **Note on BingoSquare.category:** `BingoSquare` already has a `category: SquareCategory` field (vehicles, nature, food, landmarks, weather, signs). Category-based challenges ("spot 3 vehicle tiles") can be added in a future pass simply by adding new `DailyChallengeType` cases — no model changes needed.

---

## File Structure

**New files:**
- `RoadTripBingo/Models/RoundModifier.swift` — `RoundModifier` enum, `PatternShape` enum
- `RoadTripBingo/Models/DailyChallenge.swift` — `DailyChallengeType` enum, `DailyChallenge` struct, `ChallengeEvent` enum, `ChallengeEvaluationContext` struct
- `RoadTripBingo/Models/DailyState.swift` — `DailyState` struct with UserDefaults persistence
- `RoadTripBingo/Views/ModifierRevealView.swift` — full-screen modifier reveal banner
- `RoadTripBingo/Views/ModifierBadgeView.swift` — persistent badge + rule popover
- `RoadTripBingo/Views/DailyChallengesView.swift` — challenge list sheet
- `RoadTripBingoTests/RoundModifierTests.swift`
- `RoadTripBingoTests/DailyChallengeTests.swift`

**Modified files:**
- `RoadTripBingo/Models/MultipeerMessage.swift` — add `.roundModifier`, `.boardShuffled`
- `RoadTripBingo/Models/BingoBoard.swift` — add `shuffleUnmarkedPositions()`
- `RoadTripBingo/Game/GameEngine.swift` — add `hotStreakLine(for:)`, `patternPositions`, `patternLine(for:shape:)`
- `RoadTripBingo/State/AppState.swift` — major additions throughout
- `RoadTripBingo/Views/GameView.swift` — modifier reveal overlay, modifier badge, challenge badge
- `RoadTripBingo/Views/HomeView.swift` — daily challenges button
- `RoadTripBingo/Views/BingoGridView.swift` — `hiddenPositions` parameter for Fog of War
- `RoadTripBingo/Views/BingoSquareView.swift` — `isHidden` parameter
- `RoadTripBingo/Views/TargetingOverlayView.swift` — accept `[String: Set<UUID>]`
- `RoadTripBingo/Views/OpponentStripView.swift` — accept `[String: Set<UUID>]` + `opponentBoards`
- `RoadTripBingoTests/AppStateTests.swift` — update for UUID refactor
- `RoadTripBingoTests/GameEngineTests.swift` — add modifier win condition tests
- `RoadTripBingo.xcodeproj/project.pbxproj` — register new Swift files

---

## Task 1: Refactor opponentMarked from Set\<Int\> to Set\<UUID\>

No behaviour changes — pure type correction. This is a prerequisite for Shuffle Board and prevents position-based mark tracking from breaking when tile positions move.

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`
- Modify: `RoadTripBingo/Views/TargetingOverlayView.swift`
- Modify: `RoadTripBingo/Views/OpponentStripView.swift`
- Modify: `RoadTripBingo/Views/GameView.swift`
- Modify: `RoadTripBingoTests/AppStateTests.swift`

- [ ] **Step 1: Change the opponentMarked type in AppState**

In `AppState.swift`, change the declaration:
```swift
// Before:
@Published var opponentMarked: [String: Set<Int>] = [:]

// After:
@Published var opponentMarked: [String: Set<UUID>] = [:]
```

- [ ] **Step 2: Update opponentMarked initialization sites**

Every place that sets `opponentMarked[name] = [12]` becomes `opponentMarked[name] = [BingoSquare.freeSquareID]`. There are four sites:
- `dealAndLaunchRound`: `opponentMarked[name] = [12]`
- `.gameStarted` handler: `opponentMarked[name] = [12]`
- `.playAgain` handler: `opponentMarked[name] = [12]`
- `goHome()`: No change needed — it sets `opponentMarked = [:]`

Update all three mark sites:
```swift
opponentMarked[name] = [BingoSquare.freeSquareID]
```

- [ ] **Step 3: Update squareToggled delegate handler**

In the `.squareToggled(let position, let isMarked)` handler:
```swift
// Before:
var current = opponentMarked[peerName] ?? []
if isMarked { current.insert(position) } else { current.remove(position) }
opponentMarked[peerName] = current

// After:
if let board = opponentBoards[peerName], position < board.count {
    let tileID = board[position].id
    if isMarked { opponentMarked[peerName]?.insert(tileID) }
    else { opponentMarked[peerName]?.remove(tileID) }
}
```

- [ ] **Step 4: Update applyPowerUpEffect to use UUID**

In `applyPowerUpEffect`, three cases reference `opponentMarked` by position index:

```swift
// .freeMark on opponent (byName != playerName):
// Before: opponentMarked[byName]?.insert(idx)
// After:
if let board = opponentBoards[byName], let idx, idx < board.count {
    opponentMarked[byName]?.insert(board[idx].id)
}

// .downgradeTileRandom/.downgradeTileTargeted — remove old mark before tile replaced:
// Before: opponentMarked[target]?.remove(idx)
// After:
if let board = opponentBoards[target], let idx, idx < board.count {
    opponentMarked[target]?.remove(board[idx].id)
}

// .unmarkOpponentRandom/.unmarkOpponentTargeted:
// Before: opponentMarked[target]?.remove(idx)
// After:
if let board = opponentBoards[target], let idx, idx < board.count {
    opponentMarked[target]?.remove(board[idx].id)
}
```

- [ ] **Step 5: Update lowestRarityOpponentTile() and markedOpponentTile()**

```swift
private func lowestRarityOpponentTile() -> (String, Int)? {
    let rarityOrder: [SquareRarity] = [.veryCommon, .common, .uncommon, .rare, .veryRare]
    var best: (name: String, idx: Int, rank: Int)? = nil
    for (oppName, oppBoard) in opponentBoards {
        let markedIDs = opponentMarked[oppName] ?? []
        for (idx, square) in oppBoard.enumerated() {
            guard square.id != BingoSquare.freeSquareID,
                  !markedIDs.contains(square.id) else { continue }
            let rank = rarityOrder.firstIndex(of: square.rarity) ?? 99
            if best == nil || rank < best!.rank { best = (oppName, idx, rank) }
        }
    }
    return best.map { ($0.name, $0.idx) }
}

private func markedOpponentTile() -> (String, Int)? {
    var best: (name: String, idx: Int)? = nil
    for (oppName, markedIDs) in opponentMarked {
        guard let board = opponentBoards[oppName] else { continue }
        for (idx, square) in board.enumerated() {
            guard square.id != BingoSquare.freeSquareID,
                  markedIDs.contains(square.id) else { continue }
            if best == nil || idx > best!.idx { best = (oppName, idx) }
        }
    }
    return best.map { ($0.name, $0.idx) }
}
```

- [ ] **Step 6: Update TargetingOverlayView**

Change the property type and the `isMarked` check:
```swift
// Before:
let opponentMarked: [String: Set<Int>]
// ...
let isMarked = marked.contains(idx)

// After:
let opponentMarked: [String: Set<UUID>]
// ...
let isMarked = marked.contains(square.id)
```

- [ ] **Step 7: Update OpponentStripView and MiniGridView**

`MiniGridView` still takes `Set<Int>` (positions for display) — keep it. Convert UUIDs to positions in `OpponentStripView.opponentCard(name:)`:

```swift
// Add opponentBoards property:
let opponentBoards: [String: [BingoSquare]]
let opponentMarked: [String: Set<UUID>]

// In opponentCard(name:):
private func opponentCard(name: String) -> some View {
    let markedIDs = opponentMarked[name] ?? []
    let board = opponentBoards[name] ?? []
    let markedPositions: Set<Int> = Set(board.enumerated().compactMap { idx, sq in
        markedIDs.contains(sq.id) ? idx : nil
    })
    let coins = tokenBalances[name]
    return VStack(spacing: 6) {
        // ... existing header HStack unchanged ...
        MiniGridView(markedPositions: markedPositions)
        Text("\(markedPositions.count) ✓")
            .font(AmericanaTheme.barlowSemiBold(10))
            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
    }
    .frame(maxWidth: .infinity)
}
```

- [ ] **Step 8: Update GameView call sites**

`GameView` passes `opponentMarked` to both `OpponentStripView` and `TargetingOverlayView`. The types will now match since both are updated to `[String: Set<UUID>]`. Also pass `opponentBoards` to `OpponentStripView` wherever it is constructed (search for `OpponentStripView(` in `GameView.swift` — there are two call sites, one landscape, one portrait).

- [ ] **Step 9: Update AppStateTests**

Every test that sets `opponentMarked` by position must switch to UUID:

```swift
// test_squareToggled_isMarked_appendsRecentMark:
// Before: state.opponentMarked["Emma"] = [12]
// After:
state.opponentMarked["Emma"] = [BingoSquare.freeSquareID]

// test_squareToggled_notMarked_doesNotAppendRecentMark:
// Before: state.opponentMarked["Emma"] = [5, 12]
// After (targetSquare.id is the UUID of position 5):
state.opponentMarked["Emma"] = [targetSquare.id, BingoSquare.freeSquareID]

// test_recentMarks_capped_at_three_drops_oldest:
// Before: state.opponentMarked["Emma"] = [12]
// After:
state.opponentMarked["Emma"] = [BingoSquare.freeSquareID]
```

- [ ] **Step 10: Build and run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test 2>&1 | tail -20
```
Expected: All existing tests pass.

- [ ] **Step 11: Commit**

```bash
git add RoadTripBingo/State/AppState.swift \
        RoadTripBingo/Views/TargetingOverlayView.swift \
        RoadTripBingo/Views/OpponentStripView.swift \
        RoadTripBingo/Views/GameView.swift \
        RoadTripBingoTests/AppStateTests.swift
git commit -m "refactor: opponentMarked Set<Int> → Set<UUID> for position-independent tracking"
```

---

## Task 2: Persist win history + scaffold DailyState

**Files:**
- Create: `RoadTripBingo/Models/DailyState.swift`
- Modify: `RoadTripBingo/State/AppState.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create DailyState.swift**

```swift
import Foundation

// DailyChallengeType is defined in DailyChallenge.swift (Task 10).
// Until Task 10, challengeTypes uses [String] (raw values). Task 10 upgrades it.
struct DailyState: Codable {
    var date: String                // ISO "yyyy-MM-dd"
    var challengeTypes: [String]    // DailyChallengeType.rawValues — typed in Task 10
    var completedIDs: Set<String>   // DailyChallengeType.rawValue strings
    var winsToday: Int
    var roundsPlayedToday: Int

    static let userDefaultsKey = "dailyState"

    static func load() -> DailyState {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let state = try? JSONDecoder().decode(DailyState.self, from: data)
        else { return DailyState.fresh() }
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: DailyState.userDefaultsKey)
        }
    }

    static func fresh() -> DailyState {
        DailyState(date: Self.today(), challengeTypes: [], completedIDs: [], winsToday: 0, roundsPlayedToday: 0)
    }

    static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

- [ ] **Step 2: Move winHistory to UserDefaults**

In `AppState.swift`, change `winHistory` from a bare `[String: Int]` dict to one that persists:

```swift
// Before:
@Published var winHistory: [String: Int] = [:]

// After:
@Published var winHistory: [String: Int] = {
    guard let data = UserDefaults.standard.data(forKey: "winHistory"),
          let dict = try? JSONDecoder().decode([String: Int].self, from: data)
    else { return [:] }
    return dict
}() {
    didSet {
        if let data = try? JSONEncoder().encode(winHistory) {
            UserDefaults.standard.set(data, forKey: "winHistory")
        }
    }
}
```

- [ ] **Step 3: Add dailyState to AppState and scaffold rollIfNeeded**

```swift
// In AppState, add:
var dailyState: DailyState = DailyState.load()

// Add stub that Task 11 will complete:
func rollDailyChallengesIfNeeded() {
    if dailyState.date != DailyState.today() {
        dailyState = DailyState.fresh()
    }
    // Challenge rolling wired in Task 11
}
```

Call `rollDailyChallengesIfNeeded()` from `AppState.init()`:
```swift
init() {
    self.playerName = UserDefaults.standard.string(forKey: "playerName") ?? ""
    rollDailyChallengesIfNeeded()
}
```

- [ ] **Step 4: Register DailyState.swift in project.pbxproj**

Open `RoadTripBingo.xcodeproj/project.pbxproj`. Add four entries following the exact same pattern as `BingoSquare.swift`:
1. `PBXFileReference` for `DailyState.swift` (lastKnownFileType = `sourcecode.swift`)
2. `PBXBuildFile` referencing that file reference
3. Child entry in the `Models` `PBXGroup`
4. Entry in `PBXSourcesBuildPhase`

Generate UUIDs using `uuidgen | tr -d '-' | head -c 24`.

- [ ] **Step 5: Build and run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test 2>&1 | tail -20
```
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add RoadTripBingo/Models/DailyState.swift \
        RoadTripBingo/State/AppState.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: persist win history to UserDefaults, scaffold DailyState model"
```

---

## Task 3: RoundModifier + PatternShape models + MultipeerMessage additions

**Files:**
- Create: `RoadTripBingo/Models/RoundModifier.swift`
- Modify: `RoadTripBingo/Models/MultipeerMessage.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing test for RoundModifier Codable roundtrip**

In a new file `RoadTripBingoTests/RoundModifierTests.swift`:
```swift
import XCTest
@testable import RoadTripBingo

final class RoundModifierTests: XCTestCase {

    func test_roundModifier_codable_roundtrip() throws {
        let modifiers: [RoundModifier] = [
            .hotStreak, .doubleDown, .noPowers, .sniper,
            .fogOfWar, .shiftingTiles, .shuffleBoard,
            .patternWin(.x), .patternWin(.fourCorners), .patternWin(.plus)
        ]
        for modifier in modifiers {
            let data = try JSONEncoder().encode(modifier)
            let decoded = try JSONDecoder().decode(RoundModifier.self, from: data)
            XCTAssertEqual(decoded, modifier, "Failed roundtrip for \(modifier)")
        }
    }

    func test_roundModifier_random_returnsValidModifier() {
        for _ in 0..<20 {
            let m = RoundModifier.random()
            // Just ensure it doesn't crash and is one of the known cases
            XCTAssertNotNil(m)
        }
    }

    func test_patternShape_x_positions() {
        XCTAssertEqual(PatternShape.x.positions.sorted(), [0, 4, 6, 8, 12, 16, 18, 20, 24])
    }

    func test_patternShape_fourCorners_positions() {
        XCTAssertEqual(PatternShape.fourCorners.positions.sorted(), [0, 4, 20, 24])
    }

    func test_patternShape_plus_positions() {
        XCTAssertEqual(PatternShape.plus.positions.sorted(), [2, 7, 10, 11, 12, 13, 14, 17, 22])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/RoundModifierTests 2>&1 | tail -10
```
Expected: Build error — `RoundModifier` not found.

- [ ] **Step 3: Create RoundModifier.swift**

```swift
import Foundation

enum PatternShape: String, Codable, CaseIterable, Equatable {
    case x
    case fourCorners
    case plus

    var positions: [Int] {
        switch self {
        case .x:           return [0, 4, 6, 8, 12, 16, 18, 20, 24]
        case .fourCorners: return [0, 4, 20, 24]
        case .plus:        return [2, 7, 10, 11, 12, 13, 14, 17, 22]
        }
    }

    var displayName: String {
        switch self {
        case .x:           return "X Shape"
        case .fourCorners: return "Four Corners"
        case .plus:        return "Plus Sign"
        }
    }
}

enum RoundModifier: Codable, Equatable {
    case hotStreak
    case doubleDown
    case noPowers
    case sniper
    case patternWin(PatternShape)
    case fogOfWar
    case shiftingTiles
    case shuffleBoard

    static func random() -> RoundModifier {
        let base: [RoundModifier] = [.hotStreak, .doubleDown, .noPowers, .sniper,
                                     .fogOfWar, .shiftingTiles, .shuffleBoard]
        let withPatterns: [RoundModifier] = PatternShape.allCases.map { .patternWin($0) }
        return (base + withPatterns).randomElement()!
    }

    var emoji: String {
        switch self {
        case .hotStreak:        return "🔥"
        case .doubleDown:       return "💰"
        case .noPowers:         return "🚫"
        case .sniper:           return "🎯"
        case .patternWin:       return "🗺️"
        case .fogOfWar:         return "🌫️"
        case .shiftingTiles:    return "🌊"
        case .shuffleBoard:     return "🔀"
        }
    }

    var shortName: String {
        switch self {
        case .hotStreak:            return "Hot Streak"
        case .doubleDown:           return "Double Down"
        case .noPowers:             return "No Powers"
        case .sniper:               return "Sniper"
        case .patternWin(let s):    return s.displayName
        case .fogOfWar:             return "Fog of War"
        case .shiftingTiles:        return "Shifting Tiles"
        case .shuffleBoard:         return "Shuffle Board"
        }
    }

    var ruleDescription: String {
        switch self {
        case .hotStreak:
            return "First to mark 3 tiles in any line wins instantly."
        case .doubleDown:
            return "All token earnings are doubled this round."
        case .noPowers:
            return "Power-ups are disabled. Pure spotting only."
        case .sniper:
            return "Attack power-ups cost 1 token less."
        case .patternWin(let shape):
            return "Must complete the \(shape.displayName) pattern to win."
        case .fogOfWar:
            return "10 tiles start hidden. Each opponent mark shifts the fog. Every 3rd shift clears one tile."
        case .shiftingTiles:
            return "Each time an opponent spots something, one of your unmarked tiles is replaced."
        case .shuffleBoard:
            return "Each time an opponent spots something, your unmarked tile positions shuffle."
        }
    }

    // MARK: - Manual Codable (enum with associated value can't use synthesized)

    private enum CodingKeys: String, CodingKey { case type, shape }
    private enum ModifierType: String, Codable {
        case hotStreak, doubleDown, noPowers, sniper, patternWin, fogOfWar, shiftingTiles, shuffleBoard
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hotStreak:     try c.encode(ModifierType.hotStreak, forKey: .type)
        case .doubleDown:    try c.encode(ModifierType.doubleDown, forKey: .type)
        case .noPowers:      try c.encode(ModifierType.noPowers, forKey: .type)
        case .sniper:        try c.encode(ModifierType.sniper, forKey: .type)
        case .fogOfWar:      try c.encode(ModifierType.fogOfWar, forKey: .type)
        case .shiftingTiles: try c.encode(ModifierType.shiftingTiles, forKey: .type)
        case .shuffleBoard:  try c.encode(ModifierType.shuffleBoard, forKey: .type)
        case .patternWin(let shape):
            try c.encode(ModifierType.patternWin, forKey: .type)
            try c.encode(shape, forKey: .shape)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ModifierType.self, forKey: .type)
        switch type {
        case .hotStreak:     self = .hotStreak
        case .doubleDown:    self = .doubleDown
        case .noPowers:      self = .noPowers
        case .sniper:        self = .sniper
        case .fogOfWar:      self = .fogOfWar
        case .shiftingTiles: self = .shiftingTiles
        case .shuffleBoard:  self = .shuffleBoard
        case .patternWin:
            let shape = try c.decode(PatternShape.self, forKey: .shape)
            self = .patternWin(shape)
        }
    }
}
```

- [ ] **Step 4: Add MultipeerMessage cases**

In `MultipeerMessage.swift`, add to the `MessageType` enum:
```swift
case roundModifier, boardShuffled
```

Add to the `CodingKeys` enum:
```swift
case modifier, shuffledSquares, shuffledByName
```

Add encode cases:
```swift
case .roundModifier(let modifier):
    try c.encode(MessageType.roundModifier, forKey: .type)
    try c.encode(modifier, forKey: .modifier)
case .boardShuffled(let byName, let squares):
    try c.encode(MessageType.boardShuffled, forKey: .type)
    try c.encode(byName, forKey: .shuffledByName)
    try c.encode(squares, forKey: .shuffledSquares)
```

Add decode cases:
```swift
case .roundModifier:
    self = .roundModifier(try c.decode(RoundModifier.self, forKey: .modifier))
case .boardShuffled:
    self = .boardShuffled(
        byName: try c.decode(String.self, forKey: .shuffledByName),
        squares: try c.decode([BingoSquare].self, forKey: .shuffledSquares)
    )
```

Add the enum cases themselves:
```swift
case roundModifier(RoundModifier)
case boardShuffled(byName: String, squares: [BingoSquare])
```

- [ ] **Step 5: Register new files in project.pbxproj**

Add `RoundModifier.swift` and `RoundModifierTests.swift` to the pbxproj following the same pattern as Task 2 Step 4. `RoundModifierTests.swift` goes in the test target's `PBXSourcesBuildPhase`, not the app target.

- [ ] **Step 6: Run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/RoundModifierTests 2>&1 | tail -10
```
Expected: All 5 tests pass.

- [ ] **Step 7: Commit**

```bash
git add RoadTripBingo/Models/RoundModifier.swift \
        RoadTripBingo/Models/MultipeerMessage.swift \
        RoadTripBingoTests/RoundModifierTests.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: add RoundModifier model, PatternShape, and MultipeerMessage cases"
```

---

## Task 4: GameEngine — hotStreakLine and patternLine

**Files:**
- Modify: `RoadTripBingo/Game/GameEngine.swift`
- Modify: `RoadTripBingoTests/GameEngineTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `GameEngineTests.swift`:
```swift
// MARK: - hotStreakLine

func test_hotStreakLine_freshBoardReturnsNil() {
    XCTAssertNil(GameEngine.hotStreakLine(for: makeBoard()))
}

func test_hotStreakLine_two_markedReturnsNil() {
    XCTAssertNil(GameEngine.hotStreakLine(for: makeBoard(marking: [0, 1])))
}

func test_hotStreakLine_three_inRow_returnsLine() {
    let line = GameEngine.hotStreakLine(for: makeBoard(marking: [0, 1, 2]))
    XCTAssertEqual(line, [0, 1, 2, 3, 4])
}

func test_hotStreakLine_three_inCol_returnsLine() {
    let line = GameEngine.hotStreakLine(for: makeBoard(marking: [0, 5, 10]))
    XCTAssertEqual(line, [0, 5, 10, 15, 20])
}

func test_hotStreakLine_three_inDiagonal_withFree_returnsLine() {
    // Main diagonal [0,6,12,18,24]: 12 is FREE (pre-marked). Mark 2 more → 3 total.
    let line = GameEngine.hotStreakLine(for: makeBoard(marking: [0, 6]))
    XCTAssertEqual(line, [0, 6, 12, 18, 24])
}

// MARK: - patternLine

func test_patternLine_fourCorners_allMarked_returnsPositions() {
    let board = makeBoard(marking: [0, 4, 20, 24])
    let line = GameEngine.patternLine(for: board, shape: .fourCorners)
    XCTAssertEqual(line?.sorted(), [0, 4, 20, 24])
}

func test_patternLine_fourCorners_threeMarked_returnsNil() {
    XCTAssertNil(GameEngine.patternLine(for: makeBoard(marking: [0, 4, 20]), shape: .fourCorners))
}

func test_patternLine_x_allMarked_returnsPositions() {
    // X = [0,4,6,8,12,16,18,20,24]. 12 is FREE. Mark remaining 8.
    let board = makeBoard(marking: [0, 4, 6, 8, 16, 18, 20, 24])
    let line = GameEngine.patternLine(for: board, shape: .x)
    XCTAssertEqual(line?.sorted(), [0, 4, 6, 8, 12, 16, 18, 20, 24])
}

func test_patternLine_plus_allMarked_returnsPositions() {
    // Plus = [2,7,10,11,12,13,14,17,22]. 12 is FREE. Mark remaining 8.
    let board = makeBoard(marking: [2, 7, 10, 11, 13, 14, 17, 22])
    let line = GameEngine.patternLine(for: board, shape: .plus)
    XCTAssertEqual(line?.sorted(), [2, 7, 10, 11, 12, 13, 14, 17, 22])
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/GameEngineTests 2>&1 | tail -10
```
Expected: Build error — `hotStreakLine` and `patternLine` not found.

- [ ] **Step 3: Add to GameEngine.swift**

```swift
static func hotStreakLine(for board: BingoBoard) -> [Int]? {
    winLines.first { line in
        line.filter { board.isMarked(at: $0) }.count >= 3
    }
}

static func patternLine(for board: BingoBoard, shape: PatternShape) -> [Int]? {
    let positions = shape.positions
    return positions.allSatisfy { board.isMarked(at: $0) } ? positions : nil
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/GameEngineTests 2>&1 | tail -10
```
Expected: All GameEngineTests pass.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Game/GameEngine.swift \
        RoadTripBingoTests/GameEngineTests.swift
git commit -m "feat: add GameEngine hotStreakLine and patternLine for modifier win conditions"
```

---

## Task 5: AppState — modifier selection, broadcast, and simple modifier effects

Wires the modifier into the game loop: host picks one each round, broadcasts it, all devices apply the rule.

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 1: Add activeModifier property and round tracking**

In `AppState`, add:
```swift
@Published var activeModifier: RoundModifier? = nil

// Round-scoped tracking for modifiers and challenges
private var marksThisRound = 0
private var attacksUsedThisRound = 0
private var tokensSpentThisRound = 0
private var opponentMarkCountsThisRound: [String: Int] = [:]
```

Extend `resetRound()`:
```swift
private func resetRound() {
    firstMarkClaimedThisRound = false
    patternsAwardedThisRound = []
    closeCallsAwardedThisRound = []
    // New:
    marksThisRound = 0
    attacksUsedThisRound = 0
    tokensSpentThisRound = 0
    opponentMarkCountsThisRound = [:]
    activeModifier = nil
    fogOfWarHiddenPositions = []   // added in Task 6
    fogShiftCount = 0              // added in Task 6
}
```

- [ ] **Step 2: Add updateCompletedLine helper**

Replace every `completedLine = GameEngine.winningLine(for: board)` call-site with a helper call. Add:

```swift
private func updateCompletedLine(for board: BingoBoard) {
    switch activeModifier {
    case .hotStreak:
        completedLine = GameEngine.hotStreakLine(for: board)
    case .patternWin(let shape):
        completedLine = GameEngine.patternLine(for: board, shape: shape)
    default:
        completedLine = GameEngine.winningLine(for: board)
    }
}
```

Replace all existing `completedLine = GameEngine.winningLine(for: board)` call sites with `updateCompletedLine(for: board)`. There are three: in `toggleSquare`, in `activatePowerUp` (after freeMark), and in `multipeerSession(_:didReceive:from:)` (after `.powerUpUsed`).

- [ ] **Step 3: Apply doubleDown to earnTokens**

```swift
private func earnTokens(_ amount: Int, reason: String) {
    let effective = (activeModifier == .doubleDown) ? amount * 2 : amount
    tokenBalance += effective
    pendingToast = ToastEvent(message: "+\(effective)🟡 \(reason)", style: .earn)
    multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
}
```

- [ ] **Step 4: Apply noPowers and sniper in activatePowerUp**

At the top of `activatePowerUp(_:targetPlayer:targetIndex:)`:
```swift
// noPowers blocks all power-ups
if activeModifier == .noPowers { return }

// sniper reduces cost for attack power-ups
let effectiveCost: Int = {
    if activeModifier == .sniper && powerUp.affectsOpponent {
        return max(0, powerUp.cost - 1)
    }
    return powerUp.cost
}()
guard tokenBalance >= effectiveCost, localBoard != nil else { return }
```

Then replace `tokenBalance -= powerUp.cost` with `tokenBalance -= effectiveCost`.

Also track spend for challenge evaluation:
```swift
tokensSpentThisRound += effectiveCost
```

And track attacks:
```swift
if powerUp.affectsOpponent {
    attacksUsedThisRound += 1
}
```

- [ ] **Step 5: Host selects and broadcasts modifier in dealAndLaunchRound**

After `screen = .game` in `dealAndLaunchRound`, add modifier selection:
```swift
if isHost {
    let modifier = RoundModifier.random()
    activeModifier = modifier
    multipeerSession?.send(.roundModifier(modifier))
    initializeModifier(modifier)
}
```

Add `initializeModifier(_:)`:
```swift
private func initializeModifier(_ modifier: RoundModifier) {
    // Fog of War initialization handled in Task 6
    // Other modifiers need no upfront setup
    _ = modifier
}
```

- [ ] **Step 6: Handle incoming roundModifier message**

In `multipeerSession(_:didReceive:from:)`, add a case:
```swift
case .roundModifier(let modifier):
    activeModifier = modifier
    initializeModifier(modifier)
```

- [ ] **Step 7: Track marksThisRound and opponent mark counts**

In `toggleSquare`, after the existing mark logic and before `checkBonuses`:
```swift
if isNowMarked && !wasMarked {
    marksThisRound += 1
}
```

In the `.squareToggled` handler, after updating `opponentMarked`, when `isMarked == true`:
```swift
opponentMarkCountsThisRound[peerName, default: 0] += 1
```

- [ ] **Step 8: Build**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | tail -10
```
Expected: Build succeeds.

- [ ] **Step 9: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: wire activeModifier — host selection, broadcast, doubleDown, noPowers, sniper, hotStreak/patternWin win conditions"
```

---

## Task 6: AppState + BingoGridView — Fog of War state management

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`
- Modify: `RoadTripBingo/Views/BingoGridView.swift`
- Modify: `RoadTripBingo/Views/BingoSquareView.swift`
- Modify: `RoadTripBingo/Views/GameView.swift`

- [ ] **Step 1: Add fog state to AppState**

```swift
@Published var fogOfWarHiddenPositions: Set<Int> = []
private var fogShiftCount = 0
```

- [ ] **Step 2: Complete initializeModifier for fogOfWar**

Replace the stub in `initializeModifier`:
```swift
private func initializeModifier(_ modifier: RoundModifier) {
    guard modifier == .fogOfWar, let board = localBoard else { return }
    fogShiftCount = 0
    fogOfWarHiddenPositions = pickFogPositions(hiddenCount: 10, board: board)
}

private func pickFogPositions(hiddenCount: Int, board: BingoBoard) -> Set<Int> {
    let candidates = (0..<25).filter { $0 != 12 && !board.isMarked(at: $0) }
    return Set(candidates.shuffled().prefix(min(hiddenCount, candidates.count)))
}
```

- [ ] **Step 3: Shift fog on opponent mark**

In the `.squareToggled` handler, after updating `opponentMarkCountsThisRound`, add:
```swift
if isMarked { shiftFogIfNeeded() }
```

Add `shiftFogIfNeeded()`:
```swift
private func shiftFogIfNeeded() {
    guard activeModifier == .fogOfWar, let board = localBoard else { return }
    fogShiftCount += 1
    let hiddenCount = max(3, 10 - (fogShiftCount / 3))
    fogOfWarHiddenPositions = pickFogPositions(hiddenCount: hiddenCount, board: board)
}
```

Also, when a player marks their own tile, that tile should leave the fog. After `localBoard?.toggle(at: position)`:
```swift
fogOfWarHiddenPositions.remove(position)
```

- [ ] **Step 4: Add isHidden parameter to BingoSquareView**

Read `BingoSquareView.swift` first to see its current signature, then add `isHidden: Bool = false`. When `isHidden` is true, render a face-down state (placeholder pattern using `AmericanaTheme.paper` + a question mark icon or hatching, matching the Americana aesthetic) and disable the tap gesture:

```swift
struct BingoSquareView: View {
    let square: BingoSquare
    let isMarked: Bool
    let isHighlighted: Bool
    var isHidden: Bool = false
    let onTap: () -> Void

    var body: some View {
        if isHidden {
            hiddenTileView
        } else {
            // existing view body unchanged
        }
    }

    private var hiddenTileView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AmericanaTheme.brown.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(AmericanaTheme.ink.opacity(0.15), lineWidth: 1)
                )
            Text("?")
                .font(AmericanaTheme.rye(20))
                .foregroundColor(AmericanaTheme.ink.opacity(0.3))
        }
        // No tap gesture — hidden tiles are untappable
    }
}
```

- [ ] **Step 5: Pass hiddenPositions through BingoGridView**

Add a parameter to `BingoGridView`:
```swift
var hiddenPositions: Set<Int> = []
```

In `gridArea`, pass to `BingoSquareView`:
```swift
BingoSquareView(
    square: board.squares[position],
    isMarked: board.isMarked(at: position),
    isHighlighted: highlightedPositions.contains(position),
    isHidden: hiddenPositions.contains(position),
    onTap: { onTap(position) }
)
```

- [ ] **Step 6: Wire fogOfWarHiddenPositions into GameView**

Find the `BingoGridView(...)` call(s) in `GameView.swift` (landscape and portrait layouts) and add:
```swift
hiddenPositions: appState.fogOfWarHiddenPositions
```

- [ ] **Step 7: Build and verify**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | tail -10
```

- [ ] **Step 8: Commit**

```bash
git add RoadTripBingo/State/AppState.swift \
        RoadTripBingo/Views/BingoGridView.swift \
        RoadTripBingo/Views/BingoSquareView.swift \
        RoadTripBingo/Views/GameView.swift
git commit -m "feat: Fog of War modifier — hidden tiles, fog shift on opponent mark"
```

---

## Task 7: AppState — Shifting Tiles modifier

Each time an opponent marks a tile, one of your unmarked tiles is replaced with a fresh one from the reserve pool. Silent no-op if reserve is empty.

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 1: Add shiftTileIfNeeded helper**

```swift
private func shiftTileIfNeeded() {
    guard activeModifier == .shiftingTiles,
          var board = localBoard,
          !reserveSquares.isEmpty else { return }

    let unmarkedIndices = (0..<25).filter {
        $0 != 12 && !board.isMarked(at: $0)
    }
    guard let targetIdx = unmarkedIndices.randomElement() else { return }

    let replacement = reserveSquares.removeFirst()
    board.replaceSquare(at: targetIdx, with: replacement)
    localBoard = board
}
```

- [ ] **Step 2: Call shiftTileIfNeeded on opponent mark**

In the `.squareToggled` handler, after calling `shiftFogIfNeeded()`:
```swift
if isMarked { shiftTileIfNeeded() }
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: Shifting Tiles modifier — replace one unmarked tile on each opponent mark"
```

---

## Task 8: BingoBoard + AppState — Shuffle Board modifier

Each time an opponent marks a tile, your unmarked tile positions shuffle. Broadcast the new board layout so opponents' views stay correct.

**Files:**
- Modify: `RoadTripBingo/Models/BingoBoard.swift`
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 1: Write failing test for shuffleUnmarkedPositions**

In `RoadTripBingoTests/BingoBoardTests.swift`, add:
```swift
func test_shuffleUnmarkedPositions_preservesMarkedTileIDs() {
    var board = BingoBoard(squares: (0..<25).map { i in
        i == 12 ? .free : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                                       category: .nature, rarity: .common)
    })
    board.toggle(at: 0)
    board.toggle(at: 1)
    let markedBefore = board.marked

    board.shuffleUnmarkedPositions()

    XCTAssertEqual(board.marked, markedBefore, "Marked UUID set must be unchanged after shuffle")
    XCTAssertEqual(board.squares.count, 25)
    XCTAssertEqual(board.squares[12].id, BingoSquare.freeSquareID)
}

func test_shuffleUnmarkedPositions_keepsMarkedTilesAtOriginalPositions() {
    let tile0 = BingoSquare(id: UUID(), text: "Tile 0", emoji: "x", category: .nature, rarity: .common)
    var squares: [BingoSquare] = (0..<25).map { i in
        i == 0  ? tile0 :
        i == 12 ? .free :
        BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x", category: .nature, rarity: .common)
    }
    var board = BingoBoard(squares: squares)
    board.toggle(at: 0)  // mark tile at position 0

    board.shuffleUnmarkedPositions()

    XCTAssertEqual(board.squares[0].id, tile0.id, "Marked tile must stay at its position")
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/BingoBoardTests 2>&1 | tail -10
```
Expected: Build error — `shuffleUnmarkedPositions` not found.

- [ ] **Step 3: Add shuffleUnmarkedPositions to BingoBoard**

```swift
mutating func shuffleUnmarkedPositions() {
    let unmarkedIndices = (0..<25).filter { $0 != 12 && !isMarked(at: $0) }
    let shuffledTiles = unmarkedIndices.map { squares[$0] }.shuffled()
    for (i, idx) in unmarkedIndices.enumerated() {
        squares[idx] = shuffledTiles[i]
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/BingoBoardTests 2>&1 | tail -10
```
Expected: All BingoBoardTests pass.

- [ ] **Step 5: Add shuffleBoardIfNeeded to AppState**

```swift
private func shuffleBoardIfNeeded() {
    guard activeModifier == .shuffleBoard, localBoard != nil else { return }
    localBoard!.shuffleUnmarkedPositions()
    multipeerSession?.send(.boardShuffled(byName: playerName, squares: localBoard!.squares))
}
```

- [ ] **Step 6: Call shuffleBoardIfNeeded on opponent mark**

In the `.squareToggled` handler, after `shiftTileIfNeeded()`:
```swift
if isMarked { shuffleBoardIfNeeded() }
```

- [ ] **Step 7: Handle incoming boardShuffled**

In `multipeerSession(_:didReceive:from:)`:
```swift
case .boardShuffled(let byName, let squares):
    opponentBoards[byName] = squares
    // opponentMarked[byName] UUIDs remain valid — only positions moved
```

- [ ] **Step 8: Run full test suite**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test 2>&1 | tail -20
```
Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add RoadTripBingo/Models/BingoBoard.swift \
        RoadTripBingo/State/AppState.swift
git commit -m "feat: Shuffle Board modifier — shuffle unmarked positions on opponent mark, broadcast new layout"
```

---

## Task 9: UI — Modifier reveal banner and badge (frontend-design skill required)

**Before writing any code, invoke the frontend-design skill for each component.**

**Files:**
- Create: `RoadTripBingo/Views/ModifierRevealView.swift`
- Create: `RoadTripBingo/Views/ModifierBadgeView.swift`
- Modify: `RoadTripBingo/Views/GameView.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Design ModifierRevealView with frontend-design skill**

In your Claude Code terminal, type `/frontend-design` and provide this brief:

> Design a full-screen Americana-styled modifier reveal overlay for an iPad bingo game. It appears for 2–3 seconds at the start of each round before the board is shown, then auto-dismisses. The design should feel like flipping over a dramatic road sign. Elements needed: large emoji centered near the top third of the screen, modifier name below it in Rye font (28pt), rule description in Barlow Semibold (15pt), a countdown "Starting in 3… 2… 1…" at the bottom. Color palette: `AmericanaTheme.paper` (#F5E6C8) background, `AmericanaTheme.ink` (#2C1810) text, `AmericanaTheme.green` accent. The overlay should slide up from the bottom or fade in. Make it feel exciting, not sterile — this is a surprise for kids.

Implement the design produced by the skill.

- [ ] **Step 2: Create ModifierRevealView.swift**

Implement based on the frontend-design output. The view takes:
```swift
struct ModifierRevealView: View {
    let modifier: RoundModifier
    let onDismiss: () -> Void
    // Countdown from 3 to 0, then calls onDismiss
}
```

Use a `@State private var countdown = 3` with a `Timer` publisher (`.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect())`) to decrement and call `onDismiss()` when it reaches 0.

- [ ] **Step 3: Design ModifierBadgeView with frontend-design skill**

In your Claude Code terminal, type `/frontend-design` and provide this brief:

> Design a small persistent modifier badge for an iPad bingo game header. It is a compact pill/chip showing an emoji on the left and the modifier's short name on the right. It must be readable at a glance while not dominating the game UI. Tapping it opens a popover showing the full rule description. Use AmericanaTheme colors: parchment background, ink text, green accent border. The badge should look like a road sign stamp or sticker. Keep it under 120pt wide.

Implement the design.

- [ ] **Step 4: Create ModifierBadgeView.swift**

```swift
struct ModifierBadgeView: View {
    let modifier: RoundModifier
    @State private var showPopover = false

    var body: some View {
        // Implement pill from frontend-design output
        // Tap opens popover showing modifier.ruleDescription
    }
}
```

- [ ] **Step 5: Wire ModifierRevealView into GameView**

In `GameView.swift`, add:
```swift
@State private var showModifierReveal = false
```

When `appState.screen` transitions to `.game`, set `showModifierReveal = true` if `appState.activeModifier != nil`. Use `.onChange(of: appState.screen)`:
```swift
.onChange(of: appState.screen) { screen in
    if case .game = screen, appState.activeModifier != nil {
        showModifierReveal = true
    }
}
```

Add the overlay to the outermost ZStack in `GameView.body`:
```swift
if showModifierReveal, let modifier = appState.activeModifier {
    ModifierRevealView(modifier: modifier) {
        showModifierReveal = false
    }
    .transition(.opacity)
    .zIndex(10)
}
```

- [ ] **Step 6: Wire ModifierBadgeView into GameView header**

Find the existing game header area (the top bar in landscape, or top section in portrait) and add the badge next to existing controls:
```swift
if let modifier = appState.activeModifier {
    ModifierBadgeView(modifier: modifier)
}
```

- [ ] **Step 7: Register new view files in project.pbxproj**

Add `ModifierRevealView.swift` and `ModifierBadgeView.swift` to the app target's `PBXSourcesBuildPhase`.

- [ ] **Step 8: Build**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | tail -10
```

- [ ] **Step 9: Commit**

```bash
git add RoadTripBingo/Views/ModifierRevealView.swift \
        RoadTripBingo/Views/ModifierBadgeView.swift \
        RoadTripBingo/Views/GameView.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: modifier reveal banner and badge UI"
```

---

## Task 10: DailyChallenge model and 9 concrete types

**Files:**
- Create: `RoadTripBingo/Models/DailyChallenge.swift`
- Create: `RoadTripBingoTests/DailyChallengeTests.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import RoadTripBingo

final class DailyChallengeTests: XCTestCase {

    private func makeContext(
        playerName: String = "Zoe",
        marksThisRound: Int = 0,
        opponentMarkCounts: [String: Int] = [:],
        winsToday: Int = 0,
        attacksUsedThisRound: Int = 0,
        tokensAtEndOfRound: Int = 0,
        tokensSpentThisRound: Int = 0,
        roundsPlayedToday: Int = 0,
        localBoard: BingoBoard? = nil
    ) -> ChallengeEvaluationContext {
        ChallengeEvaluationContext(
            playerName: playerName,
            marksThisRound: marksThisRound,
            opponentMarkCounts: opponentMarkCounts,
            winsToday: winsToday,
            attacksUsedThisRound: attacksUsedThisRound,
            tokensAtEndOfRound: tokensAtEndOfRound,
            tokensSpentThisRound: tokensSpentThisRound,
            roundsPlayedToday: roundsPlayedToday,
            localBoard: localBoard
        )
    }

    private func makeBoard(marking positions: Set<Int> = []) -> BingoBoard {
        let squares = (0..<25).map { i -> BingoSquare in
            i == 12 ? .free : BingoSquare(id: UUID(), text: "T\(i)", emoji: "x",
                                           category: .nature, rarity: .common)
        }
        var board = BingoBoard(squares: squares)
        for pos in positions where pos != 12 { board.toggle(at: pos) }
        return board
    }

    func test_winOne_completesOnRoundWon() {
        let challenge = DailyChallenge(type: .winOne)
        let ctx = makeContext(playerName: "Zoe")
        XCTAssertTrue(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
        XCTAssertFalse(challenge.evaluate(event: .roundWon(byPlayer: "Emma"), context: ctx))
    }

    func test_speedDemon_completesWhenFirst_to5Marks() {
        let challenge = DailyChallenge(type: .speedDemon)
        let ctx = makeContext(playerName: "Zoe", marksThisRound: 5, opponentMarkCounts: ["Emma": 3])
        let tileID = UUID()
        XCTAssertTrue(challenge.evaluate(event: .tileMarked(tileID: tileID, byPlayer: "Zoe", isFirstInGame: false), context: ctx))
    }

    func test_speedDemon_doesNotComplete_ifOpponentAlreadyHas5() {
        let challenge = DailyChallenge(type: .speedDemon)
        let ctx = makeContext(playerName: "Zoe", marksThisRound: 5, opponentMarkCounts: ["Emma": 5])
        let tileID = UUID()
        XCTAssertFalse(challenge.evaluate(event: .tileMarked(tileID: tileID, byPlayer: "Zoe", isFirstInGame: false), context: ctx))
    }

    func test_pacifist_completesOnWinWithNoAttacks() {
        let challenge = DailyChallenge(type: .pacifist)
        let ctx = makeContext(playerName: "Zoe", attacksUsedThisRound: 0)
        XCTAssertTrue(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
    }

    func test_pacifist_doesNotComplete_ifAttacksUsed() {
        let challenge = DailyChallenge(type: .pacifist)
        let ctx = makeContext(playerName: "Zoe", attacksUsedThisRound: 1)
        XCTAssertFalse(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
    }

    func test_menace_completesOn3rdAttack() {
        let challenge = DailyChallenge(type: .menace)
        let ctx = makeContext(playerName: "Zoe", attacksUsedThisRound: 3)
        XCTAssertTrue(challenge.evaluate(event: .attackUsed(byPlayer: "Zoe", type: .unmarkOpponentTargeted), context: ctx))
    }

    func test_hoarder_completesOnRoundEnd_with10Tokens() {
        let challenge = DailyChallenge(type: .hoarder)
        let ctx = makeContext(tokensAtEndOfRound: 10)
        XCTAssertTrue(challenge.evaluate(event: .roundEnded(context: ctx), context: ctx))
        let ctx2 = makeContext(tokensAtEndOfRound: 9)
        XCTAssertFalse(challenge.evaluate(event: .roundEnded(context: ctx2), context: ctx2))
    }

    func test_cornerKing_completesWhenAllCornersMarked() {
        let challenge = DailyChallenge(type: .cornerKing)
        let board = makeBoard(marking: [0, 4, 20, 24])
        let ctx = makeContext(localBoard: board)
        XCTAssertTrue(challenge.evaluate(event: .tileMarked(tileID: UUID(), byPlayer: "Zoe", isFirstInGame: false), context: ctx))
    }

    func test_onFire_completesOn2ndWin() {
        let challenge = DailyChallenge(type: .onFire)
        let ctx = makeContext(playerName: "Zoe", winsToday: 2)
        XCTAssertTrue(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
        let ctx1 = makeContext(playerName: "Zoe", winsToday: 1)
        XCTAssertFalse(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx1))
    }

    func test_spender_completesOnRoundEnd_with10TokensSpent() {
        let challenge = DailyChallenge(type: .spender)
        let ctx = makeContext(tokensSpentThisRound: 10)
        XCTAssertTrue(challenge.evaluate(event: .roundEnded(context: ctx), context: ctx))
    }

    func test_firstBlood_completesOnFirstMarkOfFirstRound() {
        let challenge = DailyChallenge(type: .firstBlood)
        let ctx = makeContext(playerName: "Zoe", roundsPlayedToday: 0)
        XCTAssertTrue(challenge.evaluate(event: .tileMarked(tileID: UUID(), byPlayer: "Zoe", isFirstInGame: true), context: ctx))
    }

    func test_firstBlood_doesNotComplete_onSubsequentRounds() {
        let challenge = DailyChallenge(type: .firstBlood)
        let ctx = makeContext(playerName: "Zoe", roundsPlayedToday: 1)
        XCTAssertFalse(challenge.evaluate(event: .tileMarked(tileID: UUID(), byPlayer: "Zoe", isFirstInGame: true), context: ctx))
    }

    func test_dailyChallenge_codable_roundtrip() throws {
        for type in DailyChallengeType.allCases {
            let challenge = DailyChallenge(type: type)
            let data = try JSONEncoder().encode(challenge)
            let decoded = try JSONDecoder().decode(DailyChallenge.self, from: data)
            XCTAssertEqual(decoded.type, challenge.type)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/DailyChallengeTests 2>&1 | tail -10
```
Expected: Build error — types not found.

- [ ] **Step 3: Create DailyChallenge.swift**

```swift
import Foundation

enum DailyChallengeType: String, Codable, CaseIterable, Equatable {
    case winOne, speedDemon, pacifist, menace, hoarder, cornerKing, onFire, spender, firstBlood
}

struct ChallengeEvaluationContext {
    let playerName: String
    let marksThisRound: Int
    let opponentMarkCounts: [String: Int]
    let winsToday: Int
    let attacksUsedThisRound: Int
    let tokensAtEndOfRound: Int
    let tokensSpentThisRound: Int
    let roundsPlayedToday: Int
    let localBoard: BingoBoard?
}

enum ChallengeEvent {
    case tileMarked(tileID: UUID, byPlayer: String, isFirstInGame: Bool)
    case roundWon(byPlayer: String)
    case attackUsed(byPlayer: String, type: PowerUpType)
    case roundEnded(context: ChallengeEvaluationContext)
    // Future: case tileMarkedWithCategory(category: SquareCategory, byPlayer: String)
    // Note: BingoSquare.category already exists — add the case and DailyChallengeType
    // when ready, no model changes needed.
}

struct DailyChallenge: Codable, Identifiable {
    let type: DailyChallengeType
    var id: String { type.rawValue }

    var title: String {
        switch type {
        case .winOne:      return "Win One"
        case .speedDemon:  return "Speed Demon"
        case .pacifist:    return "Pacifist"
        case .menace:      return "Menace"
        case .hoarder:     return "Hoarder"
        case .cornerKing:  return "Corner King"
        case .onFire:      return "On Fire"
        case .spender:     return "Spender"
        case .firstBlood:  return "First Blood"
        }
    }

    var emoji: String {
        switch type {
        case .winOne:      return "🏆"
        case .speedDemon:  return "⚡"
        case .pacifist:    return "🧘"
        case .menace:      return "💣"
        case .hoarder:     return "🎯"
        case .cornerKing:  return "🔲"
        case .onFire:      return "🔥"
        case .spender:     return "🤑"
        case .firstBlood:  return "🌅"
        }
    }

    var description: String {
        switch type {
        case .winOne:      return "Win any round today"
        case .speedDemon:  return "Be the first player to mark 5 tiles in a round"
        case .pacifist:    return "Win a round without using any attack power-ups"
        case .menace:      return "Use 3 attack power-ups in a single round"
        case .hoarder:     return "End any round with 10 or more tokens"
        case .cornerKing:  return "Mark all 4 corner tiles in a single round"
        case .onFire:      return "Win 2 rounds in the same day"
        case .spender:     return "Spend 10 or more tokens in a single round"
        case .firstBlood:  return "Be the first to spot anything in today's first round"
        }
    }

    var tokenReward: Int {
        switch type {
        case .winOne:      return 5
        case .speedDemon:  return 4
        case .pacifist:    return 6
        case .menace:      return 5
        case .hoarder:     return 4
        case .cornerKing:  return 5
        case .onFire:      return 8
        case .spender:     return 4
        case .firstBlood:  return 3
        }
    }

    func evaluate(event: ChallengeEvent, context: ChallengeEvaluationContext) -> Bool {
        switch type {
        case .winOne:
            guard case .roundWon(let by) = event else { return false }
            return by == context.playerName

        case .speedDemon:
            guard case .tileMarked(_, let by, _) = event, by == context.playerName else { return false }
            return context.marksThisRound == 5 &&
                   context.opponentMarkCounts.values.allSatisfy { $0 < 5 }

        case .pacifist:
            guard case .roundWon(let by) = event, by == context.playerName else { return false }
            return context.attacksUsedThisRound == 0

        case .menace:
            guard case .attackUsed(let by, _) = event, by == context.playerName else { return false }
            return context.attacksUsedThisRound >= 3

        case .hoarder:
            guard case .roundEnded(let ctx) = event else { return false }
            return ctx.tokensAtEndOfRound >= 10

        case .cornerKing:
            guard case .tileMarked(_, let by, _) = event, by == context.playerName else { return false }
            guard let board = context.localBoard else { return false }
            return [0, 4, 20, 24].allSatisfy { board.isMarked(at: $0) }

        case .onFire:
            guard case .roundWon(let by) = event, by == context.playerName else { return false }
            return context.winsToday >= 2

        case .spender:
            guard case .roundEnded(let ctx) = event else { return false }
            return ctx.tokensSpentThisRound >= 10

        case .firstBlood:
            guard case .tileMarked(_, let by, let isFirst) = event,
                  by == context.playerName, isFirst else { return false }
            return context.roundsPlayedToday == 0
        }
    }
}
```

- [ ] **Step 4: Upgrade DailyState.challengeTypes to [DailyChallengeType]**

Now that `DailyChallengeType` exists, update `DailyState.swift`:

```swift
// Change:
var challengeTypes: [String]
// To:
var challengeTypes: [DailyChallengeType]
```

Also update `fresh()` — no change needed there (still returns empty array). Add the roll method:

```swift
static func roll() -> [DailyChallengeType] {
    Array(DailyChallengeType.allCases.shuffled().prefix(3))
}
```

- [ ] **Step 5: Register new files in project.pbxproj**

Add `DailyChallenge.swift` (app target) and `DailyChallengeTests.swift` (test target).

- [ ] **Step 6: Run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/DailyChallengeTests 2>&1 | tail -10
```
Expected: All DailyChallengeTests pass.

- [ ] **Step 7: Commit**

```bash
git add RoadTripBingo/Models/DailyChallenge.swift \
        RoadTripBingo/Models/DailyState.swift \
        RoadTripBingoTests/DailyChallengeTests.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: DailyChallenge model with 9 challenge types and evaluate logic"
```

---

## Task 11: AppState — DailyState persistence + challenge evaluation wiring

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 1: Complete rollDailyChallengesIfNeeded**

```swift
func rollDailyChallengesIfNeeded() {
    if dailyState.date != DailyState.today() {
        dailyState = DailyState(
            date: DailyState.today(),
            challengeTypes: DailyState.roll(),
            completedIDs: [],
            winsToday: 0,
            roundsPlayedToday: 0
        )
    } else if dailyState.challengeTypes.isEmpty {
        dailyState.challengeTypes = DailyState.roll()
    }
    dailyState.save()
}
```

- [ ] **Step 2: Add activeChallenges computed property**

```swift
var activeChallenges: [DailyChallenge] {
    dailyState.challengeTypes.map { DailyChallenge(type: $0) }
}
```

- [ ] **Step 3: Add evaluateChallenges helper**

```swift
private func evaluateChallenges(event: ChallengeEvent) {
    let context = ChallengeEvaluationContext(
        playerName: playerName,
        marksThisRound: marksThisRound,
        opponentMarkCounts: opponentMarkCountsThisRound,
        winsToday: dailyState.winsToday,
        attacksUsedThisRound: attacksUsedThisRound,
        tokensAtEndOfRound: tokenBalance,
        tokensSpentThisRound: tokensSpentThisRound,
        roundsPlayedToday: dailyState.roundsPlayedToday,
        localBoard: localBoard
    )

    for challenge in activeChallenges {
        guard !dailyState.completedIDs.contains(challenge.id) else { continue }
        if challenge.evaluate(event: event, context: context) {
            dailyState.completedIDs.insert(challenge.id)
            dailyState.save()
            earnTokens(challenge.tokenReward, reason: "\(challenge.emoji) \(challenge.title)!")
        }
    }
}
```

- [ ] **Step 4: Fire events from AppState at the right call sites**

In `toggleSquare`, capture "first mark among all players" BEFORE any state is updated (both `firstMarkClaimedThisRound` and `marksThisRound` must still be at their pre-mark values):
```swift
// Capture before any updates — true if no player has marked yet this round
let isVeryFirstMark = !firstMarkClaimedThisRound &&
                      opponentMarkCountsThisRound.values.allSatisfy { $0 == 0 }
```

Then after `marksThisRound += 1`, fire:
```swift
if isNowMarked {
    evaluateChallenges(event: .tileMarked(tileID: localBoard!.squares[position].id,
                                          byPlayer: playerName,
                                          isFirstInGame: isVeryFirstMark))
}
```

In `activatePowerUp`, after incrementing `attacksUsedThisRound`:
```swift
if powerUp.affectsOpponent {
    evaluateChallenges(event: .attackUsed(byPlayer: playerName, type: powerUp))
}
```

In `callBingo`:
```swift
dailyState.winsToday += 1
dailyState.roundsPlayedToday += 1
dailyState.save()
evaluateChallenges(event: .roundWon(byPlayer: playerName))
// Build roundEnded context with final token balance for hoarder/spender
let endContext = ChallengeEvaluationContext(
    playerName: playerName, marksThisRound: marksThisRound,
    opponentMarkCounts: opponentMarkCountsThisRound, winsToday: dailyState.winsToday,
    attacksUsedThisRound: attacksUsedThisRound, tokensAtEndOfRound: tokenBalance,
    tokensSpentThisRound: tokensSpentThisRound, roundsPlayedToday: dailyState.roundsPlayedToday,
    localBoard: localBoard
)
evaluateChallenges(event: .roundEnded(context: endContext))
```

In the `.bingoAnnounced` handler (for non-winners), fire roundEnded too:
```swift
dailyState.roundsPlayedToday += 1
dailyState.save()
let endContext = ChallengeEvaluationContext(
    playerName: playerName, marksThisRound: marksThisRound,
    opponentMarkCounts: opponentMarkCountsThisRound, winsToday: dailyState.winsToday,
    attacksUsedThisRound: attacksUsedThisRound, tokensAtEndOfRound: tokenBalance,
    tokensSpentThisRound: tokensSpentThisRound, roundsPlayedToday: dailyState.roundsPlayedToday,
    localBoard: localBoard
)
evaluateChallenges(event: .roundEnded(context: endContext))
```

- [ ] **Step 5: Build and run tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test 2>&1 | tail -20
```

- [ ] **Step 6: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: wire daily challenge evaluation and DailyState persistence into AppState"
```

---

## Task 12: UI — Daily Challenges panel (frontend-design skill required)

**Before writing any code, invoke the frontend-design skill.**

**Files:**
- Create: `RoadTripBingo/Views/DailyChallengesView.swift`
- Modify: `RoadTripBingo/Views/HomeView.swift`
- Modify: `RoadTripBingo/Views/GameView.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

- [ ] **Step 1: Design DailyChallengesView with frontend-design skill**

In your Claude Code terminal, type `/frontend-design` and provide this brief:

> Design a daily challenges sheet/panel for an iPad road trip bingo game (Americana theme). It shows 3 challenges for today. Each challenge row has: emoji on the left, challenge title in Barlow Bold, description in Barlow Semibold smaller, and a token reward badge on the right showing "+N 🟡". Completed challenges get a green checkmark and are greyed out. The sheet header says "Today's Challenges" in Rye font with a road-trip flavoured subtitle like "Complete these to earn bonus tokens". Color palette: AmericanaTheme.parchment background, .ink text, .green for completed state, .yellow for the token reward badge. This is seen by 8–10 year old kids — make it feel exciting and rewarding, not like a to-do list.

Implement the design.

- [ ] **Step 2: Create DailyChallengesView.swift**

```swift
struct DailyChallengesView: View {
    let challenges: [DailyChallenge]
    let completedIDs: Set<String>

    var body: some View {
        // Implement based on frontend-design output
    }
}
```

- [ ] **Step 3: Add challenges button to HomeView**

In `HomeView.swift`, add a `@State private var showChallenges = false` and a button that opens `DailyChallengesView` as a sheet. Place it in the right panel (controls area, below the existing buttons). The button label: "🎯 Today's Challenges".

- [ ] **Step 4: Add challenge badge to GameView**

In `GameView.swift`, add a compact incomplete-count badge in the game header:
```swift
let incomplete = appState.activeChallenges.filter {
    !appState.dailyState.completedIDs.contains($0.id)
}.count

if incomplete > 0 {
    Button {
        showChallenges = true
    } label: {
        Text("🎯 \(incomplete)")
            .font(AmericanaTheme.barlowBold(13))
            .foregroundColor(AmericanaTheme.ink)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                Capsule().fill(AmericanaTheme.yellow.opacity(0.8))
            )
    }
}
```

Add `@State private var showChallenges = false` and a `.sheet(isPresented: $showChallenges)` presenting `DailyChallengesView`.

- [ ] **Step 5: Register DailyChallengesView.swift in project.pbxproj**

- [ ] **Step 6: Build**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | tail -10
```

- [ ] **Step 7: Run full test suite**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test 2>&1 | tail -20
```
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add RoadTripBingo/Views/DailyChallengesView.swift \
        RoadTripBingo/Views/HomeView.swift \
        RoadTripBingo/Views/GameView.swift \
        RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: daily challenges UI — home screen panel and in-game badge"
```
