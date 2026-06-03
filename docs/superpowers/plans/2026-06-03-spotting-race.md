# Spotting Race Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Spotting Race game type where all players share a rolling 6-tile grid, claim tiles by tapping first, and score rarity-based points before the 5-minute timer expires.

**Architecture:** `GameType` enum gates routing at `ContentView`; `AppState` owns all Spotting Race state and acts as its own host in solo mode; host-only timer loop drives expiry and replacement; peer-to-peer timestamp arbitration resolves simultaneous taps. Five new `MultipeerMessage` cases handle the claim protocol; `gameStarted`/`playAgain` gain a `gameType` parameter.

**Tech Stack:** Swift / SwiftUI (iPad-only, landscape primary), MultipeerConnectivity via existing `MultipeerSession`, `UserDefaults` for persistence, `async/await` Task for timer loops.

---

## File Map

**New files:**
- `RoadTripBingo/Models/GameType.swift` — `GameType` enum (`.bingo` / `.spottingRace`)
- `RoadTripBingo/Models/SpottingRaceTile.swift` — `SpottingRaceTile` struct (slot model)
- `RoadTripBingo/Views/SpottingRaceView.swift` — game screen (3×2 grid, timer, scores, toast)
- `RoadTripBingo/Views/SpottingRaceTileView.swift` — single tile, all 8 visual states
- `RoadTripBingoTests/SpottingRaceTests.swift` — unit tests for new logic

**Modified files:**
- `RoadTripBingo/Models/BingoSquare.swift` — add `spottingRaceScore` and `spottingRaceWeight` on `SquareRarity`
- `RoadTripBingo/Models/MultipeerMessage.swift` — 5 new cases; `gameStarted`/`playAgain` gain `gameType` param
- `RoadTripBingo/Models/ToastEvent.swift` — add `.opponentClaim` to `ToastStyle`
- `RoadTripBingo/Views/TokenToastView.swift` — handle `.opponentClaim` style
- `RoadTripBingo/State/AppState.swift` — new state, new methods, updated delegate handling
- `RoadTripBingo/ContentView.swift` — route `.game` through `gameType`
- `RoadTripBingo/Views/HomeView.swift` — game mode picker (two tappable cards above buttons)
- `RoadTripBingo/Views/WinView.swift` — Spotting Race win branch (solo + multiplayer)
- `RoadTripBingo.xcodeproj/project.pbxproj` — register 5 new Swift files

---

## Task 1: Core Models — GameType, SpottingRaceTile, SquareRarity extensions

**Files:**
- Create: `RoadTripBingo/Models/GameType.swift`
- Create: `RoadTripBingo/Models/SpottingRaceTile.swift`
- Modify: `RoadTripBingo/Models/BingoSquare.swift`

- [ ] **Step 1: Create `GameType.swift`**

```swift
// RoadTripBingo/Models/GameType.swift
import Foundation

enum GameType: String, Equatable, Codable {
    case bingo
    case spottingRace
}
```

- [ ] **Step 2: Create `SpottingRaceTile.swift`**

```swift
// RoadTripBingo/Models/SpottingRaceTile.swift
import Foundation

struct SpottingRaceTile: Identifiable {
    /// Slot identity — stable across tile replacements so SwiftUI animates the slot.
    let id: UUID
    let square: BingoSquare
    let expiresAt: Date
    var claimedBy: String?     // nil = unclaimed
    var lockedBy: String?      // nil = free; set during soft-claim window
    var lockTimestamp: Date?   // used for conflict resolution

    /// True when fewer than 3 seconds remain before expiry.
    var isExpiring: Bool { expiresAt.timeIntervalSinceNow < 3 }
}
```

- [ ] **Step 3: Add `spottingRaceScore` and `spottingRaceWeight` to `SquareRarity` in `BingoSquare.swift`**

Open `RoadTripBingo/Models/BingoSquare.swift`. After the closing brace of the existing `SquareRarity` enum (after the `scoreBonus` computed property), append:

```swift
    /// Points awarded in Spotting Race — tuned independently of Bingo's scoreBonus.
    var spottingRaceScore: Int {
        switch self {
        case .veryCommon: return 1
        case .common:     return 2
        case .uncommon:   return 3
        case .rare:       return 5
        case .veryRare:   return 8
        }
    }

    /// Weighted draw probability for the rolling tile pool (weights sum to 100).
    var spottingRaceWeight: Int {
        switch self {
        case .veryCommon: return 25
        case .common:     return 30
        case .uncommon:   return 25
        case .rare:       return 15
        case .veryRare:   return 5
        }
    }
```

The `SquareRarity` enum body should now look like:

```swift
enum SquareRarity: String, Codable, CaseIterable {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare

    var scoreBonus: Int {
        switch self {
        case .veryCommon: return 0
        case .common:     return 1
        case .uncommon:   return 2
        case .rare:       return 4
        case .veryRare:   return 7
        }
    }

    var spottingRaceScore: Int {
        switch self {
        case .veryCommon: return 1
        case .common:     return 2
        case .uncommon:   return 3
        case .rare:       return 5
        case .veryRare:   return 8
        }
    }

    var spottingRaceWeight: Int {
        switch self {
        case .veryCommon: return 25
        case .common:     return 30
        case .uncommon:   return 25
        case .rare:       return 15
        case .veryRare:   return 5
        }
    }
}
```

- [ ] **Step 4: Register new files in `project.pbxproj`**

See **Task 13** for the full pbxproj editing instructions (defer until all new files exist).

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Models/GameType.swift \
        RoadTripBingo/Models/SpottingRaceTile.swift \
        RoadTripBingo/Models/BingoSquare.swift
git commit -m "feat: add GameType enum, SpottingRaceTile model, rarity scoring extensions"
```

---

## Task 2: MultipeerMessage — 5 new cases, updated gameStarted/playAgain

**Files:**
- Modify: `RoadTripBingo/Models/MultipeerMessage.swift`
- Modify: `RoadTripBingoTests/MultipeerMessageTests.swift`

The existing `gameStarted` and `playAgain` cases gain a `gameType: GameType` parameter. Five new cases handle the Spotting Race claim protocol. All decode steps use `decodeIfPresent` with `.bingo` defaults so old app installs continue to decode correctly.

- [ ] **Step 1: Replace the entire content of `MultipeerMessage.swift`**

```swift
// RoadTripBingo/Models/MultipeerMessage.swift
import Foundation

enum MultipeerMessage: Codable {
    // Existing cases — gameStarted and playAgain now carry gameType
    case gameStarted(boards: [String: [BingoSquare]], activePackIDs: [String], gameType: GameType)
    case squareToggled(position: Int, isMarked: Bool)
    case bingoAnnounced(byName: String)
    case playAgain(boards: [String: [BingoSquare]], activePackIDs: [String], gameType: GameType)
    case difficultyChosen(byName: String, difficulty: BoardDifficulty)
    case tokenEarned(byName: String, newBalance: Int)
    case powerUpUsed(byName: String, powerUp: PowerUpType, targetPlayer: String?,
                     targetIndex: Int?, replacementSquare: BingoSquare?)
    case reserveDealt(toName: String, squares: [BingoSquare])
    case roundModifier(RoundModifier)
    case boardShuffled(byName: String, squares: [BingoSquare])
    case handicapBonus(toPlayer: String, tokens: Int)

    // Spotting Race cases
    case lockTile(slotID: UUID, squareID: UUID, byName: String, timestamp: Date)
    case releaseTile(slotID: UUID, byName: String)
    case claimTile(slotID: UUID, squareID: UUID, byName: String, timestamp: Date)
    case tileReplaced(slotID: UUID, replacement: BingoSquare, expiresAt: Date)
    case spottingRoundEnded(scores: [String: Int])

    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName, difficulty
        case newBalance, powerUp, targetPlayer, targetIndex, replacementSquare
        case toName, squares
        case modifier, shuffledSquares, shuffledByName
        case handicapToPlayer, handicapTokens
        case activePackIDs
        case gameType
        case slotID, squareID, expiresAt, lockTimestamp, spottingScores
    }

    private enum MessageType: String, Codable {
        case gameStarted, squareToggled, bingoAnnounced, playAgain, difficultyChosen
        case tokenEarned, powerUpUsed, reserveDealt
        case roundModifier, boardShuffled, handicapBonus
        case lockTile, releaseTile, claimTile, tileReplaced, spottingRoundEnded
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gameStarted(let boards, let activePackIDs, let gameType):
            try c.encode(MessageType.gameStarted, forKey: .type)
            try c.encode(boards, forKey: .boards)
            try c.encode(activePackIDs, forKey: .activePackIDs)
            try c.encode(gameType, forKey: .gameType)
        case .squareToggled(let position, let isMarked):
            try c.encode(MessageType.squareToggled, forKey: .type)
            try c.encode(position, forKey: .position)
            try c.encode(isMarked, forKey: .isMarked)
        case .bingoAnnounced(let byName):
            try c.encode(MessageType.bingoAnnounced, forKey: .type)
            try c.encode(byName, forKey: .byName)
        case .playAgain(let boards, let activePackIDs, let gameType):
            try c.encode(MessageType.playAgain, forKey: .type)
            try c.encode(boards, forKey: .boards)
            try c.encode(activePackIDs, forKey: .activePackIDs)
            try c.encode(gameType, forKey: .gameType)
        case .difficultyChosen(let byName, let difficulty):
            try c.encode(MessageType.difficultyChosen, forKey: .type)
            try c.encode(byName, forKey: .byName)
            try c.encode(difficulty, forKey: .difficulty)
        case .tokenEarned(let byName, let newBalance):
            try c.encode(MessageType.tokenEarned, forKey: .type)
            try c.encode(byName, forKey: .byName)
            try c.encode(newBalance, forKey: .newBalance)
        case .powerUpUsed(let byName, let powerUp, let targetPlayer, let targetIndex, let replacementSquare):
            try c.encode(MessageType.powerUpUsed, forKey: .type)
            try c.encode(byName, forKey: .byName)
            try c.encode(powerUp, forKey: .powerUp)
            try c.encodeIfPresent(targetPlayer, forKey: .targetPlayer)
            try c.encodeIfPresent(targetIndex, forKey: .targetIndex)
            try c.encodeIfPresent(replacementSquare, forKey: .replacementSquare)
        case .reserveDealt(let toName, let squares):
            try c.encode(MessageType.reserveDealt, forKey: .type)
            try c.encode(toName, forKey: .toName)
            try c.encode(squares, forKey: .squares)
        case .roundModifier(let modifier):
            try c.encode(MessageType.roundModifier, forKey: .type)
            try c.encode(modifier, forKey: .modifier)
        case .boardShuffled(let byName, let squares):
            try c.encode(MessageType.boardShuffled, forKey: .type)
            try c.encode(byName, forKey: .shuffledByName)
            try c.encode(squares, forKey: .shuffledSquares)
        case .handicapBonus(let toPlayer, let tokens):
            try c.encode(MessageType.handicapBonus, forKey: .type)
            try c.encode(toPlayer, forKey: .handicapToPlayer)
            try c.encode(tokens, forKey: .handicapTokens)
        case .lockTile(let slotID, let squareID, let byName, let timestamp):
            try c.encode(MessageType.lockTile, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(squareID, forKey: .squareID)
            try c.encode(byName, forKey: .byName)
            try c.encode(timestamp, forKey: .lockTimestamp)
        case .releaseTile(let slotID, let byName):
            try c.encode(MessageType.releaseTile, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(byName, forKey: .byName)
        case .claimTile(let slotID, let squareID, let byName, let timestamp):
            try c.encode(MessageType.claimTile, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(squareID, forKey: .squareID)
            try c.encode(byName, forKey: .byName)
            try c.encode(timestamp, forKey: .lockTimestamp)
        case .tileReplaced(let slotID, let replacement, let expiresAt):
            try c.encode(MessageType.tileReplaced, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(replacement, forKey: .replacementSquare)
            try c.encode(expiresAt, forKey: .expiresAt)
        case .spottingRoundEnded(let scores):
            try c.encode(MessageType.spottingRoundEnded, forKey: .type)
            try c.encode(scores, forKey: .spottingScores)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(MessageType.self, forKey: .type)
        switch type {
        case .gameStarted:
            self = .gameStarted(
                boards: try c.decode([String: [BingoSquare]].self, forKey: .boards),
                activePackIDs: (try? c.decodeIfPresent([String].self, forKey: .activePackIDs)) ?? [],
                gameType: (try? c.decodeIfPresent(GameType.self, forKey: .gameType)) ?? .bingo
            )
        case .squareToggled:
            self = .squareToggled(
                position: try c.decode(Int.self, forKey: .position),
                isMarked: try c.decode(Bool.self, forKey: .isMarked)
            )
        case .bingoAnnounced:
            self = .bingoAnnounced(byName: try c.decode(String.self, forKey: .byName))
        case .playAgain:
            self = .playAgain(
                boards: try c.decode([String: [BingoSquare]].self, forKey: .boards),
                activePackIDs: (try? c.decodeIfPresent([String].self, forKey: .activePackIDs)) ?? [],
                gameType: (try? c.decodeIfPresent(GameType.self, forKey: .gameType)) ?? .bingo
            )
        case .difficultyChosen:
            self = .difficultyChosen(
                byName: try c.decode(String.self, forKey: .byName),
                difficulty: try c.decode(BoardDifficulty.self, forKey: .difficulty)
            )
        case .tokenEarned:
            self = .tokenEarned(
                byName: try c.decode(String.self, forKey: .byName),
                newBalance: try c.decode(Int.self, forKey: .newBalance)
            )
        case .powerUpUsed:
            self = .powerUpUsed(
                byName: try c.decode(String.self, forKey: .byName),
                powerUp: try c.decode(PowerUpType.self, forKey: .powerUp),
                targetPlayer: try c.decodeIfPresent(String.self, forKey: .targetPlayer),
                targetIndex: try c.decodeIfPresent(Int.self, forKey: .targetIndex),
                replacementSquare: try c.decodeIfPresent(BingoSquare.self, forKey: .replacementSquare)
            )
        case .reserveDealt:
            self = .reserveDealt(
                toName: try c.decode(String.self, forKey: .toName),
                squares: try c.decode([BingoSquare].self, forKey: .squares)
            )
        case .roundModifier:
            self = .roundModifier(try c.decode(RoundModifier.self, forKey: .modifier))
        case .boardShuffled:
            self = .boardShuffled(
                byName: try c.decode(String.self, forKey: .shuffledByName),
                squares: try c.decode([BingoSquare].self, forKey: .shuffledSquares)
            )
        case .handicapBonus:
            self = .handicapBonus(
                toPlayer: try c.decode(String.self, forKey: .handicapToPlayer),
                tokens: try c.decode(Int.self, forKey: .handicapTokens)
            )
        case .lockTile:
            self = .lockTile(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                squareID: try c.decode(UUID.self, forKey: .squareID),
                byName: try c.decode(String.self, forKey: .byName),
                timestamp: try c.decode(Date.self, forKey: .lockTimestamp)
            )
        case .releaseTile:
            self = .releaseTile(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                byName: try c.decode(String.self, forKey: .byName)
            )
        case .claimTile:
            self = .claimTile(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                squareID: try c.decode(UUID.self, forKey: .squareID),
                byName: try c.decode(String.self, forKey: .byName),
                timestamp: try c.decode(Date.self, forKey: .lockTimestamp)
            )
        case .tileReplaced:
            self = .tileReplaced(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                replacement: try c.decode(BingoSquare.self, forKey: .replacementSquare),
                expiresAt: try c.decode(Date.self, forKey: .expiresAt)
            )
        case .spottingRoundEnded:
            self = .spottingRoundEnded(
                scores: try c.decode([String: Int].self, forKey: .spottingScores)
            )
        }
    }
}
```

- [ ] **Step 2: Update existing `gameStarted` and `playAgain` roundtrip tests in `MultipeerMessageTests.swift`**

Find `test_gameStarted_roundtrip` and update:

```swift
func test_gameStarted_roundtrip() throws {
    let square = BingoSquare(id: UUID(), text: "Cow", emoji: "🐄", category: .nature, rarity: .veryCommon)
    let boards: [String: [BingoSquare]] = ["Emma": [square]]
    let msg = MultipeerMessage.gameStarted(boards: boards, activePackIDs: ["farm-country"], gameType: .bingo)
    let decoded = try roundtrip(msg)
    guard case .gameStarted(let decodedBoards, let packIDs, let gameType) = decoded else {
        return XCTFail("Wrong case decoded")
    }
    XCTAssertEqual(decodedBoards["Emma"]?.first?.text, "Cow")
    XCTAssertEqual(packIDs, ["farm-country"])
    XCTAssertEqual(gameType, .bingo)
}

func test_playAgain_roundtrip() throws {
    let square = BingoSquare(id: UUID(), text: "Barn", emoji: "🏚️", category: .nature, rarity: .veryCommon)
    let boards: [String: [BingoSquare]] = ["Zoe": [square]]
    let msg = MultipeerMessage.playAgain(boards: boards, activePackIDs: [], gameType: .bingo)
    let decoded = try roundtrip(msg)
    guard case .playAgain(let decodedBoards, let packIDs, let gameType) = decoded else {
        return XCTFail("Wrong case decoded")
    }
    XCTAssertEqual(decodedBoards["Zoe"]?.first?.text, "Barn")
    XCTAssertTrue(packIDs.isEmpty)
    XCTAssertEqual(gameType, .bingo)
}
```

- [ ] **Step 3: Run the existing MultipeerMessage tests to confirm they pass**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/MultipeerMessageTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Models/MultipeerMessage.swift \
        RoadTripBingoTests/MultipeerMessageTests.swift
git commit -m "feat: extend MultipeerMessage with 5 Spotting Race cases; add gameType to gameStarted/playAgain"
```

---

## Task 3: ToastStyle — add `.opponentClaim`

**Files:**
- Modify: `RoadTripBingo/Models/ToastEvent.swift`
- Modify: `RoadTripBingo/Views/TokenToastView.swift`

- [ ] **Step 1: Add `.opponentClaim` to `ToastStyle` in `ToastEvent.swift`**

```swift
enum ToastStyle: Equatable { case earn, threat, opponentClaim }
```

- [ ] **Step 2: Handle `.opponentClaim` in `TokenToastView.swift`**

Update the `backgroundColor` and `textColor` computed properties:

```swift
private var backgroundColor: Color {
    switch style {
    case .earn:          return AmericanaTheme.yellow
    case .threat:        return AmericanaTheme.red
    case .opponentClaim: return AmericanaTheme.brown.opacity(0.85)
    }
}

private var textColor: Color {
    switch style {
    case .earn:          return AmericanaTheme.ink
    case .threat:        return .white
    case .opponentClaim: return .white
    }
}
```

- [ ] **Step 3: Run toast tests to confirm still passing**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/ToastTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Models/ToastEvent.swift \
        RoadTripBingo/Views/TokenToastView.swift
git commit -m "feat: add opponentClaim toast style for Spotting Race opponent notifications"
```

---

## Task 4: AppState — new state properties and cleanup

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

Add the Spotting Race state block, `soloSpottingRaceBest` persistence, `resetSpottingRound()` helper, and cleanup in `goHome()`.

- [ ] **Step 1: Add `gameType` published property with UserDefaults persistence**

After the existing `// MARK: - Game Mode` section (around line 25 in AppState.swift), add:

```swift
// MARK: - Game Type
@Published var gameType: GameType = {
    guard let raw = UserDefaults.standard.string(forKey: "gameType"),
          let gt = GameType(rawValue: raw) else { return .bingo }
    return gt
}() {
    didSet { UserDefaults.standard.set(gameType.rawValue, forKey: "gameType") }
}
```

- [ ] **Step 2: Add Spotting Race state block**

After the `// MARK: - Solo tracking` section (around line 95), add:

```swift
// MARK: - Spotting Race
@Published var spottingRaceTiles: [SpottingRaceTile] = []
@Published var mySpottingScore: Int = 0
@Published var opponentSpottingScores: [String: Int] = [:]
@Published var spottingRoundEndTime: Date? = nil
/// Host-only draw queue. Peers never see this.
var tilePool: [BingoSquare] = []
var mySpottingClaimedCount: Int = 0
private var spottingTimerTask: Task<Void, Never>? = nil
/// Pending finalize tasks keyed by slot UUID (cancelled on undo).
private var softClaimTasks: [UUID: Task<Void, Never>] = [:]

var soloSpottingRaceBest: Int {
    get { UserDefaults.standard.integer(forKey: "soloSpottingRaceBest") }
    set { UserDefaults.standard.set(newValue, forKey: "soloSpottingRaceBest") }
}
```

- [ ] **Step 3: Add `resetSpottingRound()` helper**

Add this private method after the existing `resetRound()` method:

```swift
private func resetSpottingRound() {
    spottingRaceTiles = []
    mySpottingScore = 0
    opponentSpottingScores = [:]
    spottingRoundEndTime = nil
    tilePool = []
    mySpottingClaimedCount = 0
    spottingTimerTask?.cancel()
    spottingTimerTask = nil
    softClaimTasks.values.forEach { $0.cancel() }
    softClaimTasks = [:]
}
```

- [ ] **Step 4: Add Spotting Race cleanup to `goHome()`**

Inside `goHome()`, after the line `soloStartTime = nil`, add:

```swift
resetSpottingRound()
```

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: add Spotting Race state properties and cleanup to AppState"
```

---

## Task 5: AppState — startSpottingRaceSolo and startSpottingRaceGame

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 1: Add the private `drawWeightedTile()` helper**

Add after `resetSpottingRound()`:

```swift
/// Draws one tile from `tilePool` using rarity-weighted probability.
/// Removes the drawn tile from the pool. Returns nil when pool is empty.
private func drawWeightedTile() -> BingoSquare? {
    guard !tilePool.isEmpty else { return nil }
    let totalWeight = tilePool.reduce(0) { $0 + $1.rarity.spottingRaceWeight }
    guard totalWeight > 0 else { return tilePool.removeFirst() }
    var pick = Int.random(in: 0..<totalWeight)
    for (idx, square) in tilePool.enumerated() {
        pick -= square.rarity.spottingRaceWeight
        if pick < 0 {
            tilePool.remove(at: idx)
            return square
        }
    }
    return tilePool.removeFirst()
}

/// Fills a slot with a freshly drawn tile. If pool is exhausted the slot is removed.
/// Host-only. Broadcasts `tileReplaced` to peers.
private func replaceSpottingSlot(slotID: UUID) {
    guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
    if let next = drawWeightedTile() {
        let newTile = SpottingRaceTile(
            id: slotID,
            square: next,
            expiresAt: Date().addingTimeInterval(60)
        )
        spottingRaceTiles[idx] = newTile
        multipeerSession?.send(.tileReplaced(
            slotID: slotID,
            replacement: next,
            expiresAt: newTile.expiresAt
        ))
    } else {
        // Pool exhausted — remove this slot gracefully
        spottingRaceTiles.remove(at: idx)
    }
}
```

- [ ] **Step 2: Add `startSpottingRaceSolo()`**

Add after `startSoloGame()`:

```swift
func startSpottingRaceSolo() {
    // Tear down any existing session (mirrors startSoloGame)
    multipeerSession?.disconnect()
    multipeerSession = nil
    connectedPlayerNames = []
    foundGameNames = []
    connectingToGame = nil
    opponentBoards = [:]
    opponentMarked = [:]
    recentOpponentMarks = []
    pruningTask?.cancel()
    pruningTask = nil
    lastRoundWinner = nil
    consecutiveLosses = [:]
    tokenBalance = 0
    tokenBalances = [:]
    pendingToast = nil
    completedLine = nil
    localBoard = nil
    reserveSquares = []
    playerDifficulties = [:]
    resetRound()
    resetSpottingRound()

    gameMode = .solo
    isHost = true  // solo acts as its own host for tile management

    // Build and shuffle the tile pool
    let baseTiles = SquarePool.load()
    let namedPacks = PackManager.packs(forIDs: activePackIDs)
    let activePacks = [SquarePool.loadBasePack()] + namedPacks
    tilePool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks).shuffled()

    // Populate 6 initial slots
    spottingRaceTiles = (0..<6).compactMap { _ -> SpottingRaceTile? in
        guard let sq = drawWeightedTile(), sq.id != BingoSquare.freeSquareID else { return nil }
        return SpottingRaceTile(id: UUID(), square: sq, expiresAt: Date().addingTimeInterval(60))
    }

    spottingRoundEndTime = Date().addingTimeInterval(300)  // 5 minutes
    startSpottingTimerLoop()
    screen = .game
}
```

- [ ] **Step 3: Add `startSpottingRaceGame()` (host-only)**

Add after `startSpottingRaceSolo()`:

```swift
func startSpottingRaceGame() {
    guard isHost else { return }

    let baseTiles = SquarePool.load()
    let namedPacks = PackManager.packs(forIDs: activePackIDs)
    let activePacks = [SquarePool.loadBasePack()] + namedPacks
    tilePool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks).shuffled()

    resetSpottingRound()
    opponentSpottingScores = Dictionary(
        uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
    )

    spottingRaceTiles = (0..<6).compactMap { _ -> SpottingRaceTile? in
        guard let sq = drawWeightedTile(), sq.id != BingoSquare.freeSquareID else { return nil }
        return SpottingRaceTile(id: UUID(), square: sq, expiresAt: Date().addingTimeInterval(60))
    }

    spottingRoundEndTime = Date().addingTimeInterval(300)

    multipeerSession?.stopAdvertising()
    multipeerSession?.send(.gameStarted(boards: [:], activePackIDs: activePackIDs, gameType: .spottingRace))

    // Broadcast the 6 initial tiles to peers
    for tile in spottingRaceTiles {
        multipeerSession?.send(.tileReplaced(
            slotID: tile.id,
            replacement: tile.square,
            expiresAt: tile.expiresAt
        ))
    }

    startSpottingTimerLoop()
    screen = .game
}
```

- [ ] **Step 4: Add `requestPlayAgainSpottingRace()` (host-only)**

Add after `startSpottingRaceGame()`:

```swift
func requestPlayAgainSpottingRace() {
    guard isHost, gameType == .spottingRace else { return }

    let baseTiles = SquarePool.load()
    let namedPacks = PackManager.packs(forIDs: activePackIDs)
    let activePacks = [SquarePool.loadBasePack()] + namedPacks
    tilePool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks).shuffled()

    resetSpottingRound()
    opponentSpottingScores = Dictionary(
        uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
    )

    spottingRaceTiles = (0..<6).compactMap { _ -> SpottingRaceTile? in
        guard let sq = drawWeightedTile(), sq.id != BingoSquare.freeSquareID else { return nil }
        return SpottingRaceTile(id: UUID(), square: sq, expiresAt: Date().addingTimeInterval(60))
    }

    spottingRoundEndTime = Date().addingTimeInterval(300)

    multipeerSession?.send(.playAgain(boards: [:], activePackIDs: activePackIDs, gameType: .spottingRace))
    for tile in spottingRaceTiles {
        multipeerSession?.send(.tileReplaced(
            slotID: tile.id,
            replacement: tile.square,
            expiresAt: tile.expiresAt
        ))
    }

    startSpottingTimerLoop()
    screen = .game
}
```

- [ ] **Step 5: Update `startGame()` to branch on `gameType`**

Find the existing `startGame()` method (around line 278):

```swift
func startGame() {
    guard isHost else { return }
    dealAndLaunchRound { [weak self] boards in
        self?.multipeerSession?.stopAdvertising()
        self?.multipeerSession?.send(.gameStarted(boards: boards, activePackIDs: self?.activePackIDs ?? []))
    }
}
```

Replace it with:

```swift
func startGame() {
    guard isHost else { return }
    if gameType == .spottingRace {
        startSpottingRaceGame()
    } else {
        dealAndLaunchRound { [weak self] boards in
            self?.multipeerSession?.stopAdvertising()
            self?.multipeerSession?.send(.gameStarted(
                boards: boards,
                activePackIDs: self?.activePackIDs ?? [],
                gameType: .bingo
            ))
        }
    }
}
```

- [ ] **Step 6: Update `requestPlayAgain()` to branch on `gameType`**

Find the existing `requestPlayAgain()` method (around line 381):

```swift
func requestPlayAgain() {
    guard isHost else { return }
    // Update consecutive-loss streaks ...
    ...
    dealAndLaunchRound { [weak self] boards in
        self?.multipeerSession?.send(.playAgain(boards: boards, activePackIDs: self?.activePackIDs ?? []))
    }
}
```

Replace only the inner send call with the 3-parameter version, and add the Spotting Race branch at the top:

```swift
func requestPlayAgain() {
    guard isHost else { return }
    if gameType == .spottingRace {
        requestPlayAgainSpottingRace()
        return
    }
    // Update consecutive-loss streaks based on last winner.
    if let winner = lastRoundWinner {
        let allNames = [playerName] + connectedPlayerNames
        for name in allNames {
            if name == winner {
                consecutiveLosses[name] = 0
            } else {
                consecutiveLosses[name, default: 0] += 1
            }
        }
    }
    dealAndLaunchRound { [weak self] boards in
        self?.multipeerSession?.send(.playAgain(
            boards: boards,
            activePackIDs: self?.activePackIDs ?? [],
            gameType: .bingo
        ))
    }
}
```

- [ ] **Step 7: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: add startSpottingRaceSolo, startSpottingRaceGame, tile pool management"
```

---

## Task 6: AppState — host timer loop and round end

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 1: Add `startSpottingTimerLoop()`**

Add after `replaceSpottingSlot()`:

```swift
/// Fires every second. Host-only (also used in solo).
/// Checks tile expiry and the round end condition.
private func startSpottingTimerLoop() {
    spottingTimerTask?.cancel()
    spottingTimerTask = Task { @MainActor [weak self] in
        do {
            while let self {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }

                // Round end check
                if let endTime = self.spottingRoundEndTime, Date() >= endTime {
                    self.endSpottingRound()
                    return
                }

                // Tile expiry — only replace tiles that are not currently locked
                let now = Date()
                let expiredSlotIDs = self.spottingRaceTiles
                    .filter { $0.lockedBy == nil && now >= $0.expiresAt }
                    .map(\.id)
                for slotID in expiredSlotIDs {
                    self.replaceSpottingSlot(slotID: slotID)
                }
            }
        } catch {
            // Task cancelled — exit cleanly
        }
    }
}
```

- [ ] **Step 2: Add `endSpottingRound()`**

Add after `startSpottingTimerLoop()`:

```swift
private func endSpottingRound() {
    spottingTimerTask?.cancel()
    spottingTimerTask = nil
    softClaimTasks.values.forEach { $0.cancel() }
    softClaimTasks = [:]

    if gameMode == .solo {
        // base = total rarity score; multiplier rewards sustained engagement
        let base = mySpottingScore
        let multiplier = min(2.0, 1.0 + Double(mySpottingClaimedCount) / 20.0)
        let finalScore = Int(Double(base) * multiplier)
        let isNewBest = finalScore > soloSpottingRaceBest
        if isNewBest { soloSpottingRaceBest = finalScore }

        // Reuse lastSolo* published properties so WinView can read them
        lastSoloScore = finalScore
        lastSoloRarityBonus = base            // used as "Rarity score" in breakdown card
        lastSoloTimeMultiplier = multiplier   // used as multiplier row
        lastSoloTokens = mySpottingClaimedCount  // repurposed as "Tiles claimed"
        lastSoloExtraLines = 0
        lastSoloIsNewBest = isNewBest

        screen = .win(winnerName: playerName)
    } else {
        // Host collects canonical scores and broadcasts final results
        var allScores = opponentSpottingScores
        allScores[playerName] = mySpottingScore
        multipeerSession?.send(.spottingRoundEnded(scores: allScores))

        let winner = allScores.max(by: { $0.value < $1.value })?.key ?? playerName
        lastRoundWinner = winner
        winHistory[winner, default: 0] += 1
        screen = .win(winnerName: winner)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: add Spotting Race timer loop and round end logic"
```

---

## Task 7: AppState — claim flow and peer message handling

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

- [ ] **Step 1: Add `tapSpottingTile(slotID:)`**

Add after `endSpottingRound()`:

```swift
/// Called when the local player taps a tile. Starts the 2-second soft-claim window.
func tapSpottingTile(slotID: UUID) {
    guard screen == .game, gameType == .spottingRace else { return }
    guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
    let tile = spottingRaceTiles[idx]
    guard tile.lockedBy == nil, tile.claimedBy == nil else { return }

    let myTimestamp = Date()
    spottingRaceTiles[idx].lockedBy = playerName
    spottingRaceTiles[idx].lockTimestamp = myTimestamp

    multipeerSession?.send(.lockTile(
        slotID: slotID,
        squareID: tile.square.id,
        byName: playerName,
        timestamp: myTimestamp
    ))

    // After 2 seconds, finalize the claim
    let task = Task { @MainActor [weak self] in
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            self?.finalizeSpottingClaim(slotID: slotID)
        } catch {
            // Cancelled by undo
        }
    }
    softClaimTasks[slotID] = task
}

/// Called when the local player taps Undo during the soft-claim window.
func undoSpottingClaim(slotID: UUID) {
    softClaimTasks[slotID]?.cancel()
    softClaimTasks.removeValue(forKey: slotID)
    guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
    spottingRaceTiles[idx].lockedBy = nil
    spottingRaceTiles[idx].lockTimestamp = nil
    multipeerSession?.send(.releaseTile(slotID: slotID, byName: playerName))
}

private func finalizeSpottingClaim(slotID: UUID) {
    softClaimTasks.removeValue(forKey: slotID)
    guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
    let tile = spottingRaceTiles[idx]
    // Guard: ownership may have flipped if a race was lost between lock and finalize
    guard tile.lockedBy == playerName else { return }

    spottingRaceTiles[idx].claimedBy = playerName
    mySpottingScore += tile.square.rarity.spottingRaceScore
    mySpottingClaimedCount += 1

    multipeerSession?.send(.claimTile(
        slotID: slotID,
        squareID: tile.square.id,
        byName: playerName,
        timestamp: tile.lockTimestamp ?? Date()
    ))

    // Host queues replacement after 2-second stamp hold
    if isHost {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.replaceSpottingSlot(slotID: slotID)
        }
    }
}
```

- [ ] **Step 2: Add Spotting Race cases to `multipeerSession(_:didReceive:from:)`**

Inside the `switch message {` block in the delegate method, add new cases before the closing brace:

```swift
case .lockTile(let slotID, let squareID, let byName, let timestamp):
    guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID && $0.square.id == squareID }) else { return }
    if spottingRaceTiles[idx].lockedBy == playerName,
       let myTimestamp = spottingRaceTiles[idx].lockTimestamp {
        if myTimestamp <= timestamp {
            // Local claim wins — ignore peer's lock
            return
        } else {
            // Peer wins — cancel our pending finalize and show denial
            softClaimTasks[slotID]?.cancel()
            softClaimTasks.removeValue(forKey: slotID)
            spottingRaceTiles[idx].lockedBy = byName
            spottingRaceTiles[idx].lockTimestamp = timestamp
            pendingToast = ToastEvent(message: "❌ \(byName) was faster!", style: .threat)
        }
    } else if spottingRaceTiles[idx].lockedBy == nil {
        spottingRaceTiles[idx].lockedBy = byName
        spottingRaceTiles[idx].lockTimestamp = timestamp
    }

case .releaseTile(let slotID, let byName):
    if let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }),
       spottingRaceTiles[idx].lockedBy == byName {
        spottingRaceTiles[idx].lockedBy = nil
        spottingRaceTiles[idx].lockTimestamp = nil
    }

case .claimTile(let slotID, _, let byName, _):
    if let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) {
        let score = spottingRaceTiles[idx].square.rarity.spottingRaceScore
        let tileName = spottingRaceTiles[idx].square.text
        let emoji = spottingRaceTiles[idx].square.emoji ?? "📍"
        spottingRaceTiles[idx].claimedBy = byName
        opponentSpottingScores[byName, default: 0] += score
        pendingToast = ToastEvent(
            message: "\(byName) claimed \(emoji) \(tileName) · +\(score) pts",
            style: .opponentClaim
        )
        // Host replaces the slot after 2-second stamp hold
        if isHost {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.replaceSpottingSlot(slotID: slotID)
            }
        }
    }

case .tileReplaced(let slotID, let replacement, let expiresAt):
    // Non-host peers update their local tile grid
    if !isHost {
        if let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) {
            spottingRaceTiles[idx] = SpottingRaceTile(
                id: slotID,
                square: replacement,
                expiresAt: expiresAt
            )
        } else {
            // Initial fill from host — slot doesn't exist yet
            spottingRaceTiles.append(SpottingRaceTile(
                id: slotID,
                square: replacement,
                expiresAt: expiresAt
            ))
        }
    }

case .spottingRoundEnded(let scores):
    spottingTimerTask?.cancel()
    spottingTimerTask = nil
    softClaimTasks.values.forEach { $0.cancel() }
    softClaimTasks = [:]
    mySpottingScore = scores[playerName] ?? mySpottingScore
    opponentSpottingScores = scores.filter { $0.key != playerName }
    let winner = scores.max(by: { $0.value < $1.value })?.key ?? playerName
    lastRoundWinner = winner
    winHistory[winner, default: 0] += 1
    screen = .win(winnerName: winner)
```

- [ ] **Step 3: Update existing `gameStarted` and `playAgain` delegate cases to handle the new `gameType` parameter**

Find `case .gameStarted(let boards, let activePackIDs):` in the delegate method and replace with:

```swift
case .gameStarted(let boards, let activePackIDs, let gameType):
    self.gameType = gameType
    self.activePackIDs = activePackIDs
    rollDailyChallengesIfNeeded()
    recentOpponentMarks = []
    pruningTask?.cancel()
    pruningTask = nil
    multipeerSession?.stopBrowsing()

    if gameType == .spottingRace {
        resetSpottingRound()
        opponentSpottingScores = Dictionary(
            uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
        )
        spottingRoundEndTime = Date().addingTimeInterval(300)
        // Initial tiles will arrive as tileReplaced messages from the host
    } else {
        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }
        opponentBoards = [:]
        opponentMarked = [:]
        for (name, squares) in boards where name != playerName {
            opponentBoards[name] = squares
            opponentMarked[name] = [BingoSquare.freeSquareID]
        }
        completedLine = nil
        resetRound()
        earnTokens(2, reason: "Round start")
    }
    screen = .game
```

Find `case .playAgain(let boards, let activePackIDs):` and replace with:

```swift
case .playAgain(let boards, let activePackIDs, let gameType):
    self.gameType = gameType
    self.activePackIDs = activePackIDs
    rollDailyChallengesIfNeeded()
    recentOpponentMarks = []
    pruningTask?.cancel()
    pruningTask = nil

    if gameType == .spottingRace {
        resetSpottingRound()
        opponentSpottingScores = Dictionary(
            uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
        )
        spottingRoundEndTime = Date().addingTimeInterval(300)
        // Tiles arrive as tileReplaced messages
    } else {
        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }
        opponentBoards = [:]
        opponentMarked = [:]
        for (name, squares) in boards where name != playerName {
            opponentBoards[name] = squares
            opponentMarked[name] = [BingoSquare.freeSquareID]
        }
        completedLine = nil
        resetRound()
        earnTokens(2, reason: "Round start")
    }
    screen = .game
```

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: implement Spotting Race claim flow, peer message handling, gameStarted/playAgain routing"
```

---

## Task 8: ContentView routing + HomeView game mode picker

**Files:**
- Modify: `RoadTripBingo/ContentView.swift`
- Modify: `RoadTripBingo/Views/HomeView.swift`

- [ ] **Step 1: Update `ContentView` to branch on `gameType` for the `.game` case**

Replace:

```swift
case .game:
    GameView().transition(.opacity)
```

With:

```swift
case .game:
    switch appState.gameType {
    case .bingo:
        GameView().transition(.opacity)
    case .spottingRace:
        SpottingRaceView().transition(.opacity)
    }
```

- [ ] **Step 2: Update the Solo button in `HomeView` to branch on `gameType`**

Find the button action for "Play Solo" in `HomeView.swift`:

```swift
Button(action: {
    guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    appState.startSoloGame()
}) {
```

Replace the action with:

```swift
Button(action: {
    guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    if appState.gameType == .spottingRace {
        appState.startSpottingRaceSolo()
    } else {
        appState.startSoloGame()
    }
}) {
```

- [ ] **Step 3: Add the `gameModePicker` computed property to `HomeView`**

Add this private computed property inside `HomeView`, before `rightPanel`:

```swift
private var gameModePicker: some View {
    VStack(alignment: .leading, spacing: 0) {
        Text("GAME MODE")
            .font(AmericanaTheme.barlowSemiBold(10))
            .foregroundColor(AmericanaTheme.ink.opacity(0.40))
            .kerning(3)
            .padding(.bottom, 8)

        HStack(spacing: 8) {
            gameModeCard(title: "Classic Bingo", subtitle: "5×5 grid", type: .bingo)
            gameModeCard(title: "Spotting Race", subtitle: "Time attack", type: .spottingRace)
        }
    }
    .padding(.bottom, 24)
}

private func gameModeCard(title: String, subtitle: String, type: GameType) -> some View {
    let selected = appState.gameType == type
    return Button(action: { appState.gameType = type }) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AmericanaTheme.barlowBold(14))
                .foregroundColor(selected ? .white : AmericanaTheme.ink)
            Text(subtitle)
                .font(AmericanaTheme.barlowSemiBold(11))
                .foregroundColor(selected ? .white.opacity(0.70) : AmericanaTheme.ink.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(selected ? AmericanaTheme.green : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(
                            selected ? Color.clear : AmericanaTheme.ink.opacity(0.12),
                            lineWidth: 1.5
                        )
                )
        )
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 4: Insert `gameModePicker` into `rightPanel` above the name-field label**

Inside `rightPanel`, in the `VStack(alignment: .leading, spacing: 0)`, insert `gameModePicker` immediately before the `// Name field` comment:

```swift
// Game mode picker
gameModePicker

// Name field
Text("YOUR NAME")
...
```

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/ContentView.swift \
        RoadTripBingo/Views/HomeView.swift
git commit -m "feat: ContentView routes .game through gameType; HomeView adds Spotting Race mode picker"
```

---

## Task 9: SpottingRaceTileView — all visual states

**Files:**
- Create: `RoadTripBingo/Views/SpottingRaceTileView.swift`

This is the most visually complex new file. It renders one `SpottingRaceTile` in 8 states. States are derived purely from the tile's `lockedBy`, `claimedBy`, and `isExpiring` properties.

- [ ] **Step 1: Create `SpottingRaceTileView.swift`**

```swift
// RoadTripBingo/Views/SpottingRaceTileView.swift
import SwiftUI

struct SpottingRaceTileView: View {
    let tile: SpottingRaceTile
    let playerName: String
    let onTap: () -> Void
    let onUndo: () -> Void

    @State private var stampVisible = false
    @State private var stampRotation: Double = 0
    @State private var stampScale: CGFloat = 0

    private enum TileState {
        case unclaimed
        case expiring        // <3s left, unclaimed
        case softClaimMine   // I tapped, 2-second window
        case claimedMine
        case softClaimOpponent
        case claimedOpponent
    }

    private var tileState: TileState {
        if let claimer = tile.claimedBy {
            return claimer == playerName ? .claimedMine : .claimedOpponent
        }
        if let locker = tile.lockedBy {
            return locker == playerName ? .softClaimMine : .softClaimOpponent
        }
        return tile.isExpiring ? .expiring : .unclaimed
    }

    // MARK: - Colours

    private var imageZoneBackground: Color {
        switch tileState {
        case .unclaimed, .expiring: return Color(red: 0.98, green: 0.96, blue: 0.90)   // cream
        case .softClaimMine, .claimedMine: return AmericanaTheme.green.opacity(0.18)
        case .softClaimOpponent: return Color.black.opacity(0.55)
        case .claimedOpponent: return AmericanaTheme.yellow.opacity(0.22)
        }
    }

    private var bandBackground: Color {
        switch tileState {
        case .unclaimed, .expiring: return Color(red: 0.18, green: 0.14, blue: 0.10)   // dark wood
        case .softClaimMine, .claimedMine: return AmericanaTheme.green.opacity(0.85)
        case .softClaimOpponent: return Color(red: 0.14, green: 0.10, blue: 0.08)
        case .claimedOpponent: return Color(red: 0.55, green: 0.38, blue: 0.10)
        }
    }

    // MARK: - Rarity dots

    private var rarityDotCount: Int { tile.square.rarity.spottingRaceWeight / 20 + 1 }
    // veryCommon→1, common→2, uncommon→2, rare→1... actually simpler to map directly:
    private var dotCount: Int {
        switch tile.square.rarity {
        case .veryCommon: return 1
        case .common:     return 2
        case .uncommon:   return 3
        case .rare:       return 4
        case .veryRare:   return 5
        }
    }

    private var dotColor: Color {
        switch tile.square.rarity {
        case .veryCommon: return Color(red: 0.60, green: 0.60, blue: 0.60)
        case .common:     return Color(red: 0.30, green: 0.65, blue: 0.30)
        case .uncommon:   return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .rare:       return Color(red: 0.70, green: 0.20, blue: 0.90)
        case .veryRare:   return Color(red: 0.95, green: 0.70, blue: 0.10)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            imageZone
                .frame(height: 130)
            labelBand
                .frame(height: 52)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(borderColor, lineWidth: tileState == .expiring ? 2.5 : 1)
                .opacity(tileState == .expiring ? 1 : 0.15)
                .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                           value: tileState == .expiring)
        )
        .shadow(color: AmericanaTheme.shadow, radius: 6, x: 0, y: 3)
        .onChange(of: tileState) { newState in
            if newState == .softClaimMine || newState == .claimedMine {
                triggerStamp(rotation: -12)
            } else if newState == .claimedOpponent {
                triggerStamp(rotation: 9)
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    stampVisible = false
                    stampScale = 0
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard tileState == .unclaimed || tileState == .expiring else { return }
            onTap()
        }
        .allowsHitTesting(tileState != .softClaimOpponent && tileState != .claimedOpponent && tileState != .claimedMine)
    }

    private var borderColor: Color {
        tileState == .expiring ? AmericanaTheme.red : Color.clear
    }

    // MARK: - Image zone

    private var imageZone: some View {
        ZStack {
            imageZoneBackground.ignoresSafeArea(edges: [])

            // Tile image or emoji
            Group {
                if let img = AmericanaTheme.tileImage(for: tile.square) {
                    img.resizable().scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .opacity(tileState == .softClaimOpponent ? 0.3 : 1)
                } else if let emoji = tile.square.emoji {
                    Text(emoji).font(.system(size: 52))
                        .opacity(tileState == .softClaimOpponent ? 0.3 : 1)
                }
            }

            // Rarity dots — top-left
            VStack {
                HStack {
                    HStack(spacing: 3) {
                        ForEach(0..<dotCount, id: \.self) { _ in
                            Circle().fill(dotColor).frame(width: 7, height: 7)
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.30))
                    .clipShape(Capsule())
                    Spacer()
                    // Points — top-right
                    Text("+\(tile.square.rarity.spottingRaceScore)")
                        .font(AmericanaTheme.barlowBold(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                }
                .padding(7)
                Spacer()
            }

            // Stamp (softClaimMine + claimedMine → green; claimedOpponent → amber)
            if stampVisible {
                stampView
                    .scaleEffect(stampScale)
                    .rotationEffect(.degrees(stampRotation))
                    .transition(.identity)
            }

            // Opponent soft-claim overlay
            if tileState == .softClaimOpponent {
                opponentLockOverlay
            }
        }
    }

    private var stampView: some View {
        let isMine = tileState == .softClaimMine || tileState == .claimedMine
        return VStack(spacing: 2) {
            Text(isMine ? "SPOTTED" : "TAKEN")
                .font(AmericanaTheme.rye(isMine ? 22 : 18))
                .foregroundColor(isMine ? AmericanaTheme.green : AmericanaTheme.yellow)
            if !isMine, let claimer = tile.claimedBy {
                Text("+\(tile.square.rarity.spottingRaceScore) pts · \(claimer)")
                    .font(AmericanaTheme.barlowSemiBold(10))
                    .foregroundColor(AmericanaTheme.yellow.opacity(0.85))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isMine ? AmericanaTheme.green : AmericanaTheme.yellow, lineWidth: 3)
        )
    }

    private var opponentLockOverlay: some View {
        VStack(spacing: 6) {
            Text("🔒")
                .font(.system(size: 28))
            Text(tile.lockedBy ?? "")
                .font(AmericanaTheme.barlowBold(14))
                .foregroundColor(.white)
            Text("Claiming…")
                .font(AmericanaTheme.barlowSemiBold(11))
                .foregroundColor(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.60))
    }

    // MARK: - Label band

    private var labelBand: some View {
        ZStack {
            bandBackground

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.square.text)
                        .font(AmericanaTheme.barlowSemiBold(13))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(tile.claimedBy != nil ? 0.55 : 1.0)

                    fuseBar
                }
                .padding(.horizontal, 10).padding(.vertical, 7)

                if tileState == .softClaimMine {
                    undoChip
                        .padding(.trailing, 8)
                }
            }
        }
    }

    private var fuseBar: some View {
        let total: TimeInterval = 60
        let remaining = max(0, tile.expiresAt.timeIntervalSinceNow)
        let fraction = CGFloat(remaining / total)
        let barColor: Color = tileState == .expiring ? AmericanaTheme.red : AmericanaTheme.yellow
        let isPaused = tile.lockedBy != nil || tile.claimedBy != nil

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                RoundedRectangle(cornerRadius: 2)
                    .fill(isPaused ? barColor.opacity(0.50) : barColor)
                    .frame(width: geo.size.width * (isPaused ? fraction : fraction))
            }
        }
        .frame(height: 3)
    }

    private var undoChip: some View {
        Button(action: onUndo) {
            Text("Undo")
                .font(AmericanaTheme.barlowBold(11))
                .foregroundColor(AmericanaTheme.green)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.white.opacity(0.90))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stamp animation

    private func triggerStamp(rotation: Double) {
        stampRotation = rotation
        stampVisible = true
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            stampScale = 1.0
        }
    }
}
```

- [ ] **Step 2: Add pbxproj entry for this file (see Task 13 — defer until all files are created)**

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/SpottingRaceTileView.swift
git commit -m "feat: add SpottingRaceTileView with all 8 visual states"
```

---

## Task 10: SpottingRaceView — game screen

**Files:**
- Create: `RoadTripBingo/Views/SpottingRaceView.swift`

Landscape iPad layout. 3×2 grid of `SpottingRaceTileView`, round countdown timer at top, score chip top-right, opponent scores listed in a sidebar.

- [ ] **Step 1: Create `SpottingRaceView.swift`**

```swift
// RoadTripBingo/Views/SpottingRaceView.swift
import SwiftUI

struct SpottingRaceView: View {
    @EnvironmentObject var appState: AppState
    @State private var timeRemaining: TimeInterval = 300
    @State private var toastMessage: String? = nil
    @State private var activeToastID: UUID? = nil
    @State private var toastStyle: ToastStyle = .earn

    private let timerTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmericanaTheme.gridBackground().ignoresSafeArea()

                HStack(spacing: 0) {
                    // Left sidebar: timer + scores
                    leftSidebar
                        .frame(width: 180)

                    // 3×2 tile grid
                    tileGrid
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                }

                // Toast overlay
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        TokenToastView(message: msg, style: toastStyle)
                            .padding(.bottom, 60)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onReceive(timerTick) { _ in updateTimer() }
        .onAppear { updateTimer() }
        .onChange(of: appState.pendingToast) { toast in
            guard let toast else { return }
            toastStyle = toast.style
            withAnimation(.spring()) { toastMessage = toast.message }
            activeToastID = toast.id
            appState.pendingToast = nil
            let id = toast.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                guard activeToastID == id else { return }
                withAnimation { toastMessage = nil }
            }
        }
    }

    // MARK: - Timer

    private func updateTimer() {
        if let end = appState.spottingRoundEndTime {
            timeRemaining = max(0, end.timeIntervalSinceNow)
        }
    }

    private var timerText: String {
        let mins = Int(timeRemaining) / 60
        let secs = Int(timeRemaining) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var timerColor: Color {
        timeRemaining < 30 ? AmericanaTheme.red : AmericanaTheme.yellow
    }

    // MARK: - Left sidebar

    private var leftSidebar: some View {
        ZStack {
            AmericanaTheme.paper
            VStack(spacing: 0) {
                // Timer
                VStack(spacing: 4) {
                    Text("TIME")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                        .kerning(3)
                    Text(timerText)
                        .font(AmericanaTheme.rye(36))
                        .foregroundColor(timerColor)
                        .monospacedDigit()
                }
                .padding(.top, 32)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 20)

                // My score
                VStack(spacing: 4) {
                    Text("YOUR SCORE")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                        .kerning(2)
                        .padding(.top, 16)
                    Text("\(appState.mySpottingScore)")
                        .font(AmericanaTheme.rye(44))
                        .foregroundColor(AmericanaTheme.green)
                }

                if !appState.opponentSpottingScores.isEmpty {
                    Divider().padding(.horizontal, 20).padding(.top, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(
                            appState.opponentSpottingScores.sorted(by: { $0.value > $1.value }),
                            id: \.key
                        ) { name, score in
                            HStack {
                                Text(name)
                                    .font(AmericanaTheme.barlowSemiBold(13))
                                    .foregroundColor(AmericanaTheme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(score)")
                                    .font(AmericanaTheme.barlowBold(14))
                                    .foregroundColor(AmericanaTheme.ink.opacity(0.70))
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 12)
                }

                Spacer()
            }
        }
        .ignoresSafeArea(edges: .vertical)
    }

    // MARK: - 3×2 tile grid

    private var tileGrid: some View {
        let tiles = appState.spottingRaceTiles
        return VStack(spacing: 12) {
            ForEach(0..<2) { row in
                HStack(spacing: 12) {
                    ForEach(0..<3) { col in
                        let idx = row * 3 + col
                        if idx < tiles.count {
                            let tile = tiles[idx]
                            SpottingRaceTileView(
                                tile: tile,
                                playerName: appState.playerName,
                                onTap: { appState.tapSpottingTile(slotID: tile.id) },
                                onUndo: { appState.undoSpottingClaim(slotID: tile.id) }
                            )
                            .id(tile.id)  // stable identity for SwiftUI animations
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            // Empty slot (pool exhausted)
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 182)
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: tiles.map(\.id))
    }
}
```

- [ ] **Step 2: Add pbxproj entry (see Task 13)**

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/SpottingRaceView.swift
git commit -m "feat: add SpottingRaceView — 3×2 grid, countdown timer, score sidebar, toast"
```

---

## Task 11: WinView — Spotting Race branch

**Files:**
- Modify: `RoadTripBingo/Views/WinView.swift`

- [ ] **Step 1: Update `body` to branch on `gameType`**

Replace the existing `body`:

```swift
var body: some View {
    ZStack {
        AmericanaTheme.gridBackground().ignoresSafeArea()
        if isLocalWin { ConfettiView() }
        if appState.gameType == .spottingRace {
            if appState.gameMode == .solo {
                spottingRaceSoloContent
            } else {
                spottingRaceMultiplayerContent
            }
        } else if appState.gameMode == .solo {
            soloContent
        } else {
            multiplayerContent
        }
    }
    .sensoryFeedback(.impact(weight: .heavy), trigger: didAppear)
    .onAppear { if isLocalWin { didAppear = true } }
}
```

- [ ] **Step 2: Add `spottingRaceSoloContent`**

Add after the existing `soloContent` computed property:

```swift
// MARK: - Spotting Race Solo

private var spottingRaceSoloContent: some View {
    VStack(spacing: 28) {
        Text("⏱️").font(.system(size: 96))

        Text("TIME'S UP!")
            .font(AmericanaTheme.rye(38))
            .foregroundColor(AmericanaTheme.yellow)
            .multilineTextAlignment(.center)

        spottingRaceScoreBreakdownCard

        personalBestBadge
            .onAppear { if appState.lastSoloIsNewBest { pbPulse = true } }

        VStack(spacing: 12) {
            Button(action: { appState.startSpottingRaceSolo() }) {
                HStack {
                    Text("Play Again")
                        .font(AmericanaTheme.barlowBold(18)).kerning(2)
                    Spacer()
                    Text("→").opacity(0.5)
                }
                .foregroundColor(.white)
                .padding(16).frame(maxWidth: 360)
                .background(AmericanaTheme.green)
                .cornerRadius(11)
                .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 4)
            }

            Button(action: { appState.goHome() }) {
                HStack {
                    Text("Done")
                        .font(AmericanaTheme.barlowBold(18)).kerning(2)
                    Spacer()
                    Text("→").opacity(0.35)
                }
                .foregroundColor(AmericanaTheme.brown)
                .padding(14).frame(maxWidth: 360)
                .background(AmericanaTheme.parchment)
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(AmericanaTheme.brown.opacity(0.5), lineWidth: 2))
                .cornerRadius(11)
            }
        }
    }
    .padding(48)
}

private var spottingRaceScoreBreakdownCard: some View {
    VStack(spacing: 0) {
        Text("SCORE BREAKDOWN")
            .font(AmericanaTheme.barlowSemiBold(10))
            .foregroundColor(AmericanaTheme.ink.opacity(0.40))
            .kerning(3)
            .padding(.bottom, 12)

        scoreRow(label: "Tiles claimed", value: appState.lastSoloTokens)
        scoreRow(label: "Rarity score", value: appState.lastSoloRarityBonus)

        Divider().padding(.vertical, 8)

        HStack {
            Text("× \(String(format: "%.2f", appState.lastSoloTimeMultiplier))×  (volume)")
                .font(AmericanaTheme.barlowSemiBold(15))
                .foregroundColor(AmericanaTheme.ink.opacity(0.55))
            Spacer()
        }
        .padding(.vertical, 2)

        Divider().padding(.vertical, 8)

        HStack {
            Text("Total")
                .font(AmericanaTheme.barlowBold(17)).foregroundColor(AmericanaTheme.ink)
            Spacer()
            Text("\(appState.lastSoloScore)")
                .font(AmericanaTheme.barlowBold(24)).foregroundColor(AmericanaTheme.green)
        }
    }
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white)
            .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 4)
    )
    .frame(maxWidth: 360)
}
```

- [ ] **Step 3: Add `spottingRaceMultiplayerContent`**

Add after `spottingRaceSoloContent`:

```swift
// MARK: - Spotting Race Multiplayer

private var spottingRaceMultiplayerContent: some View {
    VStack(spacing: 32) {
        Text("⏱️").font(.system(size: 96))

        Text("TIME'S UP!")
            .font(AmericanaTheme.rye(38))
            .foregroundColor(AmericanaTheme.yellow)
            .multilineTextAlignment(.center)

        // Scores — local player first, then opponents sorted by score
        HStack(spacing: 16) {
            spottingScoreCard(
                name: appState.playerName,
                score: appState.mySpottingScore,
                isWinner: isLocalWin
            )
            ForEach(
                appState.opponentSpottingScores.sorted(by: { $0.value > $1.value }),
                id: \.key
            ) { name, score in
                spottingScoreCard(
                    name: name,
                    score: score,
                    isWinner: name == winnerName
                )
            }
        }

        // Navigate to PlayAgainView (same pattern as Classic Bingo)
        Button(action: { appState.screen = .playAgain }) {
            Text("Continue →")
                .font(AmericanaTheme.barlowBold(17))
                .padding(.horizontal, 48).padding(.vertical, 16)
                .background(AmericanaTheme.green)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
    }
    .padding(48)
}

private func spottingScoreCard(name: String, score: Int, isWinner: Bool) -> some View {
    VStack(spacing: 6) {
        if isWinner { Text("🏆").font(.system(size: 28)) }
        Text(name)
            .font(AmericanaTheme.barlowBold(16))
            .foregroundColor(AmericanaTheme.ink)
        Text("\(score) pts")
            .font(AmericanaTheme.rye(28))
            .foregroundColor(isWinner ? AmericanaTheme.green : AmericanaTheme.ink.opacity(0.65))
    }
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .shadow(color: AmericanaTheme.shadow, radius: isWinner ? 10 : 4, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isWinner ? AmericanaTheme.green : Color.clear, lineWidth: 2)
            )
    )
}
```

Note: `WinView` already has `scoreRow(label:value:)` defined — `spottingRaceScoreBreakdownCard` reuses it.

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Views/WinView.swift
git commit -m "feat: add Spotting Race win screen branch (solo breakdown + multiplayer scores)"
```

---

## Task 12: Project file — register new Swift files

**Files:**
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj`

The pbxproj uses 24-character hex UUIDs. Use the UUIDs below exactly — they are pre-assigned and used consistently throughout this plan.

| File | fileRef UUID | buildFile UUID |
|---|---|---|
| `GameType.swift` | `AA112233445566770000AA01` | `AA112233445566770000AA02` |
| `SpottingRaceTile.swift` | `AA112233445566770000AA03` | `AA112233445566770000AA04` |
| `SpottingRaceView.swift` | `AA112233445566770000AA05` | `AA112233445566770000AA06` |
| `SpottingRaceTileView.swift` | `AA112233445566770000AA07` | `AA112233445566770000AA08` |
| `SpottingRaceTests.swift` | `AA112233445566770000AA09` | `AA112233445566770000AA0A` |

- [ ] **Step 1: Add PBXFileReference entries**

In the `/* Begin PBXFileReference section */` block, add these five entries (insert alphabetically by filename, near the existing `GameMode.swift` entry):

```
		AA112233445566770000AA01 /* GameType.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GameType.swift; sourceTree = "<group>"; };
		AA112233445566770000AA03 /* SpottingRaceTile.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SpottingRaceTile.swift; sourceTree = "<group>"; };
		AA112233445566770000AA05 /* SpottingRaceView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SpottingRaceView.swift; sourceTree = "<group>"; };
		AA112233445566770000AA07 /* SpottingRaceTileView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SpottingRaceTileView.swift; sourceTree = "<group>"; };
		AA112233445566770000AA09 /* SpottingRaceTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SpottingRaceTests.swift; sourceTree = "<group>"; };
```

- [ ] **Step 2: Add PBXBuildFile entries**

In the `/* Begin PBXBuildFile section */` block, add:

```
		AA112233445566770000AA02 /* GameType.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA112233445566770000AA01 /* GameType.swift */; };
		AA112233445566770000AA04 /* SpottingRaceTile.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA112233445566770000AA03 /* SpottingRaceTile.swift */; };
		AA112233445566770000AA06 /* SpottingRaceView.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA112233445566770000AA05 /* SpottingRaceView.swift */; };
		AA112233445566770000AA08 /* SpottingRaceTileView.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA112233445566770000AA07 /* SpottingRaceTileView.swift */; };
		AA112233445566770000AA0A /* SpottingRaceTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA112233445566770000AA09 /* SpottingRaceTests.swift */; };
```

- [ ] **Step 3: Add children to PBXGroup**

Find the **Models group** (UUID `6DD0FC3F37D45333EFDF804D`). Inside its `children = (` list, add the two new model file refs near `GameMode.swift`:

```
				AA112233445566770000AA01 /* GameType.swift */,
				AA112233445566770000AA03 /* SpottingRaceTile.swift */,
```

Find the **Views group** (UUID `1FE6D976819296AC8120C9D8`). Inside its `children = (`, add near `SpottingRaceView.swift`:

```
				AA112233445566770000AA05 /* SpottingRaceView.swift */,
				AA112233445566770000AA07 /* SpottingRaceTileView.swift */,
```

Find the **Tests group** (the group containing `MultipeerMessageTests.swift`). Add:

```
				AA112233445566770000AA09 /* SpottingRaceTests.swift */,
```

- [ ] **Step 4: Add to PBXSourcesBuildPhase**

Find the **main target's** `/* Sources */` build phase (the one containing `GameMode.swift in Sources`). Add:

```
				AA112233445566770000AA02 /* GameType.swift in Sources */,
				AA112233445566770000AA04 /* SpottingRaceTile.swift in Sources */,
				AA112233445566770000AA06 /* SpottingRaceView.swift in Sources */,
				AA112233445566770000AA08 /* SpottingRaceTileView.swift in Sources */,
```

Find the **test target's** Sources build phase (the one containing `MultipeerMessageTests.swift in Sources`). Add:

```
				AA112233445566770000AA0A /* SpottingRaceTests.swift in Sources */,
```

- [ ] **Step 5: Build and fix compile errors**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build 2>&1 | grep -E "error:|warning:|SUCCEEDED|FAILED" | head -40
```

Expected: `** BUILD SUCCEEDED **`

If there are compile errors, they are most likely missing `import SwiftUI` or a call site using the old 2-parameter `gameStarted`/`playAgain` signature. Fix each error and re-run.

- [ ] **Step 6: Commit**

```bash
git add RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "chore: register 5 new Spotting Race Swift files in project.pbxproj"
```

---

## Task 13: Tests

**Files:**
- Create: `RoadTripBingoTests/SpottingRaceTests.swift`

- [ ] **Step 1: Create `SpottingRaceTests.swift`**

```swift
// RoadTripBingoTests/SpottingRaceTests.swift
import XCTest
@testable import RoadTripBingo

final class SpottingRaceTests: XCTestCase {

    // MARK: - SquareRarity extensions

    func test_spottingRaceScore_allNonZero() {
        for rarity in SquareRarity.allCases {
            XCTAssertGreaterThan(rarity.spottingRaceScore, 0,
                "\(rarity) must score > 0 in Spotting Race")
        }
    }

    func test_spottingRaceScore_veryCommon_is1() {
        XCTAssertEqual(SquareRarity.veryCommon.spottingRaceScore, 1)
    }

    func test_spottingRaceScore_veryRare_is8() {
        XCTAssertEqual(SquareRarity.veryRare.spottingRaceScore, 8)
    }

    func test_spottingRaceScore_doesNotChangeScoreBonus() {
        // scoreBonus (Classic Bingo) must remain unchanged
        XCTAssertEqual(SquareRarity.veryCommon.scoreBonus, 0)
        XCTAssertEqual(SquareRarity.veryRare.scoreBonus, 7)
    }

    func test_spottingRaceWeight_sumsToHundred() {
        let total = SquareRarity.allCases.reduce(0) { $0 + $1.spottingRaceWeight }
        XCTAssertEqual(total, 100)
    }

    func test_spottingRaceWeight_allPositive() {
        for rarity in SquareRarity.allCases {
            XCTAssertGreaterThan(rarity.spottingRaceWeight, 0)
        }
    }

    // MARK: - SpottingRaceTile

    func test_spottingRaceTile_isExpiring_trueUnder3Seconds() {
        let expiry = Date().addingTimeInterval(2)
        let tile = SpottingRaceTile(
            id: UUID(),
            square: .free,
            expiresAt: expiry
        )
        XCTAssertTrue(tile.isExpiring)
    }

    func test_spottingRaceTile_isExpiring_falseOver3Seconds() {
        let expiry = Date().addingTimeInterval(60)
        let tile = SpottingRaceTile(
            id: UUID(),
            square: .free,
            expiresAt: expiry
        )
        XCTAssertFalse(tile.isExpiring)
    }

    func test_spottingRaceTile_defaultsUnlocked() {
        let tile = SpottingRaceTile(id: UUID(), square: .free, expiresAt: Date())
        XCTAssertNil(tile.lockedBy)
        XCTAssertNil(tile.claimedBy)
        XCTAssertNil(tile.lockTimestamp)
    }

    // MARK: - GameType persistence

    func test_gameType_codable_roundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for gameType in [GameType.bingo, GameType.spottingRace] {
            let data = try encoder.encode(gameType)
            let decoded = try decoder.decode(GameType.self, from: data)
            XCTAssertEqual(decoded, gameType)
        }
    }

    // MARK: - MultipeerMessage — Spotting Race cases

    private func roundtrip(_ message: MultipeerMessage) throws -> MultipeerMessage {
        let data = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(MultipeerMessage.self, from: data)
    }

    func test_lockTile_roundtrip() throws {
        let slotID = UUID()
        let squareID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_000_000)
        let msg = MultipeerMessage.lockTile(slotID: slotID, squareID: squareID, byName: "Alice", timestamp: timestamp)
        let decoded = try roundtrip(msg)
        guard case .lockTile(let s, let sq, let name, let ts) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(sq, squareID)
        XCTAssertEqual(name, "Alice")
        XCTAssertEqual(ts.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_releaseTile_roundtrip() throws {
        let slotID = UUID()
        let msg = MultipeerMessage.releaseTile(slotID: slotID, byName: "Bob")
        let decoded = try roundtrip(msg)
        guard case .releaseTile(let s, let name) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(name, "Bob")
    }

    func test_claimTile_roundtrip() throws {
        let slotID = UUID()
        let squareID = UUID()
        let timestamp = Date(timeIntervalSince1970: 500_000)
        let msg = MultipeerMessage.claimTile(slotID: slotID, squareID: squareID, byName: "Carol", timestamp: timestamp)
        let decoded = try roundtrip(msg)
        guard case .claimTile(let s, let sq, let name, let ts) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(sq, squareID)
        XCTAssertEqual(name, "Carol")
        XCTAssertEqual(ts.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_tileReplaced_roundtrip() throws {
        let slotID = UUID()
        let square = BingoSquare(id: UUID(), text: "Hawk", emoji: "🦅", category: .nature, rarity: .rare)
        let expiry = Date(timeIntervalSince1970: 999_999)
        let msg = MultipeerMessage.tileReplaced(slotID: slotID, replacement: square, expiresAt: expiry)
        let decoded = try roundtrip(msg)
        guard case .tileReplaced(let s, let sq, let exp) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(sq.text, "Hawk")
        XCTAssertEqual(exp.timeIntervalSince1970, expiry.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_spottingRoundEnded_roundtrip() throws {
        let scores = ["Alice": 12, "Bob": 7]
        let msg = MultipeerMessage.spottingRoundEnded(scores: scores)
        let decoded = try roundtrip(msg)
        guard case .spottingRoundEnded(let s) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, scores)
    }

    func test_gameStarted_spottingRace_roundtrip() throws {
        let msg = MultipeerMessage.gameStarted(boards: [:], activePackIDs: ["pack1"], gameType: .spottingRace)
        let decoded = try roundtrip(msg)
        guard case .gameStarted(let boards, let packs, let gameType) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertTrue(boards.isEmpty)
        XCTAssertEqual(packs, ["pack1"])
        XCTAssertEqual(gameType, .spottingRace)
    }

    func test_gameStarted_legacyDecodeDefaultsToBingo() throws {
        // Simulate an old message without gameType field
        let json = """
        {"type":"gameStarted","boards":{},"activePackIDs":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MultipeerMessage.self, from: json)
        guard case .gameStarted(_, _, let gameType) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(gameType, .bingo, "Legacy messages should default to .bingo")
    }
}
```

- [ ] **Step 2: Run all tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj \
  -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` with all tests listed as passing. Fix any failures before committing.

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingoTests/SpottingRaceTests.swift
git commit -m "test: add SpottingRaceTests covering rarity scoring, tile model, message roundtrips"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ GameType enum persisted in UserDefaults — Task 4
- ✅ SpottingRaceTile model (slot identity, expiresAt, lockedBy, claimedBy) — Task 1
- ✅ spottingRaceScore (1/2/3/5/8, separate from scoreBonus) — Task 1
- ✅ spottingRaceWeight (25/30/25/15/5) — Task 1
- ✅ MultipeerMessage: lockTile, releaseTile, claimTile, tileReplaced, spottingRoundEnded — Task 2
- ✅ gameStarted / playAgain carry gameType — Task 2
- ✅ Backward-compatible decode (decodeIfPresent defaults to .bingo) — Task 2
- ✅ AppState: all new state properties + goHome cleanup — Task 4
- ✅ startSpottingRaceSolo + startSpottingRaceGame + requestPlayAgainSpottingRace — Task 5
- ✅ Weighted draw from pool — Task 5
- ✅ replaceSpottingSlot (draw next tile + broadcast tileReplaced) — Task 5
- ✅ 1-second host timer loop checking expiry + round end — Task 6
- ✅ endSpottingRound (solo scoring with multiplier + multiplayer score broadcast) — Task 6
- ✅ Soft-claim: tapSpottingTile + undoSpottingClaim + finalizeSpottingClaim — Task 7
- ✅ Conflict resolution: earlier timestamp wins, loser sees denial toast — Task 7
- ✅ Peer message handling: all 5 new cases + updated gameStarted/playAgain — Task 7
- ✅ ContentView routes .game through gameType — Task 8
- ✅ HomeView game mode picker (two tappable cards, Solo button branches) — Task 8
- ✅ SpottingRaceTileView: 8 visual states, rarity dots, fuse bar, stamp, undo chip — Task 9
- ✅ SpottingRaceView: 3×2 grid, countdown timer, sidebar scores, toast — Task 10
- ✅ opponentClaim ToastStyle — Task 3
- ✅ WinView: solo breakdown (tiles claimed, rarity score, multiplier, PB) — Task 11
- ✅ WinView: multiplayer scores side-by-side, winner highlighted — Task 11
- ✅ WinView: "Continue →" → PlayAgainView (same flow as Bingo) — Task 11
- ✅ Play Again for Spotting Race goes through requestPlayAgainSpottingRace — Task 5
- ✅ pbxproj registration for all 5 new files — Task 12
- ✅ Tests: rarity scoring, tile model, all 5 message roundtrips, legacy decode — Task 13

**No placeholders found.**

**Type consistency check:**
- `SpottingRaceTile.id: UUID` (slot) / `SpottingRaceTile.square.id: UUID` (tile) — used correctly throughout; `replaceSpottingSlot` keeps `id: slotID` stable ✅
- `tapSpottingTile(slotID:)`, `undoSpottingClaim(slotID:)` — match delegate cases that use `slotID: UUID` ✅
- `lastSoloTokens` repurposed as "tiles claimed count" in Spotting Race solo win screen — noted in Task 11 ✅
- `startSpottingRaceGame()` calls `resetSpottingRound()` then sets `opponentSpottingScores` — order is correct (reset clears it first) ✅

---

**Plan complete and saved to `docs/superpowers/plans/2026-06-03-spotting-race.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session with checkpoints

Which approach?
