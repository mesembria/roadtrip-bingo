import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showChallenges = false
    @State private var showPacks = false

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                leftPanel
                    .frame(width: geo.size.width - 400, height: geo.size.height)
                rightPanel
                    .frame(width: 400, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Left panel (image + badge)

    private var leftPanel: some View {
        ZStack {
            // Background photo
            if let bg = AmericanaTheme.splashBackground() {
                bg.resizable().scaledToFill()
            } else {
                AmericanaTheme.gridBackground()
            }

            // Subtle scrim so badge reads cleanly
            Color.black.opacity(0.20)

            VStack(spacing: 16) {
                titleBadge
                miniBingoCard
            }
        }
        .clipped()
    }

    private var titleBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(AmericanaTheme.green)
                .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 5)
                .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1.5)
                .padding(6)
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AmericanaTheme.yellow)
                    .frame(width: 5)
                    .padding(.vertical, 13).padding(.leading, 13)
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(AmericanaTheme.yellow)
                    .frame(width: 5)
                    .padding(.vertical, 13).padding(.trailing, 13)
            }
            VStack(spacing: 2) {
                Text("ROAD TRIP")
                    .font(AmericanaTheme.rye(18))
                    .foregroundColor(.white.opacity(0.70))
                    .kerning(5)
                Text("BINGO")
                    .font(AmericanaTheme.rye(64))
                    .foregroundColor(AmericanaTheme.yellow)
                    .shadow(color: .black.opacity(0.20), radius: 0, x: 3, y: 3)
            }
            .padding(.horizontal, 52).padding(.vertical, 18)
        }
        .fixedSize()
    }

    private var miniBingoCard: some View {
        let pattern: [Bool] = [
            true,  false, false, true,  false,
            false, true,  false, false, true,
            false, false, false, false, false, // center row — free square handled separately
            true,  false, false, true,  false,
            false, false, true,  false, true,
        ]
        return VStack(spacing: 3) {
            // Header row
            HStack(spacing: 3) {
                ForEach(["B","I","N","G","O"], id: \.self) { letter in
                    Text(letter)
                        .font(AmericanaTheme.rye(11))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(AmericanaTheme.green)
                        .cornerRadius(4)
                }
            }
            // Grid rows
            ForEach(0..<5) { row in
                HStack(spacing: 3) {
                    ForEach(0..<5) { col in
                        let idx = row * 5 + col
                        let isFree = (row == 2 && col == 2)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isFree ? AmericanaTheme.yellow : (pattern[idx] ? AmericanaTheme.green.opacity(0.8) : Color(red: 0.94, green: 0.93, blue: 0.91)))
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 16, x: 4, y: 6)
        .rotationEffect(.degrees(4))
    }

    // MARK: - Game mode picker

    private var gameModePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("GAME MODE")
                .font(AmericanaTheme.barlowSemiBold(10))
                .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                .kerning(3)
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                gameModeCard(title: "Classic Bingo", subtitle: "5×5 grid", type: .bingo)
                gameModeCard(title: "Spotting Race", subtitle: "Time attack", type: .spottingRace)
            }
        }
        .padding(.bottom, 24)
    }

    private func gameModeCard(title: String, subtitle: String, type: GameType) -> some View {
        let selected = appState.gameType == type
        return Button(action: { appState.gameType = type }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AmericanaTheme.barlowBold(14))
                    .foregroundColor(selected ? .white : AmericanaTheme.ink)
                Text(subtitle)
                    .font(AmericanaTheme.barlowSemiBold(11))
                    .foregroundColor(selected ? .white.opacity(0.70) : AmericanaTheme.ink.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(selected ? AmericanaTheme.green : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(
                                selected ? Color.clear : AmericanaTheme.ink.opacity(0.12),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right panel (controls)

    private var rightPanel: some View {
        ZStack {
            AmericanaTheme.paper.ignoresSafeArea()
            // Subtle left border
            HStack(spacing: 0) {
                Rectangle()
                    .fill(AmericanaTheme.ink.opacity(0.08))
                    .frame(width: 1)
                Spacer()
            }

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    // Heading
                    HStack {
                        Text("Join the Journey")
                            .font(AmericanaTheme.rye(15))
                            .foregroundColor(AmericanaTheme.ink)
                        Rectangle()
                            .fill(AmericanaTheme.ink.opacity(0.10))
                            .frame(height: 1)
                    }
                    .padding(.bottom, 28)

                    // Game mode picker
                    gameModePicker

                    // Name field
                    Text("YOUR NAME")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.40))
                        .kerning(3)
                        .padding(.bottom, 8)

                    TextField("Enter your name", text: $appState.playerName)
                        .font(AmericanaTheme.barlowSemiBold(19))
                        .foregroundColor(AmericanaTheme.ink)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(AmericanaTheme.ink.opacity(0.12), lineWidth: 1.5)
                                )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .padding(.bottom, 24)

                    // Buttons
                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.createGame()
                    }) {
                        HStack {
                            Text("Create Game")
                                .font(AmericanaTheme.barlowBold(18))
                                .kerning(2)
                            Spacer()
                            Text("→").opacity(0.5)
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(AmericanaTheme.green)
                        .cornerRadius(11)
                        .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 4)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.bottom, 12)

                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.joinGame()
                    }) {
                        HStack {
                            Text("Join Game")
                                .font(AmericanaTheme.barlowBold(18))
                                .kerning(2)
                            Spacer()
                            Text("→").opacity(0.35)
                        }
                        .foregroundColor(AmericanaTheme.green)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(AmericanaTheme.green, lineWidth: 2)
                        )
                        .cornerRadius(11)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.bottom, 20)

                    Button(action: {
                        guard !appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        if appState.gameType == .spottingRace {
                            appState.startSpottingRaceSolo()
                        } else {
                            appState.startSoloGame()
                        }
                    }) {
                        HStack {
                            Text("Play Solo")
                                .font(AmericanaTheme.barlowBold(18))
                                .kerning(2)
                            Spacer()
                            Text("→").opacity(0.35)
                        }
                        .foregroundColor(AmericanaTheme.brown)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(AmericanaTheme.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(AmericanaTheme.brown.opacity(0.5), lineWidth: 2)
                        )
                        .cornerRadius(11)
                    }
                    .disabled(appState.playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.bottom, 20)

                    Button {
                        showChallenges = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("🎯")
                            Text("Today's Challenges")
                                .font(AmericanaTheme.barlowBold(15))
                        }
                        .foregroundColor(AmericanaTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AmericanaTheme.yellow.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(AmericanaTheme.ink.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .frame(maxWidth: 360)
                    .padding(.bottom, 12)
                    .sheet(isPresented: $showChallenges) {
                        DailyChallengesView(
                            challenges: appState.activeChallenges,
                            completedIDs: appState.dailyState.completedIDs
                        )
                        .presentationDetents([.large])
                    }

                    Button {
                        showPacks = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 13))
                            Text("Tile Packs")
                                .font(AmericanaTheme.barlowBold(15))
                        }
                        .foregroundColor(AmericanaTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AmericanaTheme.parchment)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(AmericanaTheme.brown.opacity(0.5), lineWidth: 1.5)
                                )
                        )
                    }
                    .frame(maxWidth: 360)
                    .sheet(isPresented: $showPacks) {
                        TilePacksView()
                            .presentationDetents([.large])
                    }
                }

                Spacer()

                Text("★  SPOT IT TO CLAIM IT  ★")
                    .font(AmericanaTheme.barlowSemiBold(10))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.22))
                    .kerning(3)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 32)
        }
    }
}
