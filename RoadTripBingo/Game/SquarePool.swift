import Foundation

enum SquarePool {
    static func load() -> [BingoSquare] {
        guard let url = Bundle.main.url(forResource: "squares", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let squares = try? JSONDecoder().decode([BingoSquare].self, from: data)
        else { fatalError("squares.json missing from bundle or malformed") }
        return squares
    }

    // Each player's 24 non-FREE squares are sampled from per-rarity buckets weighted by difficulty.
    // Non-overlap between players is best-effort; overlaps may occur when a rarity bucket runs thin.
    static func dealBoards(
        for players: [(name: String, difficulty: BoardDifficulty)],
        handicapLevels: [String: Int] = [:],
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        precondition(pool.count >= players.count * 24)
        var queues = makeQueues(from: pool)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            let level = handicapLevels[player.name, default: 0]
            result[player.name] = drawBoard(for: player.difficulty,
                                            handicapLevel: level,
                                            from: &queues)
        }
        return result
    }

    // Returns `count` extra squares per player, drawn from pool minus usedIDs.
    // Used to deal each player's power-up reserve hand at game start.
    static func dealReserve(
        for players: [(name: String, difficulty: BoardDifficulty)],
        count: Int,
        excluding usedIDs: Set<UUID>,
        from pool: [BingoSquare]
    ) -> [String: [BingoSquare]] {
        let available = pool.filter { !usedIDs.contains($0.id) }
        assert(available.count >= players.count * count,
               "Reserve pool too thin: need \(players.count * count) squares, got \(available.count)")
        var queues = makeQueues(from: available)
        var result: [String: [BingoSquare]] = [:]
        for player in players {
            result[player.name] = drawBoard(for: player.difficulty, from: &queues, total: count)
        }
        return result
    }

    // Returns the rarity weight distribution for a player at the given handicap level.
    // Each level shifts 4% weight from rare/veryRare toward veryCommon/common.
    // When a source bucket is depleted the deficit cascades to the next-hardest bucket.
    // Level is clamped to 3; weights always sum to 1.0.
    static func adjustedWeights(for difficulty: BoardDifficulty,
                                handicapLevel: Int) -> [SquareRarity: Double] {
        let level = min(handicapLevel, 3)
        guard level > 0 else { return difficulty.weights }

        var w = difficulty.weights
        let delta = 0.04

        for _ in 0..<level {
            // Reduce rare; cascade deficit to uncommon then common if depleted.
            let rareTaken = min(delta, w[.rare, default: 0])
            w[.rare, default: 0] -= rareTaken
            let rareDeficit = delta - rareTaken
            if rareDeficit > 0 {
                let uncommonTaken = min(rareDeficit, w[.uncommon, default: 0])
                w[.uncommon, default: 0] -= uncommonTaken
                let rareRemainder = rareDeficit - uncommonTaken
                if rareRemainder > 0 {
                    w[.common, default: 0] -= min(rareRemainder, w[.common, default: 0])
                }
            }

            // Reduce veryRare; cascade deficit to uncommon then common if depleted.
            let veryRareTaken = min(delta, w[.veryRare, default: 0])
            w[.veryRare, default: 0] -= veryRareTaken
            let veryRareDeficit = delta - veryRareTaken
            if veryRareDeficit > 0 {
                let uncommonTaken = min(veryRareDeficit, w[.uncommon, default: 0])
                w[.uncommon, default: 0] -= uncommonTaken
                let veryRareRemainder = veryRareDeficit - uncommonTaken
                if veryRareRemainder > 0 {
                    w[.common, default: 0] -= min(veryRareRemainder, w[.common, default: 0])
                }
            }

            w[.veryCommon, default: 0] += delta
            w[.common, default: 0] += delta
        }

        // Renormalise: corrects sum drift when the uncommon cascade bucket is
        // exhausted before absorbing the full deficit (leaving sum > 1.0),
        // and guards against floating-point accumulation over iterations.
        let total = w.values.reduce(0, +)
        if total > 0 {
            for rarity in SquareRarity.allCases {
                w[rarity, default: 0] /= total
            }
        }
        return w
    }

    /// Combines the base pool with a set of active packs.
    ///
    /// Each pack carries an explicit, curated tile list as `{id, rarity}` refs.
    /// A tile must be referenced by at least one active pack to appear in the result;
    /// tiles in `base` but not referenced by any pack are excluded.
    ///
    /// When two active packs reference the same tile with different rarities,
    /// the most-common rarity wins (most-common-wins rule).
    ///
    /// When `activePacks` is empty, returns `base` unmodified (base game with no pack active).
    static func buildPool(base: [BingoSquare], activePacks: [TilePack]) -> [BingoSquare] {
        guard !activePacks.isEmpty else { return base }

        // Build a fast lookup: UUID → BingoSquare
        let baseByID = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })

        // Resolve all tile refs: UUID → most-common rarity across all active packs
        var resolved: [UUID: SquareRarity] = [:]
        for pack in activePacks {
            for ref in pack.tiles {
                guard let id = UUID(uuidString: ref.id) else { continue }
                resolved[id] = resolved[id].map { mostCommon($0, ref.rarity) } ?? ref.rarity
            }
        }

        // Map each resolved ref to a BingoSquare, applying pack rarity when different
        return resolved.compactMap { id, rarity in
            guard let tile = baseByID[id] else { return nil }
            if tile.rarity == rarity { return tile }
            return BingoSquare(id: tile.id, text: tile.text, emoji: tile.emoji,
                               category: tile.category, rarity: rarity)
        }
    }

    /// Returns the rarity that is further toward veryCommon.
    /// `allCases` order is [veryCommon, common, uncommon, rare, veryRare] so lower index = more common.
    private static func mostCommon(_ a: SquareRarity, _ b: SquareRarity) -> SquareRarity {
        let order = SquareRarity.allCases
        let ia = order.firstIndex(of: a) ?? order.count
        let ib = order.firstIndex(of: b) ?? order.count
        return ia <= ib ? a : b
    }

    // MARK: - Private helpers

    private static func makeQueues(from pool: [BingoSquare]) -> [SquareRarity: [BingoSquare]] {
        var queues: [SquareRarity: [BingoSquare]] = [:]
        for rarity in SquareRarity.allCases {
            queues[rarity] = pool.filter { $0.rarity == rarity }.shuffled()
        }
        return queues
    }

    private static func drawBoard(
        for difficulty: BoardDifficulty,
        handicapLevel: Int = 0,
        from queues: inout [SquareRarity: [BingoSquare]],
        total: Int = 24
    ) -> [BingoSquare] {
        let w = adjustedWeights(for: difficulty, handicapLevel: handicapLevel)
        let targets = targetCounts(weights: w, total: total)
        var squares: [BingoSquare] = []
        for rarity in SquareRarity.allCases {
            squares += draw(targets[rarity, default: 0], from: &queues[rarity]!)
        }
        if squares.count < total {
            var spill = SquareRarity.allCases.flatMap { queues[$0]! }.shuffled()
            let extra = draw(total - squares.count, from: &spill)
            let extraIDs = Set(extra.map(\.id))
            for rarity in SquareRarity.allCases {
                queues[rarity]!.removeAll { extraIDs.contains($0.id) }
            }
            squares += extra
        }
        if total == 24 {
            squares.shuffle()
            squares.insert(.free, at: 12)
        } else {
            squares.shuffle()
        }
        return squares
    }

    private static func draw(_ count: Int, from bucket: inout [BingoSquare]) -> [BingoSquare] {
        let actual = min(count, bucket.count)
        let drawn = Array(bucket.prefix(actual))
        bucket.removeFirst(actual)
        return drawn
    }

    private static func targetCounts(weights: [SquareRarity: Double], total: Int = 24) -> [SquareRarity: Int] {
        let tiers = SquareRarity.allCases
        var counts: [SquareRarity: Int] = [:]
        var running = 0
        for (i, rarity) in tiers.enumerated() {
            if i == tiers.count - 1 {
                counts[rarity] = max(0, total - running)
                break
            }
            let n = Int((Double(total) * weights[rarity, default: 0]).rounded())
            counts[rarity] = n
            running += n
        }
        return counts
    }
}
