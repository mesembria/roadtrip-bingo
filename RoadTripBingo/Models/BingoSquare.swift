import Foundation

enum SquareCategory: String, Codable, CaseIterable {
    case vehicles, nature, food, landmarks, weather, signs
}

struct BingoSquare: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let emoji: String
    let category: SquareCategory

    static let freeSquareID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let free = BingoSquare(
        id: freeSquareID,
        text: "FREE",
        emoji: "⭐",
        category: .landmarks
    )
}
