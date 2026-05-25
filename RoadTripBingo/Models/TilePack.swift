import Foundation

struct TilePack: Codable, Identifiable {
    /// Stable string ID matching the JSON filename suffix (e.g. "farm-country").
    let id: String
    /// Display name shown in the pack selection grid.
    let name: String
    /// Short flavor text shown below the pack name.
    let description: String
    /// Asset catalog image name for the AI-generated pack card image.
    let imageName: String
    /// Pack-exclusive tiles — only appear when this pack is active.
    let tiles: [BingoSquare]
    /// Base tile UUID string → new rarity. Applied via most-common-wins when multiple packs are active.
    let rarityOverrides: [String: SquareRarity]
    /// Base tile UUID strings to remove when this pack is active.
    let excludedTileIDs: [String]
}
