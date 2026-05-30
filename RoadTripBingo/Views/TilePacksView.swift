import SwiftUI

struct TilePacksView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    // Base pack is excluded — it's not player-selectable; it's the implicit fallback pool.
    private let allPacks: [TilePack] = PackManager.loadAll().filter { $0.id != "base" }
    private let basePool: [BingoSquare] = SquarePool.load()

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(AmericanaTheme.ink.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tile Packs")
                        .font(AmericanaTheme.rye(18))
                        .foregroundColor(AmericanaTheme.ink)
                    Text("SELECT YOUR SCENERY")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.45))
                        .kerning(2)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .font(AmericanaTheme.barlowBold(14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(AmericanaTheme.green)
                    .cornerRadius(8)
                    .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .overlay(Rectangle().fill(AmericanaTheme.ink.opacity(0.10)).frame(height: 1), alignment: .bottom)

            // Scrollable body
            ScrollView {
                VStack(spacing: 12) {
                    // Pack grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(allPacks) { pack in
                            PackCardView(
                                pack: pack,
                                isSelected: appState.activePackIDs.contains(pack.id),
                                isReadOnly: appState.screen != .home && !appState.isHost
                            ) {
                                appState.togglePack(pack.id)
                            }
                        }
                    }

                    // Rarity distribution
                    RarityDistributionView(pool: activePool)

                    // Pool size indicator
                    PoolSizeIndicatorView(pool: activePool, playerCount: playerCount)
                }
                .padding(20)
            }
        }
        .background(AmericanaTheme.paper.ignoresSafeArea())
    }

    private var activePool: [BingoSquare] {
        let selected = allPacks.filter { appState.activePackIDs.contains($0.id) }
        let packs = selected.isEmpty ? [SquarePool.loadBasePack()] : selected
        return SquarePool.buildPool(base: basePool, activePacks: packs)
    }

    private var playerCount: Int {
        max(1, appState.connectedPlayerNames.count + 1)
    }
}

// MARK: - PackCardView

struct PackCardView: View {
    let pack: TilePack
    let isSelected: Bool
    let isReadOnly: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !isReadOnly { onTap() } }) {
            VStack(spacing: 0) {
                // Pack image
                ZStack(alignment: .topTrailing) {
                    if let path = Bundle.main.path(forResource: pack.imageName, ofType: "jpg"),
                       let uiImage = UIImage(contentsOfFile: path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 90)
                            .clipped()
                    } else {
                        // Placeholder when image asset not yet added
                        Rectangle()
                            .fill(AmericanaTheme.ink.opacity(0.08))
                            .frame(height: 90)
                            .overlay(
                                Text(pack.name.prefix(1))
                                    .font(AmericanaTheme.rye(28))
                                    .foregroundColor(AmericanaTheme.ink.opacity(0.3))
                            )
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .padding(8)
                    }
                }

                // Pack name and description
                VStack(alignment: .leading, spacing: 3) {
                    Text(pack.name)
                        .font(AmericanaTheme.barlowBold(13))
                        .foregroundColor(AmericanaTheme.ink)
                        .lineLimit(1)
                    Text(pack.description)
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.5))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .background(AmericanaTheme.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? AmericanaTheme.green : AmericanaTheme.ink.opacity(0.12),
                              lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: AmericanaTheme.shadow, radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - RarityDistributionView

struct RarityDistributionView: View {
    let pool: [BingoSquare]

    private var counts: [SquareRarity: Int] {
        var c: [SquareRarity: Int] = [:]
        for rarity in SquareRarity.allCases { c[rarity] = 0 }
        for square in pool { c[square.rarity, default: 0] += 1 }
        return c
    }

    private var total: Int { pool.count }

    // Colors from most-common (green) to rarest (deep red)
    private let rarityColors: [SquareRarity: Color] = [
        .veryCommon: Color(red: 0.102, green: 0.361, blue: 0.165),
        .common:     Color(red: 0.353, green: 0.541, blue: 0.227),
        .uncommon:   Color(red: 0.545, green: 0.412, blue: 0.078),
        .rare:       Color(red: 0.753, green: 0.224, blue: 0.169),
        .veryRare:   Color(red: 0.416, green: 0.063, blue: 0.035)
    ]

    private let rarityLabels: [SquareRarity: String] = [
        .veryCommon: "Very Common",
        .common:     "Common",
        .uncommon:   "Uncommon",
        .rare:       "Rare",
        .veryRare:   "Very Rare"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RARITY DISTRIBUTION — \(total) TILES")
                .font(AmericanaTheme.barlowSemiBold(9))
                .foregroundColor(AmericanaTheme.ink.opacity(0.45))
                .kerning(2)

            // Segmented bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(SquareRarity.allCases, id: \.self) { rarity in
                        let count = counts[rarity] ?? 0
                        let fraction = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                        if fraction > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(rarityColors[rarity] ?? .gray)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            // Legend
            HStack(spacing: 0) {
                ForEach(SquareRarity.allCases, id: \.self) { rarity in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(rarityColors[rarity] ?? .gray)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(rarityLabels[rarity] ?? "")
                                .font(AmericanaTheme.barlowSemiBold(8))
                                .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                            Text("\(counts[rarity] ?? 0)")
                                .font(AmericanaTheme.barlowBold(9))
                                .foregroundColor(AmericanaTheme.ink)
                        }
                    }
                    if rarity != .veryRare { Spacer() }
                }
            }
        }
        .padding(12)
        .background(AmericanaTheme.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AmericanaTheme.ink.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - PoolSizeIndicatorView

struct PoolSizeIndicatorView: View {
    let pool: [BingoSquare]
    let playerCount: Int

    private var minimumNeeded: Int { playerCount * 24 + playerCount * 6 }  // boards + reserve
    private var isThin: Bool { pool.count < minimumNeeded }

    var body: some View {
        HStack {
            if isThin {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AmericanaTheme.red)
                    .font(.system(size: 13))
                Text("Not enough tiles for \(playerCount) player\(playerCount == 1 ? "" : "s") — add another pack")
                    .font(AmericanaTheme.barlowSemiBold(11))
                    .foregroundColor(AmericanaTheme.red)
            } else {
                Text("Tile pool for \(playerCount) player\(playerCount == 1 ? "" : "s")")
                    .font(AmericanaTheme.barlowSemiBold(11))
                    .foregroundColor(AmericanaTheme.ink)
            }
            Spacer()
            Text("\(pool.count) tiles \(isThin ? "⚠️" : "✓")")
                .font(AmericanaTheme.barlowBold(15))
                .foregroundColor(isThin ? AmericanaTheme.red : AmericanaTheme.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isThin ? AmericanaTheme.red.opacity(0.08) : AmericanaTheme.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isThin ? AmericanaTheme.red.opacity(0.3) : AmericanaTheme.yellow.opacity(0.4),
                              lineWidth: 1)
        )
    }
}
