# Wider Opponent Mark Feed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Widen the landscape opponent mark feed pills so opponent activity is readable at a glance during gameplay.

**Architecture:** Two targeted constant changes — sidebar width in `GameView` and image/font sizes in `RecentMarkCard`. No structural changes; the pill already uses `maxWidth: .infinity` and will fill the wider sidebar automatically.

**Tech Stack:** SwiftUI, Xcode, iOS Simulator (iPad Pro 13-inch M5)

---

### Task 1: Widen the left sidebar in GameView

**Files:**
- Modify: `RoadTripBingo/Views/GameView.swift`

- [ ] **Step 1: Open GameView and locate the sidebar frame**

  In `landscapeLayout(board:)`, find the `.frame(width: 130)` applied to the left sidebar `VStack` (around line 159).

- [ ] **Step 2: Change sidebar width from 130 to 180**

  Replace:
  ```swift
  .frame(width: 130)
  ```
  With:
  ```swift
  .frame(width: 180)
  ```

- [ ] **Step 3: Build to verify no errors**

  ```bash
  xcodebuild -project RoadTripBingo.xcodeproj \
    -scheme RoadTripBingo \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

  ```bash
  git add RoadTripBingo/Views/GameView.swift
  git commit -m "feat: widen landscape left sidebar from 130pt to 180pt"
  ```

---

### Task 2: Enlarge tile image and fonts in RecentMarkCard landscape pill

**Files:**
- Modify: `RoadTripBingo/Views/RecentMarkCard.swift`

- [ ] **Step 1: Open RecentMarkCard and locate the landscapePill computed property**

  Find `private var landscapePill: some View` — the `tileImage` frame and the two `Text` font calls are all inside this property. Portrait layout (`portraitSquare`) must not be touched.

- [ ] **Step 2: Enlarge the tile image frame**

  Replace:
  ```swift
  tileImage
      .frame(width: 44, height: 44)
      .clipped()
  ```
  With:
  ```swift
  tileImage
      .frame(width: 50, height: 50)
      .clipped()
  ```

- [ ] **Step 3: Enlarge the opponent name font**

  Replace:
  ```swift
  Text(mark.opponentName.uppercased())
      .font(AmericanaTheme.barlowSemiBold(9))
  ```
  With:
  ```swift
  Text(mark.opponentName.uppercased())
      .font(AmericanaTheme.barlowSemiBold(12))
  ```

- [ ] **Step 4: Enlarge the square text font**

  Replace:
  ```swift
  Text(mark.square.text)
      .font(AmericanaTheme.barlowBold(10))
  ```
  With:
  ```swift
  Text(mark.square.text)
      .font(AmericanaTheme.barlowBold(14))
  ```

- [ ] **Step 5: Build to verify no errors**

  ```bash
  xcodebuild -project RoadTripBingo.xcodeproj \
    -scheme RoadTripBingo \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

  ```bash
  git add RoadTripBingo/Views/RecentMarkCard.swift
  git commit -m "feat: larger tile image (50x50) and fonts (12/14pt) in landscape mark feed pill"
  ```
