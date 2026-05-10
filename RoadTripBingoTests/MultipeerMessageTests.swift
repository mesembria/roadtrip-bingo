import XCTest
@testable import RoadTripBingo

final class MultipeerMessageTests: XCTestCase {

    private func roundtrip(_ message: MultipeerMessage) throws -> MultipeerMessage {
        let data = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(MultipeerMessage.self, from: data)
    }

    func test_gameStarted_roundtrip() throws {
        let square = BingoSquare(id: UUID(), text: "Cow", emoji: "🐄", category: .nature)
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
        let square = BingoSquare(id: UUID(), text: "Barn", emoji: "🏚️", category: .nature)
        let boards: [String: [BingoSquare]] = ["Zoe": [square]]
        let msg = MultipeerMessage.playAgain(boards: boards)
        let decoded = try roundtrip(msg)
        guard case .playAgain(let decodedBoards) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(decodedBoards["Zoe"]?.first?.text, "Barn")
    }
}
