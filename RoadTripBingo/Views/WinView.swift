import SwiftUI

struct WinView: View {
    let winnerName: String
    @EnvironmentObject var appState: AppState
    private var isLocalWin: Bool { winnerName == appState.playerName }

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            if isLocalWin { ConfettiView() }
            VStack(spacing: 32) {
                Text(isLocalWin ? "🏆" : "🎯").font(.system(size: 96))
                Text(isLocalWin ? "YOU GOT BINGO!" : "\(winnerName) got BINGO!")
                    .font(AmericanaTheme.rye(38))
                    .foregroundColor(isLocalWin ? AmericanaTheme.yellow : AmericanaTheme.ink)
                    .multilineTextAlignment(.center)
                if let line = appState.completedLine, isLocalWin, let board = appState.localBoard {
                    HStack(spacing: 8) {
                        ForEach(line, id: \.self) { pos in
                            winningTileCard(board.squares[pos])
                        }
                    }
                }
                Button(action: { appState.screen = .playAgain }) {
                    Text("Continue →")
                        .font(AmericanaTheme.barlowBold(17))
                        .padding(.horizontal, 48).padding(.vertical, 16)
                        .background(AmericanaTheme.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }.padding(48)
        }
    }

    private func winningTileCard(_ square: BingoSquare) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: AmericanaTheme.shadow, radius: 4, x: 0, y: 2)
            Group {
                if let img = AmericanaTheme.tileImage(for: square) {
                    img.resizable().scaledToFit()
                } else {
                    Text(square.emoji).font(.title)
                }
            }
            .padding(6)
            .frame(width: 48, height: 48)
        }
        .frame(width: 60, height: 60)
    }
}
