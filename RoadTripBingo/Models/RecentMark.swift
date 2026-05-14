import Foundation

struct RecentMark: Identifiable, Equatable, Sendable {
    let id: UUID = UUID()
    let opponentName: String
    let square: BingoSquare
    let timestamp: Date
}
