import SwiftUI

struct PowerUpStripView: View {
    let tokenBalance: Int
    let isVertical: Bool
    let onActivateRandom: (PowerUpType) -> Void
    let onRequestTargeted: (PowerUpType) -> Void

    private struct StripItem {
        let emoji: String
        let cost: Int
        let randomVariant: PowerUpType?
        let targetedVariant: PowerUpType
    }

    private let items: [StripItem] = [
        StripItem(emoji: "🔀", cost: 3, randomVariant: .upgradeTileRandom,    targetedVariant: .upgradeTileTargeted),
        StripItem(emoji: "💣", cost: 3, randomVariant: .downgradeTileRandom,  targetedVariant: .downgradeTileTargeted),
        StripItem(emoji: "✅", cost: 5, randomVariant: nil,                   targetedVariant: .freeMark),
        StripItem(emoji: "💥", cost: 4, randomVariant: .unmarkOpponentRandom, targetedVariant: .unmarkOpponentTargeted),
    ]

    var body: some View {
        Group {
            if isVertical {
                VStack(spacing: 6) { buttons; balanceBadge }
            } else {
                HStack(spacing: 6) { buttons; balanceBadge }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }

    @ViewBuilder private var buttons: some View {
        ForEach(items.indices, id: \.self) { i in
            let item = items[i]
            let canAfford = tokenBalance >= item.cost
            VStack(spacing: 2) {
                Text(item.emoji).font(.system(size: 22))
                Text("\(item.cost)🪙")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(Color.white.opacity(canAfford ? 0.12 : 0.04))
            .cornerRadius(8)
            .opacity(canAfford ? 1.0 : 0.4)
            .onTapGesture {
                guard canAfford else { return }
                if let random = item.randomVariant {
                    onActivateRandom(random)
                } else {
                    onRequestTargeted(item.targetedVariant)
                }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                guard canAfford else { return }
                onRequestTargeted(item.targetedVariant)
            }
        }
    }

    private var balanceBadge: some View {
        Text("🪙\(tokenBalance)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(8)
    }
}
