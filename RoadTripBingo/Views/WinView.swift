import SwiftUI

struct WinView: View {
    let winnerName: String
    @EnvironmentObject var appState: AppState
    private var isLocalWin: Bool { winnerName == appState.playerName }
    @State private var didAppear = false
    @State private var pbPulse = false

    var body: some View {
        ZStack {
            AmericanaTheme.gridBackground().ignoresSafeArea()
            if isLocalWin { ConfettiView() }
            if appState.gameType == .spottingRace {
                if appState.gameMode == .solo {
                    spottingRaceSoloContent
                } else {
                    spottingRaceMultiplayerContent
                }
            } else if appState.gameMode == .solo {
                soloContent
            } else {
                multiplayerContent
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: didAppear)
        .onAppear { if isLocalWin { didAppear = true } }
        .alert("Game Ended", isPresented: $appState.gameEndedByHost) {
            Button("OK") { appState.goHome() }
        } message: {
            Text("The host ended the game.")
        }
    }

    // MARK: - Multiplayer (original layout)

    private var multiplayerContent: some View {
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

    // MARK: - Solo

    private var soloContent: some View {
        VStack(spacing: 28) {
            Text("🏆").font(.system(size: 96))
            Text("YOU GOT BINGO!")
                .font(AmericanaTheme.rye(38))
                .foregroundColor(AmericanaTheme.yellow)
                .multilineTextAlignment(.center)

            scoreBreakdownCard

            personalBestBadge
                .onAppear { if appState.lastSoloIsNewBest { pbPulse = true } }

            VStack(spacing: 12) {
                Button(action: { appState.startSoloGame() }) {
                    HStack {
                        Text("Play Again")
                            .font(AmericanaTheme.barlowBold(18))
                            .kerning(2)
                        Spacer()
                        Text("→").opacity(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(16)
                    .frame(maxWidth: 360)
                    .background(AmericanaTheme.green)
                    .cornerRadius(11)
                    .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094),
                            radius: 0, x: 0, y: 4)
                }

                Button(action: { appState.goHome() }) {
                    HStack {
                        Text("Done")
                            .font(AmericanaTheme.barlowBold(18))
                            .kerning(2)
                        Spacer()
                        Text("→").opacity(0.35)
                    }
                    .foregroundColor(AmericanaTheme.brown)
                    .padding(14)
                    .frame(maxWidth: 360)
                    .background(AmericanaTheme.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(AmericanaTheme.brown.opacity(0.5), lineWidth: 2)
                    )
                    .cornerRadius(11)
                }
            }
        }
        .padding(48)
    }

    // MARK: - Spotting Race Solo

    private var spottingRaceSoloContent: some View {
        VStack(spacing: 28) {
            Text("⏱️").font(.system(size: 96))

            Text("TIME'S UP!")
                .font(AmericanaTheme.rye(38))
                .foregroundColor(AmericanaTheme.yellow)
                .multilineTextAlignment(.center)

            spottingRaceScoreBreakdownCard

            personalBestBadge
                .onAppear { if appState.lastSoloIsNewBest { pbPulse = true } }

            VStack(spacing: 12) {
                Button(action: { appState.startSpottingRaceSolo() }) {
                    HStack {
                        Text("Play Again")
                            .font(AmericanaTheme.barlowBold(18)).kerning(2)
                        Spacer()
                        Text("→").opacity(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(16).frame(maxWidth: 360)
                    .background(AmericanaTheme.green)
                    .cornerRadius(11)
                    .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 4)
                }

                Button(action: { appState.goHome() }) {
                    HStack {
                        Text("Done")
                            .font(AmericanaTheme.barlowBold(18)).kerning(2)
                        Spacer()
                        Text("→").opacity(0.35)
                    }
                    .foregroundColor(AmericanaTheme.brown)
                    .padding(14).frame(maxWidth: 360)
                    .background(AmericanaTheme.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(AmericanaTheme.brown.opacity(0.5), lineWidth: 2))
                    .cornerRadius(11)
                }
            }
        }
        .padding(48)
    }

    private var spottingRaceScoreBreakdownCard: some View {
        VStack(spacing: 0) {
            Text("SCORE BREAKDOWN")
                .font(AmericanaTheme.barlowSemiBold(10))
                .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                .kerning(3)
                .padding(.bottom, 12)

            scoreRow(label: "Tiles claimed", value: appState.lastSoloTokens)
            scoreRow(label: "Rarity score", value: appState.lastSoloRarityBonus)

            Divider().padding(.vertical, 8)

            HStack {
                Text("× \(String(format: "%.2f", appState.lastSoloTimeMultiplier))×  (volume)")
                    .font(AmericanaTheme.barlowSemiBold(15))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.55))
                Spacer()
            }
            .padding(.vertical, 2)

            Divider().padding(.vertical, 8)

            HStack {
                Text("Total")
                    .font(AmericanaTheme.barlowBold(17)).foregroundColor(AmericanaTheme.ink)
                Spacer()
                Text("\(appState.lastSoloScore)")
                    .font(AmericanaTheme.barlowBold(24)).foregroundColor(AmericanaTheme.green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: 360)
    }

    // MARK: - Spotting Race Multiplayer

    private var spottingRaceMultiplayerContent: some View {
        VStack(spacing: 32) {
            Text("⏱️").font(.system(size: 96))

            Text("TIME'S UP!")
                .font(AmericanaTheme.rye(38))
                .foregroundColor(AmericanaTheme.yellow)
                .multilineTextAlignment(.center)

            // Scores — local player first, then opponents sorted by score
            HStack(spacing: 16) {
                spottingScoreCard(
                    name: appState.playerName,
                    score: appState.mySpottingScore,
                    isWinner: isLocalWin
                )
                ForEach(
                    appState.opponentSpottingScores.sorted(by: { $0.value > $1.value }),
                    id: \.key
                ) { name, score in
                    spottingScoreCard(
                        name: name,
                        score: score,
                        isWinner: name == winnerName
                    )
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
        }
        .padding(48)
    }

    private func spottingScoreCard(name: String, score: Int, isWinner: Bool) -> some View {
        VStack(spacing: 6) {
            if isWinner { Text("🏆").font(.system(size: 28)) }
            Text(name)
                .font(AmericanaTheme.barlowBold(16))
                .foregroundColor(AmericanaTheme.ink)
            Text("\(score) pts")
                .font(AmericanaTheme.rye(28))
                .foregroundColor(isWinner ? AmericanaTheme.green : AmericanaTheme.ink.opacity(0.65))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: AmericanaTheme.shadow, radius: isWinner ? 10 : 4, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isWinner ? AmericanaTheme.green : Color.clear, lineWidth: 2)
                )
        )
    }

    // MARK: - Score breakdown card

    private var scoreBreakdownCard: some View {
        VStack(spacing: 0) {
            Text("SCORE BREAKDOWN")
                .font(AmericanaTheme.barlowSemiBold(10))
                .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                .kerning(3)
                .padding(.bottom, 12)

            scoreRow(label: "Tokens earned", value: appState.lastSoloTokens)

            if appState.lastSoloRarityBonus > 0 {
                scoreRow(label: "Rarity bonus", value: appState.lastSoloRarityBonus)
            }

            if appState.lastSoloExtraLines > 0 {
                scoreRow(
                    label: "Extra lines ×\(appState.lastSoloExtraLines)",
                    value: appState.lastSoloExtraLines * 10
                )
            }

            Divider()
                .padding(.vertical, 8)

            let base = appState.lastSoloTokens
                     + appState.lastSoloRarityBonus
                     + appState.lastSoloExtraLines * 10
            scoreRow(label: "Base score", value: base)

            HStack {
                Text("× \(String(format: "%.1f", appState.lastSoloTimeMultiplier))×  (time)")
                    .font(AmericanaTheme.barlowSemiBold(15))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.55))
                Spacer()
            }
            .padding(.vertical, 2)

            Divider()
                .padding(.vertical, 8)

            HStack {
                Text("Total")
                    .font(AmericanaTheme.barlowBold(17))
                    .foregroundColor(AmericanaTheme.ink)
                Spacer()
                Text("\(appState.lastSoloScore)")
                    .font(AmericanaTheme.barlowBold(24))
                    .foregroundColor(AmericanaTheme.green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: 360)
    }

    private func scoreRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(AmericanaTheme.barlowSemiBold(15))
                .foregroundColor(AmericanaTheme.ink)
            Spacer()
            Text("\(value)")
                .font(AmericanaTheme.barlowSemiBold(15))
                .foregroundColor(AmericanaTheme.ink)
        }
        .padding(.vertical, 2)
    }

    private var personalBestBadge: some View {
        Group {
            if appState.lastSoloIsNewBest {
                Text("★  New personal best!")
                    .font(AmericanaTheme.barlowBold(16))
                    .foregroundColor(AmericanaTheme.yellow)
                    .scaleEffect(pbPulse ? 1.12 : 1.0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.4).repeatCount(3, autoreverses: true),
                        value: pbPulse
                    )
            } else if appState.soloPersonalBest > 0 {
                Text("Your best: \(appState.soloPersonalBest)")
                    .font(AmericanaTheme.barlowSemiBold(14))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.45))
            }
        }
    }

    // MARK: - Shared helpers

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
                } else if let emoji = square.emoji {
                    Text(emoji).font(.title)
                }
            }
            .padding(6)
            .frame(width: 48, height: 48)
        }
        .frame(width: 60, height: 60)
    }
}
