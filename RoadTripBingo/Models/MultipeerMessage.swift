import Foundation

enum MultipeerMessage: Codable {
    case gameStarted(boards: [String: [BingoSquare]])
    case squareToggled(position: Int, isMarked: Bool)
    case bingoAnnounced(byName: String)
    case playAgain(boards: [String: [BingoSquare]])
    case difficultyChosen(byName: String, difficulty: BoardDifficulty)
    case tokenEarned(byName: String, newBalance: Int)
    case powerUpUsed(byName: String, powerUp: PowerUpType, targetPlayer: String?,
                     targetIndex: Int?, replacementSquare: BingoSquare?)
    case reserveDealt(toName: String, squares: [BingoSquare])
    case roundModifier(RoundModifier)
    case boardShuffled(byName: String, squares: [BingoSquare])
    case handicapBonus(toPlayer: String, tokens: Int)

    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName, difficulty
        case newBalance, powerUp, targetPlayer, targetIndex, replacementSquare
        case toName, squares
        case modifier, shuffledSquares, shuffledByName
        case handicapToPlayer, handicapTokens
    }

    private enum MessageType: String, Codable {
        case gameStarted, squareToggled, bingoAnnounced, playAgain, difficultyChosen
        case tokenEarned, powerUpUsed, reserveDealt
        case roundModifier, boardShuffled, handicapBonus
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gameStarted(let boards):
            try c.encode(MessageType.gameStarted, forKey: .type)
            try c.encode(boards, forKey: .boards)
        case .squareToggled(let position, let isMarked):
            try c.encode(MessageType.squareToggled, forKey: .type)
            try c.encode(position, forKey: .position)
            try c.encode(isMarked, forKey: .isMarked)
        case .bingoAnnounced(let byName):
            try c.encode(MessageType.bingoAnnounced, forKey: .type)
            try c.encode(byName, forKey: .byName)
        case .playAgain(let boards):
            try c.encode(MessageType.playAgain, forKey: .type)
            try c.encode(boards, forKey: .boards)
        case .difficultyChosen(let byName, let difficulty):
            try c.encode(MessageType.difficultyChosen, forKey: .type)
            try c.encode(byName, forKey: .byName)
            try c.encode(difficulty, forKey: .difficulty)
        case .tokenEarned(let byName, let newBalance):
            try c.encode(MessageType.tokenEarned, forKey: .type)
            try c.encode(byName, forKey: .byName)
            try c.encode(newBalance, forKey: .newBalance)
        case .powerUpUsed(let byName, let powerUp, let targetPlayer, let targetIndex, let replacementSquare):
            try c.encode(MessageType.powerUpUsed, forKey: .type)
            try c.encode(byName, forKey: .byName)
            try c.encode(powerUp, forKey: .powerUp)
            try c.encodeIfPresent(targetPlayer, forKey: .targetPlayer)
            try c.encodeIfPresent(targetIndex, forKey: .targetIndex)
            try c.encodeIfPresent(replacementSquare, forKey: .replacementSquare)
        case .reserveDealt(let toName, let squares):
            try c.encode(MessageType.reserveDealt, forKey: .type)
            try c.encode(toName, forKey: .toName)
            try c.encode(squares, forKey: .squares)
        case .roundModifier(let modifier):
            try c.encode(MessageType.roundModifier, forKey: .type)
            try c.encode(modifier, forKey: .modifier)
        case .boardShuffled(let byName, let squares):
            try c.encode(MessageType.boardShuffled, forKey: .type)
            try c.encode(byName, forKey: .shuffledByName)
            try c.encode(squares, forKey: .shuffledSquares)
        case .handicapBonus(let toPlayer, let tokens):
            try c.encode(MessageType.handicapBonus, forKey: .type)
            try c.encode(toPlayer, forKey: .handicapToPlayer)
            try c.encode(tokens, forKey: .handicapTokens)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(MessageType.self, forKey: .type)
        switch type {
        case .gameStarted:
            self = .gameStarted(boards: try c.decode([String: [BingoSquare]].self, forKey: .boards))
        case .squareToggled:
            self = .squareToggled(
                position: try c.decode(Int.self, forKey: .position),
                isMarked: try c.decode(Bool.self, forKey: .isMarked)
            )
        case .bingoAnnounced:
            self = .bingoAnnounced(byName: try c.decode(String.self, forKey: .byName))
        case .playAgain:
            self = .playAgain(boards: try c.decode([String: [BingoSquare]].self, forKey: .boards))
        case .difficultyChosen:
            self = .difficultyChosen(
                byName: try c.decode(String.self, forKey: .byName),
                difficulty: try c.decode(BoardDifficulty.self, forKey: .difficulty)
            )
        case .tokenEarned:
            self = .tokenEarned(
                byName: try c.decode(String.self, forKey: .byName),
                newBalance: try c.decode(Int.self, forKey: .newBalance)
            )
        case .powerUpUsed:
            self = .powerUpUsed(
                byName: try c.decode(String.self, forKey: .byName),
                powerUp: try c.decode(PowerUpType.self, forKey: .powerUp),
                targetPlayer: try c.decodeIfPresent(String.self, forKey: .targetPlayer),
                targetIndex: try c.decodeIfPresent(Int.self, forKey: .targetIndex),
                replacementSquare: try c.decodeIfPresent(BingoSquare.self, forKey: .replacementSquare)
            )
        case .reserveDealt:
            self = .reserveDealt(
                toName: try c.decode(String.self, forKey: .toName),
                squares: try c.decode([BingoSquare].self, forKey: .squares)
            )
        case .roundModifier:
            self = .roundModifier(try c.decode(RoundModifier.self, forKey: .modifier))
        case .boardShuffled:
            self = .boardShuffled(
                byName: try c.decode(String.self, forKey: .shuffledByName),
                squares: try c.decode([BingoSquare].self, forKey: .shuffledSquares)
            )
        case .handicapBonus:
            self = .handicapBonus(
                toPlayer: try c.decode(String.self, forKey: .handicapToPlayer),
                tokens: try c.decode(Int.self, forKey: .handicapTokens)
            )
        }
    }
}
