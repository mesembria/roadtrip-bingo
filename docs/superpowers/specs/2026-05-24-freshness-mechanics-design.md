# Freshness Mechanics Design

**Date:** 2026-05-24  
**Status:** Draft  
**Context:** 2–3 players (kids aged 8–10), back-to-back rounds, multi-day road trip. Goal: at least 30–45 minutes of engaging play per day across multiple days.

---

## Problem

Playing the same bingo game 4–6 rounds in a row produces a repetitive loop: same tile pool, same power-up strategies, same win condition. The attack power-ups (downgrade, unmark) partially address this but aren't enough on their own.

## Solution Overview

Two complementary systems:

1. **Round Modifiers** — a random rule twist each round, keeping each game feel different within a session
2. **Daily Challenges** — 3 random goals that span all rounds on a given calendar day, giving each session a shared story arc

A future **Phase C** covers unlockable game modes and themed tile packs (airport, farm, beach, etc.) unlocked via win history.

---

## 1. Round Modifiers

### Behaviour

- The host randomly selects one modifier when **Start Game** or **Play Again** is tapped
- The modifier is broadcast to all devices via a new `MultipeerMessage` case: `.roundModifier(RoundModifier)`
- All devices show a **full-screen reveal banner** (Americana-styled, ~2–3 seconds, auto-dismisses) before the board appears
- The active modifier is shown as a small persistent badge in the game screen header
- Modifiers are independent each round — repeats are allowed

### The Modifier Pool (9 modifiers)

| Modifier | Rule | Network impact |
|---|---|---|
| 🔥 Hot Streak | First to have 3 or more tiles marked in any single win line wins instantly (3 out of 5 in any order) | Local win check |
| 💰 Double Down | All token earnings doubled this round | Local token math |
| 🚫 No Powers | Power-ups disabled for the round | Local gate |
| 👑 Last Laugh | Player with fewest total wins gets a free power-up at round start | Needs persisted win history |
| 🎯 Sniper | Attack power-ups (downgrade, unmark) cost 1 token less | Local token math |
| 🗺️ Pattern Win | Must complete a specific shape — X, Four Corners, or Plus (sub-pattern revealed with modifier) | Local win check |
| 🌫️ Fog of War | 10 tiles start hidden (face-down, untappable). Each opponent mark shifts the fog to a new random set of non-marked tiles. Every 3rd shift, one fewer tile is hidden (minimum floor: 3 hidden). | Local — derived from incoming `squareToggled` events |
| 🌊 Shifting Tiles | Each time an opponent marks a tile, one of your non-marked tiles is replaced with a fresh one from the reserve pool. If reserve is exhausted, no replacement occurs (silent no-op). | Local — device draws from its own reserve |
| 🔀 Shuffle Board | Each time an opponent marks a tile, your non-marked tile positions shuffle randomly | Broadcast — sender emits `.boardShuffled([BingoSquare])` so opponents' view stays correct |

### `opponentMarked` Refactor

Currently `opponentMarked: [String: Set<Int>]` tracks marked tile positions. This is fragile: Shuffle Board changes positions, breaking opponents' views.

**Change:** `opponentMarked` becomes `[String: Set<UUID>]`. Since `opponentBoards[name]` already holds the full tile array, any device can derive positions locally via `opponentBoards[name]?.firstIndex(where: { $0.id == uuid })`. This also makes the downgrade power-up's `opponentMarked[target]?.remove(idx)` cleaner (remove by UUID, not inferred position).

### New `MultipeerMessage` Cases

```swift
case roundModifier(RoundModifier)
case boardShuffled(byName: String, squares: [BingoSquare])
```

### `RoundModifier` Model

```swift
enum RoundModifier: Codable, Equatable {
    case hotStreak
    case doubleDown
    case noPowers
    case lastLaugh
    case sniper
    case patternWin(PatternShape)  // shape bundled with modifier for display
    case fogOfWar
    case shiftingTiles
    case shuffleBoard

    // Used for random selection — patternWin picks a random shape
    static func random() -> RoundModifier {
        let base: [RoundModifier] = [.hotStreak, .doubleDown, .noPowers, .lastLaugh,
                                     .sniper, .fogOfWar, .shiftingTiles, .shuffleBoard]
        let withPattern: [RoundModifier] = base + [.patternWin(PatternShape.allCases.randomElement()!)]
        return withPattern.randomElement()!
    }
}

enum PatternShape: String, Codable, CaseIterable {
    case x            // positions: [0,4,6,8,12,16,18,20,24] (both diagonals)
    case fourCorners  // positions: [0,4,20,24]
    case plus         // positions: [2,7,10,11,12,13,14,17,22] (center row + center col)
}
```

---

## 2. Daily Challenges

### Behaviour

- At app launch, `AppState` checks today's calendar date against the stored `DailyState.date`
- If the date has changed (new day), 3 challenges are randomly selected from the pool and saved
- Challenges are **per-player** and tracked locally — each player's device manages its own progress
- When a challenge condition is met, tokens are awarded immediately via the existing toast system
- A completed challenge is greyed out for the rest of the day; it cannot be re-earned
- Challenges are shown in a collapsible panel accessible from the home screen and as a badge in the game screen

### Challenge Evaluation Architecture

The system is designed to be extended with metadata-based challenges (e.g., "spot 3 vehicle tiles", "mark a food tile") once `BingoSquare` gains category tags. All challenge types conform to a single protocol:

```swift
protocol DailyChallenge: Codable, Identifiable {
    var id: String { get }
    var title: String { get }
    var description: String { get }
    var tokenReward: Int { get }
    // Evaluate whether this challenge is newly completed given a game event.
    // Returns true if the event caused completion (not already completed).
    func evaluate(event: ChallengeEvent, context: ChallengeEvaluationContext) -> Bool
}

// Snapshot of game state passed to every evaluate() call.
struct ChallengeEvaluationContext {
    let playerName: String
    let marksThisRound: Int            // how many tiles this player has marked this round
    let opponentMarkCounts: [String: Int] // opponent name → their mark count this round
    let winsToday: Int                 // how many rounds this player has won today
    let attacksUsedThisRound: Int
    let tokensAtEndOfRound: Int
    let tokensSpentThisRound: Int
    let roundsPlayedToday: Int         // used by First Blood (== 0 means it's the first round)
}
```

`ChallengeEvent` is an enum covering all trackable game events:

```swift
enum ChallengeEvent {
    case tileMarked(tileID: UUID, byPlayer: String, isFirstInGame: Bool)
    case roundWon(byPlayer: String)
    case attackUsed(byPlayer: String, type: PowerUpType)
    case roundEnded(context: ChallengeEvaluationContext)  // fired for all stat-based checks
    // Future: case tileMarkedWithCategory(category: TileCategory, byPlayer: String)
}
```

Adding a metadata-based challenge later means: add a `.tileMarkedWithCategory` event (fired when `BingoSquare` has a category field), and write a new `DailyChallenge` conformance. No changes to persistence, evaluation loop, or UI.

**Speed Demon tracking:** Each device tracks its own mark count (`marksThisRound`) and opponents' counts from incoming `squareToggled` messages. When a player hits 5 marks, they check whether any opponent already has 5 — if not, Speed Demon is complete.

### Challenge Pool (9 challenges)

| Challenge | Goal | Reward |
|---|---|---|
| 🏆 Win One | Win any round today | +5 🟡 |
| ⚡ Speed Demon | Be the first player to mark 5 tiles in a round | +4 🟡 |
| 🧘 Pacifist | Win a round without using any attack power-ups | +6 🟡 |
| 💣 Menace | Use 3 attack power-ups in a single round | +5 🟡 |
| 🎯 Hoarder | End any round with 10+ tokens | +4 🟡 |
| 🔲 Corner King | Mark all 4 corner tiles in a single round | +5 🟡 |
| 🔥 On Fire | Win 2 rounds in the same day | +8 🟡 |
| 🤑 Spender | Spend 10+ tokens in a single round | +4 🟡 |
| 🌅 First Blood | Be the first player to mark a tile in today's first round | +3 🟡 |

### `DailyState` Persistence

```swift
struct DailyState: Codable {
    var date: String            // "2026-05-24" — ISO date string
    var challengeIDs: [String]  // 3 randomly selected challenge IDs
    var completedIDs: Set<String>
}
```

Stored in `UserDefaults` under key `"dailyState"`. Loaded on `AppState.init`, re-rolled whenever `date != today`.

### Win History Persistence

`winHistory: [String: Int]` is currently in-memory only. Move it to `UserDefaults` (key `"winHistory"`) so it survives app restarts. Required for **Last Laugh** modifier and **On Fire** challenge.

---

## 3. UI Changes

### Modifier Reveal Banner
- Full-screen overlay, appears after host taps Start/Play Again and before board is shown
- Americana-styled: dark parchment background, large emoji, modifier name in Rye font, rule in Barlow
- Countdown "Starting in 3…2…1…" then auto-dismisses
- Implemented as a `ZStack` overlay on `GameView`, driven by a `@State showModifierReveal: Bool`

### Active Modifier Badge
- Small pill in the game header showing the modifier emoji + short name
- Tapping it shows a popover with the full rule text

### Daily Challenges Panel
- Accessible from `HomeView` — a new button opens a sheet
- In-game: a badge in the header (shows count of incomplete challenges); tapping expands a drawer
- Each challenge shows: emoji, title, description, reward, completion checkmark if done

---

## 4. Out of Scope (Phase C — Future)

- Unlockable game modes via win history (Blackout, X-Pattern, Sprint)
- Themed tile packs (airport, farm, beach, mountains) — unlocked after N sessions
- Metadata-based challenges (requires `TileCategory` field on `BingoSquare`)

---

## Open Questions

None — all design decisions have been resolved.
