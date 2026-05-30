import Foundation

/// A lightweight reference to a tile within a pack: just the tile UUID and pack-specific rarity.
/// Full tile metadata (name, category, image) always lives in squares.json.
struct PackTileRef: Codable {
    let id: String
    let rarity: SquareRarity
}

struct TilePack: Codable, Identifiable {
    /// Stable string ID matching the JSON filename suffix (e.g. "farm-country").
    let id: String
    /// Display name shown in the pack selection grid.
    let name: String
    /// Short flavor text shown below the pack name.
    let description: String
    /// Asset catalog image name for the pack card image.
    let imageName: String
    /// Explicit curated list of tile refs. Every tile in this pack appears here.
    let tiles: [PackTileRef]
}
