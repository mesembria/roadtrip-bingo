import Foundation

enum PatternShape: String, Codable, CaseIterable, Equatable {
    case x
    case fourCorners
    case plus

    var positions: [Int] {
        switch self {
        case .x:           return [0, 4, 6, 8, 12, 16, 18, 20, 24]
        case .fourCorners: return [0, 4, 20, 24]
        case .plus:        return [2, 7, 10, 11, 12, 13, 14, 17, 22]
        }
    }

    var displayName: String {
        switch self {
        case .x:           return "X Shape"
        case .fourCorners: return "Four Corners"
        case .plus:        return "Plus Sign"
        }
    }
}

enum RoundModifier: Codable, Equatable {
    case hotStreak
    case doubleDown
    case noPowers
    case sniper
    case patternWin(PatternShape)
    case fogOfWar
    case shiftingTiles
    case shuffleBoard

    static func random() -> RoundModifier {
        let base: [RoundModifier] = [.hotStreak, .doubleDown, .noPowers, .sniper,
                                     .fogOfWar, .shiftingTiles, .shuffleBoard]
        let withPatterns: [RoundModifier] = PatternShape.allCases.map { .patternWin($0) }
        return (base + withPatterns).randomElement()!
    }

    var emoji: String {
        switch self {
        case .hotStreak:        return "🔥"
        case .doubleDown:       return "💰"
        case .noPowers:         return "🚫"
        case .sniper:           return "🎯"
        case .patternWin:       return "🗺️"
        case .fogOfWar:         return "🌫️"
        case .shiftingTiles:    return "🌊"
        case .shuffleBoard:     return "🔀"
        }
    }

    var shortName: String {
        switch self {
        case .hotStreak:            return "Hot Streak"
        case .doubleDown:           return "Double Down"
        case .noPowers:             return "No Powers"
        case .sniper:               return "Sniper"
        case .patternWin(let s):    return s.displayName
        case .fogOfWar:             return "Fog of War"
        case .shiftingTiles:        return "Shifting Tiles"
        case .shuffleBoard:         return "Shuffle Board"
        }
    }

    var ruleDescription: String {
        switch self {
        case .hotStreak:
            return "First to mark 3 tiles in any line wins instantly."
        case .doubleDown:
            return "All token earnings are doubled this round."
        case .noPowers:
            return "Power-ups are disabled. Pure spotting only."
        case .sniper:
            return "Attack power-ups cost 1 token less."
        case .patternWin(let shape):
            return "Must complete the \(shape.displayName) pattern to win."
        case .fogOfWar:
            return "10 tiles start hidden. Each opponent mark shifts the fog. Every 3rd shift clears one tile."
        case .shiftingTiles:
            return "Each time an opponent spots something, one of your unmarked tiles is replaced."
        case .shuffleBoard:
            return "Each time an opponent spots something, your unmarked tile positions shuffle."
        }
    }

    // MARK: - Manual Codable

    private enum CodingKeys: String, CodingKey { case type, shape }
    private enum ModifierType: String, Codable {
        case hotStreak, doubleDown, noPowers, sniper, patternWin, fogOfWar, shiftingTiles, shuffleBoard
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hotStreak:     try c.encode(ModifierType.hotStreak, forKey: .type)
        case .doubleDown:    try c.encode(ModifierType.doubleDown, forKey: .type)
        case .noPowers:      try c.encode(ModifierType.noPowers, forKey: .type)
        case .sniper:        try c.encode(ModifierType.sniper, forKey: .type)
        case .fogOfWar:      try c.encode(ModifierType.fogOfWar, forKey: .type)
        case .shiftingTiles: try c.encode(ModifierType.shiftingTiles, forKey: .type)
        case .shuffleBoard:  try c.encode(ModifierType.shuffleBoard, forKey: .type)
        case .patternWin(let shape):
            try c.encode(ModifierType.patternWin, forKey: .type)
            try c.encode(shape, forKey: .shape)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ModifierType.self, forKey: .type)
        switch type {
        case .hotStreak:     self = .hotStreak
        case .doubleDown:    self = .doubleDown
        case .noPowers:      self = .noPowers
        case .sniper:        self = .sniper
        case .fogOfWar:      self = .fogOfWar
        case .shiftingTiles: self = .shiftingTiles
        case .shuffleBoard:  self = .shuffleBoard
        case .patternWin:
            let shape = try c.decode(PatternShape.self, forKey: .shape)
            self = .patternWin(shape)
        }
    }
}
