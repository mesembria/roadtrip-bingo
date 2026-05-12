import Foundation
import SwiftUI

enum ToastStyle: Equatable { case earn, threat }

struct ToastEvent: Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}

enum AppScreen: Equatable {
    case home
    case lobby
    case game
    case win(winnerName: String)
    case playAgain
}

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
    @Published var playerDifficulty: BoardDifficulty = .backseat
    @Published var playerDifficulties: [String: BoardDifficulty] = [:]

    // MARK: - Game
    @Published var localBoard: BingoBoard?
    @Published var completedLine: [Int]?
    @Published var opponentMarked: [String: Set<Int>] = [:]
    @Published var opponentBoards: [String: [BingoSquare]] = [:]
    var reserveSquares: [BingoSquare] = []

    // MARK: - Tokens
    @Published var tokenBalance: Int = 0
    @Published var tokenBalances: [String: Int] = [:]
    @Published var pendingToast: ToastEvent? = nil

    // MARK: - Achievement guards (reset each round)
    private var firstMarkClaimedThisRound = false
    private var patternsAwardedThisRound: Set<String> = []
    private var closeCallsAwardedThisRound: Set<String> = []

    // MARK: - Post-game
    @Published var winHistory: [String: Int] = [:]

    // MARK: - Network
    private(set) var multipeerSession: MultipeerSession?

    init() {
        self.playerName = UserDefaults.standard.string(forKey: "playerName") ?? ""
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
        localBoard = nil
        completedLine = nil
        opponentMarked = [:]
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

        guard let board = localBoard else { return }

        if isNowMarked && !wasMarked && !firstMarkClaimedThisRound {
            firstMarkClaimedThisRound = true
            earnTokens(1, reason: "First mark")
        }

        completedLine = GameEngine.winningLine(for: board)
        checkBonuses(for: board)
    }

    func callBingo() {
        guard screen == .game, completedLine != nil else { return }
        earnTokens(5, reason: "BINGO!")   // win bonus
        multipeerSession?.send(.bingoAnnounced(byName: playerName))
        winHistory[playerName, default: 0] += 1
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
        for name in connectedPlayerNames {
            opponentBoards[name] = boards[name]
            opponentMarked[name] = [12]
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
    }

    private func earnTokens(_ amount: Int, reason: String) {
        tokenBalance += amount
        pendingToast = ToastEvent(message: "+\(amount)🪙 \(reason)", style: .earn)
        multipeerSession?.send(.tokenEarned(byName: playerName, newBalance: tokenBalance))
    }

    private func resetRound() {
        firstMarkClaimedThisRound = false
        patternsAwardedThisRound = []
        closeCallsAwardedThisRound = []
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
        guard tokenBalance >= powerUp.cost, localBoard != nil else { return }

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

        tokenBalance -= powerUp.cost
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
            completedLine = GameEngine.winningLine(for: board)
            checkBonuses(for: board)
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
                opponentBoards[target]?[idx] = newSquare
                opponentMarked[target]?.remove(idx)
            }

        case .freeMark:
            guard let idx = targetIndex else { return }
            if byName == playerName {
                localBoard?.mark(at: idx)
            } else {
                opponentMarked[byName]?.insert(idx)
            }

        case .unmarkOpponentRandom, .unmarkOpponentTargeted:
            guard let target = targetPlayer, let idx = targetIndex else { return }
            if target == playerName {
                localBoard?.unmark(at: idx)
            } else {
                opponentMarked[target]?.remove(idx)
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
            let marked = opponentMarked[oppName] ?? []
            for idx in 0..<oppBoard.count {
                guard oppBoard[idx].id != BingoSquare.freeSquareID,
                      !marked.contains(idx) else { continue }
                let rank = rarityOrder.firstIndex(of: oppBoard[idx].rarity) ?? 99
                if best == nil || rank < best!.rank {
                    best = (oppName, idx, rank)
                }
            }
        }
        return best.map { ($0.name, $0.idx) }
    }

    private func markedOpponentTile() -> (String, Int)? {
        var best: (name: String, idx: Int)? = nil
        for oppName in opponentMarked.keys {
            let marked = opponentMarked[oppName] ?? []
            if let idx = marked.filter({ $0 != 12 }).max() {
                if best == nil || idx > best!.idx {
                    best = (oppName, idx)
                }
            }
        }
        return best.map { ($0.name, $0.idx) }
    }

    // MARK: - MultipeerSessionDelegate

    func multipeerSession(_ session: MultipeerSession, didReceive message: MultipeerMessage, from peerName: String) {
        switch message {
        case .gameStarted(let boards):
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentBoards = [:]
            opponentMarked = [:]
            for (name, squares) in boards where name != playerName {
                opponentBoards[name] = squares
                opponentMarked[name] = [12]
            }
            completedLine = nil
            resetRound()
            multipeerSession?.stopBrowsing()
            earnTokens(2, reason: "Round start")   // round-start bonus for joiner
            screen = .game

        case .squareToggled(let position, let isMarked):
            var current = opponentMarked[peerName] ?? []
            if isMarked { current.insert(position) } else { current.remove(position) }
            opponentMarked[peerName] = current

        case .bingoAnnounced(let byName):
            winHistory[byName, default: 0] += 1
            screen = .win(winnerName: byName)

        case .playAgain(let boards):
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentBoards = [:]
            opponentMarked = [:]
            for (name, squares) in boards where name != playerName {
                opponentBoards[name] = squares
                opponentMarked[name] = [12]
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
            applyPowerUpEffect(powerUp, byName: byName,
                               targetPlayer: targetPlayer,
                               targetIndex: targetIndex,
                               replacementSquare: replacementSquare)
            if let board = localBoard {
                completedLine = GameEngine.winningLine(for: board)
            }
        }
    }

    func multipeerSession(_ session: MultipeerSession, peerDidConnect peerName: String) {
        if !connectedPlayerNames.contains(peerName) {
            connectedPlayerNames.append(peerName)
        }
    }

    func multipeerSession(_ session: MultipeerSession, peerDidDisconnect peerName: String) {
        connectedPlayerNames.removeAll { $0 == peerName }
        opponentMarked.removeValue(forKey: peerName)
        opponentBoards.removeValue(forKey: peerName)
        tokenBalances.removeValue(forKey: peerName)
    }

    func multipeerSession(_ session: MultipeerSession, foundPeer peerName: String) {
        if !foundGameNames.contains(peerName) { foundGameNames.append(peerName) }
    }

    func multipeerSession(_ session: MultipeerSession, lostPeer peerName: String) {
        foundGameNames.removeAll { $0 == peerName }
    }
}
