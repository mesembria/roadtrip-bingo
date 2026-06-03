// RoadTripBingo/Models/MultipeerMessage.swift
import Foundation

enum MultipeerMessage: Codable {
    // Existing cases — gameStarted and playAgain now carry gameType
    case gameStarted(boards: [String: [BingoSquare]], activePackIDs: [String], gameType: GameType)
    case squareToggled(position: Int, isMarked: Bool)
    case bingoAnnounced(byName: String)
    case playAgain(boards: [String: [BingoSquare]], activePackIDs: [String], gameType: GameType)
    case difficultyChosen(byName: String, difficulty: BoardDifficulty)
    case tokenEarned(byName: String, newBalance: Int)
    case powerUpUsed(byName: String, powerUp: PowerUpType, targetPlayer: String?,
                     targetIndex: Int?, replacementSquare: BingoSquare?)
    case reserveDealt(toName: String, squares: [BingoSquare])
    case roundModifier(RoundModifier)
    case boardShuffled(byName: String, squares: [BingoSquare])
    case handicapBonus(toPlayer: String, tokens: Int)

    // Spotting Race cases
    case lockTile(slotID: UUID, squareID: UUID, byName: String, timestamp: Date)
    case releaseTile(slotID: UUID, byName: String)
    case claimTile(slotID: UUID, squareID: UUID, byName: String, timestamp: Date)
    case tileReplaced(slotID: UUID, replacement: BingoSquare, expiresAt: Date)
    case spottingRoundEnded(scores: [String: Int])

    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName, difficulty
        case newBalance, powerUp, targetPlayer, targetIndex, replacementSquare
        case toName, squares
        case modifier, shuffledSquares, shuffledByName
        case handicapToPlayer, handicapTokens
        case activePackIDs
        case gameType
        case slotID, squareID, expiresAt, lockTimestamp, spottingScores
    }

    private enum MessageType: String, Codable {
        case gameStarted, squareToggled, bingoAnnounced, playAgain, difficultyChosen
        case tokenEarned, powerUpUsed, reserveDealt
        case roundModifier, boardShuffled, handicapBonus
        case lockTile, releaseTile, claimTile, tileReplaced, spottingRoundEnded
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gameStarted(let boards, let activePackIDs, let gameType):
            try c.encode(MessageType.gameStarted, forKey: .type)
            try c.encode(boards, forKey: .boards)
            try c.encode(activePackIDs, forKey: .activePackIDs)
            try c.encode(gameType, forKey: .gameType)
        case .squareToggled(let position, let isMarked):
            try c.encode(MessageType.squareToggled, forKey: .type)
            try c.encode(position, forKey: .position)
            try c.encode(isMarked, forKey: .isMarked)
        case .bingoAnnounced(let byName):
            try c.encode(MessageType.bingoAnnounced, forKey: .type)
            try c.encode(byName, forKey: .byName)
        case .playAgain(let boards, let activePackIDs, let gameType):
            try c.encode(MessageType.playAgain, forKey: .type)
            try c.encode(boards, forKey: .boards)
            try c.encode(activePackIDs, forKey: .activePackIDs)
            try c.encode(gameType, forKey: .gameType)
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
        case .lockTile(let slotID, let squareID, let byName, let timestamp):
            try c.encode(MessageType.lockTile, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(squareID, forKey: .squareID)
            try c.encode(byName, forKey: .byName)
            try c.encode(timestamp, forKey: .lockTimestamp)
        case .releaseTile(let slotID, let byName):
            try c.encode(MessageType.releaseTile, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(byName, forKey: .byName)
        case .claimTile(let slotID, let squareID, let byName, let timestamp):
            try c.encode(MessageType.claimTile, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(squareID, forKey: .squareID)
            try c.encode(byName, forKey: .byName)
            try c.encode(timestamp, forKey: .lockTimestamp)
        case .tileReplaced(let slotID, let replacement, let expiresAt):
            try c.encode(MessageType.tileReplaced, forKey: .type)
            try c.encode(slotID, forKey: .slotID)
            try c.encode(replacement, forKey: .replacementSquare)
            try c.encode(expiresAt, forKey: .expiresAt)
        case .spottingRoundEnded(let scores):
            try c.encode(MessageType.spottingRoundEnded, forKey: .type)
            try c.encode(scores, forKey: .spottingScores)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(MessageType.self, forKey: .type)
        switch type {
        case .gameStarted:
            self = .gameStarted(
                boards: try c.decode([String: [BingoSquare]].self, forKey: .boards),
                activePackIDs: (try? c.decodeIfPresent([String].self, forKey: .activePackIDs)) ?? [],
                gameType: (try? c.decodeIfPresent(GameType.self, forKey: .gameType)) ?? .bingo
            )
        case .squareToggled:
            self = .squareToggled(
                position: try c.decode(Int.self, forKey: .position),
                isMarked: try c.decode(Bool.self, forKey: .isMarked)
            )
        case .bingoAnnounced:
            self = .bingoAnnounced(byName: try c.decode(String.self, forKey: .byName))
        case .playAgain:
            self = .playAgain(
                boards: try c.decode([String: [BingoSquare]].self, forKey: .boards),
                activePackIDs: (try? c.decodeIfPresent([String].self, forKey: .activePackIDs)) ?? [],
                gameType: (try? c.decodeIfPresent(GameType.self, forKey: .gameType)) ?? .bingo
            )
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
        case .lockTile:
            self = .lockTile(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                squareID: try c.decode(UUID.self, forKey: .squareID),
                byName: try c.decode(String.self, forKey: .byName),
                timestamp: try c.decode(Date.self, forKey: .lockTimestamp)
            )
        case .releaseTile:
            self = .releaseTile(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                byName: try c.decode(String.self, forKey: .byName)
            )
        case .claimTile:
            self = .claimTile(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                squareID: try c.decode(UUID.self, forKey: .squareID),
                byName: try c.decode(String.self, forKey: .byName),
                timestamp: try c.decode(Date.self, forKey: .lockTimestamp)
            )
        case .tileReplaced:
            self = .tileReplaced(
                slotID: try c.decode(UUID.self, forKey: .slotID),
                replacement: try c.decode(BingoSquare.self, forKey: .replacementSquare),
                expiresAt: try c.decode(Date.self, forKey: .expiresAt)
            )
        case .spottingRoundEnded:
            self = .spottingRoundEnded(
                scores: try c.decode([String: Int].self, forKey: .spottingScores)
            )
        }
    }
}
