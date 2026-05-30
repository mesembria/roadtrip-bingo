# Americana Visual Redesign + Tile Images Design

## Overview

Replace the current dark-navy emoji-based bingo app with a vintage Americana road atlas aesthetic across all screens. Tile emojis are replaced by 182 AI-generated flat vector PNG illustrations. Power-up icons and the token icon are replaced by matching Americana-style PNGs. Custom fonts (Rye + Barlow Condensed) establish the typographic identity.

---

## Assets & Infrastructure

### Tile Images
- **Source:** `.superpowers/brainstorm/sample-tiles/{UUID}.png` — 182 files, named by tile UUID.
- **Destination:** `RoadTripBingo/Resources/TileImages/` — added as a folder reference in Xcode (not a group), so all files are accessible via `Bundle.main`.
- **Loading:** `Bundle.main.path(forResource: square.id.uuidString, ofType: "png", inDirectory: "TileImages")` → `UIImage(contentsOfFile:)` → wrapped in SwiftUI `Image`.
- **Fallback:** If an image file is missing, display the tile's existing `emoji` field. The `emoji` field on `BingoSquare` is retained but otherwise unused in the UI.

### Icon Images
- **Source:** `.superpowers/brainstorm/powerup-icons/`
- **Destination:** `RoadTripBingo/Resources/Icons/`
- **Files:**
  - `upgrade.png` → `powerup-upgrade.png`
  - `sabotage.png` → `powerup-sabotage.png`
  - `freemark.png` → `powerup-freemark.png`
  - `erase.png` → `powerup-erase.png`
  - `token-a.png` → `token.png`
- **Loading:** `Image(uiImage: UIImage(contentsOfFile: Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Icons")!)!)`

### Custom Fonts
- **Fonts:** `Rye-Regular.ttf`, `BarlowCondensed-SemiBold.ttf`, `BarlowCondensed-Bold.ttf`
- **Source:** Download from Google Fonts.
- **Destination:** `RoadTripBingo/Resources/Fonts/`
- **Registration:** Add font filenames to `Info.plist` under `UIAppFonts` array.
- **Usage:** Via `AmericanaTheme` helpers only — never hardcode font names elsewhere.

### AmericanaTheme.swift
New file at `RoadTripBingo/Views/AmericanaTheme.swift`. Static struct, no instances.

```swift
struct AmericanaTheme {
    // Colors
    static let parchment  = Color(red: 0.969, green: 0.941, blue: 0.890) // #F7F0E3
    static let paper      = Color(red: 0.929, green: 0.898, blue: 0.816) // #EDE5D0
    static let ink        = Color(red: 0.110, green: 0.071, blue: 0.035) // #1C1209
    static let green      = Color(red: 0.102, green: 0.361, blue: 0.165) // #1A5C2A
    static let greenLight = Color(red: 0.176, green: 0.478, blue: 0.243) // #2D7A3E
    static let yellow     = Color(red: 0.961, green: 0.784, blue: 0.000) // #F5C800
    static let red        = Color(red: 0.753, green: 0.224, blue: 0.169) // #C0392B
    static let shadow     = Color(red: 0.110, green: 0.071, blue: 0.035).opacity(0.18)

    // Fonts
    static func rye(_ size: CGFloat) -> Font {
        .custom("Rye-Regular", size: size)
    }
    static func barlowSemiBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-SemiBold", size: size)
    }
    static func barlowBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Bold", size: size)
    }

    // Background grid pattern (used in all screens)
    static func gridBackground() -> some View {
        AmericanaGridBackground()
    }
}
```

`AmericanaGridBackground` is a SwiftUI `View` that draws the parchment color plus a `Canvas`-based grid of thin ink lines at 28pt intervals at 4% opacity.

---

## BingoSquareView

Three visual states:

### Unmarked
- White background, 1pt ink border at 8% opacity, 8pt corner radius.
- Tile PNG fills the upper ~75% of the square via `Image` with `.resizable().scaledToFit()` and 4pt padding.
- Label strip at the bottom: white background with 1pt ink top border at 8% opacity. Text in Barlow Condensed SemiBold, 8.5pt, uppercase, ink color.
- Subtle drop shadow: ink color at 18% opacity, 2pt radius.
- Hover/tap: spring scale to 1.03, deeper shadow.

### Marked (SPOTTED!)
- Same image + label visible underneath.
- Overlay: semi-transparent white at 55% opacity fills the tile.
- "SPOTTED!" text in Rye font, 13pt, brick red, rotated −12°.
- Brick red border inside the tile at 2pt, rotated with the text, corner radius 6pt.
- Animates in with `.spring(response: 0.2)` scale from 0 → 1.

### FREE
- Forest green (`AmericanaTheme.green`) background.
- Star coin token image (or ⭐ fallback) centered, ~44pt.
- "FREE" label in Rye font, mustard yellow, 13pt, letter-spaced.
- Mustard yellow inner border at 2pt.

### Highlighted (bingo line)
- Mustard yellow outer stroke at 3pt replaces current yellow glow.

---

## BingoGridView

Gains a wrapping `VStack(spacing: 0)`:

1. **Column header bar** — forest green background, `HStack` of 5 equal cells each containing one letter (B, I, N, G, O) in Rye font, white, 20pt. Mustard yellow vertical bars (6pt wide, 60% height, 3pt corner radius) on the far left and far right edges. Rounded top corners (12pt), no bottom rounding.

2. **Grid area** — paper-toned background (`AmericanaTheme.paper`), rounded bottom corners (12pt). The `LazyVGrid` uses 6pt gaps. `padding(8)` inside.

3. **Outer shadow** — ink color at 18% opacity, 8pt radius, applied to the whole `VStack`.

---

## GameView

- Background: `AmericanaTheme.gridBackground().ignoresSafeArea()` replaces the current `Color(red:green:blue:)`.
- Portrait layout: `VStack` spacing tightened to match new component sizes.
- Landscape layout: unchanged structurally.
- **BINGO! button:** Rye font 22pt, mustard yellow background, ink foreground, 3pt mustard shadow below, 8pt corner radius. Replaces current `🎉 BINGO!` system font button.

---

## PowerUpStripView

- Background: `AmericanaTheme.green`, corner radius 12pt, shadow matching board.
- **Power-up buttons:** Each button shows a white square (44×44pt, 7pt corner radius) containing the PNG icon, with label in Barlow Condensed Bold 9pt uppercase at 75% white opacity below, and cost in Barlow Condensed Bold 12pt mustard yellow with the token PNG icon (14pt) inline.
- **Token badge:** Mustard yellow background, star coin PNG (26pt) + count in Barlow Condensed Bold 22pt ink.
- **Help button (?):** Barlow Condensed Bold 18pt, 75% white, same background treatment as power-up buttons, fixed 36pt width.
- Divider between help button and token badge: 1pt at 15% white opacity.
- Vertical layout (landscape): unchanged structurally, same visual treatment.

---

## HomeView

- Background: `AmericanaTheme.gridBackground().ignoresSafeArea()`.
- **Title banner:** Forest green rounded rectangle (12pt corners), full width, `padding(horizontal: 16)`. Contains "Road Trip Bingo" in Rye 28pt white + "★ spot it to claim it ★" in Barlow Condensed SemiBold 11pt mustard yellow caps. Mustard yellow vertical bars on each side. Box shadow: `0 4pt 0 #0F3518`, `0 6pt 20pt shadow`.
- 🚗 emoji (72pt) above the banner as a decorative accent.
- **Name field:** White paper card (12pt corner radius, 1pt ink border at 10% opacity), ink-colored text, Barlow Condensed SemiBold 17pt.
- **Create Game button:** `AmericanaTheme.green` fill, white Barlow Condensed Bold 17pt, 14pt corner radius.
- **Join Game button:** Outlined — `AmericanaTheme.green` border 2pt, green text, transparent fill.

---

## LobbyView

- Background: `AmericanaTheme.gridBackground().ignoresSafeArea()`.
- "Lobby" / "Join Game" headings: Rye font 28pt, ink color.
- Subheadings: Barlow Condensed SemiBold 14pt, ink at 60% opacity.
- **Player rows:** White paper card (10pt corner radius, 1pt border). Green filled circle indicator. Player name in Barlow Condensed Bold 16pt ink. Label/difficulty in SemiBold 12pt ink at 60%.
- **Difficulty picker:** Selected = green fill + white text. Unselected = outlined green. Barlow Condensed SemiBold 14pt.
- **Start Game / Cancel buttons:** Same green/outlined style as HomeView.
- `ProgressView` tint: `AmericanaTheme.green`.

---

## WinView

- Background: `AmericanaTheme.gridBackground().ignoresSafeArea()` with `ConfettiView` on top.
- **Win headline:** "YOU GOT BINGO!" in Rye font 38pt, mustard yellow (local win) or ink (opponent win). Multiline center-aligned.
- **Trophy / target:** Keeps existing emoji (🏆 / 🎯) at 96pt — no change.
- **Winning tile strip:** Replaces the current emoji row. Each of the 5 winning tiles shown as a white paper card (8pt corner radius, 1pt border, drop shadow) containing the tile's PNG image (48×48pt, `.scaledToFit()`) — same white-card sticker look as the board tiles, no label. Horizontal `HStack` with 8pt gaps.
- **Continue button:** Forest green fill, "Continue →" in Barlow Condensed Bold 17pt white, 14pt corner radius.

---

## OpponentStripView

Shown above the board during multiplayer. Sits on the parchment background so needs to read clearly on light.

- Container: `AmericanaTheme.paper` background, 1pt ink border at 10% opacity, 12pt corner radius. Replaces current `Color.white.opacity(0.05)`.
- Player name: Barlow Condensed SemiBold 12pt, ink at 80%.
- Token count: token PNG icon (14pt) inline + count in Barlow Condensed SemiBold 11pt ink, replacing `🟡` emoji.
- `MiniGridView` cell colors:
  - FREE cell: `AmericanaTheme.yellow`
  - Marked: `AmericanaTheme.green`
  - Unmarked: `AmericanaTheme.ink.opacity(0.12)`
- Count label ("N ✓"): Barlow Condensed SemiBold 10pt, ink at 60%.

---

## TargetingOverlayView

Full-screen targeting overlay. The dark translucent backdrop is intentional — keep it dark to focus attention.

- Backdrop: `Color.black.opacity(0.75)` — unchanged.
- Panel background: `AmericanaTheme.ink` (very dark brown) instead of blue-grey. 20pt corner radius.
- Title: "Select target" in Rye font 17pt white. Power-up icon PNG (20pt) replaces the emoji. Cost shown with token PNG (16pt) inline instead of `🟡`.
- Cancel button: Barlow Condensed SemiBold 15pt, white at 50% opacity.
- `TargetTileView`:
  - Shows tile PNG image (filling the tile) instead of `square.emoji`.
  - Selectable border: `AmericanaTheme.yellow.opacity(0.8)` at 1.5pt.
  - Marked background: `AmericanaTheme.green.opacity(0.4)` instead of blue.
  - Non-selectable: same reduced opacity (0.35).
  - Label text: Barlow Condensed SemiBold 7pt, white at 80%.

---

## PlayAgainView

- Background: `AmericanaTheme.gridBackground().ignoresSafeArea()`.
- "Session Standings" heading: Rye font 28pt, ink.
- Standings rows: white paper card (10pt corner radius, 1pt ink border at 8% opacity). Player name in Barlow Condensed Bold 16pt ink. Win count in Barlow Condensed SemiBold 13pt ink at 60%. Trophy emoji (🏆) kept as-is.
- "New Game" button: `AmericanaTheme.green` fill, Barlow Condensed Bold 17pt white. Replaces `Color.blue`.
- "Go Home" button: outlined green border 2pt, green text, transparent fill. Replaces `Color.white.opacity(0.10)`.
- "Waiting for host…" text: Barlow Condensed SemiBold 14pt, ink at 60%.

---

## Files Changed

| File | Change |
|------|--------|
| `Info.plist` | Add `UIAppFonts` entries for 3 font files |
| `RoadTripBingo/Resources/TileImages/` | New folder — 182 PNGs |
| `RoadTripBingo/Resources/Icons/` | New folder — 5 PNGs |
| `RoadTripBingo/Resources/Fonts/` | New folder — 3 TTF files |
| `AmericanaTheme.swift` | New file |
| `BingoSquareView.swift` | Full rewrite |
| `BingoGridView.swift` | Add header bar + paper background wrapper |
| `GameView.swift` | Background swap, BINGO! button restyle |
| `PowerUpStripView.swift` | Full visual rewrite (PNG icons, token badge) |
| `HomeView.swift` | Full visual rewrite |
| `LobbyView.swift` | Full visual rewrite |
| `WinView.swift` | Full visual rewrite |
| `OpponentStripView.swift` | Colors, fonts, token icon, mini-grid colors |
| `TargetingOverlayView.swift` | Panel color, fonts, tile images, token icon |
| `PlayAgainView.swift` | Full visual rewrite |

## Out of Scope

- Any changes to game logic, networking, or data models.
- `BingoSquare.emoji` field — retained as image fallback, no model changes.
