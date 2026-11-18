# Road Trip Bingo

A multiplayer bingo game for iPad, built for long family drives. Each player gets a 5×5 board of things to spot out the window (a state capitol, a fire truck, a flatbed hauling hay bales), and the iPads in the car play together over a local peer-to-peer connection, with no internet needed.

## Features

- **Local multiplayer.** Devices find each other and sync over Apple's MultipeerConnectivity, so it works in a car with no signal.
- **Non-overlapping boards.** A weighted deal by rarity tier means no two players share a square.
- **Token economy and power-ups.** Players earn tokens for first marks, close calls, completed lines and BINGOs, and spend them on power-ups.
- **Live opponent feed.** When an opponent marks a tile, a fading card shows what they spotted.
- **Themed tile packs.** Base, City, Interstate, Mountains, Farm Country, Desert Southwest and Beach & Coast, with an illustrated image for every tile.
- **Americana visual theme.** Parchment, ink and road-sign colors, with layouts tuned for portrait and landscape.

## Tech

- Swift 5.9 and SwiftUI, iOS 17+, iPad only
- MultipeerConnectivity for device-to-device networking
- XCTest unit tests (`RoadTripBingoTests/`)
- Python tooling in `tools/`, including a local web-based tile manager for editing packs and generating tile art

## Project layout

```
RoadTripBingo/
  State/       AppState: single source of truth, drives navigation
  Network/     MultipeerSession and the Codable message protocol
  Game/        GameEngine (win and close-call detection), SquarePool (dealing)
  Models/      Value types (squares, packs, power-ups, recent marks)
  Views/       SwiftUI screens and the AmericanaTheme design system
  Resources/   Tile packs (JSON), tile images, icons, fonts
RoadTripBingoTests/   Unit tests
tools/                Pack migration and tile management scripts
docs/                 Design specs and implementation plans
```

## Build and run

Open `RoadTripBingo.xcodeproj` in Xcode and run the `RoadTripBingo` scheme on an iPad or an iPad simulator. Or use the command line:

```bash
# Build
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingo \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

# Test
xcodebuild -project RoadTripBingo.xcodeproj -scheme RoadTripBingoTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test
```

To try multiplayer, run it on two or more iPads (or simulators) on the same network.

## Credits

- Fonts: [Rye](https://fonts.google.com/specimen/Rye) and [Barlow Condensed](https://fonts.google.com/specimen/Barlow+Condensed), under the SIL Open Font License 1.1. The license texts are in `RoadTripBingo/Resources/Fonts/`.

## License

The code is released under the MIT License (see [LICENSE](LICENSE)). The bundled fonts keep their own license, the SIL Open Font License.
