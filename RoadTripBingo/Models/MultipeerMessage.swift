import Foundation

enum MultipeerMessage: Codable {
    case gameStarted(boards: [String: [BingoSquare]])
    case squareToggled(position: Int, isMarked: Bool)
    case bingoAnnounced(byName: String)
    case playAgain(boards: [String: [BingoSquare]])

    private enum CodingKeys: String, CodingKey {
        case type, boards, position, isMarked, byName
    }

    private enum MessageType: String, Codable {
        case gameStarted, squareToggled, bingoAnnounced, playAgain
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
        }
    }
}
