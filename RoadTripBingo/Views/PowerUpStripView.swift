import SwiftUI

struct PowerUpStripView: View {
    let tokenBalance: Int
    let isVertical: Bool
    let activeModifier: RoundModifier?
    let onActivateRandom: (PowerUpType) -> Void
    let onRequestTargeted: (PowerUpType) -> Void

    private struct StripItem {
        let iconName: String
        let label: String
        let randomVariant: PowerUpType?
        let targetedVariant: PowerUpType

        var baseCost: Int { randomVariant?.cost ?? targetedVariant.cost }
    }

    private func effectiveCost(for item: StripItem) -> Int {
        let base = item.baseCost
        if activeModifier == .sniper && item.targetedVariant.affectsOpponent {
            return max(1, base - 1)
        }
        return base
    }

    private func effectiveCostTargeted(for item: StripItem) -> Int {
        let base = item.targetedVariant.cost
        if activeModifier == .sniper && item.targetedVariant.affectsOpponent {
            return max(1, base - 1)
        }
        return base
    }

    private var noPowersActive: Bool { activeModifier == .noPowers }

    private let items: [StripItem] = [
        StripItem(iconName: "powerup-upgrade",  label: "Upgrade",   randomVariant: .upgradeTileRandom,    targetedVariant: .upgradeTileTargeted),
        StripItem(iconName: "powerup-sabotage", label: "Sabotage",  randomVariant: .downgradeTileRandom,  targetedVariant: .downgradeTileTargeted),
        StripItem(iconName: "powerup-freemark", label: "Free Mark", randomVariant: nil,                   targetedVariant: .freeMark),
        StripItem(iconName: "powerup-erase",    label: "Erase",     randomVariant: .unmarkOpponentRandom, targetedVariant: .unmarkOpponentTargeted),
    ]

    @State private var showHelp = false

    var body: some View {
        ZStack {
            Group {
                if isVertical {
                    VStack(spacing: 9) { buttons; helpButton; balanceBadge }
                } else {
                    HStack(spacing: 9) { buttons; helpButton; Spacer(); balanceBadge }
                }
            }
            .padding(12)
            .opacity(noPowersActive ? 0.35 : 1.0)

            if noPowersActive {
                noPowersBanner
            }
        }
        .background(AmericanaTheme.green)
        .cornerRadius(12)
        .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showHelp) { PowerUpHelpView() }
    }

    private var noPowersBanner: some View {
        VStack(spacing: 4) {
            Text("🚫")
                .font(.system(size: isVertical ? 22 : 18))
            Text("NO POWERS")
                .font(AmericanaTheme.barlowBold(isVertical ? 11 : 10))
                .foregroundColor(.white)
                .kerning(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.55))
        .cornerRadius(8)
    }

    @ViewBuilder private var buttons: some View {
        ForEach(items.indices, id: \.self) { i in
            let item = items[i]
            let cost = effectiveCost(for: item)
            let canAfford = tokenBalance >= cost
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                    if let img = AmericanaTheme.icon(named: item.iconName) {
                        img.resizable().scaledToFit().padding(4)
                            .frame(width: 44, height: 44)
                    }
                }
                Text(item.label.uppercased())
                    .font(AmericanaTheme.barlowBold(9))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                HStack(spacing: 2) {
                    if let img = AmericanaTheme.icon(named: "token") {
                        img.resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    Text("\(cost)")
                        .font(AmericanaTheme.barlowBold(12))
                        .foregroundColor(AmericanaTheme.yellow)
                }
            }
            .opacity(canAfford ? 1.0 : 0.4)
            .onTapGesture {
                guard canAfford, !noPowersActive else { return }
                if let random = item.randomVariant {
                    onActivateRandom(random)
                } else {
                    onRequestTargeted(item.targetedVariant)
                }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                let targetedCost = effectiveCostTargeted(for: item)
                guard tokenBalance >= targetedCost, !noPowersActive else { return }
                onRequestTargeted(item.targetedVariant)
            }
        }
    }

    private var balanceBadge: some View {
        HStack(spacing: 4) {
            if let img = AmericanaTheme.icon(named: "token") {
                img.resizable().scaledToFit().frame(width: 26, height: 26)
            }
            Text("\(tokenBalance)")
                .font(AmericanaTheme.barlowBold(22))
                .foregroundColor(AmericanaTheme.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(AmericanaTheme.yellow)
        .cornerRadius(8)
    }

    private var helpButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 44)
            Text("?")
                .font(AmericanaTheme.barlowBold(18))
                .foregroundColor(.white.opacity(0.75))
        }
        .accessibilityLabel("Power-up help")
        .onTapGesture { showHelp = true }
    }
}
