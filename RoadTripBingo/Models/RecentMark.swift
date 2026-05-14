// RoadTripBingo/Models/RecentMark.swift
import Foundation

struct RecentMark: Identifiable {
    let id: UUID
    let opponentName: String
    let square: BingoSquare
    let timestamp: Date
}
