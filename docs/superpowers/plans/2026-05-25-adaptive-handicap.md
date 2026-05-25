# Adaptive Handicap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Silently compensate consistently-losing players between rounds by dealing them a progressively easier tile distribution and granting bonus tokens, with no visible indicator to either player.

**Architecture:** Three coordinated changes: (1) `SquarePool` gains a pure `adjustedWeights` function and an optional `handicapLevels` parameter in `dealBoards`; (2) `MultipeerMessage` gains a `.handicapBonus` case for the host to silently deliver token grants; (3) `AppState` tracks `consecutiveLosses` per player, applies both adjustments at board-deal time, and handles the incoming bonus token message without triggering a toast.

**Tech Stack:** Swift, XCTest, existing MultipeerConnectivity stack

---

## File Map

| File | Change |
|---|---|
| `RoadTripBingo/Game/SquarePool.swift` | Add `adjustedWeights(for:handicapLevel:)`, weights-based `targetCounts(weights:total:)`, update `drawBoard` and `dealBoards` |
| `RoadTripBingo/Models/MultipeerMessage.swift` | Add `.handicapBonus(toPlayer:tokens:)` with encode/decode |
| `RoadTripBingo/State/AppState.swift` | Add `lastRoundWinner`, `consecutiveLosses`, `handicapBonusTokens(forLevel:)`, streak updates, handicap application, `.handicapBonus` handler |
| `RoadTripBingoTests/SquarePoolTests.swift` | Tests for `adjustedWeights` and handicap-aware `dealBoards` |
| `RoadTripBingoTests/MultipeerMessageTests.swift` | Roundtrip test for `.handicapBonus` |
| `RoadTripBingoTests/AppStateTests.swift` | Test for `handicapBonusTokens(forLevel:)` |

---

## Task 1: `adjustedWeights` — pure weight-shift algorithm

**Files:**
- Modify: `RoadTripBingo/Game/SquarePool.swift`
- Test: `RoadTripBingoTests/SquarePoolTests.swift`

- [ ] **Step 1: Write failing tests**

Add these tests to the bottom of `SquarePoolTests`, before the closing `}`:

```swift
// MARK: - adjustedWeights

func test_adjustedWeights_level0_returnsBaseDifficultyWeights() {
    let w = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 0)
    for rarity in SquareRarity.allCases {
        XCTAssertEqual(w[rarity, default: 0],
                       BoardDifficulty.navigator.weights[rarity, default: 0],
                       accuracy: 0.001)
    }
}

func test_adjustedWeights_level1_navigatorShiftsRareAndVeryRareDown() {
    let w = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 1)
    // rare: 0.35 − 0.04 = 0.31; veryRare: 0.15 − 0.04 = 0.11
    XCTAssertEqual(w[.rare, default: 0], 0.31, accuracy: 0.001)
    XCTAssertEqual(w[.veryRare, default: 0], 0.11, accuracy: 0.001)
    XCTAssertEqual(w[.veryCommon, default: 0], 0.09, accuracy: 0.001)
    XCTAssertEqual(w[.common, default: 0], 0.19, accuracy: 0.001)
    XCTAssertEqual(w[.uncommon, default: 0], 0.30, accuracy: 0.001)
}

func test_adjustedWeights_level2_navigatorContinuesShift() {
    let w = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 2)
    XCTAssertEqual(w[.rare, default: 0], 0.27, accuracy: 0.001)
    XCTAssertEqual(w[.veryRare, default: 0], 0.07, accuracy: 0.001)
    XCTAssertEqual(w[.veryCommon, default: 0], 0.13, accuracy: 0.001)
    XCTAssertEqual(w[.common, default: 0], 0.23, accuracy: 0.001)
}

func test_adjustedWeights_sumAlwaysEqualsOne() {
    for difficulty in BoardDifficulty.allCases {
        for level in 0...4 {
            let w = SquarePool.adjustedWeights(for: difficulty, handicapLevel: level)
            let sum = w.values.reduce(0, +)
            XCTAssertEqual(sum, 1.0, accuracy: 0.001,
                "Weights for \(difficulty) at level \(level) must sum to 1.0")
        }
    }
}

func test_adjustedWeights_backseat_cascadesIntoUncommonWhenRareExhausted() {
    // Backseat starts with rare=0.05, veryRare=0.00.
    // After level 2: rare and veryRare should both be 0.
    let w = SquarePool.adjustedWeights(for: .backseat, handicapLevel: 2)
    XCTAssertEqual(w[.rare, default: 0], 0.0, accuracy: 0.001)
    XCTAssertEqual(w[.veryRare, default: 0], 0.0, accuracy: 0.001)
    // Uncommon should have shrunk to absorb the cascade deficit
    XCTAssertLessThan(w[.uncommon, default: 0],
                      BoardDifficulty.backseat.weights[.uncommon, default: 0])
}

func test_adjustedWeights_cappedAt3() {
    let w3 = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 3)
    let w5 = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 5)
    for rarity in SquareRarity.allCases {
        XCTAssertEqual(w3[rarity, default: 0], w5[rarity, default: 0], accuracy: 0.001,
            "Level >3 should produce same weights as level 3")
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: multiple `FAIL` — `adjustedWeights` doesn't exist yet.

- [ ] **Step 3: Implement `adjustedWeights` in SquarePool**

Add this method to `SquarePool` in `SquarePool.swift`, immediately after the closing `}` of `dealReserve` and before `// MARK: - Private helpers`:

```swift
    // Returns the rarity weight distribution for a player at the given handicap level.
    // Each level shifts 4% weight from rare/veryRare toward veryCommon/common.
    // When a source bucket is depleted the deficit cascades to the next-hardest bucket.
    // Level is clamped to 3; weights always sum to 1.0.
    static func adjustedWeights(for difficulty: BoardDifficulty,
                                handicapLevel: Int) -> [SquareRarity: Double] {
        let level = min(handicapLevel, 3)
        guard level > 0 else { return difficulty.weights }

        var w = difficulty.weights
        let delta = 0.04

        for _ in 0..<level {
            // Reduce rare; cascade deficit to uncommon if rare is depleted.
            let rareTaken = min(delta, w[.rare, default: 0])
            w[.rare, default: 0] -= rareTaken
            let rareDeficit = delta - rareTaken
            if rareDeficit > 0 {
                let uncommonTaken = min(rareDeficit, w[.uncommon, default: 0])
                w[.uncommon, default: 0] -= uncommonTaken
            }

            // Reduce veryRare; cascade deficit to uncommon if veryRare is depleted.
            let veryRareTaken = min(delta, w[.veryRare, default: 0])
            w[.veryRare, default: 0] -= veryRareTaken
            let veryRareDeficit = delta - veryRareTaken
            if veryRareDeficit > 0 {
                let uncommonTaken = min(veryRareDeficit, w[.uncommon, default: 0])
                w[.uncommon, default: 0] -= uncommonTaken
            }

            w[.veryCommon, default: 0] += delta
            w[.common, default: 0] += delta
        }

        // Renormalise to guard against floating-point drift.
        let total = w.values.reduce(0, +)
        if total > 0 {
            for rarity in SquareRarity.allCases {
                w[rarity, default: 0] /= total
            }
        }
        return w
    }
```

- [ ] **Step 4: Run tests and confirm they pass**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: all `SquarePoolTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Game/SquarePool.swift RoadTripBingoTests/SquarePoolTests.swift
git commit -m "feat: add SquarePool.adjustedWeights for gradual handicap tile shift"
```

---

## Task 2: Wire `handicapLevels` into `dealBoards`

**Files:**
- Modify: `RoadTripBingo/Game/SquarePool.swift`
- Test: `RoadTripBingoTests/SquarePoolTests.swift`

- [ ] **Step 1: Write failing test**

Add to `SquarePoolTests.swift` before the closing `}`:

```swift
func test_dealBoards_withHandicapLevel_stillProducesValidBoard() {
    let pool = SquarePool.load()
    let players = [(name: "A", difficulty: BoardDifficulty.navigator)]
    let boards = SquarePool.dealBoards(for: players,
                                       handicapLevels: ["A": 3],
                                       from: pool)
    XCTAssertEqual(boards["A"]?.count, 25, "Handicapped board must still have 25 squares")
    XCTAssertEqual(boards["A"]?[12].id, BingoSquare.freeSquareID, "FREE must be at index 12")
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests/test_dealBoards_withHandicapLevel_stillProducesValidBoard \
  2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: FAIL — `dealBoards` doesn't accept `handicapLevels` yet.

- [ ] **Step 3: Add `targetCounts(weights:total:)` overload in SquarePool**

In `SquarePool.swift`, replace the existing private `targetCounts` method with two methods — the original unchanged, plus a new weights-based overload:

```swift
    private static func targetCounts(for difficulty: BoardDifficulty, total: Int = 24) -> [SquareRarity: Int] {
        targetCounts(weights: difficulty.weights, total: total)
    }

    private static func targetCounts(weights: [SquareRarity: Double], total: Int = 24) -> [SquareRarity: Int] {
        let tiers = SquareRarity.allCases
        var counts: [SquareRarity: Int] = [:]
        var running = 0
        for (i, rarity) in tiers.enumerated() {
            if i == tiers.count - 1 {
                counts[rarity] = max(0, total - running)
                break
            }
            let n = Int((Double(total) * weights[rarity, default: 0]).rounded())
            counts[rarity] = n
            running += n
        }
        return counts
    }
```

- [ ] **Step 4: Update `drawBoard` to accept a handicap level**

In `SquarePool.swift`, replace the existing `drawBoard(for:from:total:)` signature and first line:

```swift
    private static func drawBoard(
        for difficulty: BoardDifficulty,
        handicapLevel: Int = 0,
        from queues: inout [SquareRarity: [BingoSquare]],
        total: Int = 24
    ) -> [BingoSquare] {
        let w = adjustedWeights(for: difficulty, handicapLevel: handicapLevel)
        let targets = targetCounts(weights: w, total: total)
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
        } else {
            squares.shuffle()
        }
        return squares
    }
```

- [ ] **Step 5: Add `handicapLevels` parameter to `dealBoards`**

In `SquarePool.swift`, replace the `dealBoards` method:

```swift
    static func dealBoards(
        for players: [(name: String, difficulty: BoardDifficulty)],
        handicapLevels: [String: Int] = [:],
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        precondition(pool.count >= players.count * 24)
        var queues = makeQueues(from: pool)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            let level = handicapLevels[player.name, default: 0]
            result[player.name] = drawBoard(for: player.difficulty,
                                            handicapLevel: level,
                                            from: &queues)
        }
        return result
    }
```

- [ ] **Step 6: Run all SquarePool tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/SquarePoolTests 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add RoadTripBingo/Game/SquarePool.swift RoadTripBingoTests/SquarePoolTests.swift
git commit -m "feat: dealBoards accepts handicapLevels for per-player tile distribution"
```

---

## Task 3: `.handicapBonus` MultipeerMessage

**Files:**
- Modify: `RoadTripBingo/Models/MultipeerMessage.swift`
- Test: `RoadTripBingoTests/MultipeerMessageTests.swift`

- [ ] **Step 1: Write failing test**

Add to `MultipeerMessageTests.swift` before the closing `}`:

```swift
func test_handicapBonus_roundtrip() throws {
    let msg = MultipeerMessage.handicapBonus(toPlayer: "Theo", tokens: 5)
    let decoded = try roundtrip(msg)
    guard case .handicapBonus(let toPlayer, let tokens) = decoded else {
        return XCTFail("Wrong case decoded")
    }
    XCTAssertEqual(toPlayer, "Theo")
    XCTAssertEqual(tokens, 5)
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/MultipeerMessageTests/test_handicapBonus_roundtrip \
  2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: FAIL — `.handicapBonus` case doesn't exist yet.

- [ ] **Step 3: Add `.handicapBonus` case to `MultipeerMessage`**

In `MultipeerMessage.swift`, add the case to the enum (after `boardShuffled`):

```swift
    case handicapBonus(toPlayer: String, tokens: Int)
```

Add `handicapBonus` to `CodingKeys`:

```swift
    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName, difficulty
        case newBalance, powerUp, targetPlayer, targetIndex, replacementSquare
        case toName, squares
        case modifier, shuffledSquares, shuffledByName
        case handicapToPlayer, handicapTokens
    }
```

Add `handicapBonus` to `MessageType`:

```swift
    private enum MessageType: String, Codable {
        case gameStarted, squareToggled, bingoAnnounced, playAgain, difficultyChosen
        case tokenEarned, powerUpUsed, reserveDealt
        case roundModifier, boardShuffled, handicapBonus
    }
```

Add encode case to the `encode(to:)` `switch` (after `.boardShuffled`):

```swift
        case .handicapBonus(let toPlayer, let tokens):
            try c.encode(MessageType.handicapBonus, forKey: .type)
            try c.encode(toPlayer, forKey: .handicapToPlayer)
            try c.encode(tokens, forKey: .handicapTokens)
```

Add decode case to `init(from:)` `switch` (after `.boardShuffled`):

```swift
        case .handicapBonus:
            self = .handicapBonus(
                toPlayer: try c.decode(String.self, forKey: .handicapToPlayer),
                tokens: try c.decode(Int.self, forKey: .handicapTokens)
            )
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/MultipeerMessageTests 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: all `MultipeerMessageTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Models/MultipeerMessage.swift RoadTripBingoTests/MultipeerMessageTests.swift
git commit -m "feat: add MultipeerMessage.handicapBonus for silent token grant"
```

---

## Task 4: Streak tracking, handicap application, and bonus handler in AppState

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`
- Test: `RoadTripBingoTests/AppStateTests.swift`

- [ ] **Step 1: Write failing test for `handicapBonusTokens(forLevel:)`**

Add to `AppStateTests.swift` before the closing `}`:

```swift
func test_handicapBonusTokens_level0_returnsZero() {
    XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 0), 0)
}

func test_handicapBonusTokens_level1_returns3() {
    XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 1), 3)
}

func test_handicapBonusTokens_level2_returns5() {
    XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 2), 5)
}

func test_handicapBonusTokens_level3_returns7() {
    XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 3), 7)
}

func test_handicapBonusTokens_levelAbove3_returns7() {
    XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 99), 7)
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/AppStateTests 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: the five new tests FAIL — `handicapBonusTokens` doesn't exist yet.

- [ ] **Step 3: Add properties and `handicapBonusTokens` to AppState**

In `AppState.swift`, find the `// MARK: - Tokens` block (around line 42) and add two new private properties directly below `private var tokensSpentThisRound = 0`:

```swift
    // MARK: - Handicap (host only)
    private var lastRoundWinner: String? = nil
    private var consecutiveLosses: [String: Int] = [:]
```

Add the static helper anywhere in `AppState` (e.g. right after the `earnTokens` private method):

```swift
    // Returns the silent token bonus for a player at the given consecutive-loss level.
    static func handicapBonusTokens(forLevel level: Int) -> Int {
        switch min(level, 3) {
        case 1: return 3
        case 2: return 5
        case 3: return 7
        default: return 0
        }
    }
```

- [ ] **Step 4: Run tests to confirm `handicapBonusTokens` tests now pass**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test -only-testing:RoadTripBingoTests/AppStateTests 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: the five new `handicapBonusTokens` tests PASS; all other AppStateTests still PASS.

- [ ] **Step 5: Record last round winner**

In `callBingo()` in `AppState.swift`, add `lastRoundWinner = playerName` immediately before `screen = .win(winnerName: playerName)`:

```swift
        lastRoundWinner = playerName
        screen = .win(winnerName: playerName)
```

In the `.bingoAnnounced` handler inside `multipeerSession(_:didReceive:from:)`, add `lastRoundWinner = byName` immediately before `screen = .win(winnerName: byName)`:

```swift
            lastRoundWinner = byName
            screen = .win(winnerName: byName)
```

- [ ] **Step 6: Update streaks and apply handicap in `requestPlayAgain`**

Replace the existing `requestPlayAgain()` method:

```swift
    func requestPlayAgain() {
        guard isHost else { return }
        // Update consecutive-loss streaks before dealing the next board.
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
            self?.multipeerSession?.send(.playAgain(boards: boards))
        }
    }
```

- [ ] **Step 7: Pass `consecutiveLosses` to `dealBoards` in `dealAndLaunchRound`**

In `dealAndLaunchRound`, find the line:

```swift
        let boards = SquarePool.dealBoards(for: players, from: pool)
```

Replace it with:

```swift
        let boards = SquarePool.dealBoards(for: players,
                                           handicapLevels: consecutiveLosses,
                                           from: pool)
```

- [ ] **Step 8: Send handicap token bonus to players after board deal**

In `dealAndLaunchRound`, immediately after `earnTokens(2, reason: "Round start")`, add:

```swift
        // Silently deliver handicap token bonuses (host only, no toast).
        if isHost {
            for name in connectedPlayerNames {
                let level = min(consecutiveLosses[name, default: 0], 3)
                let bonus = AppState.handicapBonusTokens(forLevel: level)
                if bonus > 0 {
                    multipeerSession?.send(.handicapBonus(toPlayer: name, tokens: bonus))
                }
            }
            // Apply host's own bonus directly — no toast.
            let localLevel = min(consecutiveLosses[playerName, default: 0], 3)
            let localBonus = AppState.handicapBonusTokens(forLevel: localLevel)
            if localBonus > 0 {
                tokenBalance += localBonus
                multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
            }
        }
```

- [ ] **Step 9: Handle `.handicapBonus` message on the receiving device**

In `multipeerSession(_:didReceive:from:)`, add a new case to the `switch` block (after `.boardShuffled`):

```swift
        case .handicapBonus(let toPlayer, let tokens):
            // Silently credit tokens — no toast, no earnTokens call.
            guard toPlayer == playerName else { return }
            tokenBalance += tokens
            multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
```

- [ ] **Step 10: Reset handicap state in `reset()`**

In `AppState.swift`, find the `reset()` function and add after `isHost = false`:

```swift
        lastRoundWinner = nil
        consecutiveLosses = [:]
```

- [ ] **Step 11: Run all tests**

```bash
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  test 2>&1 | grep -E "FAIL|PASS|error:|Test session"
```

Expected: all tests PASS, no compile errors.

- [ ] **Step 12: Commit**

```bash
git add RoadTripBingo/State/AppState.swift RoadTripBingoTests/AppStateTests.swift
git commit -m "feat: adaptive handicap — streak tracking, tile distribution, silent token bonus"
```
