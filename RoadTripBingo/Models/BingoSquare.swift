import Foundation

enum SquareRarity: String, Codable, CaseIterable {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare

    var scoreBonus: Int {
        switch self {
        case .veryCommon: return 0
        case .common:     return 1
        case .uncommon:   return 2
        case .rare:       return 4
        case .veryRare:   return 7
        }
    }

    /// Points awarded in Spotting Race — tuned independently of Bingo's scoreBonus.
    var spottingRaceScore: Int {
        switch self {
        case .veryCommon: return 1
        case .common:     return 2
        case .uncommon:   return 3
        case .rare:       return 5
        case .veryRare:   return 8
        }
    }

    /// Weighted draw probability for the rolling tile pool (weights sum to 100).
    var spottingRaceWeight: Int {
        switch self {
        case .veryCommon: return 25
        case .common:     return 30
        case .uncommon:   return 25
        case .rare:       return 15
        case .veryRare:   return 5
        }
    }
}

enum SquareCategory: String, Codable, CaseIterable {
    case vehicles, nature, food, landmarks, weather, signs
}

struct BingoSquare: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let emoji: String?
    let category: SquareCategory
    let rarity: SquareRarity

    static let freeSquareID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let free = BingoSquare(
        id: freeSquareID,
        text: "FREE",
        emoji: "⭐",
        category: .landmarks,
        rarity: .veryCommon
    )
}
