// RoadTripBingoTests/SpottingRaceTests.swift
import XCTest
@testable import RoadTripBingo

final class SpottingRaceTests: XCTestCase {

    // MARK: - SquareRarity extensions

    func test_spottingRaceScore_allNonZero() {
        for rarity in SquareRarity.allCases {
            XCTAssertGreaterThan(rarity.spottingRaceScore, 0,
                "\(rarity) must score > 0 in Spotting Race")
        }
    }

    func test_spottingRaceScore_veryCommon_is1() {
        XCTAssertEqual(SquareRarity.veryCommon.spottingRaceScore, 1)
    }

    func test_spottingRaceScore_veryRare_is8() {
        XCTAssertEqual(SquareRarity.veryRare.spottingRaceScore, 8)
    }

    func test_spottingRaceScore_doesNotChangeScoreBonus() {
        // scoreBonus (Classic Bingo) must remain unchanged
        XCTAssertEqual(SquareRarity.veryCommon.scoreBonus, 0)
        XCTAssertEqual(SquareRarity.veryRare.scoreBonus, 7)
    }

    func test_spottingRaceWeight_sumsToHundred() {
        let total = SquareRarity.allCases.reduce(0) { $0 + $1.spottingRaceWeight }
        XCTAssertEqual(total, 100)
    }

    func test_spottingRaceWeight_allPositive() {
        for rarity in SquareRarity.allCases {
            XCTAssertGreaterThan(rarity.spottingRaceWeight, 0)
        }
    }

    // MARK: - SpottingRaceTile

    func test_spottingRaceTile_isExpiring_trueUnder3Seconds() {
        let expiry = Date().addingTimeInterval(2)
        let tile = SpottingRaceTile(
            id: UUID(),
            square: .free,
            expiresAt: expiry
        )
        XCTAssertTrue(tile.isExpiring)
    }

    func test_spottingRaceTile_isExpiring_falseOver3Seconds() {
        let expiry = Date().addingTimeInterval(60)
        let tile = SpottingRaceTile(
            id: UUID(),
            square: .free,
            expiresAt: expiry
        )
        XCTAssertFalse(tile.isExpiring)
    }

    func test_spottingRaceTile_defaultsUnlocked() {
        let tile = SpottingRaceTile(id: UUID(), square: .free, expiresAt: Date())
        XCTAssertNil(tile.lockedBy)
        XCTAssertNil(tile.claimedBy)
        XCTAssertNil(tile.lockTimestamp)
    }

    // MARK: - GameType persistence

    func test_gameType_codable_roundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for gameType in [GameType.bingo, GameType.spottingRace] {
            let data = try encoder.encode(gameType)
            let decoded = try decoder.decode(GameType.self, from: data)
            XCTAssertEqual(decoded, gameType)
        }
    }

    // MARK: - MultipeerMessage — Spotting Race cases

    private func roundtrip(_ message: MultipeerMessage) throws -> MultipeerMessage {
        let data = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(MultipeerMessage.self, from: data)
    }

    func test_lockTile_roundtrip() throws {
        let slotID = UUID()
        let squareID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_000_000)
        let msg = MultipeerMessage.lockTile(slotID: slotID, squareID: squareID, byName: "Alice", timestamp: timestamp)
        let decoded = try roundtrip(msg)
        guard case .lockTile(let s, let sq, let name, let ts) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(sq, squareID)
        XCTAssertEqual(name, "Alice")
        XCTAssertEqual(ts.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_releaseTile_roundtrip() throws {
        let slotID = UUID()
        let msg = MultipeerMessage.releaseTile(slotID: slotID, byName: "Bob")
        let decoded = try roundtrip(msg)
        guard case .releaseTile(let s, let name) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(name, "Bob")
    }

    func test_claimTile_roundtrip() throws {
        let slotID = UUID()
        let squareID = UUID()
        let timestamp = Date(timeIntervalSince1970: 500_000)
        let msg = MultipeerMessage.claimTile(slotID: slotID, squareID: squareID, byName: "Carol", timestamp: timestamp)
        let decoded = try roundtrip(msg)
        guard case .claimTile(let s, let sq, let name, let ts) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(sq, squareID)
        XCTAssertEqual(name, "Carol")
        XCTAssertEqual(ts.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_tileReplaced_roundtrip() throws {
        let slotID = UUID()
        let square = BingoSquare(id: UUID(), text: "Hawk", emoji: "🦅", category: .nature, rarity: .rare)
        let expiry = Date(timeIntervalSince1970: 999_999)
        let msg = MultipeerMessage.tileReplaced(slotID: slotID, replacement: square, expiresAt: expiry)
        let decoded = try roundtrip(msg)
        guard case .tileReplaced(let s, let sq, let exp) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, slotID)
        XCTAssertEqual(sq.text, "Hawk")
        XCTAssertEqual(exp.timeIntervalSince1970, expiry.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_spottingRoundEnded_roundtrip() throws {
        let scores = ["Alice": 12, "Bob": 7]
        let msg = MultipeerMessage.spottingRoundEnded(scores: scores)
        let decoded = try roundtrip(msg)
        guard case .spottingRoundEnded(let s) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(s, scores)
    }

    func test_gameStarted_spottingRace_roundtrip() throws {
        let msg = MultipeerMessage.gameStarted(boards: [:], activePackIDs: ["pack1"], gameType: .spottingRace)
        let decoded = try roundtrip(msg)
        guard case .gameStarted(let boards, let packs, let gameType) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertTrue(boards.isEmpty)
        XCTAssertEqual(packs, ["pack1"])
        XCTAssertEqual(gameType, .spottingRace)
    }

    func test_gameStarted_legacyDecodeDefaultsToBingo() throws {
        // Simulate an old message without gameType field
        let json = """
        {"type":"gameStarted","boards":{},"activePackIDs":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MultipeerMessage.self, from: json)
        guard case .gameStarted(_, _, let gameType) = decoded else {
            return XCTFail("Wrong case decoded")
        }
        XCTAssertEqual(gameType, .bingo, "Legacy messages should default to .bingo")
    }
}
