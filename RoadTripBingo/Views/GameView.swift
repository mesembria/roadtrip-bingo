import SwiftUI

struct GameView: View {
    @EnvironmentObject var appState: AppState
    @State private var targetingPowerUp: PowerUpType? = nil
    @State private var toastMessage: String? = nil
    @State private var activeToastID: UUID? = nil
    @State private var toastStyle: ToastStyle = .earn
    @State private var showModifierReveal = false
    @State private var showChallenges = false
    @State private var powerUpTrigger: UUID? = nil
    @State private var threatCount: Int = 0

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()

            if let board = appState.localBoard {
                GeometryReader { geo in
                    let landscape = geo.size.width > geo.size.height
                    if landscape {
                        landscapeLayout(board: board)
                    } else {
                        portraitLayout(board: board)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7),
                           value: appState.completedLine != nil)
            } else {
                ProgressView("Setting up board…").tint(.white)
            }

            if let powerUp = targetingPowerUp {
                TargetingOverlayView(
                    powerUp: powerUp,
                    localBoard: appState.localBoard,
                    opponentBoards: appState.opponentBoards,
                    opponentMarked: appState.opponentMarked,
                    onSelect: { targetPlayer, targetIndex in
                        appState.activatePowerUp(powerUp, targetPlayer: targetPlayer, targetIndex: targetIndex)
                        powerUpTrigger = UUID()
                        withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = nil }
                    },
                    onCancel: { withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = nil } }
                )
                .transition(.opacity)
            }

            if let msg = toastMessage {
                VStack {
                    Spacer()
                    TokenToastView(message: msg, style: toastStyle)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showModifierReveal, let modifier = appState.activeModifier {
                ModifierRevealView(modifier: modifier) {
                    showModifierReveal = false
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showChallenges) {
            DailyChallengesView(
                challenges: appState.activeChallenges,
                completedIDs: appState.dailyState.completedIDs
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if appState.activeModifier != nil {
                showModifierReveal = true
            }
        }
        .onChange(of: appState.screen) { _ in
            if appState.screen == .game && appState.activeModifier != nil {
                showModifierReveal = true
            }
        }
        .onChange(of: appState.activeModifier) { _ in
            if appState.activeModifier != nil && appState.screen == .game {
                showModifierReveal = true
            }
        }
        .onChange(of: appState.pendingToast) { toast in
            guard let toast else { return }
            toastStyle = toast.style
            if toast.style == .threat { threatCount += 1 }
            withAnimation(.spring()) { toastMessage = toast.message }
            activeToastID = toast.id
            appState.pendingToast = nil
            let id = toast.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard activeToastID == id else { return }
                withAnimation { toastMessage = nil }
            }
        }
        .sensoryFeedback(.success, trigger: appState.completedLine != nil)
        .sensoryFeedback(.impact(weight: .medium), trigger: powerUpTrigger)
        .sensoryFeedback(.warning, trigger: threatCount)
    }

    private func portraitLayout(board: BingoBoard) -> some View {
        VStack(spacing: 8) {
            opponentHUD
            GeometryReader { geo in
                let gridSize = min(geo.size.width - 32, geo.size.height)
                BingoGridView(
                    board: board,
                    highlightedPositions: Set(appState.completedLine ?? []),
                    hiddenPositions: appState.fogOfWarHiddenPositions,
                    onTap: appState.toggleSquare(at:)
                )
                .frame(width: gridSize, height: gridSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            bingoButton
            OpponentMarkFeedView(marks: appState.recentOpponentMarks, isLandscape: false)
                .padding(.horizontal, 16)
                .frame(height: 90)
            powerUpStrip(isVertical: false)
        }
        .padding(.vertical, 8)
    }

    private func landscapeLayout(board: BingoBoard) -> some View {
        HStack(spacing: 8) {
            // Left sidebar: opponents stacked vertically + BINGO button at bottom
            VStack(spacing: 12) {
                if let modifier = appState.activeModifier {
                    ModifierBadgeView(modifier: modifier)
                }
                let incompleteLandscape = appState.activeChallenges.filter {
                    !appState.dailyState.completedIDs.contains($0.id)
                }.count
                if incompleteLandscape > 0 {
                    Button {
                        showChallenges = true
                    } label: {
                        Text("🎯 \(incompleteLandscape)")
                            .font(AmericanaTheme.barlowBold(13))
                            .foregroundColor(AmericanaTheme.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(AmericanaTheme.yellow.opacity(0.8))
                            )
                    }
                    .buttonStyle(.plain)
                }
                if !appState.opponentMarked.isEmpty {
                    OpponentStripView(
                        opponentBoards: appState.opponentBoards,
                        opponentMarked: appState.opponentMarked,
                        tokenBalances: appState.tokenBalances,
                        isVertical: true
                    )
                }
                OpponentMarkFeedView(marks: appState.recentOpponentMarks, isLandscape: true)
                Spacer()
                bingoButton
            }
            .frame(width: 180)

            // Center: main grid
            // BingoGridView = 44pt header + square grid area, so constrain width to
            // (available height - 44) so the whole view fits without overflowing.
            GeometryReader { geo in
                let headerHeight: CGFloat = 44
                let gridWidth = min(geo.size.width, geo.size.height - headerHeight)
                BingoGridView(
                    board: board,
                    highlightedPositions: Set(appState.completedLine ?? []),
                    hiddenPositions: appState.fogOfWarHiddenPositions,
                    onTap: appState.toggleSquare(at:)
                )
                .frame(width: gridWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Right sidebar: power-up strip
            powerUpStrip(isVertical: true)
                .frame(width: 126)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
    }

    @ViewBuilder private var opponentHUD: some View {
        let incompletePortrait = appState.activeChallenges.filter {
            !appState.dailyState.completedIDs.contains($0.id)
        }.count
        HStack {
            if let modifier = appState.activeModifier {
                ModifierBadgeView(modifier: modifier)
            }
            Spacer()
            if incompletePortrait > 0 {
                Button {
                    showChallenges = true
                } label: {
                    Text("🎯 \(incompletePortrait)")
                        .font(AmericanaTheme.barlowBold(13))
                        .foregroundColor(AmericanaTheme.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(AmericanaTheme.yellow.opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        if !appState.opponentMarked.isEmpty {
            OpponentStripView(
                opponentBoards: appState.opponentBoards,
                opponentMarked: appState.opponentMarked,
                tokenBalances: appState.tokenBalances
            )
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var bingoButton: some View {
        if appState.completedLine != nil {
            Button(action: appState.callBingo) {
                Text("BINGO!")
                    .font(AmericanaTheme.rye(22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12).padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(AmericanaTheme.yellow)
                    .foregroundColor(AmericanaTheme.ink)
                    .cornerRadius(8)
                    .shadow(color: AmericanaTheme.yellow.opacity(0.8), radius: 0, x: 0, y: 3)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func powerUpStrip(isVertical: Bool) -> some View {
        PowerUpStripView(
            tokenBalance: appState.tokenBalance,
            isVertical: isVertical,
            activeModifier: appState.activeModifier,
            onActivateRandom: { powerUp in
                appState.activatePowerUp(powerUp)
                powerUpTrigger = UUID()
            },
            onRequestTargeted: { powerUp in
                withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = powerUp }
            }
        )
        .padding(.horizontal, isVertical ? 0 : 16)
    }
}
