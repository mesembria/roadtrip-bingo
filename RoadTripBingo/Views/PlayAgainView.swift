import SwiftUI

struct PlayAgainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            VStack(spacing: 32) {
                Text("Session Standings")
                    .font(AmericanaTheme.rye(28))
                    .foregroundColor(AmericanaTheme.ink)
                VStack(spacing: 10) {
                    ForEach(appState.winHistory.sorted(by: { $0.value > $1.value }), id: \.key) { entry in
                        let name = entry.key
                        let wins = entry.value
                        HStack {
                            Text(wins == appState.winHistory.values.max() ? "🏆" : "  ")
                            Text(name)
                                .font(AmericanaTheme.barlowBold(16))
                                .foregroundColor(AmericanaTheme.ink)
                            Spacer()
                            Text("\(wins) win\(wins == 1 ? "" : "s")")
                                .font(AmericanaTheme.barlowSemiBold(13))
                                .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(AmericanaTheme.ink.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                }.frame(maxWidth: 400)
                VStack(spacing: 14) {
                    if appState.isHost {
                        Button(action: appState.requestPlayAgain) {
                            Text("New Game")
                                .font(AmericanaTheme.barlowBold(17))
                                .frame(maxWidth: 360).padding()
                                .background(AmericanaTheme.green)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    } else {
                        Text("Waiting for host to start a new game…")
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                    }
                    Button(action: appState.goHome) {
                        Text("Go Home")
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
                }
            }.padding(48)
        }
    }
}
