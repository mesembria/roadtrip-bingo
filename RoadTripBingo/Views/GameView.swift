import SwiftUI

struct GameView: View {
    @EnvironmentObject var appState: AppState
    @State private var targetingPowerUp: PowerUpType? = nil
    @State private var toastMessage: String? = nil
    @State private var activeToastID: UUID? = nil

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()

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
                        withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = nil }
                    },
                    onCancel: { withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = nil } }
                )
                .transition(.opacity)
            }

            if let msg = toastMessage {
                VStack {
                    Spacer()
                    TokenToastView(message: msg)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: appState.pendingToast) { toast in
            guard let toast else { return }
            withAnimation(.spring()) { toastMessage = toast.message }
            activeToastID = toast.id
            appState.pendingToast = nil
            let id = toast.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard activeToastID == id else { return }
                withAnimation { toastMessage = nil }
            }
        }
    }

    private func portraitLayout(board: BingoBoard) -> some View {
        VStack(spacing: 8) {
            opponentHUD
            GeometryReader { geo in
                let gridSize = min(geo.size.width - 32, geo.size.height)
                BingoGridView(
                    board: board,
                    highlightedPositions: Set(appState.completedLine ?? []),
                    onTap: appState.toggleSquare(at:)
                )
                .frame(width: gridSize, height: gridSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            bingoButton
            powerUpStrip(isVertical: false)
        }
        .padding(.vertical, 8)
    }

    private func landscapeLayout(board: BingoBoard) -> some View {
        VStack(spacing: 6) {
            opponentHUD
            HStack(spacing: 8) {
                GeometryReader { geo in
                    let gridSize = min(geo.size.width, geo.size.height)
                    BingoGridView(
                        board: board,
                        highlightedPositions: Set(appState.completedLine ?? []),
                        onTap: appState.toggleSquare(at:)
                    )
                    .frame(width: gridSize, height: gridSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                powerUpStrip(isVertical: true)
                    .frame(width: 64)
            }
            bingoButton
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
    }

    @ViewBuilder private var opponentHUD: some View {
        if !appState.opponentMarked.isEmpty {
            OpponentStripView(
                opponentMarked: appState.opponentMarked,
                tokenBalances: appState.tokenBalances
            )
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var bingoButton: some View {
        if appState.completedLine != nil {
            Button(action: appState.callBingo) {
                Text("🎉 BINGO!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .padding(.horizontal, 48).padding(.vertical, 16)
                    .background(Color.yellow).foregroundColor(.black)
                    .cornerRadius(20).shadow(color: .yellow.opacity(0.6), radius: 16)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func powerUpStrip(isVertical: Bool) -> some View {
        PowerUpStripView(
            tokenBalance: appState.tokenBalance,
            isVertical: isVertical,
            onActivateRandom: { powerUp in
                appState.activatePowerUp(powerUp)
            },
            onRequestTargeted: { powerUp in
                withAnimation(.easeInOut(duration: 0.2)) { targetingPowerUp = powerUp }
            }
        )
        .padding(.horizontal, isVertical ? 0 : 16)
    }
}
