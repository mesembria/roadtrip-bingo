import Foundation

enum PowerUpType: String, Codable, CaseIterable {
    case upgradeTileRandom
    case upgradeTileTargeted
    case downgradeTileRandom
    case downgradeTileTargeted
    case freeMark
    case unmarkOpponentRandom
    case unmarkOpponentTargeted

    var cost: Int {
        switch self {
        case .upgradeTileRandom, .downgradeTileRandom:                              return 3
        case .unmarkOpponentRandom:                                                 return 4
        case .freeMark:                                                             return 5
        case .upgradeTileTargeted, .downgradeTileTargeted, .unmarkOpponentTargeted: return 7
        }
    }

    var isTargeted: Bool {
        switch self {
        case .upgradeTileTargeted, .downgradeTileTargeted,
             .freeMark, .unmarkOpponentTargeted: return true
        default: return false
        }
    }

    var affectsOpponent: Bool {
        switch self {
        case .downgradeTileRandom, .downgradeTileTargeted,
             .unmarkOpponentRandom, .unmarkOpponentTargeted: return true
        default: return false
        }
    }

    // Emoji for the power-up category (same for random and targeted variants).
    var emoji: String {
        switch self {
        case .upgradeTileRandom, .upgradeTileTargeted:       return "🔀"
        case .downgradeTileRandom, .downgradeTileTargeted:   return "💣"
        case .freeMark:                                       return "✅"
        case .unmarkOpponentRandom, .unmarkOpponentTargeted: return "💥"
        }
    }
}
