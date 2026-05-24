# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This project uses **XcodeGen** to generate the Xcode project from `project.yml`. The generated `RoadTripBingo.xcodeproj` is committed and kept in sync manually — run `xcodegen` only if `project.yml` changes.

```bash
# Build for simulator
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

# Run tests
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test

# Run a single test class
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test -only-testing:RoadTripBingoTests/GameEngineTests
```

## Adding Resources to the Bundle

`project.yml` is **not** used to regenerate `project.pbxproj` — the pbxproj is edited manually. When adding a new file to the bundle, add four entries by hand:

1. `PBXFileReference` — declares the file (use `lastKnownFileType = folder` for directories, `folder.assetcatalog` for `.xcassets`, correct UTI for individual files)
2. `PBXBuildFile` — references the file reference
3. Child entry in the appropriate `PBXGroup`
4. Entry in `PBXResourcesBuildPhase`

Fonts must be individual file references (not folder references) so Xcode copies them to the bundle root, which is required for `UIAppFonts`.

## Architecture

### State & Navigation

`AppState` (`State/AppState.swift`) is the single source of truth — a `@StateObject` created in `RoadTripBingoApp` and injected as an `@EnvironmentObject`. It owns all game state, drives navigation via `AppScreen` enum, and implements `MultipeerSessionDelegate`.

`ContentView` is a thin router that switches on `appState.screen`:
`.home → .lobby → .game → .win → .playAgain`

### Networking

`MultipeerSession` (`Network/`) wraps Apple's MultipeerConnectivity with service type `rtbingo`. All inter-device communication goes through `MultipeerMessage` (a Codable enum with 8 variants). The session calls back into `AppState` via the `MultipeerSessionDelegate` protocol.

### Game Logic

- **`GameEngine`** (`Game/`) — stateless utility; takes a set of marked positions and returns winning lines, close-call lines, and completed-line counts. Winning lines are pre-calculated (5 rows + 5 cols + 2 diagonals).
- **`SquarePool`** (`Game/`) — loads `Resources/squares.json` on init, deals boards weighted by `BoardDifficulty` rarity tiers, and ensures no overlaps between players' boards.

### Visual Design System

`AmericanaTheme` (`Views/AmericanaTheme.swift`) is the single styling authority:
- Colors: `parchment`, `paper`, `ink`, `green`, `greenLight`, `yellow`, `red`, `brown`
- Fonts: `rye(_:)`, `barlowSemiBold(_:)`, `barlowBold(_:)` — loaded from bundle via `UIAppFonts`
- Image loaders: `tileImage(for:)` and `icon(named:)` use `NSCache` to avoid repeated disk I/O on every SwiftUI render pass; `prewarmTileImages(for:)` should be called from a background `Task` before the board is shown
- `splashBackground()` loads `BingoSplash.jpg` for both the splash and home screens

Tile images live in `Resources/TileImages/` named by square UUID. Icons live in `Resources/Icons/`. The token icon has near-white pixels stripped at load time via pixel manipulation so it renders correctly on any background colour.

### Token Economy

Tokens are earned automatically by `AppState` on game events (first mark: 1, close call: 3, completed line: 2, BINGO: 5, round start: 2) and spent on power-ups (3–7 tokens depending on type). Toast notifications use `ToastEvent` and surface via `pendingToast` → `TokenToastView`. Messages containing the 🟡 emoji have it replaced inline with the token PNG icon.

### Layout Notes

- The app targets **iPad only** in landscape. `GameView` detects orientation via `GeometryReader` and switches between `portraitLayout` and `landscapeLayout`.
- Landscape layout: 130pt left sidebar (opponents + opponent mark feed + BINGO button) | flexible center grid | 126pt right sidebar (power-ups).
- Portrait layout (top to bottom): opponent HUD | grid (GeometryReader) | BINGO button | opponent mark feed (reserved 90pt slot) | power-ups.
- `BingoGridView` has a fixed 44pt header bar. When sizing the grid in landscape, constrain **width** to `min(available_width, available_height - 44)` so the header + grid area fit without overflowing.
- `HomeView` uses a `GeometryReader`-driven split: left panel (image background + badge) gets `total_width - 400pt`, right panel (controls) gets a fixed `400pt`.

### Opponent Mark Feed

When an opponent marks a tile, a fading mini card appears showing the tile image and opponent name. Cards expire after 10 seconds and are capped at 3.

- `RecentMark` (`Models/`) — value type holding `opponentName`, `square: BingoSquare`, `timestamp`.
- `AppState.recentOpponentMarks: [RecentMark]` — published array; `appendRecentMark(_:)` enforces the cap; a `Task { @MainActor }` pruning loop clears expired entries. Cleared on round start, play-again, and peer disconnect.
- `RecentMarkCard` (`Views/`) — adaptive card: landscape pill (HStack) or portrait square (VStack). Fades over 10s via `@State opacity` animated on `onAppear`; re-appear after rotation resumes from elapsed time rather than restarting.
- `OpponentMarkFeedView` (`Views/`) — landscape: `VStack` of pills; portrait: `HStack` clipped to 90pt.

All mutation of `AppState` must occur on the main actor. `MultipeerSession` dispatches all delegate callbacks via `DispatchQueue.main.async`.
