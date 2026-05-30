# Americana Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dark-navy emoji-based UI with a vintage Americana road atlas aesthetic across all screens, using AI-generated PNG tile images, custom PNG power-up icons, and Rye + Barlow Condensed fonts.

**Architecture:** A single shared `AmericanaTheme` struct provides all colors, fonts, and the grid background view. Each screen is rewritten independently; there are no new data model changes. Image assets live in flat `Resources/TileImages/` and `Resources/Icons/` folders loaded via `Bundle.main.path(forResource:ofType:inDirectory:)`.

**Tech Stack:** SwiftUI (iOS 16+), `UIKit` only for `UIImage(contentsOfFile:)` image loading, `Canvas` for background grid lines, XcodeGen (`project.yml` already covers all new subfolders).

---

## File Map

| Task | File | Action |
|------|------|--------|
| 1 | `RoadTripBingo/Info.plist` | Add `UIAppFonts` array |
| 1 | `RoadTripBingo/Resources/Fonts/` | New folder — 3 TTF files |
| 2 | `RoadTripBingo/Resources/TileImages/` | New folder — 182 PNGs (copy from brainstorm) |
| 2 | `RoadTripBingo/Resources/Icons/` | New folder — 5 PNGs (copy from brainstorm) |
| 3 | `RoadTripBingo/Views/AmericanaTheme.swift` | New file |
| 4 | `RoadTripBingo/Views/BingoSquareView.swift` | Full rewrite |
| 5 | `RoadTripBingo/Views/BingoGridView.swift` | Add BINGO header + paper background wrapper |
| 6 | `RoadTripBingo/Views/GameView.swift` | Swap background + restyle BINGO button |
| 7 | `RoadTripBingo/Views/PowerUpStripView.swift` | Full rewrite — PNG icons + token badge |
| 8 | `RoadTripBingo/Views/HomeView.swift` | Full rewrite |
| 9 | `RoadTripBingo/Views/LobbyView.swift` | Full rewrite |
| 10 | `RoadTripBingo/Views/WinView.swift` | Full rewrite — tile image strip |
| 11 | `RoadTripBingo/Views/OpponentStripView.swift` | Colors, fonts, token icon, mini-grid colors |
| 12 | `RoadTripBingo/Views/TargetingOverlayView.swift` | Panel color, fonts, tile images, token icon |
| 13 | `RoadTripBingo/Views/PlayAgainView.swift` | Full rewrite |

---

### Task 1: Fonts — Download, Copy, Register

**Files:**
- Create: `RoadTripBingo/Resources/Fonts/Rye-Regular.ttf`
- Create: `RoadTripBingo/Resources/Fonts/BarlowCondensed-SemiBold.ttf`
- Create: `RoadTripBingo/Resources/Fonts/BarlowCondensed-Bold.ttf`
- Modify: `RoadTripBingo/Info.plist`

- [ ] **Step 1: Create the Fonts folder**

```bash
mkdir -p /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Fonts
```

- [ ] **Step 2: Download fonts from Google Fonts**

Download [Rye](https://fonts.google.com/specimen/Rye) and [Barlow Condensed](https://fonts.google.com/specimen/Barlow+Condensed) from Google Fonts (click "Download family" on each). Unzip both archives. Copy the needed files:

```bash
# After downloading and unzipping into ~/Downloads:
cp ~/Downloads/Rye/Rye-Regular.ttf \
   /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Fonts/

cp ~/Downloads/Barlow_Condensed/BarlowCondensed-SemiBold.ttf \
   /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Fonts/

cp ~/Downloads/Barlow_Condensed/BarlowCondensed-Bold.ttf \
   /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Fonts/
```

Verify:
```bash
ls /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Fonts/
# Expected: BarlowCondensed-Bold.ttf  BarlowCondensed-SemiBold.ttf  Rye-Regular.ttf
```

- [ ] **Step 3: Register fonts in Info.plist**

Add a `UIAppFonts` key to `RoadTripBingo/Info.plist`. Insert it before the closing `</dict>`:

The file currently ends with:
```xml
    <key>UILaunchScreen</key>
    <dict/>
</dict>
</plist>
```

Replace the final `</dict>` block with:
```xml
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIAppFonts</key>
    <array>
        <string>Rye-Regular.ttf</string>
        <string>BarlowCondensed-SemiBold.ttf</string>
        <string>BarlowCondensed-Bold.ttf</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Resources/Fonts/ RoadTripBingo/Info.plist
git commit -m "feat: add Rye and Barlow Condensed font assets"
```

---

### Task 2: Image Assets — Copy Tiles and Icons

**Files:**
- Create: `RoadTripBingo/Resources/TileImages/` (182 PNGs)
- Create: `RoadTripBingo/Resources/Icons/` (5 PNGs)

- [ ] **Step 1: Copy tile images**

```bash
mkdir -p /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/TileImages
cp /Users/pmoore/Source/roadtrip-bingo/.superpowers/brainstorm/sample-tiles/*.png \
   /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/TileImages/
```

Verify count:
```bash
ls /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/TileImages/ | wc -l
# Expected: 182
```

- [ ] **Step 2: Copy power-up and token icons**

```bash
mkdir -p /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Icons

SRC=/Users/pmoore/Source/roadtrip-bingo/.superpowers/brainstorm/powerup-icons
DEST=/Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Icons

cp "$SRC/upgrade.png"  "$DEST/powerup-upgrade.png"
cp "$SRC/sabotage.png" "$DEST/powerup-sabotage.png"
cp "$SRC/freemark.png" "$DEST/powerup-freemark.png"
cp "$SRC/erase.png"    "$DEST/powerup-erase.png"
cp "$SRC/token-a.png"  "$DEST/token.png"
```

Verify:
```bash
ls /Users/pmoore/Source/roadtrip-bingo/RoadTripBingo/Resources/Icons/
# Expected: powerup-erase.png  powerup-freemark.png  powerup-sabotage.png  powerup-upgrade.png  token.png
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Resources/TileImages/ RoadTripBingo/Resources/Icons/
git commit -m "feat: add 182 tile images and 5 power-up/token icons"
```

---

### Task 3: AmericanaTheme.swift

**Files:**
- Create: `RoadTripBingo/Views/AmericanaTheme.swift`

- [ ] **Step 1: Create the file**

Create `RoadTripBingo/Views/AmericanaTheme.swift` with this exact content:

```swift
import SwiftUI

struct AmericanaTheme {
    static let parchment  = Color(red: 0.969, green: 0.941, blue: 0.890)
    static let paper      = Color(red: 0.929, green: 0.898, blue: 0.816)
    static let ink        = Color(red: 0.110, green: 0.071, blue: 0.035)
    static let green      = Color(red: 0.102, green: 0.361, blue: 0.165)
    static let greenLight = Color(red: 0.176, green: 0.478, blue: 0.243)
    static let yellow     = Color(red: 0.961, green: 0.784, blue: 0.000)
    static let red        = Color(red: 0.753, green: 0.224, blue: 0.169)
    static let shadow     = Color(red: 0.110, green: 0.071, blue: 0.035).opacity(0.18)

    static func rye(_ size: CGFloat) -> Font {
        .custom("Rye-Regular", size: size)
    }
    static func barlowSemiBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-SemiBold", size: size)
    }
    static func barlowBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Bold", size: size)
    }

    static func gridBackground() -> some View {
        AmericanaGridBackground()
    }

    static func tileImage(for square: BingoSquare) -> Image? {
        guard let path = Bundle.main.path(
            forResource: square.id.uuidString,
            ofType: "png",
            inDirectory: "TileImages"
        ), let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
    }

    static func icon(named name: String) -> Image? {
        guard let path = Bundle.main.path(
            forResource: name,
            ofType: "png",
            inDirectory: "Icons"
        ), let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
    }
}

struct AmericanaGridBackground: View {
    var body: some View {
        AmericanaTheme.parchment
            .overlay(
                Canvas { context, size in
                    let spacing: CGFloat = 28
                    let color = AmericanaTheme.ink.opacity(0.04)
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                    context.stroke(path, with: .color(color), lineWidth: 1)
                }
            )
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Open the project in Xcode (`open RoadTripBingo.xcodeproj`) and build (⌘B). The new file should compile without errors. There are no callers yet so no other errors expected.

Alternatively via `xcodebuild`:
```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/AmericanaTheme.swift
git commit -m "feat: add AmericanaTheme and AmericanaGridBackground"
```

---

### Task 4: BingoSquareView — Full Rewrite

**Files:**
- Modify: `RoadTripBingo/Views/BingoSquareView.swift`

The current view uses emoji + dark backgrounds. Replace it entirely with the three Americana states (unmarked/image card, marked/SPOTTED!, FREE/green).

- [ ] **Step 1: Rewrite BingoSquareView.swift**

Replace the entire contents of `RoadTripBingo/Views/BingoSquareView.swift` with:

```swift
import SwiftUI

struct BingoSquareView: View {
    let square: BingoSquare
    let isMarked: Bool
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if square.id == BingoSquare.freeSquareID {
                    freeCell
                } else {
                    regularCell
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isMarked)
    }

    private var freeCell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AmericanaTheme.green)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AmericanaTheme.yellow, lineWidth: 2)
                .padding(2)
            VStack(spacing: 2) {
                tokenImage
                    .frame(width: 44, height: 44)
                Text("FREE")
                    .font(AmericanaTheme.rye(13))
                    .foregroundColor(AmericanaTheme.yellow)
                    .kerning(1)
            }
        }
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 0, y: 1)
    }

    private var regularCell: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Card background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isHighlighted
                                    ? AmericanaTheme.yellow
                                    : AmericanaTheme.ink.opacity(0.08),
                                lineWidth: isHighlighted ? 3 : 1
                            )
                    )

                VStack(spacing: 0) {
                    // Image area — upper 75%
                    Group {
                        if let img = AmericanaTheme.tileImage(for: square) {
                            img
                                .resizable()
                                .scaledToFit()
                        } else {
                            Text(square.emoji)
                                .font(.system(size: geo.size.width * 0.38))
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: geo.size.height * 0.75)

                    // Label strip — bottom 25%
                    ZStack {
                        Color.white
                        Rectangle()
                            .fill(AmericanaTheme.ink.opacity(0.08))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        Text(square.text.uppercased())
                            .font(AmericanaTheme.barlowSemiBold(8.5))
                            .foregroundColor(AmericanaTheme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 2)
                    }
                    .frame(height: geo.size.height * 0.25)
                    .clipShape(
                        RoundedCornerShape(radius: 8, corners: [.bottomLeft, .bottomRight])
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // SPOTTED! overlay
                if isMarked {
                    spottedOverlay
                        .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
                }
            }
        }
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 0, y: 1)
    }

    private var spottedOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.55))
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AmericanaTheme.red, lineWidth: 2)
                .padding(4)
                .rotationEffect(.degrees(-12))
            Text("SPOTTED!")
                .font(AmericanaTheme.rye(13))
                .foregroundColor(AmericanaTheme.red)
                .rotationEffect(.degrees(-12))
        }
    }

    @ViewBuilder private var tokenImage: some View {
        if let img = AmericanaTheme.icon(named: "token") {
            img.resizable().scaledToFit()
        } else {
            Text("⭐").font(.system(size: 32))
        }
    }
}

// Selective corner rounding — iOS 16 compatible
struct RoundedCornerShape: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/BingoSquareView.swift
git commit -m "feat: rewrite BingoSquareView with Americana tile images and SPOTTED! stamp"
```

---

### Task 5: BingoGridView — BINGO Header + Paper Background

**Files:**
- Modify: `RoadTripBingo/Views/BingoGridView.swift`

Wrap the existing `LazyVGrid` in a `VStack` with a forest-green BINGO header bar on top (B I N G O letters) and a paper-toned background on the grid, all rounded as a unified card.

- [ ] **Step 1: Rewrite BingoGridView.swift**

Replace the entire contents of `RoadTripBingo/Views/BingoGridView.swift` with:

```swift
import SwiftUI

struct BingoGridView: View {
    let board: BingoBoard
    let highlightedPositions: Set<Int>
    let onTap: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    private let letters = ["B", "I", "N", "G", "O"]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            gridArea
        }
        .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 4)
    }

    private var headerBar: some View {
        ZStack {
            AmericanaTheme.green

            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(AmericanaTheme.yellow)
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 10)
                    .padding(.leading, 6)

                // B I N G O letters
                HStack(spacing: 0) {
                    ForEach(letters, id: \.self) { letter in
                        Text(letter)
                            .font(AmericanaTheme.rye(20))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Right accent bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(AmericanaTheme.yellow)
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 10)
                    .padding(.trailing, 6)
            }
        }
        .frame(height: 44)
        .clipShape(
            RoundedCornerShape(radius: 12, corners: [.topLeft, .topRight])
        )
    }

    private var gridArea: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<25, id: \.self) { position in
                BingoSquareView(
                    square: board.squares[position],
                    isMarked: board.isMarked(at: position),
                    isHighlighted: highlightedPositions.contains(position),
                    onTap: { onTap(position) }
                ).aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(8)
        .background(
            AmericanaTheme.paper
                .clipShape(RoundedCornerShape(radius: 12, corners: [.bottomLeft, .bottomRight]))
        )
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/BingoGridView.swift
git commit -m "feat: add Americana BINGO header bar and paper background to BingoGridView"
```

---

### Task 6: GameView — Parchment Background + Americana BINGO Button

**Files:**
- Modify: `RoadTripBingo/Views/GameView.swift`

Two targeted changes: (1) swap the dark background for `AmericanaTheme.gridBackground()`, (2) restyle the BINGO button with Rye font, mustard yellow background, and ink foreground.

- [ ] **Step 1: Swap background**

In `GameView.swift`, replace:
```swift
Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
```
with:
```swift
AmericanaTheme.gridBackground().ignoresSafeArea()
```

- [ ] **Step 2: Restyle the BINGO button**

Replace the `bingoButton` computed property (lines 118–129):
```swift
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
```
with:
```swift
@ViewBuilder private var bingoButton: some View {
    if appState.completedLine != nil {
        Button(action: appState.callBingo) {
            Text("BINGO!")
                .font(AmericanaTheme.rye(22))
                .padding(.horizontal, 48).padding(.vertical, 14)
                .background(AmericanaTheme.yellow)
                .foregroundColor(AmericanaTheme.ink)
                .cornerRadius(8)
                .shadow(color: AmericanaTheme.yellow.opacity(0.8), radius: 0, x: 0, y: 3)
        }
        .transition(.scale.combined(with: .opacity))
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 4: Commit**

```bash
git add RoadTripBingo/Views/GameView.swift
git commit -m "feat: swap GameView to parchment background and Americana BINGO button"
```

---

### Task 7: PowerUpStripView — PNG Icons + Token Badge

**Files:**
- Modify: `RoadTripBingo/Views/PowerUpStripView.swift`

Replace emoji icons and the `🟡` token badge with PNG images. The strip background becomes forest green.

- [ ] **Step 1: Rewrite PowerUpStripView.swift**

Replace the entire contents of `RoadTripBingo/Views/PowerUpStripView.swift` with:

```swift
import SwiftUI

struct PowerUpStripView: View {
    let tokenBalance: Int
    let isVertical: Bool
    let onActivateRandom: (PowerUpType) -> Void
    let onRequestTargeted: (PowerUpType) -> Void

    private struct StripItem {
        let iconName: String
        let label: String
        let randomVariant: PowerUpType?
        let targetedVariant: PowerUpType

        var displayCost: Int { randomVariant?.cost ?? targetedVariant.cost }
    }

    private let items: [StripItem] = [
        StripItem(iconName: "powerup-upgrade",  label: "Upgrade",   randomVariant: .upgradeTileRandom,    targetedVariant: .upgradeTileTargeted),
        StripItem(iconName: "powerup-sabotage", label: "Sabotage",  randomVariant: .downgradeTileRandom,  targetedVariant: .downgradeTileTargeted),
        StripItem(iconName: "powerup-freemark", label: "Free Mark", randomVariant: nil,                   targetedVariant: .freeMark),
        StripItem(iconName: "powerup-erase",    label: "Erase",     randomVariant: .unmarkOpponentRandom, targetedVariant: .unmarkOpponentTargeted),
    ]

    @State private var showHelp = false

    var body: some View {
        Group {
            if isVertical {
                VStack(spacing: 9) { buttons; helpButton; balanceBadge }
            } else {
                HStack(spacing: 9) { buttons; helpButton; Spacer(); balanceBadge }
            }
        }
        .padding(12)
        .background(AmericanaTheme.green)
        .cornerRadius(12)
        .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showHelp) { PowerUpHelpView() }
    }

    @ViewBuilder private var buttons: some View {
        ForEach(items.indices, id: \.self) { i in
            let item = items[i]
            let canAfford = tokenBalance >= item.displayCost
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                    if let img = AmericanaTheme.icon(named: item.iconName) {
                        img.resizable().scaledToFit().padding(4)
                            .frame(width: 44, height: 44)
                    }
                }
                Text(item.label.uppercased())
                    .font(AmericanaTheme.barlowBold(9))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                HStack(spacing: 2) {
                    if let img = AmericanaTheme.icon(named: "token") {
                        img.resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    Text("\(item.displayCost)")
                        .font(AmericanaTheme.barlowBold(12))
                        .foregroundColor(AmericanaTheme.yellow)
                }
            }
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
                guard tokenBalance >= item.targetedVariant.cost else { return }
                onRequestTargeted(item.targetedVariant)
            }
        }
    }

    private var balanceBadge: some View {
        HStack(spacing: 4) {
            if let img = AmericanaTheme.icon(named: "token") {
                img.resizable().scaledToFit().frame(width: 26, height: 26)
            }
            Text("\(tokenBalance)")
                .font(AmericanaTheme.barlowBold(22))
                .foregroundColor(AmericanaTheme.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(AmericanaTheme.yellow)
        .cornerRadius(8)
    }

    private var helpButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 44)
            Text("?")
                .font(AmericanaTheme.barlowBold(18))
                .foregroundColor(.white.opacity(0.75))
        }
        .accessibilityLabel("Power-up help")
        .onTapGesture { showHelp = true }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/PowerUpStripView.swift
git commit -m "feat: rewrite PowerUpStripView with Americana PNG icons and token badge"
```

---

### Task 8: HomeView — Americana Redesign

**Files:**
- Modify: `RoadTripBingo/Views/HomeView.swift`

Replace dark navy + system fonts with parchment grid background, green title banner with Rye font, paper-card text field, and green/outlined buttons.

- [ ] **Step 1: Rewrite HomeView.swift**

Replace the entire contents of `RoadTripBingo/Views/HomeView.swift` with:

```swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            VStack(spacing: 28) {
                Text("🚗").font(.system(size: 72))

                // Title banner
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AmericanaTheme.green)
                        .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 4)
                        .shadow(color: AmericanaTheme.shadow, radius: 20, x: 0, y: 6)
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AmericanaTheme.yellow)
                            .frame(width: 6).padding(.vertical, 12).padding(.leading, 10)
                        VStack(spacing: 4) {
                            Text("Road Trip Bingo")
                                .font(AmericanaTheme.rye(28))
                                .foregroundColor(.white)
                            Text("★ SPOT IT TO CLAIM IT ★")
                                .font(AmericanaTheme.barlowSemiBold(11))
                                .foregroundColor(AmericanaTheme.yellow)
                        }
                        .frame(maxWidth: .infinity)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AmericanaTheme.yellow)
                            .frame(width: 6).padding(.vertical, 12).padding(.trailing, 10)
                    }
                }
                .frame(maxWidth: 400)
                .frame(height: 88)

                // Name field
                TextField("Enter your name", text: $appState.playerName)
                    .font(AmericanaTheme.barlowSemiBold(17))
                    .foregroundColor(AmericanaTheme.ink)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .frame(maxWidth: 360)

                // Buttons
                VStack(spacing: 14) {
                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.createGame()
                    }) {
                        Text("Create Game")
                            .font(AmericanaTheme.barlowBold(17))
                            .frame(maxWidth: 360).padding()
                            .background(AmericanaTheme.green)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.joinGame()
                    }) {
                        Text("Join Game")
                            .font(AmericanaTheme.barlowBold(17))
                            .frame(maxWidth: 360).padding()
                            .background(Color.clear)
                            .foregroundColor(AmericanaTheme.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(AmericanaTheme.green, lineWidth: 2)
                            )
                            .cornerRadius(14)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(48)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/HomeView.swift
git commit -m "feat: rewrite HomeView with Americana title banner and paper-card inputs"
```

---

### Task 9: LobbyView — Americana Redesign

**Files:**
- Modify: `RoadTripBingo/Views/LobbyView.swift`

Replace dark navy + system fonts with parchment background, Rye headings, Barlow Condensed body text, paper-card player rows, and green/outlined buttons.

- [ ] **Step 1: Rewrite LobbyView.swift**

Replace the entire contents of `RoadTripBingo/Views/LobbyView.swift` with:

```swift
import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            if appState.isHost { hostView } else { joinerView }
        }
    }

    private var hostView: some View {
        VStack(spacing: 28) {
            Text("Lobby")
                .font(AmericanaTheme.rye(28))
                .foregroundColor(AmericanaTheme.ink)
            Text("Other players appear automatically nearby")
                .font(AmericanaTheme.barlowSemiBold(14))
                .foregroundColor(AmericanaTheme.ink.opacity(0.6))
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
                    .font(AmericanaTheme.barlowBold(17))
                    .frame(maxWidth: 360).padding()
                    .background(appState.connectedPlayerNames.isEmpty
                                ? AmericanaTheme.green.opacity(0.4)
                                : AmericanaTheme.green)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .disabled(appState.connectedPlayerNames.isEmpty)
            if appState.connectedPlayerNames.isEmpty {
                Text("Waiting for players to join…")
                    .font(AmericanaTheme.barlowSemiBold(14))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.6))
            }
            Button("Cancel", role: .destructive, action: appState.goHome)
                .font(AmericanaTheme.barlowSemiBold(15))
                .foregroundColor(AmericanaTheme.ink.opacity(0.5))
        }.padding(48)
    }

    private var joinerView: some View {
        VStack(spacing: 28) {
            Text("Join Game")
                .font(AmericanaTheme.rye(28))
                .foregroundColor(AmericanaTheme.ink)
            difficultyPicker
            if appState.connectedPlayerNames.isEmpty {
                VStack(spacing: 16) {
                    if appState.foundGameNames.isEmpty {
                        ProgressView().tint(AmericanaTheme.green)
                        Text("Looking for nearby games…")
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                    } else {
                        Text("Games nearby:")
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                        ForEach(appState.foundGameNames, id: \.self) { name in
                            Button(action: { appState.inviteGame(named: name) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(AmericanaTheme.barlowBold(16))
                                            .foregroundColor(AmericanaTheme.ink)
                                        Text("Tap to join")
                                            .font(AmericanaTheme.barlowSemiBold(12))
                                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(AmericanaTheme.green)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }.frame(maxWidth: 400)
            } else {
                VStack(spacing: 10) {
                    Text("Connected! Waiting for host…")
                        .font(AmericanaTheme.barlowSemiBold(14))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                    playerRow(name: appState.playerName, label: "you", difficulty: nil)
                    ForEach(appState.connectedPlayerNames, id: \.self) { playerRow(name: $0, label: nil, difficulty: nil) }
                }.frame(maxWidth: 400)
            }
            Button("Cancel", role: .destructive, action: appState.goHome)
                .font(AmericanaTheme.barlowSemiBold(15))
                .foregroundColor(AmericanaTheme.ink.opacity(0.5))
        }.padding(48)
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(BoardDifficulty.allCases, id: \.self) { difficulty in
                Button(action: { appState.chooseDifficulty(difficulty) }) {
                    Text(difficulty.displayName)
                        .font(AmericanaTheme.barlowSemiBold(14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            appState.playerDifficulty == difficulty
                                ? AmericanaTheme.green
                                : Color.clear
                        )
                        .foregroundColor(
                            appState.playerDifficulty == difficulty
                                ? .white
                                : AmericanaTheme.green
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(AmericanaTheme.green, lineWidth: appState.playerDifficulty == difficulty ? 0 : 1.5)
                        )
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: 400)
    }

    private func playerRow(name: String, label: String?, difficulty: BoardDifficulty?) -> some View {
        HStack(spacing: 12) {
            Circle().fill(AmericanaTheme.green).frame(width: 10, height: 10)
            Text(name)
                .font(AmericanaTheme.barlowBold(16))
                .foregroundColor(AmericanaTheme.ink)
            if let label {
                Text(label)
                    .font(AmericanaTheme.barlowSemiBold(12))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.6))
            }
            Spacer()
            if let difficulty {
                Text(difficulty.displayName)
                    .font(AmericanaTheme.barlowSemiBold(12))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.6))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                )
        )
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/LobbyView.swift
git commit -m "feat: rewrite LobbyView with Americana headings, paper-card rows, and green buttons"
```

---

### Task 10: WinView — Americana Redesign + Tile Image Strip

**Files:**
- Modify: `RoadTripBingo/Views/WinView.swift`

Replace dark navy + emoji row with parchment background, Rye heading, and a horizontal strip of winning tiles shown as white paper-card stickers using the PNG images.

- [ ] **Step 1: Rewrite WinView.swift**

Replace the entire contents of `RoadTripBingo/Views/WinView.swift` with:

```swift
import SwiftUI

struct WinView: View {
    let winnerName: String
    @EnvironmentObject var appState: AppState
    private var isLocalWin: Bool { winnerName == appState.playerName }

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            if isLocalWin { ConfettiView() }
            VStack(spacing: 32) {
                Text(isLocalWin ? "🏆" : "🎯").font(.system(size: 96))
                Text(isLocalWin ? "YOU GOT BINGO!" : "\(winnerName) got BINGO!")
                    .font(AmericanaTheme.rye(38))
                    .foregroundColor(isLocalWin ? AmericanaTheme.yellow : AmericanaTheme.ink)
                    .multilineTextAlignment(.center)
                if let line = appState.completedLine, isLocalWin, let board = appState.localBoard {
                    HStack(spacing: 8) {
                        ForEach(line, id: \.self) { pos in
                            winningTileCard(board.squares[pos])
                        }
                    }
                }
                Button(action: { appState.screen = .playAgain }) {
                    Text("Continue →")
                        .font(AmericanaTheme.barlowBold(17))
                        .padding(.horizontal, 48).padding(.vertical, 16)
                        .background(AmericanaTheme.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }.padding(48)
        }
    }

    private func winningTileCard(_ square: BingoSquare) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: AmericanaTheme.shadow, radius: 4, x: 0, y: 2)
            Group {
                if let img = AmericanaTheme.tileImage(for: square) {
                    img.resizable().scaledToFit()
                } else {
                    Text(square.emoji).font(.title)
                }
            }
            .padding(6)
            .frame(width: 48, height: 48)
        }
        .frame(width: 60, height: 60)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/WinView.swift
git commit -m "feat: rewrite WinView with Americana theme and tile image strip"
```

---

### Task 11: OpponentStripView — Colors, Fonts, Token Icon, Mini-Grid Colors

**Files:**
- Modify: `RoadTripBingo/Views/OpponentStripView.swift`

Update the container background, player name font, token display (PNG instead of 🟡), and mini-grid cell colors to use the Americana palette.

- [ ] **Step 1: Rewrite OpponentStripView.swift**

Replace the entire contents of `RoadTripBingo/Views/OpponentStripView.swift` with:

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
                            .font(AmericanaTheme.barlowSemiBold(12))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.8))
                        if let coins {
                            HStack(spacing: 2) {
                                if let img = AmericanaTheme.icon(named: "token") {
                                    img.resizable().scaledToFit().frame(width: 14, height: 14)
                                }
                                Text("\(coins)")
                                    .font(AmericanaTheme.barlowSemiBold(11))
                                    .foregroundColor(AmericanaTheme.ink)
                            }
                        }
                    }
                    MiniGridView(markedPositions: marked)
                    Text("\(marked.count) ✓")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AmericanaTheme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                )
        )
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
                            .fill(pos == 12 ? AmericanaTheme.yellow :
                                  markedPositions.contains(pos) ? AmericanaTheme.green :
                                  AmericanaTheme.ink.opacity(0.12))
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/OpponentStripView.swift
git commit -m "feat: update OpponentStripView to Americana colors, fonts, and token icon"
```

---

### Task 12: TargetingOverlayView — Ink Panel, PNG Icons, Tile Images

**Files:**
- Modify: `RoadTripBingo/Views/TargetingOverlayView.swift`

Replace the blue-grey panel with `AmericanaTheme.ink`, update the title line to use Rye font + power-up PNG icon + token PNG, and update `TargetTileView` to show tile PNG images with Americana border colors.

- [ ] **Step 1: Rewrite TargetingOverlayView.swift**

Replace the entire contents of `RoadTripBingo/Views/TargetingOverlayView.swift` with:

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
                HStack(spacing: 8) {
                    if let img = AmericanaTheme.icon(named: "powerup-\(powerUp.iconSlug)") {
                        img.resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                    Text("Select target")
                        .font(AmericanaTheme.rye(17))
                        .foregroundColor(.white)
                    HStack(spacing: 3) {
                        Text("·")
                        if let img = AmericanaTheme.icon(named: "token") {
                            img.resizable().scaledToFit().frame(width: 16, height: 16)
                        }
                        Text("\(powerUp.cost)")
                            .font(AmericanaTheme.barlowBold(15))
                    }
                    .foregroundColor(AmericanaTheme.yellow)
                }

                if powerUp.affectsOpponent {
                    opponentGrid
                } else {
                    selfGrid
                }

                Button("Cancel") { onCancel() }
                    .font(AmericanaTheme.barlowSemiBold(15))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.8)
            .padding(24)
            .background(AmericanaTheme.ink)
            .cornerRadius(20)
            .padding(20)
        }
    }

    @ViewBuilder private var selfGrid: some View {
        if let board = localBoard {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(0..<25, id: \.self) { idx in
                    let square = board.squares[idx]
                    let isFree = square.id == BingoSquare.freeSquareID
                    let isMarked = board.isMarked(at: idx)
                    let selectable: Bool = {
                        guard !isFree else { return false }
                        switch powerUp {
                        case .freeMark, .upgradeTileTargeted: return !isMarked
                        default: return true
                        }
                    }()
                    TargetTileView(square: square, isMarked: isMarked, isSelectable: selectable) {
                        if selectable { onSelect(nil, idx) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var opponentGrid: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(opponentBoards.keys.sorted(), id: \.self) { oppName in
                    let oppBoard = opponentBoards[oppName] ?? []
                    let marked = opponentMarked[oppName] ?? []
                    VStack(spacing: 8) {
                        Text(oppName)
                            .font(AmericanaTheme.barlowSemiBold(14))
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
            Group {
                if let img = AmericanaTheme.tileImage(for: square) {
                    img.resizable().scaledToFit()
                } else {
                    Text(square.emoji).font(.system(size: 14))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(square.text)
                .font(AmericanaTheme.barlowSemiBold(7))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            isMarked     ? AmericanaTheme.green.opacity(0.4) :
            isSelectable ? Color.white.opacity(0.12) :
                           Color.white.opacity(0.03)
        )
        .cornerRadius(6)
        .overlay(
            isSelectable
                ? RoundedRectangle(cornerRadius: 6)
                    .stroke(AmericanaTheme.yellow.opacity(0.8), lineWidth: 1.5)
                : nil
        )
        .opacity(isSelectable ? 1.0 : 0.35)
        .onTapGesture { onTap() }
    }
}

// Map PowerUpType to its icon file slug
private extension PowerUpType {
    var iconSlug: String {
        switch self {
        case .upgradeTileRandom, .upgradeTileTargeted:     return "upgrade"
        case .downgradeTileRandom, .downgradeTileTargeted: return "sabotage"
        case .freeMark:                                    return "freemark"
        case .unmarkOpponentRandom, .unmarkOpponentTargeted: return "erase"
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

Note: If `PowerUpType` enum cases differ from the switch above, adjust the `iconSlug` extension to match the actual case names. Check `RoadTripBingo/Models/PowerUp.swift` or similar for the exact enum definition.

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/TargetingOverlayView.swift
git commit -m "feat: update TargetingOverlayView with Americana ink panel, PNG icons, and tile images"
```

---

### Task 13: PlayAgainView — Americana Redesign

**Files:**
- Modify: `RoadTripBingo/Views/PlayAgainView.swift`

Replace dark navy + blue buttons with parchment grid background, Rye heading, paper-card standings rows, and green/outlined buttons.

- [ ] **Step 1: Rewrite PlayAgainView.swift**

Replace the entire contents of `RoadTripBingo/Views/PlayAgainView.swift` with:

```swift
import SwiftUI

struct PlayAgainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            VStack(spacing: 32) {
                Text("Session Standings")
                    .font(AmericanaTheme.rye(28))
                    .foregroundColor(AmericanaTheme.ink)
                VStack(spacing: 10) {
                    ForEach(appState.winHistory.sorted(by: { $0.value > $1.value }), id: \.key) { entry in
                        let name = entry.key
                        let wins = entry.value
                        HStack {
                            Text(wins == appState.winHistory.values.max() ? "🏆" : "  ")
                            Text(name)
                                .font(AmericanaTheme.barlowBold(16))
                                .foregroundColor(AmericanaTheme.ink)
                            Spacer()
                            Text("\(wins) win\(wins == 1 ? "" : "s")")
                                .font(AmericanaTheme.barlowSemiBold(13))
                                .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(AmericanaTheme.ink.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                }.frame(maxWidth: 400)
                VStack(spacing: 14) {
                    if appState.isHost {
                        Button(action: appState.requestPlayAgain) {
                            Text("New Game")
                                .font(AmericanaTheme.barlowBold(17))
                                .frame(maxWidth: 360).padding()
                                .background(AmericanaTheme.green)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    } else {
                        Text("Waiting for host to start a new game…")
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                    }
                    Button(action: appState.goHome) {
                        Text("Go Home")
                            .font(AmericanaTheme.barlowBold(17))
                            .frame(maxWidth: 360).padding()
                            .background(Color.clear)
                            .foregroundColor(AmericanaTheme.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(AmericanaTheme.green, lineWidth: 2)
                            )
                            .cornerRadius(14)
                    }
                }
            }.padding(48)
        }
    }
}
```

- [ ] **Step 2: Build and verify (full clean build)**

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -10
# Expected: ** BUILD SUCCEEDED **
```

- [ ] **Step 3: Commit**

```bash
git add RoadTripBingo/Views/PlayAgainView.swift
git commit -m "feat: rewrite PlayAgainView with Americana theme"
```

---

## Final Verification

After all 13 tasks, do a complete clean build and run on the iPad simulator:

```bash
cd /Users/pmoore/Source/roadtrip-bingo
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo -destination 'platform=iOS Simulator,name=iPad (10th generation)' clean build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

Manual smoke-test checklist:
- [ ] Home screen shows parchment background, green title banner, paper text field
- [ ] Lobby shows Rye headings, green difficulty picker, paper-card player rows
- [ ] Game board shows BINGO header, paper background, tile PNG images in every cell
- [ ] FREE tile shows green background, star coin image, "FREE" in mustard yellow Rye font
- [ ] Tapping a tile shows SPOTTED! stamp
- [ ] Bingo line tiles get mustard yellow border
- [ ] BINGO button appears in Rye font on mustard yellow
- [ ] Power-up strip shows PNG icons, mustard token badge
- [ ] Win screen shows parchment background, mustard "YOU GOT BINGO!" in Rye, tile image strip
- [ ] Opponent strip shows paper card, green mini-grid marks
- [ ] Targeting overlay shows dark ink panel, PNG power-up icon, tile images in grid
- [ ] Play Again screen shows parchment background, paper-card standings rows
