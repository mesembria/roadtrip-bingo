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
            case .game, .win(_), .playAgain:
                // Phase 2: game screens added in Tasks 9–14
                Text("Game coming soon").foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.screen)
    }
}
