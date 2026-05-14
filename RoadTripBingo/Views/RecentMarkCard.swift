// RoadTripBingo/Views/RecentMarkCard.swift
import SwiftUI

struct RecentMarkCard: View {
    let mark: RecentMark
    let isLandscape: Bool
    @State private var opacity: Double = 1.0

    var body: some View {
        Group {
            if isLandscape { landscapePill } else { portraitSquare }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.linear(duration: 10)) { opacity = 0 }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private var landscapePill: some View {
        HStack(spacing: 0) {
            tileImage
                .frame(width: 44, height: 44)
                .clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(mark.opponentName.uppercased())
                    .font(AmericanaTheme.barlowSemiBold(9))
                    .foregroundColor(AmericanaTheme.greenLight)
                    .lineLimit(1)
                Text(mark.square.text)
                    .font(AmericanaTheme.barlowBold(10))
                    .foregroundColor(AmericanaTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AmericanaTheme.parchment)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(Color(red: 0.545, green: 0.412, blue: 0.078), lineWidth: 2))
        .cornerRadius(6)
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 1, y: 1)
    }

    private var portraitSquare: some View {
        VStack(spacing: 0) {
            Text(mark.opponentName.uppercased())
                .font(AmericanaTheme.barlowSemiBold(9))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(AmericanaTheme.green)
            tileImage
                .frame(width: 68, height: 54)
                .clipped()
            Text(mark.square.text)
                .font(AmericanaTheme.barlowBold(9))
                .foregroundColor(AmericanaTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 3).padding(.vertical, 2)
        }
        .frame(width: 72)
        .background(AmericanaTheme.parchment)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(Color(red: 0.545, green: 0.412, blue: 0.078), lineWidth: 2))
        .cornerRadius(6)
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 1, y: 1)
    }

    @ViewBuilder private var tileImage: some View {
        if let img = AmericanaTheme.tileImage(for: mark.square) {
            img.resizable().scaledToFill()
        } else {
            AmericanaTheme.paper
        }
    }
}
