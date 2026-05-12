import Foundation
import SwiftUI

struct ToastEvent: Equatable {
    let id = UUID()
    let message: String
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
    var opponentBoards: [String: [BingoSquare]] = [:]
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
            earnTokens(1)
        }

        completedLine = GameEngine.winningLine(for: board)
        checkBonuses(for: board)
    }

    func callBingo() {
        guard completedLine != nil else { return }
        earnTokens(5)   // win bonus
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
        earnTokens(2)
        screen = .game
    }

    private func earnTokens(_ amount: Int) {
        tokenBalance += amount
        pendingToast = ToastEvent(message: "+\(amount)🪙")
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
                earnTokens(3)
            }
        }
        for line in GameEngine.completedLines(for: board) {
            let id = line.map(String.init).joined(separator: ",")
            if !patternsAwardedThisRound.contains(id) {
                patternsAwardedThisRound.insert(id)
                earnTokens(2)
            }
        }
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
            earnTokens(2)   // round-start bonus for joiner
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
            earnTokens(2)   // round-start bonus for joiner
            screen = .game

        case .difficultyChosen(let byName, let difficulty):
            if isHost { playerDifficulties[byName] = difficulty }

        case .tokenEarned(let byName, let newBalance):
            tokenBalances[byName] = newBalance

        case .reserveDealt(let toName, let squares):
            if toName == playerName { reserveSquares = squares }

        case .powerUpUsed:
            break  // handled in Task 7
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
