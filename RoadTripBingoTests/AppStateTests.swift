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
}
