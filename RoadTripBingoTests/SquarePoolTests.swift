import XCTest
@testable import RoadTripBingo

final class SquarePoolTests: XCTestCase {

    func test_load_returnsAtLeast150Squares() {
        XCTAssertGreaterThanOrEqual(SquarePool.load().count, 150)
    }

    func test_load_allIDsUnique() {
        let pool = SquarePool.load()
        XCTAssertEqual(pool.map(\.id).count, Set(pool.map(\.id)).count)
    }

    func test_load_noFreeSquareInPool() {
        XCTAssertFalse(SquarePool.load().contains { $0.id == BingoSquare.freeSquareID })
    }

    func test_load_semiTruckIsVeryCommon() {
        let semiTruck = SquarePool.load().first { $0.text == "Semi Truck" }
        XCTAssertEqual(semiTruck?.rarity, .veryCommon)
    }

    func test_load_ghostTownIsVeryRare() {
        let ghostTown = SquarePool.load().first { $0.text == "Ghost Town" }
        XCTAssertEqual(ghostTown?.rarity, .veryRare)
    }

    func test_dealBoards_eachBoardHas25Squares() {
        let players = [("A", BoardDifficulty.backseat), ("B", .backseat), ("C", .backseat)]
            .map { (name: $0.0, difficulty: $0.1) }
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        XCTAssertEqual(boards["A"]?.count, 25)
        XCTAssertEqual(boards["B"]?.count, 25)
        XCTAssertEqual(boards["C"]?.count, 25)
    }

    func test_dealBoards_index12IsFree() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        XCTAssertEqual(boards["A"]?[12].id, BingoSquare.freeSquareID)
    }

    func test_dealBoards_noOverlapBetweenPlayers() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let aIDs = Set(boards["A"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        let bIDs = Set(boards["B"]!.map(\.id)).subtracting([BingoSquare.freeSquareID])
        XCTAssertTrue(aIDs.isDisjoint(with: bIDs))
    }

    func test_dealBoards_backseatBoardHasAtLeast15CommonOrBetterSquares() {
        let players = [(name: "A", difficulty: BoardDifficulty.backseat)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let nonFree = boards["A"]!.filter { $0.id != BingoSquare.freeSquareID }
        let easyCount = nonFree.filter { $0.rarity == .veryCommon || $0.rarity == .common }.count
        XCTAssertGreaterThanOrEqual(easyCount, 15,
            "Backseat board should have at least 15 veryCommon+common squares")
    }

    func test_dealBoards_navigatorBoardHasAtLeast8RareOrVeryRareSquares() {
        let players = [(name: "A", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: SquarePool.load())
        let nonFree = boards["A"]!.filter { $0.id != BingoSquare.freeSquareID }
        let hardCount = nonFree.filter { $0.rarity == .rare || $0.rarity == .veryRare }.count
        XCTAssertGreaterThanOrEqual(hardCount, 8,
            "Navigator board should have at least 8 rare+veryRare squares")
    }

    func test_dealReserve_returnsCorrectCountPerPlayer() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        XCTAssertEqual(reserve["A"]?.count, 6)
        XCTAssertEqual(reserve["B"]?.count, 6)
    }

    func test_dealReserve_noOverlapWithDealtBoards() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.shotgun)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        let reserveIDs = Set(reserve["A"]!.map(\.id))
        XCTAssertTrue(reserveIDs.isDisjoint(with: usedIDs))
    }

    func test_dealReserve_noOverlapBetweenPlayers() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.backseat),
                       (name: "B", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players, from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        let aIDs = Set(reserve["A"]!.map(\.id))
        let bIDs = Set(reserve["B"]!.map(\.id))
        XCTAssertTrue(aIDs.isDisjoint(with: bIDs))
    }

    // MARK: - adjustedWeights

    func test_adjustedWeights_level0_returnsBaseDifficultyWeights() {
        let w = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 0)
        for rarity in SquareRarity.allCases {
            XCTAssertEqual(w[rarity, default: 0],
                           BoardDifficulty.navigator.weights[rarity, default: 0],
                           accuracy: 0.001)
        }
    }

    func test_adjustedWeights_level1_navigatorShiftsRareAndVeryRareDown() {
        let w = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 1)
        // rare: 0.35 − 0.04 = 0.31; veryRare: 0.15 − 0.04 = 0.11
        XCTAssertEqual(w[.rare, default: 0], 0.31, accuracy: 0.001)
        XCTAssertEqual(w[.veryRare, default: 0], 0.11, accuracy: 0.001)
        XCTAssertEqual(w[.veryCommon, default: 0], 0.09, accuracy: 0.001)
        XCTAssertEqual(w[.common, default: 0], 0.19, accuracy: 0.001)
        XCTAssertEqual(w[.uncommon, default: 0], 0.30, accuracy: 0.001)
    }

    func test_adjustedWeights_level2_navigatorContinuesShift() {
        let w = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 2)
        XCTAssertEqual(w[.rare, default: 0], 0.27, accuracy: 0.001)
        XCTAssertEqual(w[.veryRare, default: 0], 0.07, accuracy: 0.001)
        XCTAssertEqual(w[.veryCommon, default: 0], 0.13, accuracy: 0.001)
        XCTAssertEqual(w[.common, default: 0], 0.23, accuracy: 0.001)
    }

    func test_adjustedWeights_sumAlwaysEqualsOne() {
        for difficulty in BoardDifficulty.allCases {
            for level in 0...4 {
                let w = SquarePool.adjustedWeights(for: difficulty, handicapLevel: level)
                let sum = w.values.reduce(0, +)
                XCTAssertEqual(sum, 1.0, accuracy: 0.001,
                    "Weights for \(difficulty) at level \(level) must sum to 1.0")
            }
        }
    }

    func test_adjustedWeights_backseat_cascadesIntoUncommonWhenRareExhausted() {
        // Backseat starts with rare=0.05, veryRare=0.00.
        // After level 2: rare and veryRare should both be 0.
        let w = SquarePool.adjustedWeights(for: .backseat, handicapLevel: 2)
        XCTAssertEqual(w[.rare, default: 0], 0.0, accuracy: 0.001)
        XCTAssertEqual(w[.veryRare, default: 0], 0.0, accuracy: 0.001)
        // Uncommon should have shrunk to absorb the cascade deficit
        XCTAssertLessThan(w[.uncommon, default: 0],
                          BoardDifficulty.backseat.weights[.uncommon, default: 0])
    }

    func test_adjustedWeights_cappedAt3() {
        let w3 = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 3)
        let w5 = SquarePool.adjustedWeights(for: .navigator, handicapLevel: 5)
        for rarity in SquareRarity.allCases {
            XCTAssertEqual(w3[rarity, default: 0], w5[rarity, default: 0], accuracy: 0.001,
                "Level >3 should produce same weights as level 3")
        }
    }

    func test_dealBoards_withHandicapLevel_stillProducesValidBoard() {
        let pool = SquarePool.load()
        let players = [(name: "A", difficulty: BoardDifficulty.navigator)]
        let boards = SquarePool.dealBoards(for: players,
                                           handicapLevels: ["A": 3],
                                           from: pool)
        XCTAssertEqual(boards["A"]?.count, 25, "Handicapped board must still have 25 squares")
        XCTAssertEqual(boards["A"]?[12].id, BingoSquare.freeSquareID, "FREE must be at index 12")
        // Verify handicap actually shifts the distribution: level-3 navigator should have
        // fewer rare+veryRare tiles than an un-handicapped navigator (which gets at least 8).
        let nonFree = boards["A"]!.filter { $0.id != BingoSquare.freeSquareID }
        let hardCount = nonFree.filter { $0.rarity == .rare || $0.rarity == .veryRare }.count
        XCTAssertLessThanOrEqual(hardCount, 7,
            "Level-3 handicap on Navigator should reduce rare+veryRare below the un-handicapped baseline of ~12")
    }

    // MARK: - buildPool

    // Helper: make a minimal BingoSquare for tests
    private func square(_ id: String, rarity: SquareRarity, text: String = "Test") -> BingoSquare {
        BingoSquare(id: UUID(uuidString: id)!, text: text, emoji: nil,
                    category: .vehicles, rarity: rarity)
    }

    // Helper: make a TilePack with explicit overrides, exclusions, and exclusive tiles
    private func pack(id: String = "test", overrides: [String: SquareRarity] = [:],
                      excluded: [String] = [], tiles: [BingoSquare] = []) -> TilePack {
        TilePack(id: id, name: id, description: "", imageName: "",
                 tiles: tiles, rarityOverrides: overrides, excludedTileIDs: excluded)
    }

    func test_buildPool_emptyPacksReturnsBaseUnchanged() {
        let base = [square("00000000-0000-0000-0000-000000000001", rarity: .common)]
        let result = SquarePool.buildPool(base: base, activePacks: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].rarity, .common)
    }

    func test_buildPool_appliesRarityOverride() {
        let tractorID = "4A495FE0-B728-477D-8863-FD00E9140BB6"
        let base = [square(tractorID, rarity: .uncommon, text: "Tractor")]
        let farmPack = pack(overrides: [tractorID: .veryCommon])
        let result = SquarePool.buildPool(base: base, activePacks: [farmPack])
        XCTAssertEqual(result.first?.rarity, .veryCommon)
    }

    func test_buildPool_mostCommonWinsWhenTwoPacksOverrideSameTile() {
        let id = "4A495FE0-B728-471D-8863-FD00E9140BB6"
        let base = [square(id, rarity: .uncommon)]
        let pack1 = pack(id: "a", overrides: [id: .common])
        let pack2 = pack(id: "b", overrides: [id: .veryCommon])
        let result = SquarePool.buildPool(base: base, activePacks: [pack1, pack2])
        XCTAssertEqual(result.first?.rarity, .veryCommon,
                       "veryCommon should beat common under most-common-wins")
    }

    func test_buildPool_excludesTileFromAnyActivePack() {
        let excludedID = "3DE3F367-3105-4F8B-A89D-2F134E21D01D"
        let base = [
            square(excludedID, rarity: .veryCommon, text: "Subway"),
            square("11111111-1111-1111-1111-111111111111", rarity: .common, text: "Other")
        ]
        let p = pack(excluded: [excludedID])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertFalse(result.contains { $0.id.uuidString == excludedID })
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Other")
    }

    func test_buildPool_appendsExclusiveTiles() {
        let base = [square("11111111-1111-1111-1111-111111111111", rarity: .common)]
        let exclusive = BingoSquare(id: UUID(), text: "Combine Harvester", emoji: nil,
                                    category: .vehicles, rarity: .veryCommon)
        let p = pack(tiles: [exclusive])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.text == "Combine Harvester" })
    }

    func test_buildPool_exclusionAndOverrideAreCombined() {
        let excludedID = "3DE3F367-3105-4F8B-A89D-2F134E21D01D"
        let overriddenID = "4A495FE0-B728-471D-8863-FD00E9140BB6"
        let base = [
            square(excludedID, rarity: .veryCommon, text: "Subway"),
            square(overriddenID, rarity: .uncommon, text: "Tractor")
        ]
        let p = pack(overrides: [overriddenID: .veryCommon], excluded: [excludedID])
        let result = SquarePool.buildPool(base: base, activePacks: [p])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Tractor")
        XCTAssertEqual(result[0].rarity, .veryCommon)
    }

    func test_buildPool_withRealBasePool_doesNotShrinkBelowUsableSize() {
        let base = SquarePool.load()
        // With no packs: pool should be unchanged
        let result = SquarePool.buildPool(base: base, activePacks: [])
        XCTAssertEqual(result.count, base.count)
    }
}
