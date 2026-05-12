import SwiftUI

struct PowerUpStripView: View {
    let tokenBalance: Int
    let isVertical: Bool
    let onActivateRandom: (PowerUpType) -> Void
    let onRequestTargeted: (PowerUpType) -> Void

    private struct StripItem {
        let emoji: String
        let label: String
        let randomVariant: PowerUpType?
        let targetedVariant: PowerUpType

        var displayCost: Int { randomVariant?.cost ?? targetedVariant.cost }
    }

    private let items: [StripItem] = [
        StripItem(emoji: "🔀", label: "Upgrade",   randomVariant: .upgradeTileRandom,    targetedVariant: .upgradeTileTargeted),
        StripItem(emoji: "💣", label: "Sabotage",  randomVariant: .downgradeTileRandom,  targetedVariant: .downgradeTileTargeted),
        StripItem(emoji: "✅", label: "Free Mark", randomVariant: nil,                   targetedVariant: .freeMark),
        StripItem(emoji: "💥", label: "Erase",     randomVariant: .unmarkOpponentRandom, targetedVariant: .unmarkOpponentTargeted),
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
            let canAfford = tokenBalance >= item.displayCost
            VStack(spacing: 2) {
                Text(item.emoji).font(.system(size: 22))
                Text(item.label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Text("\(item.displayCost)🪙")
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
                guard tokenBalance >= item.targetedVariant.cost else { return }
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
