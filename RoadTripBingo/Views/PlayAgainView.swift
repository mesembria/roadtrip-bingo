import SwiftUI

struct PlayAgainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            VStack(spacing: 36) {
                Text("Session Standings")
                    .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.white)
                VStack(spacing: 10) {
                    ForEach(appState.winHistory.sorted(by: { $0.value > $1.value }), id: \.key) { entry in
                        let name = entry.key
                        let wins = entry.value
                        HStack {
                            Text(wins == appState.winHistory.values.max() ? "🏆" : "  ")
                            Text(name).font(.headline).foregroundColor(.white)
                            Spacer()
                            Text("\(wins) win\(wins == 1 ? "" : "s")").font(.subheadline).foregroundColor(.white.opacity(0.6))
                        }
                        .padding().background(Color.white.opacity(0.06)).cornerRadius(10)
                    }
                }.frame(maxWidth: 400)
                VStack(spacing: 14) {
                    if appState.isHost {
                        Button(action: appState.requestPlayAgain) {
                            Label("New Game", systemImage: "arrow.clockwise")
                                .font(.title3.bold()).frame(maxWidth: 360).padding()
                                .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                        }
                    } else {
                        Text("Waiting for host to start a new game…").font(.subheadline).foregroundColor(.white.opacity(0.6))
                    }
                    Button(action: appState.goHome) {
                        Label("Go Home", systemImage: "house.fill")
                            .font(.title3.bold()).frame(maxWidth: 360).padding()
                            .background(Color.white.opacity(0.10)).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }.padding(48)
        }
    }
}
