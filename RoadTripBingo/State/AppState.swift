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

    // MARK: - Lobby
    @Published var isHost = false
    @Published var connectedPlayerNames: [String] = []
    @Published var foundGameNames: [String] = []
    @Published var connectingToGame: String? = nil   // set while MC handshake is in flight
    @Published var playerDifficulty: BoardDifficulty = .backseat
    @Published var playerDifficulties: [String: BoardDifficulty] = [:]

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

    var activeChallenges: [DailyChallenge] {
        dailyState.challengeTypes.map { DailyChallenge(type: $0) }
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
        playerDifficulty = .backseat
        playerDifficulties = [:]
        tokenBalance = 0
        tokenBalances = [:]
        pendingToast = nil
        resetRound()
        // winHistory intentionally preserved
        screen = .home
    }

    // MARK: - Lobby (host only)

    func startGame() {
        guard isHost else { return }
        dealAndLaunchRound { [weak self] boards in
            self?.multipeerSession?.stopAdvertising()
            self?.multipeerSession?.send(.gameStarted(boards: boards))
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
        winHistory[playerName, default: 0] += 1
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
        screen = .win(winnerName: playerName)
    }

    func requestPlayAgain() {
        guard isHost else { return }
        dealAndLaunchRound { [weak self] boards in
            self?.multipeerSession?.send(.playAgain(boards: boards))
        }
    }

    // MARK: - Token helpers

    private func dealAndLaunchRound(sendBoardsMessage: @escaping ([String: [BingoSquare]]) -> Void) {
        rollDailyChallengesIfNeeded()
        let pool = SquarePool.load()
        let allNames = [playerName] + connectedPlayerNames
        let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
            let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
            return (name: name, difficulty: diff)
        }
        let boards = SquarePool.dealBoards(for: players, from: pool)
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
        pendingToast = ToastEvent(message: "+\(effective)🟡 \(reason)", style: .earn)
        multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
    }

    private func resetRound() {
        firstMarkClaimedThisRound = false
        patternsAwardedThisRound = []
        closeCallsAwardedThisRound = []
        activeModifier = nil
        marksThisRound = 0
        attacksUsedThisRound = 0
        tokensSpentThisRound = 0
        opponentMarkCountsThisRound = [:]
        fogOfWarHiddenPositions = []
        fogShiftCount = 0
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
        case .gameStarted(let boards):
            rollDailyChallengesIfNeeded()
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentBoards = [:]
            opponentMarked = [:]
            recentOpponentMarks = []
            pruningTask?.cancel()
            pruningTask = nil
            for (name, squares) in boards where name != playerName {
                opponentBoards[name] = squares
                opponentMarked[name] = [BingoSquare.freeSquareID]
            }
            completedLine = nil
            resetRound()
            multipeerSession?.stopBrowsing()
            earnTokens(2, reason: "Round start")   // round-start bonus for joiner
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

        case .playAgain(let boards):
            rollDailyChallengesIfNeeded()
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentBoards = [:]
            opponentMarked = [:]
            recentOpponentMarks = []
            pruningTask?.cancel()
            pruningTask = nil
            for (name, squares) in boards where name != playerName {
                opponentBoards[name] = squares
                opponentMarked[name] = [BingoSquare.freeSquareID]
            }
            completedLine = nil
            resetRound()
            earnTokens(2, reason: "Round start")   // round-start bonus for joiner
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
        recentOpponentMarks.removeAll { $0.opponentName == peerName }
    }

    func multipeerSession(_ session: MultipeerSession, foundPeer peerName: String) {
        if !foundGameNames.contains(peerName) { foundGameNames.append(peerName) }
    }

    func multipeerSession(_ session: MultipeerSession, lostPeer peerName: String) {
        foundGameNames.removeAll { $0 == peerName }
    }
}
