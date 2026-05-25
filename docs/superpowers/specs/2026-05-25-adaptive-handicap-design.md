# Adaptive Handicap Design Spec

**Date:** 2026-05-25
**Feature:** Automatic between-round handicap for consistently losing players

---

## Overview

When one player loses multiple rounds in a row, the game quietly compensates them going into the next round — easier tiles on their board and bonus tokens at the start. No UI indicator is shown to either player. The system is designed for an 8 and 10 year old sibling play context where the older child tends to win more often.

---

## Data Model

`AppState` (host only) gains:

```swift
var consecutiveLosses: [String: Int] = [:]   // player name → current losing streak
```

- Incremented for every player who did **not** win the round
- Reset to 0 for the round winner
- Capped at 3 for handicap calculation (streaks can exceed 3, but compensation maxes out at level 3)

The existing `playerDifficulties: [String: BoardDifficulty]` is unchanged. The chosen difficulty remains the baseline; the handicap applies an offset on top of it.

---

## Board Adjustment Algorithm

For each consecutive loss (up to 3), a fixed weight delta is applied to the player's chosen difficulty weights before `SquarePool` deals their board:

| Per loss level | veryCommon | common | uncommon | rare | veryRare |
|---|---|---|---|---|---|
| Δ weights | +4% | +4% | 0% | −4% | −4% |

**Maximum shift at level 3:** +12% veryCommon, +12% common, −12% rare, −12% veryRare — approximately 5–6 extra easy tiles on a 24-tile board.

**Cascade rule:** If a source bucket (rare or veryRare) would be reduced below 0%, the remaining deficit is taken from the next-hardest available bucket (uncommon, then common). Weights are renormalised to sum to 100% after applying the delta.

**Example — Navigator player after 2 losses:**

Base Navigator weights: veryCommon 5%, common 15%, uncommon 30%, rare 35%, veryRare 15%

After 2× delta (−8% rare, −8% veryRare, +8% veryCommon, +8% common):
- veryCommon: 13%
- common: 23%
- uncommon: 30%
- rare: 27%
- veryRare: 7%

Renormalises to 100% ✓ — roughly 3 veryCommon, 6 common, 7 uncommon, 6 rare, 2 veryRare (vs baseline ~1, 4, 7, 8, 4).

**Example — Backseat player after 2 losses:**

Base Backseat weights: veryCommon 40%, common 35%, uncommon 20%, rare 5%, veryRare 0%

After level 1 delta (rare 5%−4%=1%, veryRare 0%−4%→floor 0%, cascade −4% to uncommon→16%):
- veryCommon 44%, common 39%, uncommon 16%, rare 1%, veryRare 0%

After level 2 delta (rare 1%−4%→floor 0%, cascade −3% to uncommon; veryRare still 0%, cascade −4% to uncommon→uncommon 16%−3%−4%=9%):
- veryCommon 48%, common 43%, uncommon 9%, rare 0%, veryRare 0%

Renormalises to 100% ✓ — the cascade into uncommon is expected for Backseat players who have very few rare/veryRare tiles to draw from.

---

## Token Bonus

A new `MultipeerMessage` case is sent by the host to the handicapped player immediately after board deal:

```swift
case handicapBonus(toPlayer: String, tokens: Int)
```

| Consecutive losses | Bonus tokens |
|---|---|
| 1 | +3 |
| 2 | +5 |
| 3+ | +7 |

The `.handicapBonus` handler on the receiving device applies the grant **without** calling `earnTokens(_:reason:)` (which would trigger a toast). Instead it directly increments `tokenBalance` and sends `.tokenEarned(byName:newBalance:)` to update the host's balance display — no `pendingToast` is set. The round winner receives nothing extra.

---

## Network Protocol

| Message | Sender | Timing | Purpose |
|---|---|---|---|
| `handicapBonus(toPlayer:tokens:)` | host → affected player | immediately after board deal | delivers token bonus silently |

The board adjustment requires no new message — it is computed on the host at deal time and reflected in the dealt board the opponent receives via the existing board-deal flow.

---

## Streak Lifecycle

```
Round ends
  └─ winner:  consecutiveLosses[winner] = 0
  └─ losers:  consecutiveLosses[loser] = min(current + 1, Int.max)

Next board deal (host)
  └─ handicapLevel = min(consecutiveLosses[player], 3)
  └─ apply weight delta × handicapLevel before drawing tiles
  └─ if handicapLevel > 0: send .handicapBonus(toPlayer:tokens:)
```

Streak is reset on any win — even if a player wins just one round in a long session, their next board returns to their chosen baseline with no bonus tokens.

---

## Out of Scope

- No UI to show handicap status to either player (fully silent)
- No option to disable mid-session
- Solo / single-player mode is unaffected (no opponent means no loser tracking)
- Handicap does not affect which specific tiles are excluded between players (non-overlap logic is unchanged)
- No persistent handicap state across app launches — streak is session-only
