import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            if appState.isHost { hostView } else { joinerView }
        }
    }

    private var hostView: some View {
        VStack(spacing: 28) {
            Text("Lobby")
                .font(AmericanaTheme.rye(28))
                .foregroundColor(AmericanaTheme.ink)
            Text("Other players appear automatically nearby")
                .font(AmericanaTheme.barlowSemiBold(14))
                .foregroundColor(AmericanaTheme.ink.opacity(0.6))
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
                    .font(AmericanaTheme.barlowBold(17))
                    .frame(maxWidth: 360).padding()
                    .background(appState.connectedPlayerNames.isEmpty
                                ? AmericanaTheme.green.opacity(0.4)
                                : AmericanaTheme.green)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .disabled(appState.connectedPlayerNames.isEmpty)
            if appState.connectedPlayerNames.isEmpty {
                Text("Waiting for players to join…")
                    .font(AmericanaTheme.barlowSemiBold(14))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.6))
            }
            Button("Cancel", role: .destructive, action: appState.goHome)
                .font(AmericanaTheme.barlowSemiBold(15))
                .foregroundColor(AmericanaTheme.ink.opacity(0.5))
        }.padding(48)
    }

    private var joinerView: some View {
        VStack(spacing: 28) {
            Text("Join Game")
                .font(AmericanaTheme.rye(28))
                .foregroundColor(AmericanaTheme.ink)
            difficultyPicker
            if appState.connectedPlayerNames.isEmpty {
                VStack(spacing: 16) {
                    if appState.foundGameNames.isEmpty {
                        ProgressView().tint(AmericanaTheme.green)
                        Text("Looking for nearby games…")
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                    } else {
                        Text("Games nearby:")
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                        ForEach(appState.foundGameNames, id: \.self) { name in
                            Button(action: { appState.inviteGame(named: name) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(AmericanaTheme.barlowBold(16))
                                            .foregroundColor(AmericanaTheme.ink)
                                        Text("Tap to join")
                                            .font(AmericanaTheme.barlowSemiBold(12))
                                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(AmericanaTheme.green)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }.frame(maxWidth: 400)
            } else {
                VStack(spacing: 10) {
                    Text("Connected! Waiting for host…")
                        .font(AmericanaTheme.barlowSemiBold(14))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                    playerRow(name: appState.playerName, label: "you", difficulty: nil)
                    ForEach(appState.connectedPlayerNames, id: \.self) { playerRow(name: $0, label: nil, difficulty: nil) }
                }.frame(maxWidth: 400)
            }
            Button("Cancel", role: .destructive, action: appState.goHome)
                .font(AmericanaTheme.barlowSemiBold(15))
                .foregroundColor(AmericanaTheme.ink.opacity(0.5))
        }.padding(48)
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(BoardDifficulty.allCases, id: \.self) { difficulty in
                Button(action: { appState.chooseDifficulty(difficulty) }) {
                    Text(difficulty.displayName)
                        .font(AmericanaTheme.barlowSemiBold(14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            appState.playerDifficulty == difficulty
                                ? AmericanaTheme.green
                                : Color.clear
                        )
                        .foregroundColor(
                            appState.playerDifficulty == difficulty
                                ? .white
                                : AmericanaTheme.green
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(AmericanaTheme.green, lineWidth: appState.playerDifficulty == difficulty ? 0 : 1.5)
                        )
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: 400)
    }

    private func playerRow(name: String, label: String?, difficulty: BoardDifficulty?) -> some View {
        HStack(spacing: 12) {
            Circle().fill(AmericanaTheme.green).frame(width: 10, height: 10)
            Text(name)
                .font(AmericanaTheme.barlowBold(16))
                .foregroundColor(AmericanaTheme.ink)
            if let label {
                Text(label)
                    .font(AmericanaTheme.barlowSemiBold(12))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.6))
            }
            Spacer()
            if let difficulty {
                Text(difficulty.displayName)
                    .font(AmericanaTheme.barlowSemiBold(12))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.6))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                )
        )
    }
}
