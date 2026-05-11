import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            if appState.isHost { hostView } else { joinerView }
        }
    }

    private var hostView: some View {
        VStack(spacing: 32) {
            Text("Lobby").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text("Other players appear automatically nearby").font(.subheadline).foregroundColor(.white.opacity(0.6))
            difficultyPicker
            VStack(spacing: 10) {
                playerRow(name: appState.playerName, label: "you (host)", difficulty: appState.playerDifficulty)
                ForEach(appState.connectedPlayerNames, id: \.self) { name in
                    playerRow(name: name, label: nil,
                              difficulty: appState.playerDifficulties[name] ?? .backseat)
                }
            }.frame(maxWidth: 400)
            Button(action: appState.startGame) {
                Text("Start Game ▶")
                    .font(.title3.bold()).frame(maxWidth: 360).padding()
                    .background(appState.connectedPlayerNames.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                    .foregroundColor(.white).cornerRadius(14)
            }
            .disabled(appState.connectedPlayerNames.isEmpty)
            if appState.connectedPlayerNames.isEmpty {
                Text("Waiting for players to join…").font(.caption).foregroundColor(.white.opacity(0.6))
            }
            Button("Cancel", role: .destructive, action: appState.goHome).foregroundColor(.white.opacity(0.6))
        }.padding(48)
    }

    private var joinerView: some View {
        VStack(spacing: 32) {
            Text("Join Game").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.white)
            difficultyPicker
            if appState.connectedPlayerNames.isEmpty {
                VStack(spacing: 16) {
                    if appState.foundGameNames.isEmpty {
                        ProgressView().tint(.white)
                        Text("Looking for nearby games…").font(.subheadline).foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("Games nearby:").font(.subheadline).foregroundColor(.white.opacity(0.6))
                        ForEach(appState.foundGameNames, id: \.self) { name in
                            Button(action: { appState.inviteGame(named: name) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name).font(.headline).foregroundColor(.white)
                                        Text("Tap to join").font(.caption).foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundColor(.blue)
                                }
                                .padding().background(Color.white.opacity(0.08)).cornerRadius(12)
                            }
                        }
                    }
                }.frame(maxWidth: 400)
            } else {
                VStack(spacing: 10) {
                    Text("Connected! Waiting for host…").font(.subheadline).foregroundColor(.white.opacity(0.6))
                    playerRow(name: appState.playerName, label: "you", difficulty: nil)
                    ForEach(appState.connectedPlayerNames, id: \.self) { playerRow(name: $0, label: nil, difficulty: nil) }
                }.frame(maxWidth: 400)
            }
            Button("Cancel", role: .destructive, action: appState.goHome).foregroundColor(.white.opacity(0.6))
        }.padding(48)
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(BoardDifficulty.allCases, id: \.self) { difficulty in
                Button(action: { appState.chooseDifficulty(difficulty) }) {
                    Text(difficulty.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(appState.playerDifficulty == difficulty
                                    ? Color.blue
                                    : Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: 400)
    }

    private func playerRow(name: String, label: String?, difficulty: BoardDifficulty?) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color.green).frame(width: 10, height: 10)
            Text(name).font(.headline).foregroundColor(.white)
            if let label { Text(label).font(.caption).foregroundColor(.white.opacity(0.6)) }
            Spacer()
            if let difficulty {
                Text(difficulty.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.06)).cornerRadius(10)
    }
}
