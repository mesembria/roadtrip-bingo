import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            VStack(spacing: 28) {
                Text("🚗").font(.system(size: 72))

                // Title banner
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AmericanaTheme.green)
                        .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 4)
                        .shadow(color: AmericanaTheme.shadow, radius: 20, x: 0, y: 6)
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AmericanaTheme.yellow)
                            .frame(width: 6).padding(.vertical, 12).padding(.leading, 10)
                        VStack(spacing: 4) {
                            Text("Road Trip Bingo")
                                .font(AmericanaTheme.rye(28))
                                .foregroundColor(.white)
                            Text("★ SPOT IT TO CLAIM IT ★")
                                .font(AmericanaTheme.barlowSemiBold(11))
                                .foregroundColor(AmericanaTheme.yellow)
                        }
                        .frame(maxWidth: .infinity)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AmericanaTheme.yellow)
                            .frame(width: 6).padding(.vertical, 12).padding(.trailing, 10)
                    }
                }
                .frame(maxWidth: 400)
                .frame(height: 88)

                // Name field
                TextField("Enter your name", text: $appState.playerName)
                    .font(AmericanaTheme.barlowSemiBold(17))
                    .foregroundColor(AmericanaTheme.ink)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .frame(maxWidth: 360)

                // Buttons
                VStack(spacing: 14) {
                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.createGame()
                    }) {
                        Text("Create Game")
                            .font(AmericanaTheme.barlowBold(17))
                            .frame(maxWidth: 360).padding()
                            .background(AmericanaTheme.green)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.joinGame()
                    }) {
                        Text("Join Game")
                            .font(AmericanaTheme.barlowBold(17))
                            .frame(maxWidth: 360).padding()
                            .background(Color.clear)
                            .foregroundColor(AmericanaTheme.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(AmericanaTheme.green, lineWidth: 2)
                            )
                            .cornerRadius(14)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(48)
        }
    }
}
