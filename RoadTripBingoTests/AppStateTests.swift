import XCTest
@testable import RoadTripBingo

final class AppStateTests: XCTestCase {

    private func makeBoard(targetText: String, atIndex targetIdx: Int) -> BingoBoard {
        var squares: [BingoSquare] = (0..<25).map { i in
            i == 12
                ? BingoSquare.free
                : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "🐄",
                              category: .nature, rarity: .veryCommon)
        }
        squares[targetIdx] = BingoSquare(id: UUID(), text: targetText, emoji: "👶",
                                         category: .nature, rarity: .common)
        return BingoBoard(squares: squares)
    }

    private func makeSession() -> MultipeerSession {
        MultipeerSession(displayName: "test-helper")
    }

    func test_powerUpUsed_downgrade_targeted_postsThreatsToast() {
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Sleeping Baby", atIndex: 3)

        let replacement = BingoSquare(id: UUID(), text: "Hard Thing", emoji: "🔥",
                                      category: .nature, rarity: .veryRare)
        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .downgradeTileTargeted,
                                     targetPlayer: "Zoe", targetIndex: 3,
                                     replacementSquare: replacement),
            from: "Liam")

        XCTAssertEqual(state.pendingToast?.message, "💣 Liam downgraded 'Sleeping Baby'")
        XCTAssertEqual(state.pendingToast?.style, .threat)
    }

    func test_powerUpUsed_unmark_targeted_postsThreatsToast() {
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Rest Stop", atIndex: 7)

        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .unmarkOpponentTargeted,
                                     targetPlayer: "Zoe", targetIndex: 7,
                                     replacementSquare: nil),
            from: "Liam")

        XCTAssertEqual(state.pendingToast?.message, "💥 Liam erased 'Rest Stop'")
        XCTAssertEqual(state.pendingToast?.style, .threat)
    }

    func test_powerUpUsed_upgrade_doesNotPostThreatsToast() {
        // Upgrade affects activating player's own board — not an opponent-targeting action
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Irrelevant", atIndex: 3)

        let replacement = BingoSquare(id: UUID(), text: "Easy", emoji: "🌱",
                                      category: .nature, rarity: .veryCommon)
        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .upgradeTileTargeted,
                                     targetPlayer: nil, targetIndex: 3,
                                     replacementSquare: replacement),
            from: "Liam")

        XCTAssertNil(state.pendingToast)
    }

    func test_powerUpUsed_downgrade_notTargetingMe_doesNotPostThreatsToast() {
        // Liam is targeting "Emma", not "Zoe"
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Irrelevant", atIndex: 3)
        state.opponentBoards["Emma"] = makeBoard(targetText: "Emma Tile", atIndex: 3).squares

        let replacement = BingoSquare(id: UUID(), text: "Hard", emoji: "🔥",
                                      category: .nature, rarity: .veryRare)
        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .downgradeTileTargeted,
                                     targetPlayer: "Emma", targetIndex: 3,
                                     replacementSquare: replacement),
            from: "Liam")

        XCTAssertNil(state.pendingToast)
    }

    func test_activatePowerUp_upgrade_random_postsToastWithOldTileName() {
        let state = AppState()
        state.playerName = "Zoe"
        state.tokenBalance = 10

        // Make index 3 the hardest tile so highestRarityIndex picks it
        var squares: [BingoSquare] = (0..<25).map { i in
            i == 12 ? BingoSquare.free
                    : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "🐄",
                                  category: .nature, rarity: .veryCommon)
        }
        squares[3] = BingoSquare(id: UUID(), text: "Super Hard Thing", emoji: "🔥",
                                  category: .nature, rarity: .veryRare)
        state.localBoard = BingoBoard(squares: squares)
        state.reserveSquares = [BingoSquare(id: UUID(), text: "Easy", emoji: "🌱",
                                             category: .nature, rarity: .veryCommon)]

        state.activatePowerUp(.upgradeTileRandom)

        XCTAssertEqual(state.pendingToast?.message, "🔀 Upgraded 'Super Hard Thing'")
        XCTAssertEqual(state.pendingToast?.style, .earn)
    }

    func test_activatePowerUp_freeMark_postsToastWithTileName() {
        let state = AppState()
        state.playerName = "Zoe"
        state.tokenBalance = 10

        var squares: [BingoSquare] = (0..<25).map { i in
            i == 12 ? BingoSquare.free
                    : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "🐄",
                                  category: .nature, rarity: .veryCommon)
        }
        squares[5] = BingoSquare(id: UUID(), text: "Scenic Overlook", emoji: "🏔️",
                                  category: .landmarks, rarity: .rare)
        state.localBoard = BingoBoard(squares: squares)

        state.activatePowerUp(.freeMark, targetIndex: 5)

        XCTAssertEqual(state.pendingToast?.message, "✅ Marked 'Scenic Overlook'")
        XCTAssertEqual(state.pendingToast?.style, .earn)
    }

    func test_powerUpUsed_unmark_random_postsThreatsToast() {
        let state = AppState()
        state.playerName = "Zoe"
        state.localBoard = makeBoard(targetText: "Scenic Overlook", atIndex: 5)

        state.multipeerSession(makeSession(),
            didReceive: .powerUpUsed(byName: "Liam", powerUp: .unmarkOpponentRandom,
                                     targetPlayer: "Zoe", targetIndex: 5,
                                     replacementSquare: nil),
            from: "Liam")

        XCTAssertEqual(state.pendingToast?.message, "💥 Liam erased 'Scenic Overlook'")
        XCTAssertEqual(state.pendingToast?.style, .threat)
    }

    func test_squareToggled_isMarked_appendsRecentMark() {
        let state = AppState()
        let targetSquare = BingoSquare(id: UUID(), text: "Red Car", emoji: "x",
                                       category: .vehicles, rarity: .common)
        state.opponentBoards["Emma"] = (0..<25).map { i in
            if i == 5  { return targetSquare }
            if i == 12 { return BingoSquare.free }
            return BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                               category: .nature, rarity: .veryCommon)
        }
        state.opponentMarked["Emma"] = [BingoSquare.freeSquareID]

        state.multipeerSession(makeSession(),
            didReceive: .squareToggled(position: 5, isMarked: true),
            from: "Emma")

        XCTAssertEqual(state.recentOpponentMarks.count, 1)
        XCTAssertEqual(state.recentOpponentMarks[0].opponentName, "Emma")
        XCTAssertEqual(state.recentOpponentMarks[0].square.text, "Red Car")
    }

    func test_squareToggled_notMarked_doesNotAppendRecentMark() {
        let state = AppState()
        let targetSquare = BingoSquare(id: UUID(), text: "Red Car", emoji: "x",
                                       category: .vehicles, rarity: .common)
        state.opponentBoards["Emma"] = (0..<25).map { i in
            if i == 5  { return targetSquare }
            if i == 12 { return BingoSquare.free }
            return BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                               category: .nature, rarity: .veryCommon)
        }
        state.opponentMarked["Emma"] = [targetSquare.id, BingoSquare.freeSquareID]

        state.multipeerSession(makeSession(),
            didReceive: .squareToggled(position: 5, isMarked: false),
            from: "Emma")

        XCTAssertTrue(state.recentOpponentMarks.isEmpty)
    }

    func test_recentMarks_capped_at_three_drops_oldest() {
        let state = AppState()
        let squares: [BingoSquare] = (0..<25).map { i in
            i == 12 ? BingoSquare.free
                    : BingoSquare(id: UUID(), text: "Tile \(i)", emoji: "x",
                                  category: .nature, rarity: .veryCommon)
        }
        state.opponentBoards["Emma"] = squares
        state.opponentMarked["Emma"] = [BingoSquare.freeSquareID]

        let session = makeSession()
        for pos in [0, 1, 2, 3] {
            state.multipeerSession(session,
                didReceive: .squareToggled(position: pos, isMarked: true),
                from: "Emma")
        }

        XCTAssertEqual(state.recentOpponentMarks.count, 3)
        XCTAssertEqual(state.recentOpponentMarks[0].square.text, "Tile 1")
        XCTAssertEqual(state.recentOpponentMarks[2].square.text, "Tile 3")
    }

    func test_gameStarted_clearsRecentMarks() {
        let state = AppState()
        state.playerName = "Zoe"
        let stub = BingoSquare(id: UUID(), text: "Stub", emoji: "x",
                               category: .nature, rarity: .veryCommon)
        state.recentOpponentMarks = [RecentMark(opponentName: "Emma",
                                                 square: stub, timestamp: Date())]

        var boards: [String: [BingoSquare]] = [:]
        for name in ["Zoe", "Emma"] {
            boards[name] = (0..<25).map { i in
                i == 12 ? BingoSquare.free
                        : BingoSquare(id: UUID(), text: "\(name) \(i)", emoji: "x",
                                      category: .nature, rarity: .veryCommon)
            }
        }
        state.multipeerSession(makeSession(),
            didReceive: .gameStarted(boards: boards),
            from: "host")

        XCTAssertTrue(state.recentOpponentMarks.isEmpty)
    }

    func test_handicapBonusTokens_level0_returnsZero() {
        XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 0), 0)
    }

    func test_handicapBonusTokens_level1_returns3() {
        XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 1), 3)
    }

    func test_handicapBonusTokens_level2_returns5() {
        XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 2), 5)
    }

    func test_handicapBonusTokens_level3_returns7() {
        XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 3), 7)
    }

    func test_handicapBonusTokens_levelAbove3_returns7() {
        XCTAssertEqual(AppState.handicapBonusTokens(forLevel: 99), 7)
    }

    func test_handicapBonus_message_creditsTokensSilently() {
        let state = AppState()
        state.playerName = "Theo"
        let session = MultipeerSession(displayName: "test-helper")

        state.multipeerSession(session,
            didReceive: .handicapBonus(toPlayer: "Theo", tokens: 5),
            from: "host")

        XCTAssertEqual(state.tokenBalance, 5, "Handicap bonus should credit tokens")
        XCTAssertNil(state.pendingToast, "Handicap bonus must not trigger a toast")
    }

    func test_handicapBonus_message_ignoredForOtherPlayer() {
        let state = AppState()
        state.playerName = "Theo"
        let session = MultipeerSession(displayName: "test-helper")

        state.multipeerSession(session,
            didReceive: .handicapBonus(toPlayer: "AnotherPlayer", tokens: 5),
            from: "host")

        XCTAssertEqual(state.tokenBalance, 0, "Bonus for another player must not credit local balance")
    }

    func test_appState_defaultGameMode_isMultiplayer() {
        let state = AppState()
        XCTAssertEqual(state.gameMode, .multiplayer)
    }

    func test_activeChallenges_solo_excludesPacifistAndMenace() {
        let state = AppState()
        // Force a known challenge set that includes pacifist and menace
        state.dailyState = DailyState(
            date: DailyState.today(),
            challengeTypes: [.pacifist, .menace, .winOne],
            completedIDs: [],
            winsToday: 0,
            roundsPlayedToday: 0
        )
        state.gameMode = .solo
        let ids = state.activeChallenges.map(\.type)
        XCTAssertFalse(ids.contains(.pacifist))
        XCTAssertFalse(ids.contains(.menace))
        XCTAssertTrue(ids.contains(.winOne))
    }

    func test_activeChallenges_multiplayer_includesPacifistAndMenace() {
        let state = AppState()
        state.dailyState = DailyState(
            date: DailyState.today(),
            challengeTypes: [.pacifist, .menace, .winOne],
            completedIDs: [],
            winsToday: 0,
            roundsPlayedToday: 0
        )
        state.gameMode = .multiplayer
        let ids = state.activeChallenges.map(\.type)
        XCTAssertTrue(ids.contains(.pacifist))
        XCTAssertTrue(ids.contains(.menace))
    }

    func test_tokensEarnedThisRound_startsAtZero() {
        let state = AppState()
        XCTAssertEqual(state.tokensEarnedThisRound, 0)
    }
}
