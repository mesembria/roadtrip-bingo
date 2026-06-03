import XCTest
@testable import RoadTripBingo

final class MultipeerMessageTests: XCTestCase {

    private func roundtrip(_ message: MultipeerMessage) throws -> MultipeerMessage {
        let data = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(MultipeerMessage.self, from: data)
    }

    func test_gameStarted_roundtrip() throws {
        let square = BingoSquare(id: UUID(), text: "Cow", emoji: "🐄", category: .nature, rarity: .veryCommon)
        let boards: [String: [BingoSquare]] = ["Emma": [square]]
        let msg = MultipeerMessage.gameStarted(boards: boards, activePackIDs: ["farm-country"], gameType: .bingo)
        let decoded = try roundtrip(msg)
        guard case .gameStarted(let decodedBoards, let packIDs, let gameType) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(decodedBoards["Emma"]?.first?.text, "Cow")
        XCTAssertEqual(packIDs, ["farm-country"])
        XCTAssertEqual(gameType, .bingo)
    }

    func test_squareToggled_roundtrip() throws {
        let msg = MultipeerMessage.squareToggled(position: 7, isMarked: true)
        let decoded = try roundtrip(msg)
        guard case .squareToggled(let pos, let marked) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(pos, 7)
        XCTAssertTrue(marked)
    }

    func test_bingoAnnounced_roundtrip() throws {
        let msg = MultipeerMessage.bingoAnnounced(byName: "Liam")
        let decoded = try roundtrip(msg)
        guard case .bingoAnnounced(let name) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(name, "Liam")
    }

    func test_playAgain_roundtrip() throws {
        let square = BingoSquare(id: UUID(), text: "Barn", emoji: "🏚️", category: .nature, rarity: .veryCommon)
        let boards: [String: [BingoSquare]] = ["Zoe": [square]]
        let msg = MultipeerMessage.playAgain(boards: boards, activePackIDs: [], gameType: .bingo)
        let decoded = try roundtrip(msg)
        guard case .playAgain(let decodedBoards, let packIDs, let gameType) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(decodedBoards["Zoe"]?.first?.text, "Barn")
        XCTAssertTrue(packIDs.isEmpty)
        XCTAssertEqual(gameType, .bingo)
    }

    func test_difficultyChosen_roundtrip() throws {
        let msg = MultipeerMessage.difficultyChosen(byName: "Zoe", difficulty: .navigator)
        let decoded = try roundtrip(msg)
        guard case .difficultyChosen(let name, let diff) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(name, "Zoe")
        XCTAssertEqual(diff, .navigator)
    }

    func test_tokenEarned_roundtrip() throws {
        let msg = MultipeerMessage.tokenEarned(byName: "Zoe", newBalance: 12)
        let decoded = try roundtrip(msg)
        guard case .tokenEarned(let name, let balance) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(name, "Zoe")
        XCTAssertEqual(balance, 12)
    }

    func test_powerUpUsed_roundtrip_withAllFields() throws {
        let square = BingoSquare(id: UUID(), text: "Cow", emoji: "🐄", category: .nature, rarity: .veryCommon)
        let msg = MultipeerMessage.powerUpUsed(
            byName: "Liam",
            powerUp: .upgradeTileTargeted,
            targetPlayer: nil,
            targetIndex: 5,
            replacementSquare: square
        )
        let decoded = try roundtrip(msg)
        guard case .powerUpUsed(let name, let powerUp, let tp, let ti, let rs) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(name, "Liam")
        XCTAssertEqual(powerUp, .upgradeTileTargeted)
        XCTAssertNil(tp)
        XCTAssertEqual(ti, 5)
        XCTAssertEqual(rs?.text, "Cow")
    }

    func test_powerUpUsed_roundtrip_nilFields() throws {
        let msg = MultipeerMessage.powerUpUsed(
            byName: "Liam",
            powerUp: .unmarkOpponentRandom,
            targetPlayer: "Zoe",
            targetIndex: 3,
            replacementSquare: nil
        )
        let decoded = try roundtrip(msg)
        guard case .powerUpUsed(_, _, let tp, let ti, let rs) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(tp, "Zoe")
        XCTAssertEqual(ti, 3)
        XCTAssertNil(rs)
    }

    func test_reserveDealt_roundtrip() throws {
        let square = BingoSquare(id: UUID(), text: "Barn", emoji: "🏚️", category: .nature, rarity: .common)
        let msg = MultipeerMessage.reserveDealt(toName: "Liam", squares: [square])
        let decoded = try roundtrip(msg)
        guard case .reserveDealt(let name, let squares) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertEqual(name, "Liam")
        XCTAssertEqual(squares.first?.text, "Barn")
    }

    func test_encode_decode_roundModifier() throws {
        let modifiers: [RoundModifier] = [
            .hotStreak, .doubleDown, .noPowers, .sniper,
            .fogOfWar, .shiftingTiles, .shuffleBoard,
            .patternWin(.x), .patternWin(.fourCorners), .patternWin(.plus)
        ]
        for modifier in modifiers {
            let message = MultipeerMessage.roundModifier(modifier)
            let data = try JSONEncoder().encode(message)
            let decoded = try JSONDecoder().decode(MultipeerMessage.self, from: data)
            guard case .roundModifier(let decodedModifier) = decoded else {
                XCTFail("Expected roundModifier, got \(decoded)")
                return
            }
            XCTAssertEqual(decodedModifier, modifier)
        }
    }

    func test_encode_decode_boardShuffled() throws {
        let squares: [BingoSquare] = [.free]
        let message = MultipeerMessage.boardShuffled(byName: "Emma", squares: squares)
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(MultipeerMessage.self, from: data)
        guard case .boardShuffled(let byName, let decodedSquares) = decoded else {
            XCTFail("Expected boardShuffled, got \(decoded)")
            return
        }
        XCTAssertEqual(byName, "Emma")
        XCTAssertEqual(decodedSquares.count, 1)
        XCTAssertEqual(decodedSquares[0].id, BingoSquare.freeSquareID)
    }

    func test_handicapBonus_roundtrip() throws {
        let msg = MultipeerMessage.handicapBonus(toPlayer: "Theo", tokens: 5)
        let decoded = try roundtrip(msg)
        guard case .handicapBonus(let toPlayer, let tokens) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(toPlayer, "Theo")
        XCTAssertEqual(tokens, 5)
    }

    func test_gameStarted_backwardCompat_missingActivePackIDsDecodesAsEmpty() throws {
        // Simulate a message from an older client that doesn't send activePackIDs
        let json = """
        {
          "type": "gameStarted",
          "boards": {}
        }
        """
        let decoded = try JSONDecoder().decode(MultipeerMessage.self, from: Data(json.utf8))
        guard case .gameStarted(_, let packIDs, _) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertTrue(packIDs.isEmpty, "Missing activePackIDs should decode as empty array")
    }

    func test_playAgain_backwardCompat_missingActivePackIDsDecodesAsEmpty() throws {
        // Simulate a message from an older client that doesn't send activePackIDs
        let json = """
        {
          "type": "playAgain",
          "boards": {}
        }
        """
        let decoded = try JSONDecoder().decode(MultipeerMessage.self, from: Data(json.utf8))
        guard case .playAgain(_, let packIDs, _) = decoded else {
            return XCTFail("Wrong case")
        }
        XCTAssertTrue(packIDs.isEmpty, "Missing activePackIDs should decode as empty array")
    }
}
