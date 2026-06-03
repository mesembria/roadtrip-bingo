import Foundation

struct SpottingRaceTile: Identifiable {
    /// Slot identity — stable across tile replacements so SwiftUI animates the slot.
    let id: UUID
    let square: BingoSquare
    let expiresAt: Date
    var claimedBy: String?     // nil = unclaimed
    var lockedBy: String?      // nil = free; set during soft-claim window
    var lockTimestamp: Date?   // used for conflict resolution

    /// True when fewer than 3 seconds remain before expiry.
    var isExpiring: Bool { expiresAt.timeIntervalSinceNow < 3 }
}
