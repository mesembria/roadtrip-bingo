import SwiftUI

struct WinView: View {
    let winnerName: String
    @EnvironmentObject var appState: AppState
    private var isLocalWin: Bool { winnerName == appState.playerName }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            if isLocalWin { ConfettiView() }
            VStack(spacing: 32) {
                Text(isLocalWin ? "🏆" : "🎯").font(.system(size: 96))
                Text(isLocalWin ? "YOU GOT BINGO!" : "\(winnerName) got BINGO!")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(isLocalWin ? .yellow : .white).multilineTextAlignment(.center)
                if let line = appState.completedLine, isLocalWin, let board = appState.localBoard {
                    HStack(spacing: 8) {
                        ForEach(line, id: \.self) { pos in
                            Text(board.squares[pos].emoji).font(.title)
                                .padding(8).background(Color.yellow.opacity(0.25)).cornerRadius(8)
                        }
                    }
                }
                Button(action: { appState.screen = .playAgain }) {
                    Text("Continue →")
                        .font(.title3.bold()).padding(.horizontal, 48).padding(.vertical, 16)
                        .background(Color.white.opacity(0.15)).foregroundColor(.white).cornerRadius(14)
                }
            }.padding(48)
        }
    }
}
