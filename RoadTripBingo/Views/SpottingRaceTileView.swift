// RoadTripBingo/Views/SpottingRaceTileView.swift
import SwiftUI

struct SpottingRaceTileView: View {
    let tile: SpottingRaceTile
    let playerName: String
    let onTap: () -> Void
    let onUndo: () -> Void

    @State private var stampVisible = false
    @State private var stampRotation: Double = 0
    @State private var stampScale: CGFloat = 0

    private enum TileState {
        case unclaimed
        case expiring        // <3s left, unclaimed
        case softClaimMine   // I tapped, 2-second window
        case claimedMine
        case softClaimOpponent
        case claimedOpponent
    }

    private var tileState: TileState {
        if let claimer = tile.claimedBy {
            return claimer == playerName ? .claimedMine : .claimedOpponent
        }
        if let locker = tile.lockedBy {
            return locker == playerName ? .softClaimMine : .softClaimOpponent
        }
        return tile.isExpiring ? .expiring : .unclaimed
    }

    // MARK: - Colours

    private var imageZoneBackground: Color {
        switch tileState {
        case .unclaimed, .expiring: return Color(red: 0.98, green: 0.96, blue: 0.90)   // cream
        case .softClaimMine, .claimedMine: return AmericanaTheme.green.opacity(0.18)
        case .softClaimOpponent: return Color.black.opacity(0.55)
        case .claimedOpponent: return AmericanaTheme.yellow.opacity(0.22)
        }
    }

    private var bandBackground: Color {
        switch tileState {
        case .unclaimed, .expiring: return Color(red: 0.18, green: 0.14, blue: 0.10)   // dark wood
        case .softClaimMine, .claimedMine: return AmericanaTheme.green.opacity(0.85)
        case .softClaimOpponent: return Color(red: 0.14, green: 0.10, blue: 0.08)
        case .claimedOpponent: return Color(red: 0.55, green: 0.38, blue: 0.10)
        }
    }

    // MARK: - Rarity dots

    private var dotCount: Int {
        switch tile.square.rarity {
        case .veryCommon: return 1
        case .common:     return 2
        case .uncommon:   return 3
        case .rare:       return 4
        case .veryRare:   return 5
        }
    }

    private var dotColor: Color {
        switch tile.square.rarity {
        case .veryCommon: return Color(red: 0.60, green: 0.60, blue: 0.60)
        case .common:     return Color(red: 0.30, green: 0.65, blue: 0.30)
        case .uncommon:   return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .rare:       return Color(red: 0.70, green: 0.20, blue: 0.90)
        case .veryRare:   return Color(red: 0.95, green: 0.70, blue: 0.10)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            imageZone
                .frame(height: 130)
            labelBand
                .frame(height: 52)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(borderColor, lineWidth: tileState == .expiring ? 2.5 : 1)
                .opacity(tileState == .expiring ? 1 : 0.15)
                .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                           value: tileState == .expiring)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        .onChange(of: tileState) { newState in
            if newState == .softClaimMine || newState == .claimedMine {
                triggerStamp(rotation: -12)
            } else if newState == .claimedOpponent {
                triggerStamp(rotation: 9)
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    stampVisible = false
                    stampScale = 0
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard tileState == .unclaimed || tileState == .expiring else { return }
            onTap()
        }
        .allowsHitTesting(tileState != .softClaimOpponent && tileState != .claimedOpponent && tileState != .claimedMine)
    }

    private var borderColor: Color {
        tileState == .expiring ? AmericanaTheme.red : Color.clear
    }

    // MARK: - Image zone

    private var imageZone: some View {
        ZStack {
            imageZoneBackground.ignoresSafeArea(edges: [])

            // Tile image or emoji
            Group {
                if let img = AmericanaTheme.tileImage(for: tile.square) {
                    img.resizable().scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .opacity(tileState == .softClaimOpponent ? 0.3 : 1)
                } else if let emoji = tile.square.emoji {
                    Text(emoji).font(.system(size: 52))
                        .opacity(tileState == .softClaimOpponent ? 0.3 : 1)
                }
            }

            // Rarity dots — top-left
            VStack {
                HStack {
                    HStack(spacing: 3) {
                        ForEach(0..<dotCount, id: \.self) { _ in
                            Circle().fill(dotColor).frame(width: 7, height: 7)
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.30))
                    .clipShape(Capsule())
                    Spacer()
                    // Points — top-right
                    Text("+\(tile.square.rarity.spottingRaceScore)")
                        .font(AmericanaTheme.barlowBold(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                }
                .padding(7)
                Spacer()
            }

            // Stamp (softClaimMine + claimedMine → green; claimedOpponent → amber)
            if stampVisible {
                stampView
                    .scaleEffect(stampScale)
                    .rotationEffect(.degrees(stampRotation))
                    .transition(.identity)
            }

            // Opponent soft-claim overlay
            if tileState == .softClaimOpponent {
                opponentLockOverlay
            }
        }
    }

    private var stampView: some View {
        let isMine = tileState == .softClaimMine || tileState == .claimedMine
        return VStack(spacing: 2) {
            Text(isMine ? "SPOTTED" : "TAKEN")
                .font(AmericanaTheme.rye(isMine ? 22 : 18))
                .foregroundColor(isMine ? AmericanaTheme.green : AmericanaTheme.yellow)
            if !isMine, let claimer = tile.claimedBy {
                Text("+\(tile.square.rarity.spottingRaceScore) pts · \(claimer)")
                    .font(AmericanaTheme.barlowSemiBold(10))
                    .foregroundColor(AmericanaTheme.yellow.opacity(0.85))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isMine ? AmericanaTheme.green : AmericanaTheme.yellow, lineWidth: 3)
        )
    }

    private var opponentLockOverlay: some View {
        VStack(spacing: 6) {
            Text("🔒")
                .font(.system(size: 28))
            Text(tile.lockedBy ?? "")
                .font(AmericanaTheme.barlowBold(14))
                .foregroundColor(.white)
            Text("Claiming…")
                .font(AmericanaTheme.barlowSemiBold(11))
                .foregroundColor(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.60))
    }

    // MARK: - Label band

    private var labelBand: some View {
        ZStack {
            bandBackground

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.square.text)
                        .font(AmericanaTheme.barlowSemiBold(13))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(tile.claimedBy != nil ? 0.55 : 1.0)

                    fuseBar
                }
                .padding(.horizontal, 10).padding(.vertical, 7)

                if tileState == .softClaimMine {
                    undoChip
                        .padding(.trailing, 8)
                }
            }
        }
    }

    private var fuseBar: some View {
        let total: TimeInterval = 60
        let remaining = max(0, tile.expiresAt.timeIntervalSinceNow)
        let fraction = CGFloat(remaining / total)
        let barColor: Color = tileState == .expiring ? AmericanaTheme.red : AmericanaTheme.yellow
        let isPaused = tile.lockedBy != nil || tile.claimedBy != nil

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                RoundedRectangle(cornerRadius: 2)
                    .fill(isPaused ? barColor.opacity(0.50) : barColor)
                    .frame(width: geo.size.width * (isPaused ? fraction : fraction))
            }
        }
        .frame(height: 3)
    }

    private var undoChip: some View {
        Button(action: onUndo) {
            Text("Undo")
                .font(AmericanaTheme.barlowBold(11))
                .foregroundColor(AmericanaTheme.green)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.white.opacity(0.90))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stamp animation

    private func triggerStamp(rotation: Double) {
        stampRotation = rotation
        stampVisible = true
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            stampScale = 1.0
        }
    }
}
