# Difficulty & Rarity Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five-tier rarity classification to bingo squares and per-player difficulty levels (Backseat / Shotgun / Navigator) that weight board composition accordingly.

**Architecture:** `SquareRarity` and `BoardDifficulty` enums extend the model layer; `SquarePool.dealBoards()` gains a new signature that accepts per-player difficulties and samples squares from per-rarity buckets using weighted percentages. A new `difficultyChosen` network message propagates picker changes from joiners to the host before game start. `LobbyView` grows a three-button difficulty picker (visible to all players) and difficulty badges on the host's player list.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest; xcodegen for project file regeneration.

---

## File Map

| File | Change |
|---|---|
| `RoadTripBingo/Models/BingoSquare.swift` | Add `SquareRarity` enum; add `rarity` field to `BingoSquare` |
| `RoadTripBingo/Models/BoardDifficulty.swift` | **New** — `BoardDifficulty` enum with `weights` |
| `RoadTripBingo/Resources/squares.json` | Add `"rarity"` key to all 150 entries |
| `RoadTripBingo/Models/MultipeerMessage.swift` | Add `difficultyChosen` case with encode/decode |
| `RoadTripBingo/Game/SquarePool.swift` | Update `dealBoards()` for weighted sampling |
| `RoadTripBingo/State/AppState.swift` | Add difficulty state, `chooseDifficulty()`, handle `difficultyChosen`, update dealing calls |
| `RoadTripBingo/Views/LobbyView.swift` | Add difficulty picker; difficulty badges on host player rows |
| `RoadTripBingoTests/BingoBoardTests.swift` | Add `rarity:` to `BingoSquare` initializer |
| `RoadTripBingoTests/MultipeerMessageTests.swift` | Add `rarity:` to initializers; add `difficultyChosen` roundtrip test |
| `RoadTripBingoTests/SquarePoolTests.swift` | Update `dealBoards` call sites; add weighted-dealing tests |

---

### Task 1: Add `SquareRarity` enum to `BingoSquare.swift`

**Files:**
- Modify: `RoadTripBingo/Models/BingoSquare.swift`

Purely additive — no existing code changes, no test updates needed.

- [ ] **Step 1: Replace `BingoSquare.swift` with the following**

```swift
import Foundation

enum SquareRarity: String, Codable, CaseIterable {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare
}

enum SquareCategory: String, Codable, CaseIterable {
    case vehicles, nature, food, landmarks, weather, signs
}

struct BingoSquare: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let emoji: String
    let category: SquareCategory

    static let freeSquareID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let free = BingoSquare(
        id: freeSquareID,
        text: "FREE",
        emoji: "⭐",
        category: .landmarks
    )
}
```

- [ ] **Step 2: Build to verify no errors**

```bash
xcodebuild -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | grep -E 'error:|BUILD'
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Models/BingoSquare.swift
git commit -m "feat: add SquareRarity enum"
```

---

### Task 2: Add `rarity` field to `BingoSquare`, classify all 150 squares in JSON, fix test call sites

**Files:**
- Modify: `RoadTripBingo/Models/BingoSquare.swift`
- Modify: `RoadTripBingo/Resources/squares.json`
- Modify: `RoadTripBingoTests/BingoBoardTests.swift`
- Modify: `RoadTripBingoTests/MultipeerMessageTests.swift`
- Modify: `RoadTripBingoTests/SquarePoolTests.swift`

All five files must change together — adding `rarity` to the struct without updating JSON causes a decode `fatalError` at runtime; not updating test call sites causes compile errors.

- [ ] **Step 1: Write two failing spot-check tests in `SquarePoolTests.swift`**

Add at the end of the class (before the final `}`):

```swift
func test_load_semiTruckIsVeryCommon() {
    let semiTruck = SquarePool.load().first { $0.text == "Semi Truck" }
    XCTAssertEqual(semiTruck?.rarity, .veryCommon)
}

func test_load_ghostTownIsVeryRare() {
    let ghostTown = SquarePool.load().first { $0.text == "Ghost Town" }
    XCTAssertEqual(ghostTown?.rarity, .veryRare)
}
```

These will not compile until Step 2 (the `rarity` property doesn't exist yet). That is the expected failure.

- [ ] **Step 2: Update `BingoSquare.swift` — add `rarity` field and update `.free` sentinel**

```swift
import Foundation

enum SquareRarity: String, Codable, CaseIterable {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare
}

enum SquareCategory: String, Codable, CaseIterable {
    case vehicles, nature, food, landmarks, weather, signs
}

struct BingoSquare: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let emoji: String
    let category: SquareCategory
    let rarity: SquareRarity

    static let freeSquareID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let free = BingoSquare(
        id: freeSquareID,
        text: "FREE",
        emoji: "⭐",
        category: .landmarks,
        rarity: .veryCommon
    )
}
```

- [ ] **Step 3: Update `BingoBoardTests.swift` — add `rarity:` to the `BingoSquare` initializer in `makeBoard()`**

Replace the `makeBoard()` function:

```swift
private func makeBoard() -> BingoBoard {
    let squares = (0..<25).map { i -> BingoSquare in
        if i == 12 { return .free }
        return BingoSquare(id: UUID(), text: "Item \(i)", emoji: "🚗", category: .vehicles, rarity: .common)
    }
    return BingoBoard(squares: squares)
}
```

- [ ] **Step 4: Update `MultipeerMessageTests.swift` — add `rarity:` to both `BingoSquare` initializers**

In `test_gameStarted_roundtrip`, replace the square construction line:
```swift
let square = BingoSquare(id: UUID(), text: "Cow", emoji: "🐄", category: .nature, rarity: .veryCommon)
```

In `test_playAgain_roundtrip`, replace the square construction line:
```swift
let square = BingoSquare(id: UUID(), text: "Barn", emoji: "🏚️", category: .nature, rarity: .veryCommon)
```

- [ ] **Step 5: Update `squares.json` — add `"rarity"` to all 150 entries**

Each JSON object gains one key. The string value must exactly match a `SquareRarity` raw value: `veryCommon`, `common`, `uncommon`, `rare`, or `veryRare`.

Example entry before:
```json
{
  "category" : "vehicles",
  "emoji" : "🚛",
  "id" : "95F10877-1BC5-4F38-A6B1-5C8469946794",
  "text" : "Semi Truck"
}
```

Example entry after (keys stay alphabetically sorted as Xcode's JSONEncoder writes them):
```json
{
  "category" : "vehicles",
  "emoji" : "🚛",
  "id" : "95F10877-1BC5-4F38-A6B1-5C8469946794",
  "rarity" : "veryCommon",
  "text" : "Semi Truck"
}
```

Apply these rarity values, matched by `"text"`:

**Vehicles**

| text | rarity |
|---|---|
| Semi Truck | veryCommon |
| Pickup Truck | veryCommon |
| Motorcycle | veryCommon |
| School Bus | common |
| Police Car | common |
| Minivan | veryCommon |
| Sports Car | common |
| Tow Truck | common |
| Flatbed Truck | common |
| Dump Truck | common |
| Ambulance | uncommon |
| Fire Truck | uncommon |
| RV | uncommon |
| Food Truck | uncommon |
| Mail Truck | uncommon |
| Convertible | uncommon |
| Construction Vehicle | common |
| Boat on Trailer | uncommon |
| Horse Trailer | rare |
| Tank Truck | rare |
| Double-Decker Bus | rare |
| Ice Cream Truck | rare |
| Small Plane | rare |
| Helicopter | rare |
| Tractor | uncommon |

**Nature**

| text | rarity |
|---|---|
| Cow | veryCommon |
| Red Barn | veryCommon |
| Hay Bale | veryCommon |
| Cornfield | veryCommon |
| Flock of Birds | veryCommon |
| Horse | common |
| Sheep | common |
| Pig | common |
| Goat | common |
| Dog in Car Window | common |
| Deer | uncommon |
| Sunflower Field | uncommon |
| Wind Turbine | uncommon |
| Mountain | uncommon |
| River | common |
| Lake | common |
| Cactus | uncommon |
| Orchard | uncommon |
| Vineyard | uncommon |
| Wildflowers | common |
| Waterfall | uncommon |
| Buffalo | rare |
| Hawk | uncommon |
| Rainbow | rare |
| Double Rainbow | veryRare |

**Food & Stops**

| text | rarity |
|---|---|
| Gas Station | veryCommon |
| McDonald's | veryCommon |
| Subway | veryCommon |
| Dollar General | veryCommon |
| Rest Stop | veryCommon |
| Starbucks | common |
| Wendy's | common |
| Taco Bell | common |
| Chick-fil-A | common |
| Truck Stop | common |
| Billboard | veryCommon |
| Drive-Through | common |
| Motel Sign | common |
| Waffle House | uncommon |
| Dairy Queen | uncommon |
| Cracker Barrel | uncommon |
| Car Wash | uncommon |
| Roadside Diner | uncommon |
| Campground Sign | uncommon |
| RV Park | uncommon |
| Fruit Stand | rare |
| Fireworks Stand | rare |
| Roadside BBQ | rare |
| Outlet Mall | uncommon |
| Ice Cream Stand | rare |

**Landmarks**

| text | rarity |
|---|---|
| Overpass | veryCommon |
| Bridge | veryCommon |
| Railroad Crossing | common |
| Water Tower | common |
| Church Steeple | common |
| Grain Silo | common |
| State Border Sign | uncommon |
| Welcome Sign | uncommon |
| Toll Booth | uncommon |
| Sports Stadium | uncommon |
| Fairground | uncommon |
| State Capitol | uncommon |
| Radio Tower | common |
| Airport | uncommon |
| Wind Farm | uncommon |
| Solar Farm | uncommon |
| National Park Sign | rare |
| Drive-In Theater | rare |
| Covered Bridge | rare |
| Lighthouse | rare |
| Monument | rare |
| Dam | rare |
| Ghost Town | veryRare |
| Roadside Attraction | rare |
| Mining Facility | rare |

**Weather**

| text | rarity |
|---|---|
| Dark Clouds | veryCommon |
| Sun Glare | veryCommon |
| Overcast Sky | veryCommon |
| Puddles | common |
| Sprinkles | common |
| Fog | common |
| Dramatic Sunset | common |
| Windy Flags | common |
| Snow on Mountains | uncommon |
| Morning Mist | uncommon |
| Dramatic Clouds | common |
| Low-Hanging Moon | uncommon |
| Stars Visible | uncommon |
| Thunderstorm | uncommon |
| Lightning | uncommon |
| Hail | rare |
| Frost on Windows | rare |
| Wildfire Smoke | rare |
| Dust Devil | rare |
| Ice on Road Sign | rare |
| Flash Flood Sign | rare |
| Mirage | rare |
| Hot Haze Shimmer | uncommon |
| Dust Storm | veryRare |
| Tornado Warning Sign | veryRare |

**Signs & Roads**

| text | rarity |
|---|---|
| Construction Zone | veryCommon |
| Speed Limit 75+ | veryCommon |
| Mile Marker ×0 | common |
| Rest Area Sign | common |
| Deer Crossing Sign | common |
| Highway Interchange | common |
| No Passing Zone | common |
| Detour Sign | uncommon |
| Weigh Station | uncommon |
| Low Clearance Sign | uncommon |
| Wrong Way Sign | uncommon |
| Divided Highway Sign | uncommon |
| Scenic Overlook Sign | uncommon |
| Historical Marker | uncommon |
| Adopt-a-Highway Sign | common |
| Road Narrows Sign | uncommon |
| Bridge Ices Sign | uncommon |
| Slippery When Wet | uncommon |
| Merging Traffic Sign | common |
| End Construction Sign | uncommon |
| State Highway Sign | common |
| Falling Rock Sign | rare |
| Chain Control Sign | rare |
| Runaway Truck Ramp | rare |
| No U-Turn Sign | uncommon |

- [ ] **Step 6: Verify all 150 entries have `"rarity"`**

```bash
python3 -c "
import json
with open('RoadTripBingo/Resources/squares.json') as f:
    squares = json.load(f)
missing = [s['text'] for s in squares if 'rarity' not in s]
if missing:
    print('MISSING rarity:', missing)
else:
    print(f'OK: all {len(squares)} squares have rarity')
"
```
Expected: `OK: all 150 squares have rarity`

- [ ] **Step 7: Run tests**

```bash
xcodebuild test -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' 2>&1 | grep -E 'error:|Test Suite|passed|failed|BUILD'
```
Expected: all tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add RoadTripBingo/Models/BingoSquare.swift \
        RoadTripBingo/Resources/squares.json \
        RoadTripBingoTests/BingoBoardTests.swift \
        RoadTripBingoTests/MultipeerMessageTests.swift \
        RoadTripBingoTests/SquarePoolTests.swift
git commit -m "feat: add rarity field to BingoSquare and classify all 150 squares"
```

---

### Task 3: Create `BoardDifficulty.swift` + regenerate project

**Files:**
- Create: `RoadTripBingo/Models/BoardDifficulty.swift`
- Modify: `RoadTripBingo.xcodeproj/project.pbxproj` (via xcodegen)

- [ ] **Step 1: Create `RoadTripBingo/Models/BoardDifficulty.swift`**

```swift
import Foundation

enum BoardDifficulty: String, Codable, CaseIterable {
    case backseat
    case shotgun
    case navigator

    var displayName: String {
        switch self {
        case .backseat:  return "Backseat"
        case .shotgun:   return "Shotgun"
        case .navigator: return "Navigator"
        }
    }

    // Fractional weight per rarity tier. Values sum to 1.0.
    var weights: [SquareRarity: Double] {
        switch self {
        case .backseat:
            return [.veryCommon: 0.40, .common: 0.35, .uncommon: 0.20, .rare: 0.05, .veryRare: 0.00]
        case .shotgun:
            return [.veryCommon: 0.20, .common: 0.30, .uncommon: 0.30, .rare: 0.15, .veryRare: 0.05]
        case .navigator:
            return [.veryCommon: 0.05, .common: 0.15, .uncommon: 0.30, .rare: 0.35, .veryRare: 0.15]
        }
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project so the new file is included in the build target**

```bash
xcodegen generate
```
Expected: output ending with `✅  Created project at RoadTripBingo.xcodeproj`

- [ ] **Step 3: Build to verify `BoardDifficulty` is visible**

```bash
xcodebuild -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | grep -E 'error:|BUILD'
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Models/BoardDifficulty.swift RoadTripBingo.xcodeproj/project.pbxproj
git commit -m "feat: add BoardDifficulty enum with rarity weights"
```

---

### Task 4: Add `difficultyChosen` to `MultipeerMessage` + test

**Files:**
- Modify: `RoadTripBingo/Models/MultipeerMessage.swift`
- Modify: `RoadTripBingoTests/MultipeerMessageTests.swift`

- [ ] **Step 1: Add the failing roundtrip test to `MultipeerMessageTests.swift`**

Add at the end of the class (before the final `}`):

```swift
func test_difficultyChosen_roundtrip() throws {
    let msg = MultipeerMessage.difficultyChosen(byName: "Zoe", difficulty: .navigator)
    let decoded = try roundtrip(msg)
    guard case .difficultyChosen(let name, let diff) = decoded else {
        return XCTFail("Wrong case decoded")
    }
    XCTAssertEqual(name, "Zoe")
    XCTAssertEqual(diff, .navigator)
}
```

- [ ] **Step 2: Verify the test fails to compile (expected)**

```bash
xcodebuild test -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' 2>&1 | grep "error:"
```
Expected: error — `'difficultyChosen' is not a member of type 'MultipeerMessage'`

- [ ] **Step 3: Replace `MultipeerMessage.swift` with the following**

```swift
import Foundation

enum MultipeerMessage: Codable {
    case gameStarted(boards: [String: [BingoSquare]])
    case squareToggled(position: Int, isMarked: Bool)
    case bingoAnnounced(byName: String)
    case playAgain(boards: [String: [BingoSquare]])
    case difficultyChosen(byName: String, difficulty: BoardDifficulty)

    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName, difficulty
    }

    private enum MessageType: String, Codable {
        case gameStarted, squareToggled, bingoAnnounced, playAgain, difficultyChosen
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
                isMarked: try c.decode(Bool.self, forKey: .isMarked)
            )
        case .bingoAnnounced:
            self = .bingoAnnounced(byName: try c.decode(String.self, forKey: .byName))
        case .playAgain:
            self = .playAgain(boards: try c.decode([String: [BingoSquare]].self, forKey: .boards))
        case .difficultyChosen:
            self = .difficultyChosen(
                byName: try c.decode(String.self, forKey: .byName),
                difficulty: try c.decode(BoardDifficulty.self, forKey: .difficulty)
            )
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' 2>&1 | grep -E 'error:|Test Suite|passed|failed|BUILD'
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RoadTripBingo/Models/MultipeerMessage.swift RoadTripBingoTests/MultipeerMessageTests.swift
git commit -m "feat: add difficultyChosen network message"
```

---

### Task 5: Update `SquarePool.dealBoards()` for weighted dealing + update call sites + tests

**Files:**
- Modify: `RoadTripBingo/Game/SquarePool.swift`
- Modify: `RoadTripBingo/State/AppState.swift` (call sites only — full difficulty wiring in Task 6)
- Modify: `RoadTripBingoTests/SquarePoolTests.swift`

The signature changes from `for playerNames: [String]` to `for players: [(name: String, difficulty: BoardDifficulty)]`. AppState call sites must be updated in this same task to keep the build green. AppState will pass `.backseat` as a placeholder for all players; Task 6 wires in real per-player difficulties.

- [ ] **Step 1: Add weighted-dealing tests to `SquarePoolTests.swift`**

Replace the full file content with the following (preserves all existing tests, adds three new ones, and updates the `dealBoards` call sites):

```swift
import XCTest
@testable import RoadTripBingo

final class SquarePoolTests: XCTestCase {

    func test_load_returnsAtLeast150Squares() {
        XCTAssertGreaterThanOrEqual(SquarePool.load().count, 150)
    }

    func test_load_allIDsUnique() {
        let pool = SquarePool.load()
        XCTAssertEqual(pool.map(\.id).count, Set(pool.map(\.id)).count)
    }

    func test_load_noFreeSquareInPool() {
        XCTAssertFalse(SquarePool.load().contains { $0.id == BingoSquare.freeSquareID })
    }

    func test_load_semiTruckIsVeryCommon() {
        let semiTruck = SquarePool.load().first { $0.text == "Semi Truck" }
        XCTAssertEqual(semiTruck?.rarity, .veryCommon)
    }

    func test_load_ghostTownIsVeryRare() {
        let ghostTown = SquarePool.load().first { $0.text == "Ghost Town" }
        XCTAssertEqual(ghostTown?.rarity, .veryRare)
    }

    func test_dealBoards_eachBoardHas25Squares() {
        let players = [("A", BoardDifficulty.backseat), ("B", .backseat), ("C", .backseat)]
            .map { (name: $0.0, difficulty: $0.1) }
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        XCTAssertEqual(boards["A"]?.count, 25)
        XCTAssertEqual(boards["B"]?.count, 25)
        XCTAssertEqual(boards["C"]?.count, 25)
    }

    func test_dealBoards_index12IsFree() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        XCTAssertEqual(boards["A"]?[12].id, BingoSquare.freeSquareID)
    }

    func test_dealBoards_noOverlapBetweenPlayers() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let aIDs = Set(boards["A"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        let bIDs = Set(boards["B"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        XCTAssertTrue(aIDs.isDisjoint(with: bIDs))
    }

    func test_dealBoards_backseatBoardHasAtLeast15CommonOrBetterSquares() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let nonFree = boards["A"]!.filter { $0.id != BingoSquare.freeSquareID }
        let easyCount = nonFree.filter { $0.rarity == .veryCommon || $0.rarity == .common }.count
        XCTAssertGreaterThanOrEqual(easyCount, 15,
            "Backseat board should have at least 15 veryCommon+common squares")
    }

    func test_dealBoards_navigatorBoardHasAtLeast8RareOrVeryRareSquares() {
        let players = [(name: "A", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let nonFree = boards["A"]!.filter { $0.id != BingoSquare.freeSquareID }
        let hardCount = nonFree.filter { $0.rarity == .rare || $0.rarity == .veryRare }.count
        XCTAssertGreaterThanOrEqual(hardCount, 8,
            "Navigator board should have at least 8 rare+veryRare squares")
    }
}
```

- [ ] **Step 2: Verify these tests fail (expected — new `dealBoards` signature doesn't exist yet)**

```bash
xcodebuild test -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' 2>&1 | grep "error:"
```
Expected: errors about mismatched argument labels on `dealBoards`.

- [ ] **Step 3: Replace `SquarePool.swift` with the weighted implementation**

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
    // Each player's 24 non-FREE squares are sampled from per-rarity buckets weighted by difficulty.
    // Non-overlap between players is best-effort; overlaps may occur when a rarity bucket runs thin.
    // Precondition: pool.count >= players.count * 24
    static func dealBoards(
        for players: [(name: String, difficulty: BoardDifficulty)],
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        precondition(pool.count >= players.count * 24)

        // Build per-rarity shuffled queues; players draw from the front.
        var queues: [SquareRarity: [BingoSquare]] = [:]
        for rarity in SquareRarity.allCases {
            queues[rarity] = pool.filter { $0.rarity == rarity }.shuffled()
        }

        var result: [String: [BingoSquare]] = [:]

        for player in players {
            let targets = targetCounts(for: player.difficulty)
            var squares: [BingoSquare] = []

            for rarity in SquareRarity.allCases {
                squares += draw(targets[rarity, default: 0], from: &queues[rarity]!)
            }

            // Thin-bucket fallback: fill any shortage from the combined remainder.
            if squares.count < 24 {
                var spill = SquareRarity.allCases.flatMap { queues[$0]! }.shuffled()
                let extra = draw(24 - squares.count, from: &spill)
                let extraIDs = Set(extra.map(\.id))
                for rarity in SquareRarity.allCases {
                    queues[rarity]!.removeAll { extraIDs.contains($0.id) }
                }
                squares += extra
            }

            squares.shuffle()
            squares.insert(.free, at: 12)
            result[player.name] = squares
        }

        return result
    }

    // MARK: - Private helpers

    private static func draw(_ count: Int, from bucket: inout [BingoSquare]) -> [BingoSquare] {
        let actual = min(count, bucket.count)
        let drawn = Array(bucket.prefix(actual))
        bucket.removeFirst(actual)
        return drawn
    }

    // Returns target square count per rarity tier summing to exactly 24.
    private static func targetCounts(for difficulty: BoardDifficulty) -> [SquareRarity: Int] {
        let tiers = SquareRarity.allCases
        var counts: [SquareRarity: Int] = [:]
        var running = 0
        for (i, rarity) in tiers.enumerated() {
            if i == tiers.count - 1 {
                counts[rarity] = 24 - running
            } else {
                let n = Int((24.0 * difficulty.weights[rarity, default: 0]).rounded())
                counts[rarity] = n
                running += n
            }
        }
        return counts
    }
}
```

- [ ] **Step 4: Update `AppState.swift` call sites — pass `.backseat` as placeholder difficulty**

In `startGame()`, replace:
```swift
let boards = SquarePool.dealBoards(for: allNames, from: pool)
```
with:
```swift
let players = allNames.map { (name: $0, difficulty: BoardDifficulty.backseat) }
let boards = SquarePool.dealBoards(for: players, from: pool)
```

In `requestPlayAgain()`, apply the same replacement:
```swift
let players = allNames.map { (name: $0, difficulty: BoardDifficulty.backseat) }
let boards = SquarePool.dealBoards(for: players, from: pool)
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' 2>&1 | grep -E 'error:|Test Suite|passed|failed|BUILD'
```
Expected: all tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add RoadTripBingo/Game/SquarePool.swift \
        RoadTripBingo/State/AppState.swift \
        RoadTripBingoTests/SquarePoolTests.swift
git commit -m "feat: weighted difficulty-based board dealing in SquarePool"
```

---

### Task 6: Add difficulty state and message handling to `AppState`

**Files:**
- Modify: `RoadTripBingo/State/AppState.swift`

Adds `playerDifficulty`, `playerDifficulties`, `chooseDifficulty()`, handles the incoming `difficultyChosen` message, and wires real per-player difficulties into `startGame()` and `requestPlayAgain()`.

- [ ] **Step 1: Add published difficulty properties to `AppState`**

In the `// MARK: - Lobby` section, after `@Published var foundGameNames: [String] = []`, add:

```swift
@Published var playerDifficulty: BoardDifficulty = .backseat
var playerDifficulties: [String: BoardDifficulty] = [:]  // host only: name → difficulty
```

- [ ] **Step 2: Add `chooseDifficulty()` method to `AppState`**

Add after the `inviteGame(named:)` method:

```swift
func chooseDifficulty(_ difficulty: BoardDifficulty) {
    playerDifficulty = difficulty
    if !isHost {
        multipeerSession?.send(.difficultyChosen(byName: playerName, difficulty: difficulty))
    }
}
```

- [ ] **Step 3: Reset difficulty state in `goHome()`**

Inside `goHome()`, after the existing reset lines and before `screen = .home`, add:

```swift
playerDifficulty = .backseat
playerDifficulties = [:]
```

- [ ] **Step 4: Handle `difficultyChosen` in `didReceive`**

Inside `multipeerSession(_:didReceive:from:)`, add a new case to the switch (after `.playAgain`):

```swift
case .difficultyChosen(let byName, let difficulty):
    playerDifficulties[byName] = difficulty
```

- [ ] **Step 5: Wire real per-player difficulties into `startGame()`**

Replace the placeholder `players` construction added in Task 5 with one that uses actual stored difficulties:

```swift
let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
    let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
    return (name: name, difficulty: diff)
}
```

- [ ] **Step 6: Wire real per-player difficulties into `requestPlayAgain()`**

Apply the same replacement in `requestPlayAgain()`:

```swift
let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
    let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
    return (name: name, difficulty: diff)
}
```

- [ ] **Step 7: Build and verify**

```bash
xcodebuild -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | grep -E 'error:|BUILD'
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 8: Commit**

```bash
git add RoadTripBingo/State/AppState.swift
git commit -m "feat: AppState difficulty state, chooseDifficulty, difficultyChosen handling"
```

---

### Task 7: Update `LobbyView` with difficulty picker and difficulty badges

**Files:**
- Modify: `RoadTripBingo/Views/LobbyView.swift`

Adds a three-button difficulty picker above the player list for both host and joiner. Shows a difficulty badge alongside each connected player's name on the host's view.

- [ ] **Step 1: Replace `LobbyView.swift` with the following**

```swift
import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            if appState.isHost { hostView } else { joinerView }
        }
    }

    private var hostView: some View {
        VStack(spacing: 32) {
            Text("Lobby").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text("Other players appear automatically nearby").font(.subheadline).foregroundColor(.white.opacity(0.6))
            difficultyPicker
            VStack(spacing: 10) {
                playerRow(name: appState.playerName, label: "you (host)", difficulty: appState.playerDifficulty)
                ForEach(appState.connectedPlayerNames, id: \.self) { name in
                    playerRow(name: name, label: nil,
                              difficulty: appState.playerDifficulties[name] ?? .backseat)
                }
            }.frame(maxWidth: 400)
            Button(action: appState.startGame) {
                Text("Start Game ▶")
                    .font(.title3.bold()).frame(maxWidth: 360).padding()
                    .background(appState.connectedPlayerNames.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                    .foregroundColor(.white).cornerRadius(14)
            }
            .disabled(appState.connectedPlayerNames.isEmpty)
            if appState.connectedPlayerNames.isEmpty {
                Text("Waiting for players to join…").font(.caption).foregroundColor(.white.opacity(0.6))
            }
            Button("Cancel", role: .destructive, action: appState.goHome).foregroundColor(.white.opacity(0.6))
        }.padding(48)
    }

    private var joinerView: some View {
        VStack(spacing: 32) {
            Text("Join Game").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.white)
            difficultyPicker
            if appState.connectedPlayerNames.isEmpty {
                VStack(spacing: 16) {
                    if appState.foundGameNames.isEmpty {
                        ProgressView().tint(.white)
                        Text("Looking for nearby games…").font(.subheadline).foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("Games nearby:").font(.subheadline).foregroundColor(.white.opacity(0.6))
                        ForEach(appState.foundGameNames, id: \.self) { name in
                            Button(action: { appState.inviteGame(named: name) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name).font(.headline).foregroundColor(.white)
                                        Text("Tap to join").font(.caption).foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundColor(.blue)
                                }
                                .padding().background(Color.white.opacity(0.08)).cornerRadius(12)
                            }
                        }
                    }
                }.frame(maxWidth: 400)
            } else {
                VStack(spacing: 10) {
                    Text("Connected! Waiting for host…").font(.subheadline).foregroundColor(.white.opacity(0.6))
                    playerRow(name: appState.playerName, label: "you", difficulty: nil)
                    ForEach(appState.connectedPlayerNames, id: \.self) { playerRow(name: $0, label: nil, difficulty: nil) }
                }.frame(maxWidth: 400)
            }
            Button("Cancel", role: .destructive, action: appState.goHome).foregroundColor(.white.opacity(0.6))
        }.padding(48)
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(BoardDifficulty.allCases, id: \.self) { difficulty in
                Button(action: { appState.chooseDifficulty(difficulty) }) {
                    Text(difficulty.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(appState.playerDifficulty == difficulty
                                    ? Color.blue
                                    : Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: 400)
    }

    private func playerRow(name: String, label: String?, difficulty: BoardDifficulty?) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color.green).frame(width: 10, height: 10)
            Text(name).font(.headline).foregroundColor(.white)
            if let label { Text(label).font(.caption).foregroundColor(.white.opacity(0.6)) }
            Spacer()
            if let difficulty {
                Text(difficulty.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.06)).cornerRadius(10)
    }
}
```

- [ ] **Step 2: Build and run all tests**

```bash
xcodebuild test -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' 2>&1 | grep -E 'error:|Test Suite|passed|failed|BUILD'
```
Expected: all tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 3: Manual verification on simulator**

Launch the app on two simulators (or one simulator + one device):
1. Both players reach the lobby — both show `[Backseat] [Shotgun] [Navigator]` picker with Backseat selected.
2. One player taps "Navigator" — host's player list updates their row to show "Navigator".
3. Host taps "Start Game" — game begins. Verify boards contain tiles appropriate to each difficulty (Navigator player's board should show unusual/rare squares; Backseat player's board should show common everyday items).

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Views/LobbyView.swift
git commit -m "feat: difficulty picker and per-player difficulty badges in LobbyView"
```
