import Foundation

enum DailyChallengeType: String, Codable, CaseIterable, Equatable {
    case winOne, speedDemon, pacifist, menace, hoarder, cornerKing, onFire, spender, firstBlood
}

struct ChallengeEvaluationContext {
    let playerName: String
    let marksThisRound: Int
    let opponentMarkCounts: [String: Int]
    let winsToday: Int
    let attacksUsedThisRound: Int
    let tokensAtEndOfRound: Int
    let tokensSpentThisRound: Int
    let roundsPlayedToday: Int
    let localBoard: BingoBoard?
}

enum ChallengeEvent {
    case tileMarked(tileID: UUID, byPlayer: String, isFirstInGame: Bool)
    case roundWon(byPlayer: String)
    case attackUsed(byPlayer: String)
    case roundEnded(context: ChallengeEvaluationContext)
    // Future: case tileMarkedWithCategory(category: SquareCategory, byPlayer: String)
    // BingoSquare.category already exists — add the case and a DailyChallengeType when ready.
}

struct DailyChallenge: Codable, Identifiable {
    let type: DailyChallengeType
    var id: String { type.rawValue }

    var title: String {
        switch type {
        case .winOne:      return "Win One"
        case .speedDemon:  return "Speed Demon"
        case .pacifist:    return "Pacifist"
        case .menace:      return "Menace"
        case .hoarder:     return "Hoarder"
        case .cornerKing:  return "Corner King"
        case .onFire:      return "On Fire"
        case .spender:     return "Spender"
        case .firstBlood:  return "First Blood"
        }
    }

    var emoji: String {
        switch type {
        case .winOne:      return "🏆"
        case .speedDemon:  return "⚡"
        case .pacifist:    return "🧘"
        case .menace:      return "💣"
        case .hoarder:     return "🎯"
        case .cornerKing:  return "🔲"
        case .onFire:      return "🔥"
        case .spender:     return "🤑"
        case .firstBlood:  return "🌅"
        }
    }

    var description: String {
        switch type {
        case .winOne:      return "Win any round today"
        case .speedDemon:  return "Be the first player to mark 5 tiles in a round"
        case .pacifist:    return "Win a round without using any attack power-ups"
        case .menace:      return "Use 3 attack power-ups in a single round"
        case .hoarder:     return "End any round with 10 or more tokens"
        case .cornerKing:  return "Mark all 4 corner tiles in a single round"
        case .onFire:      return "Win 2 rounds in the same day"
        case .spender:     return "Spend 10 or more tokens in a single round"
        case .firstBlood:  return "Be the first to spot anything in today's first round"
        }
    }

    var tokenReward: Int {
        switch type {
        case .winOne:      return 5
        case .speedDemon:  return 4
        case .pacifist:    return 6
        case .menace:      return 5
        case .hoarder:     return 4
        case .cornerKing:  return 5
        case .onFire:      return 8
        case .spender:     return 4
        case .firstBlood:  return 3
        }
    }

    func evaluate(event: ChallengeEvent, context: ChallengeEvaluationContext) -> Bool {
        switch type {
        case .winOne:
            guard case .roundWon(let by) = event else { return false }
            return by == context.playerName

        case .speedDemon:
            guard case .tileMarked(_, let by, _) = event, by == context.playerName else { return false }
            return context.marksThisRound == 5 &&
                   context.opponentMarkCounts.values.allSatisfy { $0 < 5 }

        case .pacifist:
            guard case .roundWon(let by) = event, by == context.playerName else { return false }
            return context.attacksUsedThisRound == 0

        case .menace:
            guard case .attackUsed(let by) = event, by == context.playerName else { return false }
            return context.attacksUsedThisRound >= 3

        case .hoarder:
            guard case .roundEnded(let ctx) = event else { return false }
            return ctx.tokensAtEndOfRound >= 10

        case .cornerKing:
            guard case .tileMarked(_, let by, _) = event, by == context.playerName else { return false }
            guard let board = context.localBoard else { return false }
            return [0, 4, 20, 24].allSatisfy { board.isMarked(at: $0) }

        case .onFire:
            guard case .roundWon(let by) = event, by == context.playerName else { return false }
            return context.winsToday >= 2

        case .spender:
            guard case .roundEnded(let ctx) = event else { return false }
            return ctx.tokensSpentThisRound >= 10

        case .firstBlood:
            guard case .tileMarked(_, let by, let isFirst) = event,
                  by == context.playerName, isFirst else { return false }
            return context.roundsPlayedToday == 0
        }
    }
}
