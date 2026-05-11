import SwiftUI

struct GameView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            if let board = appState.localBoard {
                VStack(spacing: 12) {
                    if !appState.opponentMarked.isEmpty {
                        OpponentStripView(opponentMarked: appState.opponentMarked).padding(.horizontal, 16)
                    }
                    BingoGridView(
                        board: board,
                        highlightedPositions: Set(appState.completedLine ?? []),
                        onTap: appState.toggleSquare(at:)
                    ).padding(.horizontal, 16)
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
                .padding(.vertical, 12)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appState.completedLine != nil)
            } else {
                ProgressView("Setting up board…").tint(.white)
            }
        }
    }
}
