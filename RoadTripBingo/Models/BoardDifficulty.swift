import Foundation

enum BoardDifficulty: String, Codable, CaseIterable {
    case backseat
    case shotgun
    case navigator

    var displayName: String {
        switch self {
        case .backseat:  return "Backseat"
        case .shotgun:   return "Shotgun"
        case .navigator: return "Navigator"
        }
    }

    // Fractional weight per rarity tier. Values sum to 1.0.
    var weights: [SquareRarity: Double] {
        switch self {
        case .backseat:
            return [.veryCommon: 0.40, .common: 0.35, .uncommon: 0.20, .rare: 0.05, .veryRare: 0.00]
        case .shotgun:
            return [.veryCommon: 0.20, .common: 0.30, .uncommon: 0.30, .rare: 0.15, .veryRare: 0.05]
        case .navigator:
            return [.veryCommon: 0.05, .common: 0.15, .uncommon: 0.30, .rare: 0.35, .veryRare: 0.15]
        }
    }
}
