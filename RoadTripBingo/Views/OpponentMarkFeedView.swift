// RoadTripBingo/Views/OpponentMarkFeedView.swift
import SwiftUI

struct OpponentMarkFeedView: View {
    let marks: [RecentMark]
    let isLandscape: Bool

    var body: some View {
        if isLandscape {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(marks) { mark in
                    RecentMarkCard(mark: mark, isLandscape: true)
                }
            }
            .animation(.spring(response: 0.25), value: marks)
        } else {
            HStack(spacing: 8) {
                ForEach(marks) { mark in
                    RecentMarkCard(mark: mark, isLandscape: false)
                }
            }
            .clipped()
            .animation(.spring(response: 0.25), value: marks)
        }
    }
}
