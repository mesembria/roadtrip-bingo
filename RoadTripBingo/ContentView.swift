import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.screen {
            case .home:
                HomeView().transition(.opacity)
            case .lobby:
                LobbyView().transition(.opacity)
            case .game:
                switch appState.gameType {
                case .bingo:
                    GameView().transition(.opacity)
                case .spottingRace:
                    SpottingRaceView().transition(.opacity)
                }
            case .win(let winnerName):
                WinView(winnerName: winnerName).transition(.opacity)
            case .playAgain:
                PlayAgainView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.screen)
    }
}
