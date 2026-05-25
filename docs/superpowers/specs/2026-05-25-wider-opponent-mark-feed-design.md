# Wider Opponent Mark Feed (Landscape)

**Date:** 2026-05-25  
**Status:** Approved

## Problem

In landscape mode the opponent mark feed pills are hard to read. The left sidebar is 130pt wide, leaving very little room for text after the tile image. Font sizes of 9/10pt are too small for at-a-glance readability during gameplay.

## Solution

Widen the left sidebar from 130pt to 180pt and use the extra space to enlarge the tile image and font sizes in the landscape pill variant of `RecentMarkCard`.

## Changes

### `GameView.swift`
- Left sidebar `frame(width:)`: `130` → `180`

### `RecentMarkCard.swift` — `landscapePill` only
- Tile image frame: `44×44` → `50×50`
- Opponent name font: `barlowSemiBold(9)` → `barlowSemiBold(12)`
- Square text font: `barlowBold(10)` → `barlowBold(14)`

## Non-changes
- Portrait layout (`portraitSquare`) is unchanged.
- The pill already uses `.frame(maxWidth: .infinity)` so it fills the wider sidebar automatically — no layout restructuring needed.

## Device Impact
The sidebar widening does not affect grid size on any supported iPad. The bingo grid is always height-capped in landscape, leaving 78–157pt of unused horizontal slack in the center column (depending on device). The left sidebar would need to exceed ~287pt on the smallest supported iPad (mini 6th gen) before the grid would be affected.
