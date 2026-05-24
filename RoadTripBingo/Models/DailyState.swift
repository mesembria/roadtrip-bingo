import Foundation

struct DailyState: Codable {
    var date: String                    // ISO "yyyy-MM-dd"
    var challengeTypes: [DailyChallengeType]
    var completedIDs: Set<String>       // DailyChallengeType.rawValue strings
    var winsToday: Int
    var roundsPlayedToday: Int

    static let userDefaultsKey = "dailyState"

    static func load() -> DailyState {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let state = try? JSONDecoder().decode(DailyState.self, from: data)
        else { return DailyState.fresh() }
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: DailyState.userDefaultsKey)
        }
    }

    static func roll() -> [DailyChallengeType] {
        Array(DailyChallengeType.allCases.shuffled().prefix(3))
    }

    static func fresh() -> DailyState {
        DailyState(date: Self.today(), challengeTypes: [], completedIDs: [], winsToday: 0, roundsPlayedToday: 0)
    }

    static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
