# Token & Power-Up System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token economy and four power-up types that let players earn coins for in-game achievements and spend them on strategic advantages.

**Architecture:** New `PowerUpType` model; `BingoBoard` and `GameEngine` gain helper methods for power-up effects; `MultipeerMessage` gets three new cases; `AppState` gains token state, earning triggers, and power-up activation; three new SwiftUI views handle the strip UI, targeting overlay, and earning toast; `GameView` is updated with an orientation-aware layout.

**Tech Stack:** SwiftUI, MultipeerConnectivity, existing AppState/ObservableObject/EnvironmentObject pattern, xcodegen (run `xcodegen generate` from project root after adding any new Swift file)

---

## File Map

**Create:**
- `RoadTripBingo/Models/PowerUpType.swift`
- `RoadTripBingo/Views/PowerUpStripView.swift`
- `RoadTripBingo/Views/TargetingOverlayView.swift`
- `RoadTripBingo/Views/TokenToastView.swift`
- `RoadTripBingoTests/PowerUpTypeTests.swift`

**Modify:**
- `RoadTripBingo/Models/BingoBoard.swift` — add `mark`, `unmark`, `replaceSquare`; change `let squares` to `var squares`
- `RoadTripBingo/Game/GameEngine.swift` — add `closeCallLines`, `completedLines`
- `RoadTripBingo/Models/MultipeerMessage.swift` — add `tokenEarned`, `powerUpUsed`, `reserveDealt`
- `RoadTripBingo/Game/SquarePool.swift` — add `dealReserve`; make `targetCounts` accept a `total` param
- `RoadTripBingo/State/AppState.swift` — token state, earning, opponent board storage, power-up activation
- `RoadTripBingo/Views/GameView.swift` — orientation-aware layout, integrate strip + overlay + toast
- `RoadTripBingo/Views/OpponentStripView.swift` — show token balances
- `RoadTripBingoTests/BingoBoardTests.swift` — new tests
- `RoadTripBingoTests/GameEngineTests.swift` — new tests
- `RoadTripBingoTests/MultipeerMessageTests.swift` — new tests
- `RoadTripBingoTests/SquarePoolTests.swift` — new tests

---

## Task 1: PowerUpType model

**Files:**
- Create: `RoadTripBingo/Models/PowerUpType.swift`
- Create: `RoadTripBingoTests/PowerUpTypeTests.swift`

- [ ] **Step 1: Write the failing tests**

Add `RoadTripBingoTests/PowerUpTypeTests.swift`:

```swift
import XCTest
@testable import RoadTripBingo

final class PowerUpTypeTests: XCTestCase {

    func test_cost_upgradeTileRandom() { XCTAssertEqual(PowerUpType.upgradeTileRandom.cost, 3) }
    func test_cost_upgradeTileTargeted() { XCTAssertEqual(PowerUpType.upgradeTileTargeted.cost, 7) }
    func test_cost_downgradeTileRandom() { XCTAssertEqual(PowerUpType.downgradeTileRandom.cost, 3) }
    func test_cost_downgradeTileTargeted() { XCTAssertEqual(PowerUpType.downgradeTileTargeted.cost, 7) }
    func test_cost_freeMark() { XCTAssertEqual(PowerUpType.freeMark.cost, 5) }
    func test_cost_unmarkOpponentRandom() { XCTAssertEqual(PowerUpType.unmarkOpponentRandom.cost, 4) }
    func test_cost_unmarkOpponentTargeted() { XCTAssertEqual(PowerUpType.unmarkOpponentTargeted.cost, 7) }

    func test_isTargeted_freeMark() { XCTAssertTrue(PowerUpType.freeMark.isTargeted) }
    func test_isTargeted_upgradeTileTargeted() { XCTAssertTrue(PowerUpType.upgradeTileTargeted.isTargeted) }
    func test_isTargeted_upgradeTileRandom() { XCTAssertFalse(PowerUpType.upgradeTileRandom.isTargeted) }

    func test_affectsOpponent_downgradeTileRandom() { XCTAssertTrue(PowerUpType.downgradeTileRandom.affectsOpponent) }
    func test_affectsOpponent_unmarkOpponentTargeted() { XCTAssertTrue(PowerUpType.unmarkOpponentTargeted.affectsOpponent) }
    func test_affectsOpponent_upgradeTileRandom() { XCTAssertFalse(PowerUpType.upgradeTileRandom.affectsOpponent) }
    func test_affectsOpponent_freeMark() { XCTAssertFalse(PowerUpType.freeMark.affectsOpponent) }

    func test_codable_roundtrip() throws {
        for type in PowerUpType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(PowerUpType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }
}
```

- [ ] **Step 2: Run tests — expect build failure (type not defined)**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build FAILED)'
```

Expected: `error: cannot find type 'PowerUpType'`

- [ ] **Step 3: Create PowerUpType.swift**

```swift
import Foundation

enum PowerUpType: String, Codable, CaseIterable {
    case upgradeTileRandom
    case upgradeTileTargeted
    case downgradeTileRandom
    case downgradeTileTargeted
    case freeMark
    case unmarkOpponentRandom
    case unmarkOpponentTargeted

    var cost: Int {
        switch self {
        case .upgradeTileRandom, .downgradeTileRandom:                              return 3
        case .unmarkOpponentRandom:                                                 return 4
        case .freeMark:                                                             return 5
        case .upgradeTileTargeted, .downgradeTileTargeted, .unmarkOpponentTargeted: return 7
        }
    }

    var isTargeted: Bool {
        switch self {
        case .upgradeTileTargeted, .downgradeTileTargeted,
             .freeMark, .unmarkOpponentTargeted: return true
        default: return false
        }
    }

    var affectsOpponent: Bool {
        switch self {
        case .downgradeTileRandom, .downgradeTileTargeted,
             .unmarkOpponentRandom, .unmarkOpponentTargeted: return true
        default: return false
        }
    }

    // Emoji for the power-up category (same for random and targeted variants).
    var emoji: String {
        switch self {
        case .upgradeTileRandom, .upgradeTileTargeted:       return "🔀"
        case .downgradeTileRandom, .downgradeTileTargeted:   return "💣"
        case .freeMark:                                       return "✅"
        case .unmarkOpponentRandom, .unmarkOpponentTargeted: return "💥"
        }
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

Expected: `Test Suite 'PowerUpTypeTests' passed`

- [ ] **Step 5: Run xcodegen, then commit**

```bash
xcodegen generate
git add RoadTripBingo/Models/PowerUpType.swift RoadTripBingoTests/PowerUpTypeTests.swift
git commit -m "feat: add PowerUpType model with cost, isTargeted, affectsOpponent"
```

---

## Task 2: BingoBoard — mark, unmark, replaceSquare

**Files:**
- Modify: `RoadTripBingo/Models/BingoBoard.swift`
- Modify: `RoadTripBingoTests/BingoBoardTests.swift`

Context: `BingoBoard` currently has `let squares` (immutable). Changing it to `var` is required to support tile replacement. The `marked: Set<UUID>` already exists.

- [ ] **Step 1: Write the failing tests**

Append to `RoadTripBingoTests/BingoBoardTests.swift` (after existing tests):

```swift
    // MARK: - mark / unmark

    func test_mark_marksTile() {
        var board = makeBoard()
        board.mark(at: 0)
        XCTAssertTrue(board.isMarked(at: 0))
    }

    func test_mark_isIdempotent() {
        var board = makeBoard()
        board.mark(at: 0)
        board.mark(at: 0)
        XCTAssertTrue(board.isMarked(at: 0))
    }

    func test_unmark_unmarksTile() {
        var board = makeBoard()
        board.toggle(at: 0)
        board.unmark(at: 0)
        XCTAssertFalse(board.isMarked(at: 0))
    }

    func test_unmark_ignoresFreeSquare() {
        var board = makeBoard()
        board.unmark(at: 12)
        XCTAssertTrue(board.isMarked(at: 12))
    }

    // MARK: - replaceSquare

    func test_replaceSquare_changesContent() {
        var board = makeBoard()
        let newSquare = BingoSquare(id: UUID(), text: "New", emoji: "⭐", category: .vehicles, rarity: .rare)
        board.replaceSquare(at: 0, with: newSquare)
        XCTAssertEqual(board.squares[0].text, "New")
    }

    func test_replaceSquare_unmarksOldTile() {
        var board = makeBoard()
        board.toggle(at: 0)
        XCTAssertTrue(board.isMarked(at: 0))
        let newSquare = BingoSquare(id: UUID(), text: "New", emoji: "⭐", category: .vehicles, rarity: .rare)
        board.replaceSquare(at: 0, with: newSquare)
        XCTAssertFalse(board.isMarked(at: 0))
    }

    func test_replaceSquare_doesNotAffectFreeSquare() {
        var board = makeBoard()
        let oldID = board.squares[12].id
        let newSquare = BingoSquare(id: UUID(), text: "Not Free", emoji: "❌", category: .vehicles, rarity: .common)
        board.replaceSquare(at: 12, with: newSquare)
        XCTAssertEqual(board.squares[12].id, oldID)
    }
```

- [ ] **Step 2: Run tests — expect build failure**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build FAILED)'
```

Expected: `error: value of type 'BingoBoard' has no member 'mark'`

- [ ] **Step 3: Update BingoBoard.swift**

Replace the entire file:

```swift
import Foundation

struct BingoBoard {
    // 25 squares row-major. Index 12 must always be BingoSquare.free.
    var squares: [BingoSquare]   // var (was let) to support tile replacement
    var marked: Set<UUID>

    init(squares: [BingoSquare]) {
        precondition(squares.count == 25, "Board must have exactly 25 squares")
        precondition(squares[12].id == BingoSquare.freeSquareID, "Index 12 must be the FREE square")
        self.squares = squares
        self.marked = [BingoSquare.freeSquareID]
    }

    mutating func toggle(at position: Int) {
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
    }

    // Force-marks a square without toggling. No-op on the FREE square.
    mutating func mark(at position: Int) {
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.insert(id)
    }

    // Force-unmarks a square. No-op on the FREE square.
    mutating func unmark(at position: Int) {
        let id = squares[position].id
        guard id != BingoSquare.freeSquareID else { return }
        marked.remove(id)
    }

    // Replaces the tile at position with newSquare, clearing its old mark.
    // No-op if position 12 (the FREE square must not be replaced).
    mutating func replaceSquare(at position: Int, with newSquare: BingoSquare) {
        guard position != 12 else { return }
        let oldID = squares[position].id
        marked.remove(oldID)
        squares[position] = newSquare
    }

    func isMarked(at position: Int) -> Bool {
        marked.contains(squares[position].id)
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

Expected: `Test Suite 'BingoBoardTests' passed`

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Models/BingoBoard.swift RoadTripBingoTests/BingoBoardTests.swift
git commit -m "feat: add mark, unmark, replaceSquare to BingoBoard"
```

---

## Task 3: GameEngine — closeCallLines and completedLines

**Files:**
- Modify: `RoadTripBingo/Game/GameEngine.swift`
- Modify: `RoadTripBingoTests/GameEngineTests.swift`

Context: `GameEngine.winLines` contains all 12 win lines (5 rows + 5 cols + 2 diags). `winningLine(for:)` already returns the first completed line. `closeCallLines` returns lines with exactly 4 marked; `completedLines` returns all fully-marked lines (needed to award the 2🪙 pattern bonus without double-counting).

- [ ] **Step 1: Write the failing tests**

Append to `RoadTripBingoTests/GameEngineTests.swift`:

```swift
    // MARK: - closeCallLines

    func test_closeCallLines_emptyBoardReturnsNone() {
        let board = makeBoard()
        XCTAssertTrue(GameEngine.closeCallLines(for: board).isEmpty)
    }

    func test_closeCallLines_detectsFourInARow() {
        var board = makeBoard()
        // Mark row 0 positions 0–3 (not 4)
        for i in [0, 1, 2, 3] { board.toggle(at: i) }
        let lines = GameEngine.closeCallLines(for: board)
        XCTAssertTrue(lines.contains([0, 1, 2, 3, 4]))
    }

    func test_closeCallLines_excludesCompleteLines() {
        var board = makeBoard()
        for i in 0..<5 { board.toggle(at: i) }    // complete row 0
        let lines = GameEngine.closeCallLines(for: board)
        XCTAssertFalse(lines.contains([0, 1, 2, 3, 4]))
    }

    // MARK: - completedLines

    func test_completedLines_emptyBoardReturnsNone() {
        let board = makeBoard()
        XCTAssertTrue(GameEngine.completedLines(for: board).isEmpty)
    }

    func test_completedLines_returnsAllCompleteLines() {
        var board = makeBoard()
        for i in 0..<5 { board.toggle(at: i) }       // complete row 0
        for i in [0, 5, 10, 15, 20] { board.toggle(at: i) }  // complete col 0 (pos 0 already marked)
        let lines = GameEngine.completedLines(for: board)
        XCTAssertEqual(lines.count, 2)
    }
```

The existing `makeBoard()` helper in `GameEngineTests.swift` builds a board from 25 unique squares; reuse it.

- [ ] **Step 2: Run tests — expect failure**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build FAILED)'
```

Expected: `error: type 'GameEngine' has no member 'closeCallLines'`

- [ ] **Step 3: Add methods to GameEngine.swift**

Append inside `enum GameEngine { ... }` after `winningLine`:

```swift
    static func closeCallLines(for board: BingoBoard) -> [[Int]] {
        winLines.filter { line in
            line.filter { board.isMarked(at: $0) }.count == 4
        }
    }

    static func completedLines(for board: BingoBoard) -> [[Int]] {
        winLines.filter { $0.allSatisfy { board.isMarked(at: $0) } }
    }
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Game/GameEngine.swift RoadTripBingoTests/GameEngineTests.swift
git commit -m "feat: add closeCallLines and completedLines to GameEngine"
```

---

## Task 4: MultipeerMessage — tokenEarned, powerUpUsed, reserveDealt

**Files:**
- Modify: `RoadTripBingo/Models/MultipeerMessage.swift`
- Modify: `RoadTripBingoTests/MultipeerMessageTests.swift`

Context: `MultipeerMessage` uses a manual `Codable` implementation with a `type` discriminator. Follow the exact same pattern as existing cases. New CodingKeys needed: `newBalance`, `powerUp`, `targetPlayer`, `targetIndex`, `replacementSquare`, `toName`, `squares`.

- [ ] **Step 1: Write the failing tests**

Append to `RoadTripBingoTests/MultipeerMessageTests.swift`:

```swift
    func test_tokenEarned_roundtrip() throws {
        let msg = MultipeerMessage.tokenEarned(byName: "Zoe", newBalance: 12)
        let decoded = try roundtrip(msg)
        guard case .tokenEarned(let name, let balance) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(name, "Zoe")
        XCTAssertEqual(balance, 12)
    }

    func test_powerUpUsed_roundtrip_withAllFields() throws {
        let square = BingoSquare(id: UUID(), text: "Cow", emoji: "🐄", category: .nature, rarity: .veryCommon)
        let msg = MultipeerMessage.powerUpUsed(
            byName: "Liam",
            powerUp: .upgradeTileTargeted,
            targetPlayer: nil,
            targetIndex: 5,
            replacementSquare: square
        )
        let decoded = try roundtrip(msg)
        guard case .powerUpUsed(let name, let powerUp, let tp, let ti, let rs) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(name, "Liam")
        XCTAssertEqual(powerUp, .upgradeTileTargeted)
        XCTAssertNil(tp)
        XCTAssertEqual(ti, 5)
        XCTAssertEqual(rs?.text, "Cow")
    }

    func test_powerUpUsed_roundtrip_nilFields() throws {
        let msg = MultipeerMessage.powerUpUsed(
            byName: "Liam",
            powerUp: .unmarkOpponentRandom,
            targetPlayer: "Zoe",
            targetIndex: 3,
            replacementSquare: nil
        )
        let decoded = try roundtrip(msg)
        guard case .powerUpUsed(_, _, let tp, let ti, let rs) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(tp, "Zoe")
        XCTAssertEqual(ti, 3)
        XCTAssertNil(rs)
    }

    func test_reserveDealt_roundtrip() throws {
        let square = BingoSquare(id: UUID(), text: "Barn", emoji: "🏚️", category: .nature, rarity: .common)
        let msg = MultipeerMessage.reserveDealt(toName: "Liam", squares: [square])
        let decoded = try roundtrip(msg)
        guard case .reserveDealt(let name, let squares) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(name, "Liam")
        XCTAssertEqual(squares.first?.text, "Barn")
    }
```

- [ ] **Step 2: Run tests — expect build failure**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build FAILED)'
```

- [ ] **Step 3: Replace MultipeerMessage.swift**

```swift
import Foundation

enum MultipeerMessage: Codable {
    case gameStarted(boards: [String: [BingoSquare]])
    case squareToggled(position: Int, isMarked: Bool)
    case bingoAnnounced(byName: String)
    case playAgain(boards: [String: [BingoSquare]])
    case difficultyChosen(byName: String, difficulty: BoardDifficulty)
    case tokenEarned(byName: String, newBalance: Int)
    case powerUpUsed(byName: String, powerUp: PowerUpType, targetPlayer: String?,
                     targetIndex: Int?, replacementSquare: BingoSquare?)
    case reserveDealt(toName: String, squares: [BingoSquare])

    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName, difficulty
        case newBalance, powerUp, targetPlayer, targetIndex, replacementSquare
        case toName, squares
    }

    private enum MessageType: String, Codable {
        case gameStarted, squareToggled, bingoAnnounced, playAgain, difficultyChosen
        case tokenEarned, powerUpUsed, reserveDealt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gameStarted(let boards):
            try c.encode(MessageType.gameStarted, forKey: .type)
            try c.encode(boards, forKey: .boards)
        case .squareToggled(let position, let isMarked):
            try c.encode(MessageType.squareToggled, forKey: .type)
            try c.encode(position, forKey: .position)
            try c.encode(isMarked, forKey: .isMarked)
        case .bingoAnnounced(let byName):
            try c.encode(MessageType.bingoAnnounced, forKey: .type)
            try c.encode(byName, forKey: .byName)
        case .playAgain(let boards):
            try c.encode(MessageType.playAgain, forKey: .type)
            try c.encode(boards, forKey: .boards)
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
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(MessageType.self, forKey: .type)
        switch type {
        case .gameStarted:
            self = .gameStarted(boards: try c.decode([String: [BingoSquare]].self, forKey: .boards))
        case .squareToggled:
            self = .squareToggled(
                position: try c.decode(Int.self, forKey: .position),
                isMarked: try c.decode(Bool.self, forKey: .isMarked))
        case .bingoAnnounced:
            self = .bingoAnnounced(byName: try c.decode(String.self, forKey: .byName))
        case .playAgain:
            self = .playAgain(boards: try c.decode([String: [BingoSquare]].self, forKey: .boards))
        case .difficultyChosen:
            self = .difficultyChosen(
                byName: try c.decode(String.self, forKey: .byName),
                difficulty: try c.decode(BoardDifficulty.self, forKey: .difficulty))
        case .tokenEarned:
            self = .tokenEarned(
                byName: try c.decode(String.self, forKey: .byName),
                newBalance: try c.decode(Int.self, forKey: .newBalance))
        case .powerUpUsed:
            self = .powerUpUsed(
                byName: try c.decode(String.self, forKey: .byName),
                powerUp: try c.decode(PowerUpType.self, forKey: .powerUp),
                targetPlayer: try c.decodeIfPresent(String.self, forKey: .targetPlayer),
                targetIndex: try c.decodeIfPresent(Int.self, forKey: .targetIndex),
                replacementSquare: try c.decodeIfPresent(BingoSquare.self, forKey: .replacementSquare))
        case .reserveDealt:
            self = .reserveDealt(
                toName: try c.decode(String.self, forKey: .toName),
                squares: try c.decode([BingoSquare].self, forKey: .squares))
        }
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Models/MultipeerMessage.swift RoadTripBingoTests/MultipeerMessageTests.swift
git commit -m "feat: add tokenEarned, powerUpUsed, reserveDealt message cases"
```

---

## Task 5: SquarePool — dealReserve

**Files:**
- Modify: `RoadTripBingo/Game/SquarePool.swift`
- Modify: `RoadTripBingoTests/SquarePoolTests.swift`

Context: `dealReserve` deals `count` extra squares per player from the portion of the pool not already dealt. The caller passes the dealt boards so `dealReserve` can exclude those IDs. The existing `targetCounts` needs a `total` parameter (default 24) so it can also size reserve draws.

- [ ] **Step 1: Write the failing tests**

Append to `RoadTripBingoTests/SquarePoolTests.swift`:

```swift
    func test_dealReserve_returnsCorrectCountPerPlayer() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        XCTAssertEqual(reserve["A"]?.count, 6)
        XCTAssertEqual(reserve["B"]?.count, 6)
    }

    func test_dealReserve_noOverlapWithDealtBoards() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.shotgun)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        let reserveIDs = Set(reserve["A"]!.map(\.id))
        XCTAssertTrue(reserveIDs.isDisjoint(with: usedIDs))
    }
```

- [ ] **Step 2: Run tests — expect failure**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build FAILED)'
```

- [ ] **Step 3: Update SquarePool.swift**

Replace the entire file:

```swift
import Foundation

enum SquarePool {
    static func load() -> [BingoSquare] {
        guard let url = Bundle.main.url(forResource: "squares", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let squares = try? JSONDecoder().decode([BingoSquare].self, from: data)
        else { fatalError("squares.json missing from bundle or malformed") }
        return squares
    }

    // Returns one 25-element array per player (index 12 = FREE).
    static func dealBoards(
        for players: [(name: String, difficulty: BoardDifficulty)],
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        precondition(pool.count >= players.count * 24)
        var queues = makeQueues(from: pool)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            result[player.name] = drawBoard(for: player.difficulty, from: &queues)
        }
        return result
    }

    // Returns `count` extra squares per player, drawn from pool minus usedIDs.
    // Used to deal each player's power-up reserve hand at game start.
    static func dealReserve(
        for players: [(name: String, difficulty: BoardDifficulty)],
        count: Int,
        excluding usedIDs: Set<UUID>,
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        let available = pool.filter { !usedIDs.contains($0.id) }
        var queues = makeQueues(from: available)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            result[player.name] = drawBoard(for: player.difficulty, from: &queues, total: count)
        }
        return result
    }

    // MARK: - Private helpers

    private static func makeQueues(from pool: [BingoSquare]) -> [SquareRarity: [BingoSquare]] {
        var queues: [SquareRarity: [BingoSquare]] = [:]
        for rarity in SquareRarity.allCases {
            queues[rarity] = pool.filter { $0.rarity == rarity }.shuffled()
        }
        return queues
    }

    private static func drawBoard(
        for difficulty: BoardDifficulty,
        from queues: inout [SquareRarity: [BingoSquare]],
        total: Int = 24
    ) -> [BingoSquare] {
        let targets = targetCounts(for: difficulty, total: total)
        var squares: [BingoSquare] = []
        for rarity in SquareRarity.allCases {
            squares += draw(targets[rarity, default: 0], from: &queues[rarity]!)
        }
        if squares.count < total {
            var spill = SquareRarity.allCases.flatMap { queues[$0]! }.shuffled()
            let extra = draw(total - squares.count, from: &spill)
            let extraIDs = Set(extra.map(\.id))
            for rarity in SquareRarity.allCases {
                queues[rarity]!.removeAll { extraIDs.contains($0.id) }
            }
            squares += extra
        }
        if total == 24 {
            squares.shuffle()
            squares.insert(.free, at: 12)
        }
        return squares
    }

    private static func draw(_ count: Int, from bucket: inout [BingoSquare]) -> [BingoSquare] {
        let actual = min(count, bucket.count)
        let drawn = Array(bucket.prefix(actual))
        bucket.removeFirst(actual)
        return drawn
    }

    private static func targetCounts(for difficulty: BoardDifficulty, total: Int = 24) -> [SquareRarity: Int] {
        let tiers = SquareRarity.allCases
        var counts: [SquareRarity: Int] = [:]
        var running = 0
        for (i, rarity) in tiers.enumerated() {
            if i == tiers.count - 1 {
                counts[rarity] = total - running
                break
            }
            let n = Int((Double(total) * difficulty.weights[rarity, default: 0]).rounded())
            counts[rarity] = n
            running += n
        }
        return counts
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Game/SquarePool.swift RoadTripBingoTests/SquarePoolTests.swift
git commit -m "feat: add dealReserve to SquarePool; extract shared drawBoard helper"
```

---

## Task 6: AppState — token state, earning, opponent boards, reserve

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

Context: This task adds the data layer only — no power-up activation yet (Task 7). Key changes:
1. New `@Published` token and opponent board properties
2. `earnTokens(_:)` — self-reports balance change to all peers
3. `resetRound()` — clears per-round achievement guards
4. `startGame()` and `requestPlayAgain()` — deal reserve, store opponent boards, award round-start tokens (host)
5. `toggleSquare()` — first-mark, close-call, and pattern-complete bonuses
6. `callBingo()` — win bonus
7. `goHome()` — full state reset
8. Delegate — handle `tokenEarned`, `reserveDealt`; store opponent boards on `gameStarted`/`playAgain`; award round-start tokens (joiner)

- [ ] **Step 1: Replace AppState.swift**

```swift
import Foundation
import SwiftUI

enum AppScreen: Equatable {
    case home
    case lobby
    case game
    case win(winnerName: String)
    case playAgain
}

final class AppState: ObservableObject, MultipeerSessionDelegate {

    // MARK: - Navigation
    @Published var screen: AppScreen = .home

    // MARK: - Identity
    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: "playerName") }
    }

    // MARK: - Lobby
    @Published var isHost = false
    @Published var connectedPlayerNames: [String] = []
    @Published var foundGameNames: [String] = []
    @Published var playerDifficulty: BoardDifficulty = .backseat
    @Published var playerDifficulties: [String: BoardDifficulty] = [:]

    // MARK: - Game
    @Published var localBoard: BingoBoard?
    @Published var completedLine: [Int]?
    @Published var opponentMarked: [String: Set<Int>] = [:]
    var opponentBoards: [String: [BingoSquare]] = [:]
    var reserveSquares: [BingoSquare] = []

    // MARK: - Tokens
    @Published var tokenBalance: Int = 0
    @Published var tokenBalances: [String: Int] = [:]
    @Published var pendingToastMessage: String? = nil   // consumed by GameView to show toast

    // MARK: - Achievement guards (reset each round)
    private var firstMarkClaimedThisRound = false
    private var patternsAwardedThisRound: Set<String> = []
    private var closeCallsAwardedThisRound: Set<String> = []

    // MARK: - Post-game
    @Published var winHistory: [String: Int] = [:]

    // MARK: - Network
    private(set) var multipeerSession: MultipeerSession?

    init() {
        self.playerName = UserDefaults.standard.string(forKey: "playerName") ?? ""
    }

    // MARK: - Home actions

    func createGame() {
        isHost = true
        connectedPlayerNames = []
        let session = MultipeerSession(displayName: playerName)
        session.delegate = self
        session.startAdvertising()
        multipeerSession = session
        screen = .lobby
    }

    func joinGame() {
        isHost = false
        foundGameNames = []
        let session = MultipeerSession(displayName: playerName)
        session.delegate = self
        session.startBrowsing()
        multipeerSession = session
        screen = .lobby
    }

    func inviteGame(named name: String) {
        multipeerSession?.invitePeer(named: name)
    }

    func chooseDifficulty(_ difficulty: BoardDifficulty) {
        playerDifficulty = difficulty
        if !isHost {
            multipeerSession?.send(.difficultyChosen(byName: playerName, difficulty: difficulty))
        }
    }

    func goHome() {
        multipeerSession?.disconnect()
        multipeerSession = nil
        connectedPlayerNames = []
        foundGameNames = []
        localBoard = nil
        completedLine = nil
        opponentMarked = [:]
        opponentBoards = [:]
        reserveSquares = []
        isHost = false
        playerDifficulty = .backseat
        playerDifficulties = [:]
        tokenBalance = 0
        tokenBalances = [:]
        pendingToastMessage = nil
        resetRound()
        // winHistory intentionally preserved
        screen = .home
    }

    // MARK: - Lobby (host only)

    func startGame() {
        guard isHost else { return }
        let pool = SquarePool.load()
        let allNames = [playerName] + connectedPlayerNames
        let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
            let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
            return (name: name, difficulty: diff)
        }
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)

        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }
        opponentBoards = [:]
        opponentMarked = [:]
        for name in connectedPlayerNames {
            opponentBoards[name] = boards[name]
            opponentMarked[name] = [12]
        }
        reserveSquares = reserve[playerName] ?? []
        completedLine = nil
        resetRound()

        multipeerSession?.stopAdvertising()
        multipeerSession?.send(.gameStarted(boards: boards))
        for name in connectedPlayerNames {
            multipeerSession?.send(.reserveDealt(toName: name, squares: reserve[name] ?? []))
        }

        earnTokens(2)  // round-start bonus for host
        screen = .game
    }

    // MARK: - Game actions

    func toggleSquare(at position: Int) {
        guard screen == .game else { return }
        let wasMarked = localBoard?.isMarked(at: position) ?? false
        localBoard?.toggle(at: position)
        let isNowMarked = localBoard?.isMarked(at: position) ?? false
        multipeerSession?.send(.squareToggled(position: position, isMarked: isNowMarked))

        guard let board = localBoard else { return }

        if isNowMarked && !wasMarked && !firstMarkClaimedThisRound {
            firstMarkClaimedThisRound = true
            earnTokens(1)
        }

        completedLine = GameEngine.winningLine(for: board)
        checkBonuses(for: board)
    }

    func callBingo() {
        guard completedLine != nil else { return }
        earnTokens(5)   // win bonus
        multipeerSession?.send(.bingoAnnounced(byName: playerName))
        winHistory[playerName, default: 0] += 1
        screen = .win(winnerName: playerName)
    }

    func requestPlayAgain() {
        guard isHost else { return }
        let pool = SquarePool.load()
        let allNames = [playerName] + connectedPlayerNames
        let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
            let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
            return (name: name, difficulty: diff)
        }
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)

        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }
        opponentBoards = [:]
        opponentMarked = [:]
        for name in connectedPlayerNames {
            opponentBoards[name] = boards[name]
            opponentMarked[name] = [12]
        }
        reserveSquares = reserve[playerName] ?? []
        completedLine = nil
        resetRound()

        multipeerSession?.send(.playAgain(boards: boards))
        for name in connectedPlayerNames {
            multipeerSession?.send(.reserveDealt(toName: name, squares: reserve[name] ?? []))
        }

        earnTokens(2)  // round-start bonus for host
        screen = .game
    }

    // MARK: - Token helpers

    func earnTokens(_ amount: Int) {
        tokenBalance += amount
        pendingToastMessage = "+\(amount)🪙"
        multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
    }

    private func resetRound() {
        firstMarkClaimedThisRound = false
        patternsAwardedThisRound = []
        closeCallsAwardedThisRound = []
    }

    private func checkBonuses(for board: BingoBoard) {
        for line in GameEngine.closeCallLines(for: board) {
            let id = line.map(String.init).joined(separator: ",")
            if !closeCallsAwardedThisRound.contains(id) {
                closeCallsAwardedThisRound.insert(id)
                earnTokens(3)
            }
        }
        for line in GameEngine.completedLines(for: board) {
            let id = line.map(String.init).joined(separator: ",")
            if !patternsAwardedThisRound.contains(id) {
                patternsAwardedThisRound.insert(id)
                earnTokens(2)
            }
        }
    }

    // MARK: - MultipeerSessionDelegate

    func multipeerSession(_ session: MultipeerSession, didReceive message: MultipeerMessage, from peerName: String) {
        switch message {
        case .gameStarted(let boards):
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentBoards = [:]
            opponentMarked = [:]
            for (name, squares) in boards where name != playerName {
                opponentBoards[name] = squares
                opponentMarked[name] = [12]
            }
            completedLine = nil
            resetRound()
            multipeerSession?.stopBrowsing()
            earnTokens(2)   // round-start bonus for joiner
            screen = .game

        case .squareToggled(let position, let isMarked):
            var current = opponentMarked[peerName] ?? []
            if isMarked { current.insert(position) } else { current.remove(position) }
            opponentMarked[peerName] = current

        case .bingoAnnounced(let byName):
            winHistory[byName, default: 0] += 1
            screen = .win(winnerName: byName)

        case .playAgain(let boards):
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentBoards = [:]
            opponentMarked = [:]
            for (name, squares) in boards where name != playerName {
                opponentBoards[name] = squares
                opponentMarked[name] = [12]
            }
            completedLine = nil
            resetRound()
            earnTokens(2)   // round-start bonus for joiner
            screen = .game

        case .difficultyChosen(let byName, let difficulty):
            if isHost { playerDifficulties[byName] = difficulty }

        case .tokenEarned(let byName, let newBalance):
            tokenBalances[byName] = newBalance

        case .reserveDealt(let toName, let squares):
            if toName == playerName { reserveSquares = squares }

        case .powerUpUsed:
            break  // handled in Task 7
        }
    }

    func multipeerSession(_ session: MultipeerSession, peerDidConnect peerName: String) {
        if !connectedPlayerNames.contains(peerName) {
            connectedPlayerNames.append(peerName)
        }
    }

    func multipeerSession(_ session: MultipeerSession, peerDidDisconnect peerName: String) {
        connectedPlayerNames.removeAll { $0 == peerName }
        opponentMarked.removeValue(forKey: peerName)
        opponentBoards.removeValue(forKey: peerName)
    }

    func multipeerSession(_ session: MultipeerSession, foundPeer peerName: String) {
        if !foundGameNames.contains(peerName) { foundGameNames.append(peerName) }
    }

    func multipeerSession(_ session: MultipeerSession, lostPeer peerName: String) {
        foundGameNames.removeAll { $0 == peerName }
    }
}
```

- [ ] **Step 2: Build to confirm no compile errors**

```bash
xcodebuild build -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build succeeded|Build FAILED)'
```

Expected: `Build succeeded`

- [ ] **Step 3: Run tests — all existing tests should still pass**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: add token state, earning, opponent boards and reserve to AppState"
```

---

## Task 7: AppState — power-up activation and effect handling

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

Context: This adds `activatePowerUp` (called from the UI), private target-picking helpers, `applyPowerUpEffect` (called locally and from the delegate), and the `powerUpUsed` delegate handler. All peers receive `powerUpUsed` and apply the effect themselves using `applyPowerUpEffect`.

- [ ] **Step 1: Append to AppState.swift — power-up activation**

Add the following methods inside `AppState`, below `earnTokens`:

```swift
    // MARK: - Power-up activation

    func activatePowerUp(_ powerUp: PowerUpType, targetPlayer: String? = nil, targetIndex: Int? = nil) {
        guard tokenBalance >= powerUp.cost, localBoard != nil else { return }

        var resolvedTargetPlayer = targetPlayer
        var resolvedTargetIndex = targetIndex
        var replacementSquare: BingoSquare? = nil

        switch powerUp {
        case .upgradeTileRandom:
            resolvedTargetIndex = highestRarityIndex(on: localBoard!)
            replacementSquare = reserveSquares.isEmpty ? nil : reserveSquares.removeFirst()
        case .upgradeTileTargeted:
            replacementSquare = reserveSquares.isEmpty ? nil : reserveSquares.removeFirst()
        case .downgradeTileRandom:
            if let (name, idx) = lowestRarityOpponentTile() {
                resolvedTargetPlayer = name
                resolvedTargetIndex = idx
            }
            replacementSquare = reserveSquares.isEmpty ? nil : reserveSquares.removeFirst()
        case .downgradeTileTargeted:
            replacementSquare = reserveSquares.isEmpty ? nil : reserveSquares.removeFirst()
        case .freeMark:
            break  // targetIndex provided by caller
        case .unmarkOpponentRandom:
            if let (name, idx) = markedOpponentTile() {
                resolvedTargetPlayer = name
                resolvedTargetIndex = idx
            }
        case .unmarkOpponentTargeted:
            break  // targetPlayer and targetIndex provided by caller
        }

        guard resolvedTargetIndex != nil else { return }

        tokenBalance -= powerUp.cost
        multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))

        applyPowerUpEffect(powerUp, byName: playerName,
                           targetPlayer: resolvedTargetPlayer,
                           targetIndex: resolvedTargetIndex,
                           replacementSquare: replacementSquare)

        multipeerSession?.send(.powerUpUsed(byName: playerName, powerUp: powerUp,
                                            targetPlayer: resolvedTargetPlayer,
                                            targetIndex: resolvedTargetIndex,
                                            replacementSquare: replacementSquare))

        // Re-check win and bonus conditions after free mark
        if powerUp == .freeMark, let board = localBoard {
            completedLine = GameEngine.winningLine(for: board)
            checkBonuses(for: board)
        }
    }

    func applyPowerUpEffect(
        _ powerUp: PowerUpType,
        byName: String,
        targetPlayer: String?,
        targetIndex: Int?,
        replacementSquare: BingoSquare?
    ) {
        switch powerUp {
        case .upgradeTileRandom, .upgradeTileTargeted:
            guard let idx = targetIndex, let newSquare = replacementSquare else { return }
            if byName == playerName {
                localBoard?.replaceSquare(at: idx, with: newSquare)
            } else {
                opponentBoards[byName]?[idx] = newSquare
            }

        case .downgradeTileRandom, .downgradeTileTargeted:
            guard let target = targetPlayer, let idx = targetIndex,
                  let newSquare = replacementSquare else { return }
            if target == playerName {
                localBoard?.replaceSquare(at: idx, with: newSquare)
            } else {
                opponentBoards[target]?[idx] = newSquare
                opponentMarked[target]?.remove(idx)
            }

        case .freeMark:
            guard let idx = targetIndex else { return }
            if byName == playerName {
                localBoard?.mark(at: idx)
            } else {
                opponentMarked[byName]?.insert(idx)
            }

        case .unmarkOpponentRandom, .unmarkOpponentTargeted:
            guard let target = targetPlayer, let idx = targetIndex else { return }
            if target == playerName {
                localBoard?.unmark(at: idx)
            } else {
                opponentMarked[target]?.remove(idx)
            }
        }
    }

    // MARK: - Power-up target helpers

    private func highestRarityIndex(on board: BingoBoard) -> Int? {
        let rarityOrder: [SquareRarity] = [.veryRare, .rare, .uncommon, .common, .veryCommon]
        let candidates = (0..<25).filter {
            board.squares[$0].id != BingoSquare.freeSquareID && !board.isMarked(at: $0)
        }
        return candidates.min {
            let ra = rarityOrder.firstIndex(of: board.squares[$0].rarity) ?? 99
            let rb = rarityOrder.firstIndex(of: board.squares[$1].rarity) ?? 99
            return ra < rb
        }
    }

    private func lowestRarityOpponentTile() -> (String, Int)? {
        let rarityOrder: [SquareRarity] = [.veryCommon, .common, .uncommon, .rare, .veryRare]
        var best: (name: String, idx: Int, rank: Int)? = nil
        for (oppName, oppBoard) in opponentBoards {
            let marked = opponentMarked[oppName] ?? []
            for idx in 0..<25 {
                guard oppBoard[idx].id != BingoSquare.freeSquareID,
                      !marked.contains(idx) else { continue }
                let rank = rarityOrder.firstIndex(of: oppBoard[idx].rarity) ?? 99
                if best == nil || rank < best!.rank {
                    best = (oppName, idx, rank)
                }
            }
        }
        return best.map { ($0.name, $0.idx) }
    }

    private func markedOpponentTile() -> (String, Int)? {
        for oppName in opponentMarked.keys.sorted() {
            let marked = opponentMarked[oppName] ?? []
            if let idx = marked.filter({ $0 != 12 }).max() {
                return (oppName, idx)
            }
        }
        return nil
    }
```

- [ ] **Step 2: Add `powerUpUsed` case to the delegate switch**

Find the `case .powerUpUsed: break` line added in Task 6 and replace it:

```swift
        case .powerUpUsed(let byName, let powerUp, let targetPlayer, let targetIndex, let replacementSquare):
            applyPowerUpEffect(powerUp, byName: byName,
                               targetPlayer: targetPlayer,
                               targetIndex: targetIndex,
                               replacementSquare: replacementSquare)
```

- [ ] **Step 3: Build and run all tests**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

Expected: all suites pass.

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: add power-up activation and effect handling to AppState"
```

---

## Task 8: PowerUpStripView

**Files:**
- Create: `RoadTripBingo/Views/PowerUpStripView.swift`

Context: The strip shows 4 power-up buttons and the coin balance. Portrait: horizontal layout. Landscape: vertical layout (caller passes `isVertical: true`). Tap = random variant; long-press (0.4 s) = targeted variant callback. `freeMark` has no random variant — tap and long-press both call `onRequestTargeted`.

- [ ] **Step 1: Create PowerUpStripView.swift**

```swift
import SwiftUI

struct PowerUpStripView: View {
    let tokenBalance: Int
    let isVertical: Bool
    let onActivateRandom: (PowerUpType) -> Void
    let onRequestTargeted: (PowerUpType) -> Void

    private struct StripItem {
        let emoji: String
        let cost: Int
        let randomVariant: PowerUpType?      // nil = always targeted (freeMark)
        let targetedVariant: PowerUpType
    }

    private let items: [StripItem] = [
        StripItem(emoji: "🔀", cost: 3, randomVariant: .upgradeTileRandom,   targetedVariant: .upgradeTileTargeted),
        StripItem(emoji: "💣", cost: 3, randomVariant: .downgradeTileRandom, targetedVariant: .downgradeTileTargeted),
        StripItem(emoji: "✅", cost: 5, randomVariant: nil,                  targetedVariant: .freeMark),
        StripItem(emoji: "💥", cost: 4, randomVariant: .unmarkOpponentRandom, targetedVariant: .unmarkOpponentTargeted),
    ]

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

    @ViewBuilder private var buttons: some View {
        ForEach(items.indices, id: \.self) { i in
            let item = items[i]
            let canAfford = tokenBalance >= item.cost
            VStack(spacing: 2) {
                Text(item.emoji).font(.system(size: 22))
                Text("\(item.cost)🪙")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(Color.white.opacity(canAfford ? 0.12 : 0.04))
            .cornerRadius(8)
            .opacity(canAfford ? 1.0 : 0.4)
            .onTapGesture {
                guard canAfford else { return }
                if let random = item.randomVariant {
                    onActivateRandom(random)
                } else {
                    onRequestTargeted(item.targetedVariant)
                }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                guard canAfford else { return }
                onRequestTargeted(item.targetedVariant)
            }
        }
    }

    private var balanceBadge: some View {
        Text("🪙\(tokenBalance)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(8)
    }
}
```

- [ ] **Step 2: Run xcodegen, then build**

```bash
xcodegen generate
xcodebuild build -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build succeeded|Build FAILED)'
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/PowerUpStripView.swift
git commit -m "feat: add PowerUpStripView with tap/long-press activation"
```

---

## Task 9: TargetingOverlayView and TokenToastView

**Files:**
- Create: `RoadTripBingo/Views/TargetingOverlayView.swift`
- Create: `RoadTripBingo/Views/TokenToastView.swift`

Context: `TargetingOverlayView` slides up when a player long-presses a power-up button. For self-targeting it shows the player's own board; for opponent-targeting it shows a per-opponent tappable mini-grid. `TokenToastView` is a small yellow pill that appears when tokens are earned.

- [ ] **Step 1: Create TargetingOverlayView.swift**

```swift
import SwiftUI

struct TargetingOverlayView: View {
    let powerUp: PowerUpType
    let localBoard: BingoBoard?
    let opponentBoards: [String: [BingoSquare]]
    let opponentMarked: [String: Set<Int>]
    let onSelect: (_ targetPlayer: String?, _ targetIndex: Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 20) {
                Text("\(powerUp.emoji)  Select target  ·  \(powerUp.cost)🪙")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if powerUp.affectsOpponent {
                    opponentGrid
                } else {
                    selfGrid
                }

                Button("Cancel") { onCancel() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(24)
            .background(Color(red: 0.10, green: 0.14, blue: 0.22))
            .cornerRadius(20)
            .padding(20)
        }
    }

    // MARK: Self-targeting (upgrade tile, free mark)

    @ViewBuilder private var selfGrid: some View {
        if let board = localBoard {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(0..<25, id: \.self) { idx in
                    let square = board.squares[idx]
                    let isFree = square.id == BingoSquare.freeSquareID
                    let isMarked = board.isMarked(at: idx)
                    let selectable: Bool = {
                        guard !isFree else { return false }
                        return powerUp == .freeMark ? !isMarked : true
                    }()
                    TargetTileView(square: square, isMarked: isMarked, isSelectable: selectable) {
                        if selectable { onSelect(nil, idx) }
                    }
                }
            }
        }
    }

    // MARK: Opponent-targeting (downgrade, unmark)

    @ViewBuilder private var opponentGrid: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(opponentBoards.keys.sorted(), id: \.self) { oppName in
                    let oppBoard = opponentBoards[oppName] ?? []
                    let marked = opponentMarked[oppName] ?? []
                    VStack(spacing: 8) {
                        Text(oppName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                            ForEach(0..<min(oppBoard.count, 25), id: \.self) { idx in
                                let square = oppBoard[idx]
                                let isFree = square.id == BingoSquare.freeSquareID
                                let isMarked = marked.contains(idx)
                                let selectable: Bool = {
                                    guard !isFree else { return false }
                                    if powerUp == .downgradeTileTargeted { return !isMarked }
                                    if powerUp == .unmarkOpponentTargeted { return isMarked }
                                    return false
                                }()
                                TargetTileView(square: square, isMarked: isMarked, isSelectable: selectable) {
                                    if selectable { onSelect(oppName, idx) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TargetTileView: View {
    let square: BingoSquare
    let isMarked: Bool
    let isSelectable: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text(square.emoji).font(.system(size: 14))
            Text(square.text)
                .font(.system(size: 7, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            isMarked     ? Color.blue.opacity(0.35) :
            isSelectable ? Color.white.opacity(0.12) :
                           Color.white.opacity(0.03)
        )
        .cornerRadius(6)
        .overlay(
            isSelectable
                ? RoundedRectangle(cornerRadius: 6).stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                : nil
        )
        .opacity(isSelectable ? 1.0 : 0.35)
        .onTapGesture { onTap() }
    }
}
```

- [ ] **Step 2: Create TokenToastView.swift**

```swift
import SwiftUI

struct TokenToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color.yellow.opacity(0.95))
            .foregroundColor(.black)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.25), radius: 8)
    }
}
```

- [ ] **Step 3: Run xcodegen, then build**

```bash
xcodegen generate
xcodebuild build -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build succeeded|Build FAILED)'
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Views/TargetingOverlayView.swift RoadTripBingo/Views/TokenToastView.swift
git commit -m "feat: add TargetingOverlayView and TokenToastView"
```

---

## Task 10: GameView + OpponentStripView — layout, token HUD, overlay, toast

**Files:**
- Modify: `RoadTripBingo/Views/GameView.swift`
- Modify: `RoadTripBingo/Views/OpponentStripView.swift`

Context: `GameView` gains an orientation-aware layout: portrait keeps the strip below the grid; landscape moves it to a trailing sidebar. A `@State var targetingPowerUp` drives the targeting overlay. `@State var toastMessage` drives the toast (auto-dismissed after 1.5 s by observing `appState.pendingToastMessage`). `OpponentStripView` gains a `tokenBalances` parameter to show each opponent's coin count.

- [ ] **Step 1: Replace GameView.swift**

```swift
import SwiftUI

struct GameView: View {
    @EnvironmentObject var appState: AppState
    @State private var targetingPowerUp: PowerUpType? = nil
    @State private var toastMessage: String? = nil

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()

            if let board = appState.localBoard {
                GeometryReader { geo in
                    let landscape = geo.size.width > geo.size.height
                    if landscape {
                        landscapeLayout(board: board)
                    } else {
                        portraitLayout(board: board)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7),
                           value: appState.completedLine != nil)
            } else {
                ProgressView("Setting up board…").tint(.white)
            }

            // Targeting overlay
            if let powerUp = targetingPowerUp {
                TargetingOverlayView(
                    powerUp: powerUp,
                    localBoard: appState.localBoard,
                    opponentBoards: appState.opponentBoards,
                    opponentMarked: appState.opponentMarked,
                    onSelect: { targetPlayer, targetIndex in
                        appState.activatePowerUp(powerUp, targetPlayer: targetPlayer, targetIndex: targetIndex)
                        targetingPowerUp = nil
                    },
                    onCancel: { targetingPowerUp = nil }
                )
                .transition(.opacity)
            }

            // Earning toast
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    TokenToastView(message: msg)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onChange(of: appState.pendingToastMessage) { msg in
            guard let msg else { return }
            withAnimation(.spring()) { toastMessage = msg }
            appState.pendingToastMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { toastMessage = nil }
            }
        }
    }

    // MARK: - Portrait layout

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
            powerUpStrip(isVertical: false)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Landscape layout

    private func landscapeLayout(board: BingoBoard) -> some View {
        VStack(spacing: 6) {
            opponentHUD
            HStack(spacing: 8) {
                GeometryReader { geo in
                    let gridSize = min(geo.size.width, geo.size.height)
                    BingoGridView(
                        board: board,
                        highlightedPositions: Set(appState.completedLine ?? []),
                        onTap: appState.toggleSquare(at:)
                    )
                    .frame(width: gridSize, height: gridSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                powerUpStrip(isVertical: true)
                    .frame(width: 64)
            }
            bingoButton   // full-width below grid+strip so it isn't squeezed into the sidebar
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
    }

    // MARK: - Shared subviews

    @ViewBuilder private var opponentHUD: some View {
        if !appState.opponentMarked.isEmpty {
            OpponentStripView(
                opponentMarked: appState.opponentMarked,
                tokenBalances: appState.tokenBalances
            )
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var bingoButton: some View {
        if appState.completedLine != nil {
            Button(action: appState.callBingo) {
                Text("🎉 BINGO!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .padding(.horizontal, 48).padding(.vertical, 16)
                    .background(Color.yellow).foregroundColor(.black)
                    .cornerRadius(20).shadow(color: .yellow.opacity(0.6), radius: 16)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func powerUpStrip(isVertical: Bool) -> some View {
        PowerUpStripView(
            tokenBalance: appState.tokenBalance,
            isVertical: isVertical,
            onActivateRandom: { powerUp in
                appState.activatePowerUp(powerUp)
            },
            onRequestTargeted: { powerUp in
                targetingPowerUp = powerUp
            }
        )
        .padding(.horizontal, isVertical ? 0 : 16)
    }
}
```

- [ ] **Step 2: Replace OpponentStripView.swift**

```swift
import SwiftUI

struct OpponentStripView: View {
    let opponentMarked: [String: Set<Int>]
    let tokenBalances: [String: Int]

    var body: some View {
        HStack(spacing: 24) {
            ForEach(opponentMarked.keys.sorted(), id: \.self) { name in
                let marked = opponentMarked[name] ?? []
                let coins = tokenBalances[name]
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        if let coins {
                            Text("· 🪙\(coins)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                    }
                    MiniGridView(markedPositions: marked)
                    Text("\(marked.count) ✓")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.white.opacity(0.05)).cornerRadius(12)
    }
}

private struct MiniGridView: View {
    let markedPositions: Set<Int>
    private let size: CGFloat = 10
    private let gap: CGFloat = 2

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<5, id: \.self) { col in
                        let pos = row * 5 + col
                        RoundedRectangle(cornerRadius: 2)
                            .fill(pos == 12 ? Color.yellow :
                                  markedPositions.contains(pos) ? Color.blue :
                                  Color.white.opacity(0.15))
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build — verify no errors**

```bash
xcodebuild build -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(error:|Build succeeded|Build FAILED)'
```

Expected: `Build succeeded`

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' \
  2>&1 | grep -E '(passed|failed|Build FAILED)'
```

Expected: all suites pass.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Views/GameView.swift RoadTripBingo/Views/OpponentStripView.swift
git commit -m "feat: integrate power-up strip, targeting overlay, and token HUD into game screen"
```
