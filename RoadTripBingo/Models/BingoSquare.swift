import Foundation

enum SquareRarity: String, Codable, CaseIterable {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare
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
