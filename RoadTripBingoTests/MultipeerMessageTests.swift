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
        let msg = MultipeerMessage.gameStarted(boards: boards)
        let decoded = try roundtrip(msg)
        guard case .gameStarted(let decodedBoards) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(decodedBoards["Emma"]?.first?.text, "Cow")
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
        let msg = MultipeerMessage.playAgain(boards: boards)
        let decoded = try roundtrip(msg)
        guard case .playAgain(let decodedBoards) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(decodedBoards["Zoe"]?.first?.text, "Barn")
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
}
