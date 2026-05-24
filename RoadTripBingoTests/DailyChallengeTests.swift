import XCTest
@testable import RoadTripBingo

final class DailyChallengeTests: XCTestCase {

    private func makeContext(
        playerName: String = "Zoe",
        marksThisRound: Int = 0,
        opponentMarkCounts: [String: Int] = [:],
        winsToday: Int = 0,
        attacksUsedThisRound: Int = 0,
        tokensAtEndOfRound: Int = 0,
        tokensSpentThisRound: Int = 0,
        roundsPlayedToday: Int = 0,
        localBoard: BingoBoard? = nil
    ) -> ChallengeEvaluationContext {
        ChallengeEvaluationContext(
            playerName: playerName,
            marksThisRound: marksThisRound,
            opponentMarkCounts: opponentMarkCounts,
            winsToday: winsToday,
            attacksUsedThisRound: attacksUsedThisRound,
            tokensAtEndOfRound: tokensAtEndOfRound,
            tokensSpentThisRound: tokensSpentThisRound,
            roundsPlayedToday: roundsPlayedToday,
            localBoard: localBoard
        )
    }

    private func makeBoard(marking positions: Set<Int> = []) -> BingoBoard {
        let squares = (0..<25).map { i -> BingoSquare in
            i == 12 ? .free : BingoSquare(id: UUID(), text: "T\(i)", emoji: "x",
                                           category: .nature, rarity: .common)
        }
        var board = BingoBoard(squares: squares)
        for pos in positions where pos != 12 { board.toggle(at: pos) }
        return board
    }

    func test_winOne_completesOnRoundWon() {
        let challenge = DailyChallenge(type: .winOne)
        let ctx = makeContext(playerName: "Zoe")
        XCTAssertTrue(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
        XCTAssertFalse(challenge.evaluate(event: .roundWon(byPlayer: "Emma"), context: ctx))
    }

    func test_speedDemon_completesWhenFirst_to5Marks() {
        let challenge = DailyChallenge(type: .speedDemon)
        let ctx = makeContext(playerName: "Zoe", marksThisRound: 5, opponentMarkCounts: ["Emma": 3])
        let tileID = UUID()
        XCTAssertTrue(challenge.evaluate(event: .tileMarked(tileID: tileID, byPlayer: "Zoe", isFirstInGame: false), context: ctx))
    }

    func test_speedDemon_doesNotComplete_ifOpponentAlreadyHas5() {
        let challenge = DailyChallenge(type: .speedDemon)
        let ctx = makeContext(playerName: "Zoe", marksThisRound: 5, opponentMarkCounts: ["Emma": 5])
        let tileID = UUID()
        XCTAssertFalse(challenge.evaluate(event: .tileMarked(tileID: tileID, byPlayer: "Zoe", isFirstInGame: false), context: ctx))
    }

    func test_pacifist_completesOnWinWithNoAttacks() {
        let challenge = DailyChallenge(type: .pacifist)
        let ctx = makeContext(playerName: "Zoe", attacksUsedThisRound: 0)
        XCTAssertTrue(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
    }

    func test_pacifist_doesNotComplete_ifAttacksUsed() {
        let challenge = DailyChallenge(type: .pacifist)
        let ctx = makeContext(playerName: "Zoe", attacksUsedThisRound: 1)
        XCTAssertFalse(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
    }

    func test_menace_completesOn3rdAttack() {
        let challenge = DailyChallenge(type: .menace)
        let ctx = makeContext(playerName: "Zoe", attacksUsedThisRound: 3)
        XCTAssertTrue(challenge.evaluate(event: .attackUsed(byPlayer: "Zoe"), context: ctx))
    }

    func test_hoarder_completesOnRoundEnd_with10Tokens() {
        let challenge = DailyChallenge(type: .hoarder)
        let ctx = makeContext(tokensAtEndOfRound: 10)
        XCTAssertTrue(challenge.evaluate(event: .roundEnded(context: ctx), context: ctx))
        let ctx2 = makeContext(tokensAtEndOfRound: 9)
        XCTAssertFalse(challenge.evaluate(event: .roundEnded(context: ctx2), context: ctx2))
    }

    func test_cornerKing_completesWhenAllCornersMarked() {
        let challenge = DailyChallenge(type: .cornerKing)
        let board = makeBoard(marking: [0, 4, 20, 24])
        let ctx = makeContext(localBoard: board)
        XCTAssertTrue(challenge.evaluate(event: .tileMarked(tileID: UUID(), byPlayer: "Zoe", isFirstInGame: false), context: ctx))
    }

    func test_onFire_completesOn2ndWin() {
        let challenge = DailyChallenge(type: .onFire)
        let ctx = makeContext(playerName: "Zoe", winsToday: 2)
        XCTAssertTrue(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx))
        let ctx1 = makeContext(playerName: "Zoe", winsToday: 1)
        XCTAssertFalse(challenge.evaluate(event: .roundWon(byPlayer: "Zoe"), context: ctx1))
    }

    func test_spender_completesOnRoundEnd_with10TokensSpent() {
        let challenge = DailyChallenge(type: .spender)
        let ctx = makeContext(tokensSpentThisRound: 10)
        XCTAssertTrue(challenge.evaluate(event: .roundEnded(context: ctx), context: ctx))
    }

    func test_firstBlood_completesOnFirstMarkOfFirstRound() {
        let challenge = DailyChallenge(type: .firstBlood)
        let ctx = makeContext(playerName: "Zoe", roundsPlayedToday: 0)
        XCTAssertTrue(challenge.evaluate(event: .tileMarked(tileID: UUID(), byPlayer: "Zoe", isFirstInGame: true), context: ctx))
    }

    func test_firstBlood_doesNotComplete_onSubsequentRounds() {
        let challenge = DailyChallenge(type: .firstBlood)
        let ctx = makeContext(playerName: "Zoe", roundsPlayedToday: 1)
        XCTAssertFalse(challenge.evaluate(event: .tileMarked(tileID: UUID(), byPlayer: "Zoe", isFirstInGame: true), context: ctx))
    }

    func test_dailyChallenge_codable_roundtrip() throws {
        for type in DailyChallengeType.allCases {
            let challenge = DailyChallenge(type: type)
            let data = try JSONEncoder().encode(challenge)
            let decoded = try JSONDecoder().decode(DailyChallenge.self, from: data)
            XCTAssertEqual(decoded.type, challenge.type)
        }
    }
}
