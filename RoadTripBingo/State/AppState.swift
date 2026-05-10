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

    func goHome() {
        multipeerSession?.disconnect()
        multipeerSession = nil
        connectedPlayerNames = []
        foundGameNames = []
        localBoard = nil
        completedLine = nil
        opponentMarked = [:]
        isHost = false
        // winHistory is intentionally preserved across sessions
        screen = .home
    }

    // MARK: - Lobby (host only) — Phase 2 will fill startGame()

    func startGame() {
        guard isHost, !connectedPlayerNames.isEmpty else { return }
        multipeerSession?.stopAdvertising()
        // Phase 2: replace [:] with real board assignment
        multipeerSession?.send(.gameStarted(boards: [:]))
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
        // Phase 2: deal new boards
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
