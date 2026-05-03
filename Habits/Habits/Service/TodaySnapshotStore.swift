import Foundation

struct StartupHabit: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let progress: Double
}

struct TodayStartupSnapshot: Codable, Equatable {
    let date: Date
    let habits: [StartupHabit]
    let greeting: String
}

protocol TodayStartupSnapshotStoring {
    func loadSyncLightweight() -> TodayStartupSnapshot?
    func saveLightweight(_ snapshot: TodayStartupSnapshot)
}

final class TodaySnapshotStore: TodayStartupSnapshotStoring {
    static let shared = TodaySnapshotStore()

    private enum Keys {
        static let snapshot = "today.startup.snapshot.v2"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSyncLightweight() -> TodayStartupSnapshot? {
        guard let data = defaults.data(forKey: Keys.snapshot) else {
            return nil
        }

        #if DEBUG
        print("SNAPSHOT SIZE: \(data.count) bytes")
        #endif

        return try? PropertyListDecoder().decode(TodayStartupSnapshot.self, from: data)
    }

    func saveLightweight(_ snapshot: TodayStartupSnapshot) {
        let cappedHabits = Array(snapshot.habits.prefix(20))
        let compact = TodayStartupSnapshot(
            date: snapshot.date,
            habits: cappedHabits,
            greeting: snapshot.greeting
        )
        guard let data = try? PropertyListEncoder().encode(compact) else { return }
        defaults.set(data, forKey: Keys.snapshot)
    }
}
