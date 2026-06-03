// RoadTripBingo/Views/SpottingRaceView.swift
import Combine
import SwiftUI

struct SpottingRaceView: View {
    @EnvironmentObject var appState: AppState
    @State private var timeRemaining: TimeInterval = 300
    @State private var toastMessage: String? = nil
    @State private var activeToastID: UUID? = nil
    @State private var toastStyle: ToastStyle = .earn
    @State private var timerCancellable: AnyCancellable? = nil

    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common)

    var body: some View {
        GeometryReader { _ in
            ZStack {
                AmericanaTheme.gridBackground().ignoresSafeArea()

                HStack(spacing: 0) {
                    // Left sidebar: timer + scores
                    leftSidebar
                        .frame(width: 180)

                    // 3×2 tile grid
                    tileGrid
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                }

                // Toast overlay
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        TokenToastView(message: msg, style: toastStyle)
                            .padding(.bottom, 60)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            updateTimer()
            timerCancellable = timerPublisher.autoconnect().sink { _ in updateTimer() }
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
        .onChange(of: appState.pendingToast) { toast in
            guard let toast else { return }
            toastStyle = toast.style
            withAnimation(.spring()) { toastMessage = toast.message }
            activeToastID = toast.id
            appState.pendingToast = nil
            let id = toast.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                guard activeToastID == id else { return }
                withAnimation { toastMessage = nil }
            }
        }
    }

    // MARK: - Timer

    private func updateTimer() {
        if let end = appState.spottingRoundEndTime {
            timeRemaining = max(0, end.timeIntervalSinceNow)
        }
    }

    private var timerText: String {
        let mins = Int(timeRemaining) / 60
        let secs = Int(timeRemaining) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var timerColor: Color {
        timeRemaining < 30 ? AmericanaTheme.red : AmericanaTheme.yellow
    }

    // MARK: - Left sidebar

    private var leftSidebar: some View {
        ZStack {
            AmericanaTheme.paper
            VStack(spacing: 0) {
                // Timer
                VStack(spacing: 4) {
                    Text("TIME")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                        .kerning(3)
                    Text(timerText)
                        .font(AmericanaTheme.rye(36))
                        .foregroundColor(timerColor)
                        .monospacedDigit()
                }
                .padding(.top, 32)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 20)

                // My score
                VStack(spacing: 4) {
                    Text("YOUR SCORE")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                        .kerning(2)
                        .padding(.top, 16)
                    Text("\(appState.mySpottingScore)")
                        .font(AmericanaTheme.rye(44))
                        .foregroundColor(AmericanaTheme.green)
                }

                if !appState.opponentSpottingScores.isEmpty {
                    Divider().padding(.horizontal, 20).padding(.top, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(
                            appState.opponentSpottingScores.sorted(by: { $0.value > $1.value }),
                            id: \.key
                        ) { name, score in
                            HStack {
                                Text(name)
                                    .font(AmericanaTheme.barlowSemiBold(13))
                                    .foregroundColor(AmericanaTheme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(score)")
                                    .font(AmericanaTheme.barlowBold(14))
                                    .foregroundColor(AmericanaTheme.ink.opacity(0.70))
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 12)
                }

                Spacer()
            }
        }
        .ignoresSafeArea(edges: .vertical)
    }

    // MARK: - 3×2 tile grid

    private var tileGrid: some View {
        let tiles = appState.spottingRaceTiles
        return VStack(spacing: 12) {
            ForEach(0..<2) { row in
                HStack(spacing: 12) {
                    ForEach(0..<3) { col in
                        let idx = row * 3 + col
                        if idx < tiles.count {
                            let tile = tiles[idx]
                            SpottingRaceTileView(
                                tile: tile,
                                playerName: appState.playerName,
                                onTap: { appState.tapSpottingTile(slotID: tile.id) },
                                onUndo: { appState.undoSpottingClaim(slotID: tile.id) }
                            )
                            .id(tile.id)  // stable identity for SwiftUI animations
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            // Empty slot (pool exhausted)
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 182)
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: tiles.map(\.id))
    }
}
