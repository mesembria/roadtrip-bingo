import Foundation
import SwiftUI

enum AppScreen: Equatable {
    case home
    case lobby
    case game
    case win(winnerName: String)
    case playAgain
}

// All mutation of AppState must occur on the main actor.
// MultipeerSession dispatches all delegate callbacks via DispatchQueue.main.async.
final class AppState: ObservableObject, MultipeerSessionDelegate {

    // MARK: - Navigation
    @Published var screen: AppScreen = .home

    // MARK: - Identity
    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: "playerName") }
    }

    // MARK: - Game Mode
    @Published var gameMode: GameMode = .multiplayer

    // MARK: - Game Type
    @Published var gameType: GameType = {
        guard let raw = UserDefaults.standard.string(forKey: "gameType"),
              let gt = GameType(rawValue: raw) else { return .bingo }
        return gt
    }() {
        didSet { UserDefaults.standard.set(gameType.rawValue, forKey: "gameType") }
    }

    // MARK: - Lobby
    @Published var isHost = false
    @Published var connectedPlayerNames: [String] = []
    @Published var foundGameNames: [String] = []
    @Published var connectingToGame: String? = nil   // set while MC handshake is in flight
    @Published var playerDifficulty: BoardDifficulty = .backseat
    @Published var playerDifficulties: [String: BoardDifficulty] = [:]

    // MARK: - Tile packs (host only — persisted and broadcast at game start)
    @Published var activePackIDs: [String] = {
        UserDefaults.standard.stringArray(forKey: "activePackIDs") ?? []
    }() {
        didSet {
            UserDefaults.standard.set(activePackIDs, forKey: "activePackIDs")
        }
    }

    // MARK: - Game
    @Published var localBoard: BingoBoard?
    @Published var completedLine: [Int]?
    @Published var opponentMarked: [String: Set<UUID>] = [:]
    @Published var opponentBoards: [String: [BingoSquare]] = [:]
    var reserveSquares: [BingoSquare] = []
    @Published var recentOpponentMarks: [RecentMark] = []
    private let maxRecentMarks = 3
    private var pruningTask: Task<Void, Never>?

    // MARK: - Tokens
    @Published var tokenBalance: Int = 0
    @Published var tokenBalances: [String: Int] = [:]
    @Published var pendingToast: ToastEvent? = nil

    // MARK: - Achievement guards (reset each round)
    private var firstMarkClaimedThisRound = false
    private var patternsAwardedThisRound: Set<String> = []
    private var closeCallsAwardedThisRound: Set<String> = []

    // MARK: - Round modifier
    @Published var activeModifier: RoundModifier? = nil
    @Published var fogOfWarHiddenPositions: Set<Int> = []
    private var fogShiftCount = 0

    // Round-scoped tracking for challenge evaluation (added to by Task 11)
    private var marksThisRound = 0
    private var attacksUsedThisRound = 0
    private var tokensSpentThisRound = 0
    private var opponentMarkCountsThisRound: [String: Int] = [:]

    // MARK: - Handicap (host only)
    private var lastRoundWinner: String? = nil
    private var consecutiveLosses: [String: Int] = [:]

    // MARK: - Post-game
    @Published var winHistory: [String: Int] = {
        guard let data = UserDefaults.standard.data(forKey: "winHistory"),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(winHistory) {
                UserDefaults.standard.set(data, forKey: "winHistory")
            }
        }
    }

    @Published var dailyState: DailyState = DailyState.load()

    // MARK: - Solo tracking
    private(set) var tokensEarnedThisRound: Int = 0
    var soloStartTime: Date? = nil

    // MARK: - Spotting Race
    @Published var spottingRaceTiles: [SpottingRaceTile] = []
    @Published var mySpottingScore: Int = 0
    @Published var opponentSpottingScores: [String: Int] = [:]
    @Published var spottingRoundEndTime: Date? = nil
    /// Host-only draw queue. Peers never see this.
    var tilePool: [BingoSquare] = []
    var mySpottingClaimedCount: Int = 0
    private var spottingTimerTask: Task<Void, Never>? = nil
    /// Pending finalize tasks keyed by slot UUID (cancelled on undo).
    private var softClaimTasks: [UUID: Task<Void, Never>] = [:]

    var soloSpottingRaceBest: Int {
        get { UserDefaults.standard.integer(forKey: "soloSpottingRaceBest") }
        set { UserDefaults.standard.set(newValue, forKey: "soloSpottingRaceBest") }
    }

    var soloPersonalBest: Int {
        get { UserDefaults.standard.integer(forKey: "soloPersonalBest") }
        set { UserDefaults.standard.set(newValue, forKey: "soloPersonalBest") }
    }

    @Published var lastSoloScore: Int = 0
    @Published var lastSoloIsNewBest: Bool = false
    @Published var lastSoloTokens: Int = 0
    @Published var lastSoloRarityBonus: Int = 0
    @Published var lastSoloExtraLines: Int = 0
    @Published var lastSoloTimeMultiplier: Double = 1.0

    var activeChallenges: [DailyChallenge] {
        let excluded: Set<DailyChallengeType> = gameMode == .solo ? [.pacifist, .menace] : []
        return dailyState.challengeTypes
            .filter { !excluded.contains($0) }
            .map { DailyChallenge(type: $0) }
    }

    // MARK: - Network
    private(set) var multipeerSession: MultipeerSession?

    init() {
        self.playerName = UserDefaults.standard.string(forKey: "playerName") ?? ""
        rollDailyChallengesIfNeeded()
    }

    func rollDailyChallengesIfNeeded() {
        if dailyState.date != DailyState.today() {
            dailyState = DailyState(
                date: DailyState.today(),
                challengeTypes: DailyState.roll(),
                completedIDs: [],
                winsToday: 0,
                roundsPlayedToday: 0
            )
        } else if dailyState.challengeTypes.isEmpty {
            dailyState.challengeTypes = DailyState.roll()
        }
        dailyState.save()
    }

    // MARK: - Home actions

    func createGame() {
        isHost = true
        connectedPlayerNames = []
        let session = MultipeerSession(displayName: playerName)
        session.delegate = self
        session.startAdvertising()
        multipeerSession = session
        screen = .lobby
    }

    func joinGame() {
        isHost = false
        foundGameNames = []
        let session = MultipeerSession(displayName: playerName)
        session.delegate = self
        session.startBrowsing()
        multipeerSession = session
        screen = .lobby
    }

    func startSoloGame() {
        // Reset multiplayer state
        multipeerSession?.disconnect()
        multipeerSession = nil
        connectedPlayerNames = []
        foundGameNames = []
        connectingToGame = nil
        opponentBoards = [:]
        opponentMarked = [:]
        recentOpponentMarks = []
        pruningTask?.cancel()
        pruningTask = nil
        lastRoundWinner = nil
        consecutiveLosses = [:]
        tokenBalance = 0
        tokenBalances = [:]
        pendingToast = nil
        completedLine = nil
        localBoard = nil
        reserveSquares = []
        isHost = false
        playerDifficulties = [:]
        resetRound()

        // Set solo mode and record start time
        gameMode = .solo
        soloStartTime = Date()

        // Deal board
        let baseTiles = SquarePool.load()
        let namedPacks = PackManager.packs(forIDs: activePackIDs)
        let activePacks = [SquarePool.loadBasePack()] + namedPacks
        let pool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks)
        let players: [(name: String, difficulty: BoardDifficulty)] = [
            (name: playerName, difficulty: playerDifficulty)
        ]
        let boards = SquarePool.dealBoards(for: players, handicapLevels: [:], from: pool)

        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }

        // Deal reserve (needed for upgradeTile power-ups)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)
        reserveSquares = reserve[playerName] ?? []

        // Solo-compatible modifier (excludes fogOfWar, shiftingTiles, shuffleBoard, sniper)
        let modifier = soloRandomModifier()
        activeModifier = modifier
        initializeModifier(modifier)

        earnTokens(2, reason: "Round start")
        screen = .game
    }

    func startSpottingRaceSolo() {
        // Tear down any existing session (mirrors startSoloGame)
        multipeerSession?.disconnect()
        multipeerSession = nil
        connectedPlayerNames = []
        foundGameNames = []
        connectingToGame = nil
        opponentBoards = [:]
        opponentMarked = [:]
        recentOpponentMarks = []
        pruningTask?.cancel()
        pruningTask = nil
        lastRoundWinner = nil
        consecutiveLosses = [:]
        tokenBalance = 0
        tokenBalances = [:]
        pendingToast = nil
        completedLine = nil
        localBoard = nil
        reserveSquares = []
        playerDifficulties = [:]
        soloStartTime = nil
        resetRound()
        resetSpottingRound()

        gameMode = .solo
        isHost = true  // solo acts as its own host for tile management

        // Build and shuffle the tile pool
        let baseTiles = SquarePool.load()
        let namedPacks = PackManager.packs(forIDs: activePackIDs)
        let activePacks = [SquarePool.loadBasePack()] + namedPacks
        tilePool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks).shuffled()

        // Populate 6 initial slots
        spottingRaceTiles = (0..<6).compactMap { _ -> SpottingRaceTile? in
            guard let sq = drawWeightedTile(), sq.id != BingoSquare.freeSquareID else { return nil }
            return SpottingRaceTile(id: UUID(), square: sq, expiresAt: Date().addingTimeInterval(60))
        }

        spottingRoundEndTime = Date().addingTimeInterval(300)  // 5 minutes
        startSpottingTimerLoop()
        screen = .game
    }

    private func soloRandomModifier() -> RoundModifier {
        var candidates: [RoundModifier] = [.hotStreak, .doubleDown, .noPowers]
        candidates += PatternShape.allCases.map { .patternWin($0) }
        return candidates.randomElement()!
    }

    func startSpottingRaceGame() {
        guard isHost else { return }

        let baseTiles = SquarePool.load()
        let namedPacks = PackManager.packs(forIDs: activePackIDs)
        let activePacks = [SquarePool.loadBasePack()] + namedPacks

        resetSpottingRound()
        tilePool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks).shuffled()
        opponentSpottingScores = Dictionary(
            uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
        )

        spottingRaceTiles = (0..<6).compactMap { _ -> SpottingRaceTile? in
            guard let sq = drawWeightedTile(), sq.id != BingoSquare.freeSquareID else { return nil }
            return SpottingRaceTile(id: UUID(), square: sq, expiresAt: Date().addingTimeInterval(60))
        }

        spottingRoundEndTime = Date().addingTimeInterval(300)

        multipeerSession?.stopAdvertising()
        multipeerSession?.send(.gameStarted(boards: [:], activePackIDs: activePackIDs, gameType: .spottingRace))

        // Broadcast the 6 initial tiles to peers
        for tile in spottingRaceTiles {
            multipeerSession?.send(.tileReplaced(
                slotID: tile.id,
                replacement: tile.square,
                expiresAt: tile.expiresAt
            ))
        }

        startSpottingTimerLoop()
        screen = .game
    }

    func requestPlayAgainSpottingRace() {
        guard isHost, gameType == .spottingRace else { return }

        let baseTiles = SquarePool.load()
        let namedPacks = PackManager.packs(forIDs: activePackIDs)
        let activePacks = [SquarePool.loadBasePack()] + namedPacks

        resetSpottingRound()
        tilePool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks).shuffled()
        opponentSpottingScores = Dictionary(
            uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
        )

        spottingRaceTiles = (0..<6).compactMap { _ -> SpottingRaceTile? in
            guard let sq = drawWeightedTile(), sq.id != BingoSquare.freeSquareID else { return nil }
            return SpottingRaceTile(id: UUID(), square: sq, expiresAt: Date().addingTimeInterval(60))
        }

        spottingRoundEndTime = Date().addingTimeInterval(300)

        multipeerSession?.send(.playAgain(boards: [:], activePackIDs: activePackIDs, gameType: .spottingRace))
        for tile in spottingRaceTiles {
            multipeerSession?.send(.tileReplaced(
                slotID: tile.id,
                replacement: tile.square,
                expiresAt: tile.expiresAt
            ))
        }

        startSpottingTimerLoop()
        screen = .game
    }

    func inviteGame(named name: String) {
        connectingToGame = name
        multipeerSession?.invitePeer(named: name)
    }

    func chooseDifficulty(_ difficulty: BoardDifficulty) {
        playerDifficulty = difficulty
        if !isHost {
            multipeerSession?.send(.difficultyChosen(byName: playerName, difficulty: difficulty))
        }
    }

    func togglePack(_ packID: String) {
        // Allow toggle from the home screen (before a game) or by the host during a session.
        guard isHost || screen == .home else { return }
        if activePackIDs.contains(packID) {
            activePackIDs.removeAll { $0 == packID }
        } else {
            activePackIDs.append(packID)
        }
    }

    func goHome() {
        multipeerSession?.disconnect()
        multipeerSession = nil
        connectedPlayerNames = []
        foundGameNames = []
        connectingToGame = nil
        localBoard = nil
        completedLine = nil
        opponentMarked = [:]
        recentOpponentMarks = []
        pruningTask?.cancel()
        pruningTask = nil
        opponentBoards = [:]
        reserveSquares = []
        isHost = false
        lastRoundWinner = nil
        consecutiveLosses = [:]
        playerDifficulty = .backseat
        playerDifficulties = [:]
        tokenBalance = 0
        tokenBalances = [:]
        pendingToast = nil
        resetRound()
        soloStartTime = nil
        resetSpottingRound()
        gameMode = .multiplayer
        // winHistory intentionally preserved
        screen = .home
    }

    // MARK: - Lobby (host only)

    func startGame() {
        guard isHost else { return }
        if gameType == .spottingRace {
            startSpottingRaceGame()
        } else {
            dealAndLaunchRound { [weak self] boards in
                self?.multipeerSession?.stopAdvertising()
                self?.multipeerSession?.send(.gameStarted(
                    boards: boards,
                    activePackIDs: self?.activePackIDs ?? [],
                    gameType: .bingo
                ))
            }
        }
    }

    // MARK: - Game actions

    func toggleSquare(at position: Int) {
        guard screen == .game else { return }
        let wasMarked = localBoard?.isMarked(at: position) ?? false
        localBoard?.toggle(at: position)
        let isNowMarked = localBoard?.isMarked(at: position) ?? false
        multipeerSession?.send(.squareToggled(position: position, isMarked: isNowMarked))

        fogOfWarHiddenPositions.remove(position)

        let isVeryFirstMark = !firstMarkClaimedThisRound &&
                              opponentMarkCountsThisRound.values.allSatisfy { $0 == 0 }

        guard let board = localBoard else { return }

        if isNowMarked && !wasMarked {
            marksThisRound += 1
        }

        if isNowMarked && !wasMarked && !firstMarkClaimedThisRound {
            firstMarkClaimedThisRound = true
            earnTokens(1, reason: "First mark")
        }

        if isNowMarked && !wasMarked {
            evaluateChallenges(event: .tileMarked(
                tileID: board.squares[position].id,
                byPlayer: playerName,
                isFirstInGame: isVeryFirstMark
            ))
        }

        updateCompletedLine(for: board)
        checkBonuses(for: board)
    }

    func callBingo() {
        guard screen == .game, completedLine != nil else { return }
        earnTokens(5, reason: "BINGO!")   // win bonus
        multipeerSession?.send(.bingoAnnounced(byName: playerName))
        if gameMode != .solo { winHistory[playerName, default: 0] += 1 }
        dailyState.winsToday += 1
        dailyState.roundsPlayedToday += 1
        dailyState.save()
        evaluateChallenges(event: .roundWon(byPlayer: playerName))
        let endCtx = ChallengeEvaluationContext(
            playerName: playerName, marksThisRound: marksThisRound,
            opponentMarkCounts: opponentMarkCountsThisRound, winsToday: dailyState.winsToday,
            attacksUsedThisRound: attacksUsedThisRound, tokensAtEndOfRound: tokenBalance,
            tokensSpentThisRound: tokensSpentThisRound, roundsPlayedToday: dailyState.roundsPlayedToday,
            localBoard: localBoard
        )
        evaluateChallenges(event: .roundEnded(context: endCtx))
        lastRoundWinner = playerName
        if gameMode == .solo {
            computeSoloScore()
        }
        screen = .win(winnerName: playerName)
    }

    private func computeSoloScore() {
        guard let board = localBoard else { return }

        let elapsed = Date().timeIntervalSince(soloStartTime ?? Date())
        let timeMultiplier = max(1.0, 2.0 - elapsed / 600.0)

        let markedSquares = (0..<25)
            .filter { board.isMarked(at: $0) }
            .map { board.squares[$0] }
        let rarityBonus = markedSquares
            .filter { $0.id != BingoSquare.freeSquareID }
            .reduce(0) { $0 + $1.rarity.scoreBonus }

        let completedLineCount = GameEngine.completedLines(for: board).count
        let extraLines = max(0, completedLineCount - 1)
        let baseScore = tokensEarnedThisRound + (extraLines * 10) + rarityBonus
        let soloScore = Int(Double(baseScore) * timeMultiplier)

        lastSoloTokens = tokensEarnedThisRound
        lastSoloRarityBonus = rarityBonus
        lastSoloExtraLines = extraLines
        lastSoloTimeMultiplier = timeMultiplier
        lastSoloScore = soloScore
        lastSoloIsNewBest = soloScore > soloPersonalBest
        if lastSoloIsNewBest {
            soloPersonalBest = soloScore
        }
    }

    /// Exposed for unit testing only — wraps the private computeSoloScore().
    func computeSoloScoreForTest() {
        computeSoloScore()
    }

    func requestPlayAgain() {
        guard isHost else { return }
        if gameType == .spottingRace {
            requestPlayAgainSpottingRace()
            return
        }
        // Update consecutive-loss streaks based on last winner.
        if let winner = lastRoundWinner {
            let allNames = [playerName] + connectedPlayerNames
            for name in allNames {
                if name == winner {
                    consecutiveLosses[name] = 0
                } else {
                    consecutiveLosses[name, default: 0] += 1
                }
            }
        }
        dealAndLaunchRound { [weak self] boards in
            self?.multipeerSession?.send(.playAgain(boards: boards, activePackIDs: self?.activePackIDs ?? [], gameType: .bingo))
        }
    }

    // MARK: - Token helpers

    private func dealAndLaunchRound(sendBoardsMessage: @escaping ([String: [BingoSquare]]) -> Void) {
        rollDailyChallengesIfNeeded()
        let baseTiles = SquarePool.load()
        let namedPacks = PackManager.packs(forIDs: activePackIDs)
        let activePacks = [SquarePool.loadBasePack()] + namedPacks
        let pool = SquarePool.buildPool(base: baseTiles, activePacks: activePacks)
        let allNames = [playerName] + connectedPlayerNames
        let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
            let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
            return (name: name, difficulty: diff)
        }
        let boards = SquarePool.dealBoards(for: players,
                                           handicapLevels: consecutiveLosses,
                                           from: pool)
        let usedIDs = Set(boards.values.flatMap { $0 }.map(\.id))
        let reserve = SquarePool.dealReserve(for: players, count: 6, excluding: usedIDs, from: pool)

        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }
        opponentBoards = [:]
        opponentMarked = [:]
        recentOpponentMarks = []
        pruningTask?.cancel()
        pruningTask = nil
        for name in connectedPlayerNames {
            opponentBoards[name] = boards[name]
            opponentMarked[name] = [BingoSquare.freeSquareID]
        }
        reserveSquares = reserve[playerName] ?? []
        completedLine = nil
        resetRound()

        sendBoardsMessage(boards)
        for name in connectedPlayerNames {
            multipeerSession?.send(.reserveDealt(toName: name, squares: reserve[name] ?? []))
        }
        earnTokens(2, reason: "Round start")

        // Silently deliver handicap token bonuses (host only, no toast).
        if isHost {
            for name in connectedPlayerNames {
                let level = min(consecutiveLosses[name, default: 0], 3)
                let bonus = AppState.handicapBonusTokens(forLevel: level)
                if bonus > 0 {
                    multipeerSession?.send(.handicapBonus(toPlayer: name, tokens: bonus))
                }
            }
            // Apply host's own bonus directly — no toast.
            let localLevel = min(consecutiveLosses[playerName, default: 0], 3)
            let localBonus = AppState.handicapBonusTokens(forLevel: localLevel)
            if localBonus > 0 {
                tokenBalance += localBonus
                multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
            }
        }

        screen = .game

        if isHost {
            let modifier = RoundModifier.random()
            activeModifier = modifier
            multipeerSession?.send(.roundModifier(modifier))
            initializeModifier(modifier)
        }
    }

    private func updateCompletedLine(for board: BingoBoard) {
        switch activeModifier {
        case .hotStreak:
            completedLine = GameEngine.hotStreakLine(for: board)
        case .patternWin(let shape):
            completedLine = GameEngine.patternLine(for: board, shape: shape)
        default:
            completedLine = GameEngine.winningLine(for: board)
        }
    }

    private func initializeModifier(_ modifier: RoundModifier) {
        guard modifier == .fogOfWar, let board = localBoard else { return }
        fogShiftCount = 0
        fogOfWarHiddenPositions = pickFogPositions(hiddenCount: 10, board: board)
    }

    private func pickFogPositions(hiddenCount: Int, board: BingoBoard) -> Set<Int> {
        let candidates = (0..<25).filter { $0 != 12 && !board.isMarked(at: $0) }
        return Set(candidates.shuffled().prefix(min(hiddenCount, candidates.count)))
    }

    private func shiftFogIfNeeded() {
        guard activeModifier == .fogOfWar, let board = localBoard else { return }
        fogShiftCount += 1
        let hiddenCount = max(3, 10 - fogShiftCount)
        fogOfWarHiddenPositions = pickFogPositions(hiddenCount: hiddenCount, board: board)
    }

    private func shuffleBoardIfNeeded() {
        guard activeModifier == .shuffleBoard, var board = localBoard else { return }
        board.shuffleUnmarkedPositions()
        localBoard = board
        multipeerSession?.send(.boardShuffled(byName: playerName, squares: board.squares))
    }

    private func shiftTileIfNeeded() {
        guard activeModifier == .shiftingTiles,
              var board = localBoard,
              !reserveSquares.isEmpty else { return }

        let unmarkedIndices = (0..<25).filter {
            $0 != 12 && !board.isMarked(at: $0)
        }
        guard let targetIdx = unmarkedIndices.randomElement() else { return }

        let replacement = reserveSquares.removeFirst()
        board.replaceSquare(at: targetIdx, with: replacement)
        localBoard = board
    }

    private func evaluateChallenges(event: ChallengeEvent) {
        let context = ChallengeEvaluationContext(
            playerName: playerName,
            marksThisRound: marksThisRound,
            opponentMarkCounts: opponentMarkCountsThisRound,
            winsToday: dailyState.winsToday,
            attacksUsedThisRound: attacksUsedThisRound,
            tokensAtEndOfRound: tokenBalance,
            tokensSpentThisRound: tokensSpentThisRound,
            roundsPlayedToday: dailyState.roundsPlayedToday,
            localBoard: localBoard
        )

        for challenge in activeChallenges {
            guard !dailyState.completedIDs.contains(challenge.id) else { continue }
            if challenge.evaluate(event: event, context: context) {
                dailyState.completedIDs.insert(challenge.id)
                dailyState.save()
                earnTokens(challenge.tokenReward, reason: "\(challenge.emoji) \(challenge.title)!")
            }
        }
    }

    private func earnTokens(_ amount: Int, reason: String) {
        let effective = (activeModifier == .doubleDown) ? amount * 2 : amount
        tokenBalance += effective
        tokensEarnedThisRound += effective
        pendingToast = ToastEvent(message: "+\(effective)🟡 \(reason)", style: .earn)
        multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
    }

    // Returns the silent token bonus for a player at the given consecutive-loss level.
    static func handicapBonusTokens(forLevel level: Int) -> Int {
        switch min(level, 3) {
        case 1: return 3
        case 2: return 5
        case 3: return 7
        default: return 0
        }
    }

    private func resetRound() {
        firstMarkClaimedThisRound = false
        patternsAwardedThisRound = []
        closeCallsAwardedThisRound = []
        activeModifier = nil
        marksThisRound = 0
        attacksUsedThisRound = 0
        tokensSpentThisRound = 0
        tokensEarnedThisRound = 0
        opponentMarkCountsThisRound = [:]
        fogOfWarHiddenPositions = []
        fogShiftCount = 0
    }

    private func resetSpottingRound() {
        spottingRaceTiles = []
        mySpottingScore = 0
        opponentSpottingScores = [:]
        spottingRoundEndTime = nil
        tilePool = []
        mySpottingClaimedCount = 0
        spottingTimerTask?.cancel()
        spottingTimerTask = nil
        softClaimTasks.values.forEach { $0.cancel() }
        softClaimTasks = [:]
    }

    /// Draws one tile from `tilePool` using rarity-weighted probability.
    /// Removes the drawn tile from the pool. Returns nil when pool is empty.
    private func drawWeightedTile() -> BingoSquare? {
        guard !tilePool.isEmpty else { return nil }
        let totalWeight = tilePool.reduce(0) { $0 + $1.rarity.spottingRaceWeight }
        guard totalWeight > 0 else { return tilePool.removeFirst() }
        var pick = Int.random(in: 0..<totalWeight)
        for (idx, square) in tilePool.enumerated() {
            pick -= square.rarity.spottingRaceWeight
            if pick < 0 {
                tilePool.remove(at: idx)
                return square
            }
        }
        return tilePool.removeFirst()
    }

    /// Fills a slot with a freshly drawn tile. If pool is exhausted the slot is removed.
    /// Host-only. Broadcasts `tileReplaced` to peers.
    private func replaceSpottingSlot(slotID: UUID) {
        guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
        if let next = drawWeightedTile() {
            let newTile = SpottingRaceTile(
                id: slotID,  // keep slot ID stable for SwiftUI animation
                square: next,
                expiresAt: Date().addingTimeInterval(60)
            )
            spottingRaceTiles[idx] = newTile
            multipeerSession?.send(.tileReplaced(
                slotID: slotID,
                replacement: next,
                expiresAt: newTile.expiresAt
            ))
        } else {
            // Pool exhausted — remove this slot gracefully
            spottingRaceTiles.remove(at: idx)
        }
    }

    /// Fires every second. Host-only (also used in solo).
    /// Checks tile expiry and the round end condition.
    private func startSpottingTimerLoop() {
        spottingTimerTask?.cancel()
        spottingTimerTask = Task { @MainActor [weak self] in
            do {
                while let self {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self else { return }

                    // Round end check
                    if let endTime = self.spottingRoundEndTime, Date() >= endTime {
                        self.endSpottingRound()
                        return
                    }

                    // Tile expiry — only replace tiles that are not currently locked
                    let now = Date()
                    let expiredSlotIDs = self.spottingRaceTiles
                        .filter { $0.lockedBy == nil && now >= $0.expiresAt }
                        .map(\.id)
                    for slotID in expiredSlotIDs {
                        self.replaceSpottingSlot(slotID: slotID)
                    }
                }
            } catch {
                // Task cancelled — exit cleanly
            }
        }
    }

    private func endSpottingRound() {
        spottingTimerTask?.cancel()
        spottingTimerTask = nil
        softClaimTasks.values.forEach { $0.cancel() }
        softClaimTasks = [:]

        if gameMode == .solo {
            // base = total rarity score; multiplier rewards sustained engagement
            let base = mySpottingScore
            let multiplier = min(2.0, 1.0 + Double(mySpottingClaimedCount) / 20.0)
            let finalScore = Int(Double(base) * multiplier)
            let isNewBest = finalScore > soloSpottingRaceBest
            if isNewBest { soloSpottingRaceBest = finalScore }

            // Reuse lastSolo* published properties so WinView can read them
            lastSoloScore = finalScore
            lastSoloRarityBonus = base            // used as "Rarity score" in breakdown card
            lastSoloTimeMultiplier = multiplier   // used as multiplier row
            lastSoloTokens = mySpottingClaimedCount  // repurposed as "Tiles claimed"
            lastSoloExtraLines = 0
            lastSoloIsNewBest = isNewBest

            screen = .win(winnerName: playerName)
        } else {
            // Host collects canonical scores and broadcasts final results
            var allScores = opponentSpottingScores
            allScores[playerName] = mySpottingScore
            multipeerSession?.send(.spottingRoundEnded(scores: allScores))

            let winner = allScores.max(by: { $0.value < $1.value })?.key ?? playerName
            lastRoundWinner = winner
            winHistory[winner, default: 0] += 1
            screen = .win(winnerName: winner)
        }
    }

    /// Called when the local player taps a tile. Starts the 2-second soft-claim window.
    func tapSpottingTile(slotID: UUID) {
        guard screen == .game, gameType == .spottingRace else { return }
        guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
        let tile = spottingRaceTiles[idx]
        guard tile.lockedBy == nil, tile.claimedBy == nil else { return }

        let myTimestamp = Date()
        spottingRaceTiles[idx].lockedBy = playerName
        spottingRaceTiles[idx].lockTimestamp = myTimestamp

        multipeerSession?.send(.lockTile(
            slotID: slotID,
            squareID: tile.square.id,
            byName: playerName,
            timestamp: myTimestamp
        ))

        // After 2 seconds, finalize the claim
        let task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                self?.finalizeSpottingClaim(slotID: slotID)
            } catch {
                // Cancelled by undo
            }
        }
        softClaimTasks[slotID] = task
    }

    /// Called when the local player taps Undo during the soft-claim window.
    func undoSpottingClaim(slotID: UUID) {
        softClaimTasks[slotID]?.cancel()
        softClaimTasks.removeValue(forKey: slotID)
        guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
        spottingRaceTiles[idx].lockedBy = nil
        spottingRaceTiles[idx].lockTimestamp = nil
        multipeerSession?.send(.releaseTile(slotID: slotID, byName: playerName))
    }

    private func finalizeSpottingClaim(slotID: UUID) {
        softClaimTasks.removeValue(forKey: slotID)
        guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) else { return }
        let tile = spottingRaceTiles[idx]
        // Guard: ownership may have flipped if a race was lost between lock and finalize
        guard tile.lockedBy == playerName else { return }

        spottingRaceTiles[idx].claimedBy = playerName
        mySpottingScore += tile.square.rarity.spottingRaceScore
        mySpottingClaimedCount += 1

        multipeerSession?.send(.claimTile(
            slotID: slotID,
            squareID: tile.square.id,
            byName: playerName,
            timestamp: tile.lockTimestamp ?? Date()
        ))

        // Host queues replacement after 2-second stamp hold
        if isHost {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.replaceSpottingSlot(slotID: slotID)
            }
        }
    }

    private func checkBonuses(for board: BingoBoard) {
        for line in GameEngine.closeCallLines(for: board) {
            let id = line.map(String.init).joined(separator: ",")
            if !closeCallsAwardedThisRound.contains(id) {
                closeCallsAwardedThisRound.insert(id)
                earnTokens(3, reason: "Close call!")
            }
        }
        for line in GameEngine.completedLines(for: board) {
            let id = line.map(String.init).joined(separator: ",")
            if !patternsAwardedThisRound.contains(id) {
                patternsAwardedThisRound.insert(id)
                earnTokens(2, reason: "Pattern complete")
            }
        }
    }

    // MARK: - Power-up activation

    func activatePowerUp(_ powerUp: PowerUpType, targetPlayer: String? = nil, targetIndex: Int? = nil) {
        if activeModifier == .noPowers { return }

        let effectiveCost: Int = {
            if activeModifier == .sniper && powerUp.affectsOpponent {
                return max(0, powerUp.cost - 1)
            }
            return powerUp.cost
        }()
        guard tokenBalance >= effectiveCost, localBoard != nil else { return }

        var resolvedTargetPlayer = targetPlayer
        var resolvedTargetIndex = targetIndex
        var replacementSquare: BingoSquare? = nil

        switch powerUp {
        case .upgradeTileRandom:
            resolvedTargetIndex = highestRarityIndex(on: localBoard!)
        case .upgradeTileTargeted:
            break  // targetIndex provided by caller
        case .downgradeTileRandom:
            if let (name, idx) = lowestRarityOpponentTile() {
                resolvedTargetPlayer = name
                resolvedTargetIndex = idx
            }
        case .downgradeTileTargeted:
            break  // targetPlayer and targetIndex provided by caller
        case .freeMark:
            break  // targetIndex provided by caller
        case .unmarkOpponentRandom:
            if let (name, idx) = markedOpponentTile() {
                resolvedTargetPlayer = name
                resolvedTargetIndex = idx
            }
        case .unmarkOpponentTargeted:
            break  // targetPlayer and targetIndex provided by caller
        }

        guard resolvedTargetIndex != nil else { return }
        if powerUp.affectsOpponent { guard resolvedTargetPlayer != nil else { return } }

        // Pop reserve only after confirming we will proceed
        if powerUp == .upgradeTileRandom || powerUp == .upgradeTileTargeted ||
           powerUp == .downgradeTileRandom || powerUp == .downgradeTileTargeted {
            guard !reserveSquares.isEmpty else { return }
            replacementSquare = reserveSquares.removeFirst()
        }

        // Capture tile name before the board is mutated (upgrade replaces the tile)
        var selfActionMessage: String? = nil
        switch powerUp {
        case .upgradeTileRandom, .upgradeTileTargeted:
            if let idx = resolvedTargetIndex, let board = localBoard, idx < board.squares.count {
                selfActionMessage = "🔀 Upgraded '\(board.squares[idx].text)'"
            }
        case .freeMark:
            if let idx = resolvedTargetIndex, let board = localBoard, idx < board.squares.count {
                selfActionMessage = "✅ Marked '\(board.squares[idx].text)'"
            }
        case .downgradeTileRandom, .downgradeTileTargeted:
            selfActionMessage = "💣 Sabotaged \(resolvedTargetPlayer ?? "opponent")"
        case .unmarkOpponentRandom, .unmarkOpponentTargeted:
            selfActionMessage = "💥 Erased \(resolvedTargetPlayer ?? "opponent")'s mark"
        }

        tokenBalance -= effectiveCost
        tokensSpentThisRound += effectiveCost
        if powerUp.affectsOpponent {
            attacksUsedThisRound += 1
            evaluateChallenges(event: .attackUsed(byPlayer: playerName))
        }
        multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))

        applyPowerUpEffect(powerUp, byName: playerName,
                           targetPlayer: resolvedTargetPlayer,
                           targetIndex: resolvedTargetIndex,
                           replacementSquare: replacementSquare)

        multipeerSession?.send(.powerUpUsed(byName: playerName, powerUp: powerUp,
                                            targetPlayer: resolvedTargetPlayer,
                                            targetIndex: resolvedTargetIndex,
                                            replacementSquare: replacementSquare))

        // Re-check win and bonus conditions after free mark
        if powerUp == .freeMark, let board = localBoard {
            updateCompletedLine(for: board)
            checkBonuses(for: board)
        }

        // Show which tile was affected (posted last so it appears above any earn toasts)
        if let msg = selfActionMessage {
            pendingToast = ToastEvent(message: msg, style: .earn)
        }
    }

    func applyPowerUpEffect(
        _ powerUp: PowerUpType,
        byName: String,
        targetPlayer: String?,
        targetIndex: Int?,
        replacementSquare: BingoSquare?
    ) {
        switch powerUp {
        case .upgradeTileRandom, .upgradeTileTargeted:
            guard let idx = targetIndex, let newSquare = replacementSquare else { return }
            if byName == playerName {
                localBoard?.replaceSquare(at: idx, with: newSquare)
            } else {
                opponentBoards[byName]?[idx] = newSquare
            }

        case .downgradeTileRandom, .downgradeTileTargeted:
            guard let target = targetPlayer, let idx = targetIndex,
                  let newSquare = replacementSquare else { return }
            if target == playerName {
                localBoard?.replaceSquare(at: idx, with: newSquare)
            } else {
                if let board = opponentBoards[target], idx < board.count {
                    opponentMarked[target]?.remove(board[idx].id)
                }
                opponentBoards[target]?[idx] = newSquare
            }

        case .freeMark:
            guard let idx = targetIndex else { return }
            if byName == playerName {
                localBoard?.markFree(at: idx)
            } else {
                if let board = opponentBoards[byName], idx < board.count {
                    opponentMarked[byName, default: []].insert(board[idx].id)
                }
            }

        case .unmarkOpponentRandom, .unmarkOpponentTargeted:
            guard let target = targetPlayer, let idx = targetIndex else { return }
            if target == playerName {
                localBoard?.unmark(at: idx)
            } else {
                if let board = opponentBoards[target], idx < board.count {
                    opponentMarked[target]?.remove(board[idx].id)
                }
            }
        }
    }

    // MARK: - Power-up target helpers

    private func highestRarityIndex(on board: BingoBoard) -> Int? {
        let rarityOrder: [SquareRarity] = [.veryRare, .rare, .uncommon, .common, .veryCommon]
        let candidates = (0..<25).filter {
            board.squares[$0].id != BingoSquare.freeSquareID && !board.isMarked(at: $0)
        }
        return candidates.min {
            let ra = rarityOrder.firstIndex(of: board.squares[$0].rarity) ?? 99
            let rb = rarityOrder.firstIndex(of: board.squares[$1].rarity) ?? 99
            return ra < rb
        }
    }

    private func lowestRarityOpponentTile() -> (String, Int)? {
        let rarityOrder: [SquareRarity] = [.veryCommon, .common, .uncommon, .rare, .veryRare]
        var best: (name: String, idx: Int, rank: Int)? = nil
        for (oppName, oppBoard) in opponentBoards {
            let markedIDs = opponentMarked[oppName] ?? []
            for (idx, square) in oppBoard.enumerated() {
                guard square.id != BingoSquare.freeSquareID,
                      !markedIDs.contains(square.id) else { continue }
                let rank = rarityOrder.firstIndex(of: square.rarity) ?? 99
                if best == nil || rank < best!.rank { best = (oppName, idx, rank) }
            }
        }
        return best.map { ($0.name, $0.idx) }
    }

    private func markedOpponentTile() -> (String, Int)? {
        var best: (name: String, idx: Int)? = nil
        for (oppName, markedIDs) in opponentMarked {
            guard let board = opponentBoards[oppName] else { continue }
            for (idx, square) in board.enumerated() {
                guard square.id != BingoSquare.freeSquareID,
                      markedIDs.contains(square.id) else { continue }
                if best == nil || idx > best!.idx { best = (oppName, idx) }
            }
        }
        return best.map { ($0.name, $0.idx) }
    }

    private func appendRecentMark(_ mark: RecentMark) {
        if recentOpponentMarks.count >= maxRecentMarks {
            recentOpponentMarks.removeFirst()
        }
        recentOpponentMarks.append(mark)
        startPruningIfNeeded()
    }

    private func startPruningIfNeeded() {
        guard pruningTask == nil else { return }
        pruningTask = Task { @MainActor [weak self] in
            defer { self?.pruningTask = nil }
            do {
                while let self, !self.recentOpponentMarks.isEmpty {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    let cutoff = Date().addingTimeInterval(-10)
                    self.recentOpponentMarks.removeAll { $0.timestamp < cutoff }
                }
            } catch {
                // Cancelled — exit cleanly
            }
        }
    }

    // MARK: - MultipeerSessionDelegate

    func multipeerSession(_ session: MultipeerSession, didReceive message: MultipeerMessage, from peerName: String) {
        switch message {
        case .gameStarted(let boards, let activePackIDs, let gameType):
            self.gameType = gameType
            self.activePackIDs = activePackIDs
            rollDailyChallengesIfNeeded()
            recentOpponentMarks = []
            pruningTask?.cancel()
            pruningTask = nil
            multipeerSession?.stopBrowsing()

            if gameType == .spottingRace {
                resetSpottingRound()
                opponentSpottingScores = Dictionary(
                    uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
                )
                spottingRoundEndTime = Date().addingTimeInterval(300)
                // Initial tiles will arrive as tileReplaced messages from the host
            } else {
                if let mySquares = boards[playerName] {
                    localBoard = BingoBoard(squares: mySquares)
                }
                opponentBoards = [:]
                opponentMarked = [:]
                for (name, squares) in boards where name != playerName {
                    opponentBoards[name] = squares
                    opponentMarked[name] = [BingoSquare.freeSquareID]
                }
                completedLine = nil
                resetRound()
                earnTokens(2, reason: "Round start")
            }
            screen = .game

        case .squareToggled(let position, let isMarked):
            if let board = opponentBoards[peerName], position < board.count {
                let tileID = board[position].id
                if isMarked { opponentMarked[peerName, default: []].insert(tileID) }
                else { opponentMarked[peerName]?.remove(tileID) }
            }
            if isMarked {
                opponentMarkCountsThisRound[peerName, default: 0] += 1
                shiftFogIfNeeded()
                shiftTileIfNeeded()
                shuffleBoardIfNeeded()
            }
            if isMarked, let square = opponentBoards[peerName]?[position] {
                appendRecentMark(RecentMark(opponentName: peerName,
                                            square: square, timestamp: Date()))
            }

        case .bingoAnnounced(let byName):
            winHistory[byName, default: 0] += 1
            lastRoundWinner = byName
            screen = .win(winnerName: byName)
            dailyState.roundsPlayedToday += 1
            dailyState.save()
            let endCtx = ChallengeEvaluationContext(
                playerName: playerName, marksThisRound: marksThisRound,
                opponentMarkCounts: opponentMarkCountsThisRound, winsToday: dailyState.winsToday,
                attacksUsedThisRound: attacksUsedThisRound, tokensAtEndOfRound: tokenBalance,
                tokensSpentThisRound: tokensSpentThisRound, roundsPlayedToday: dailyState.roundsPlayedToday,
                localBoard: localBoard
            )
            evaluateChallenges(event: .roundEnded(context: endCtx))

        case .playAgain(let boards, let activePackIDs, let gameType):
            self.gameType = gameType
            self.activePackIDs = activePackIDs
            rollDailyChallengesIfNeeded()
            recentOpponentMarks = []
            pruningTask?.cancel()
            pruningTask = nil

            if gameType == .spottingRace {
                resetSpottingRound()
                opponentSpottingScores = Dictionary(
                    uniqueKeysWithValues: connectedPlayerNames.map { ($0, 0) }
                )
                spottingRoundEndTime = Date().addingTimeInterval(300)
                // Tiles arrive as tileReplaced messages
            } else {
                if let mySquares = boards[playerName] {
                    localBoard = BingoBoard(squares: mySquares)
                }
                opponentBoards = [:]
                opponentMarked = [:]
                for (name, squares) in boards where name != playerName {
                    opponentBoards[name] = squares
                    opponentMarked[name] = [BingoSquare.freeSquareID]
                }
                completedLine = nil
                resetRound()
                earnTokens(2, reason: "Round start")
            }
            screen = .game

        case .difficultyChosen(let byName, let difficulty):
            if isHost { playerDifficulties[byName] = difficulty }

        case .tokenEarned(let byName, let newBalance):
            tokenBalances[byName] = newBalance

        case .reserveDealt(let toName, let squares):
            if toName == playerName { reserveSquares = squares }

        case .powerUpUsed(let byName, let powerUp, let targetPlayer, let targetIndex, let replacementSquare):
            // Capture tile name before effect mutates the board
            var threatMessage: String? = nil
            if targetPlayer == playerName, powerUp.affectsOpponent,
               let idx = targetIndex, let board = localBoard, idx < board.squares.count {
                let tileName = board.squares[idx].text
                let verb: String
                let emoji: String
                // Random and targeted variants use the same verb — the distinction isn't surfaced to the target player
                switch powerUp {
                case .downgradeTileRandom, .downgradeTileTargeted:
                    verb = "downgraded"; emoji = "💣"
                default:
                    verb = "erased"; emoji = "💥"
                }
                threatMessage = "\(emoji) \(byName) \(verb) '\(tileName)'"
            }

            applyPowerUpEffect(powerUp, byName: byName,
                               targetPlayer: targetPlayer,
                               targetIndex: targetIndex,
                               replacementSquare: replacementSquare)
            if let board = localBoard {
                updateCompletedLine(for: board)
            }
            if let msg = threatMessage {
                pendingToast = ToastEvent(message: msg, style: .threat)
            }

        case .roundModifier(let modifier):
            activeModifier = modifier
            initializeModifier(modifier)

        case .boardShuffled(let byName, let squares):
            opponentBoards[byName] = squares
            // opponentMarked[byName] UUID set remains valid — only tile positions moved

        case .handicapBonus(let toPlayer, let tokens):
            // Silently credit tokens — no toast, no earnTokens call.
            // tokens > 0 is a defensive guard; the host already filters before sending.
            guard toPlayer == playerName, tokens > 0 else { return }
            tokenBalance += tokens
            multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))

        case .lockTile(let slotID, let squareID, let byName, let timestamp):
            guard let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID && $0.square.id == squareID }) else { return }
            guard spottingRaceTiles[idx].claimedBy == nil else { return }
            if spottingRaceTiles[idx].lockedBy == playerName,
               let myTimestamp = spottingRaceTiles[idx].lockTimestamp {
                if myTimestamp <= timestamp {
                    // Local claim wins — ignore peer's lock
                    return
                } else {
                    // Peer wins — cancel our pending finalize and show denial
                    softClaimTasks[slotID]?.cancel()
                    softClaimTasks.removeValue(forKey: slotID)
                    spottingRaceTiles[idx].lockedBy = byName
                    spottingRaceTiles[idx].lockTimestamp = timestamp
                    pendingToast = ToastEvent(message: "❌ \(byName) was faster!", style: .threat)
                }
            } else if spottingRaceTiles[idx].lockedBy == nil {
                spottingRaceTiles[idx].lockedBy = byName
                spottingRaceTiles[idx].lockTimestamp = timestamp
            }

        case .releaseTile(let slotID, let byName):
            if let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }),
               spottingRaceTiles[idx].lockedBy == byName {
                spottingRaceTiles[idx].lockedBy = nil
                spottingRaceTiles[idx].lockTimestamp = nil
            }

        case .claimTile(let slotID, let squareID, let byName, _):
            if let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID && $0.square.id == squareID }) {
                let score = spottingRaceTiles[idx].square.rarity.spottingRaceScore
                let tileName = spottingRaceTiles[idx].square.text
                let emoji = spottingRaceTiles[idx].square.emoji ?? "📍"
                spottingRaceTiles[idx].claimedBy = byName
                opponentSpottingScores[byName, default: 0] += score
                pendingToast = ToastEvent(
                    message: "\(byName) claimed \(emoji) \(tileName) · +\(score) pts",
                    style: .opponentClaim
                )
                // Host replaces the slot after 2-second stamp hold
                if isHost {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        self?.replaceSpottingSlot(slotID: slotID)
                    }
                }
            }

        case .tileReplaced(let slotID, let replacement, let expiresAt):
            // Non-host peers update their local tile grid
            if !isHost {
                if let idx = spottingRaceTiles.firstIndex(where: { $0.id == slotID }) {
                    spottingRaceTiles[idx] = SpottingRaceTile(
                        id: slotID,
                        square: replacement,
                        expiresAt: expiresAt
                    )
                } else {
                    // Initial fill from host — slot doesn't exist yet
                    spottingRaceTiles.append(SpottingRaceTile(
                        id: slotID,
                        square: replacement,
                        expiresAt: expiresAt
                    ))
                }
            }

        case .spottingRoundEnded(let scores):
            spottingTimerTask?.cancel()
            spottingTimerTask = nil
            softClaimTasks.values.forEach { $0.cancel() }
            softClaimTasks = [:]
            mySpottingScore = scores[playerName] ?? mySpottingScore
            opponentSpottingScores = scores.filter { $0.key != playerName }
            let winner = scores.max(by: { $0.value < $1.value })?.key ?? playerName
            lastRoundWinner = winner
            winHistory[winner, default: 0] += 1
            screen = .win(winnerName: winner)
        }
    }

    func multipeerSession(_ session: MultipeerSession, peerDidConnect peerName: String) {
        connectingToGame = nil
        if !connectedPlayerNames.contains(peerName) {
            connectedPlayerNames.append(peerName)
        }
    }

    func multipeerSession(_ session: MultipeerSession, peerDidDisconnect peerName: String) {
        if connectingToGame == peerName { connectingToGame = nil }
        connectedPlayerNames.removeAll { $0 == peerName }
        opponentMarked.removeValue(forKey: peerName)
        opponentBoards.removeValue(forKey: peerName)
        tokenBalances.removeValue(forKey: peerName)
        consecutiveLosses.removeValue(forKey: peerName)
        recentOpponentMarks.removeAll { $0.opponentName == peerName }
    }

    func multipeerSession(_ session: MultipeerSession, foundPeer peerName: String) {
        if !foundGameNames.contains(peerName) { foundGameNames.append(peerName) }
    }

    func multipeerSession(_ session: MultipeerSession, lostPeer peerName: String) {
        foundGameNames.removeAll { $0 == peerName }
    }
}
