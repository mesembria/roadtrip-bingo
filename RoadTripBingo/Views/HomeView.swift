import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("🚗").font(.system(size: 72))
                    Text("Road Trip Bingo")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                VStack(spacing: 12) {
                    TextField("Enter your name", text: $appState.playerName)
                        .font(.title3)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
                .frame(maxWidth: 360)
                VStack(spacing: 14) {
                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.createGame()
                    }) {
                        Label("Create Game", systemImage: "plus.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: 360).padding()
                            .background(Color.blue).foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.joinGame()
                    }) {
                        Label("Join Game", systemImage: "arrow.right.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: 360).padding()
                            .background(Color.white.opacity(0.12)).foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(48)
        }
    }
}
