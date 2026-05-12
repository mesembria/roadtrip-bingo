import Foundation
import SwiftUI

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
    @Published var playerDifficulties: [String: BoardDifficulty] = [:]  // host only: name → difficulty

    // MARK: - Game (Phase 2 — stubbed for now)
    @Published var localBoard: BingoBoard?
    @Published var completedLine: [Int]?
    @Published var opponentMarked: [String: Set<Int>] = [:]

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
        isHost = false
        playerDifficulty = .backseat
        playerDifficulties = [:]
        // winHistory is intentionally preserved across sessions
        screen = .home
    }

    // MARK: - Lobby (host only) — Phase 2 will fill startGame()

    func startGame() {
        guard isHost else { return }
        let pool = SquarePool.load()
        let allNames = [playerName] + connectedPlayerNames
        let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
            let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
            return (name: name, difficulty: diff)
        }
        let boards = SquarePool.dealBoards(for: players, from: pool)

        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }
        for name in connectedPlayerNames {
            opponentMarked[name] = [12]
        }
        completedLine = nil
        multipeerSession?.stopAdvertising()
        multipeerSession?.send(.gameStarted(boards: boards))
        screen = .game
    }

    // MARK: - Game actions — Phase 2

    func toggleSquare(at position: Int) {
        guard screen == .game else { return }
        localBoard?.toggle(at: position)
        let isNowMarked = localBoard?.isMarked(at: position) ?? false
        multipeerSession?.send(.squareToggled(position: position, isMarked: isNowMarked))
        if let board = localBoard {
            completedLine = GameEngine.winningLine(for: board)
        }
    }

    func callBingo() {
        guard completedLine != nil else { return }
        multipeerSession?.send(.bingoAnnounced(byName: playerName))
        winHistory[playerName, default: 0] += 1
        screen = .win(winnerName: playerName)
    }

    func requestPlayAgain() {
        guard isHost else { return }
        let pool = SquarePool.load()
        let allNames = [playerName] + connectedPlayerNames
        let players = allNames.map { name -> (name: String, difficulty: BoardDifficulty) in
            let diff = name == playerName ? playerDifficulty : (playerDifficulties[name] ?? .backseat)
            return (name: name, difficulty: diff)
        }
        let boards = SquarePool.dealBoards(for: players, from: pool)

        if let mySquares = boards[playerName] {
            localBoard = BingoBoard(squares: mySquares)
        }
        for name in connectedPlayerNames {
            opponentMarked[name] = [12]
        }
        completedLine = nil
        multipeerSession?.send(.playAgain(boards: boards))
        screen = .game
    }

    // MARK: - MultipeerSessionDelegate

    func multipeerSession(_ session: MultipeerSession, didReceive message: MultipeerMessage, from peerName: String) {
        switch message {
        case .gameStarted(let boards):
            let freeSquarePosition = 12
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentMarked = [:]
            for (name, _) in boards where name != playerName {
                opponentMarked[name] = [freeSquarePosition]
            }
            completedLine = nil
            multipeerSession?.stopBrowsing()
            screen = .game

        case .squareToggled(let position, let isMarked):
            var current = opponentMarked[peerName] ?? []
            if isMarked { current.insert(position) } else { current.remove(position) }
            opponentMarked[peerName] = current

        case .bingoAnnounced(let byName):
            winHistory[byName, default: 0] += 1
            screen = .win(winnerName: byName)

        case .playAgain(let boards):
            let freeSquarePosition = 12
            if let mySquares = boards[playerName] {
                localBoard = BingoBoard(squares: mySquares)
            }
            opponentMarked = [:]
            for (name, _) in boards where name != playerName {
                opponentMarked[name] = [freeSquarePosition]
            }
            completedLine = nil
            screen = .game

        case .difficultyChosen(let byName, let difficulty):
            if isHost {
                playerDifficulties[byName] = difficulty
            }

        case .tokenEarned(let byName, let newBalance):
            // Task 6: handle token balance sync
            break

        case .powerUpUsed(let byName, let powerUp, let targetPlayer, let targetIndex, let replacementSquare):
            // Task 7: handle power-up application
            break

        case .reserveDealt(let toName, let squares):
            // Task 6: handle reserve squares distribution
            break
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
    }

    func multipeerSession(_ session: MultipeerSession, foundPeer peerName: String) {
        if !foundGameNames.contains(peerName) {
            foundGameNames.append(peerName)
        }
    }

    func multipeerSession(_ session: MultipeerSession, lostPeer peerName: String) {
        foundGameNames.removeAll { $0 == peerName }
    }
}
