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

    @State private var showHelp = false

    var body: some View {
        Group {
            if isVertical {
                VStack(spacing: 9) { buttons; helpButton; balanceBadge }
            } else {
                HStack(spacing: 9) { buttons; helpButton; balanceBadge }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
        .sheet(isPresented: $showHelp) { PowerUpHelpView() }
    }

    @ViewBuilder private var buttons: some View {
        ForEach(items.indices, id: \.self) { i in
            let item = items[i]
            let canAfford = tokenBalance >= item.displayCost
            VStack(spacing: 3) {
                Text(item.emoji).font(.system(size: 33))
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                Text("\(item.displayCost)🪙")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
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
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .padding(.horizontal, 15).padding(.vertical, 9)
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(8)
    }

    private var helpButton: some View {
        Text("?")
            .font(.system(size: 23, weight: .bold))
            .foregroundColor(.white.opacity(0.7))
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(8)
            .accessibilityLabel("Power-up help")
            .onTapGesture { showHelp = true }
    }
}
