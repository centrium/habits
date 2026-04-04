import Foundation

struct IdentityOutput: Codable {
    let title: String
    let line1: String?
    let line2: String?
}

enum HabitIdentityState: Equatable {
    case starting
    case building
    case holding
    case returning
}

struct CadenceLanguage {
    static func shortLabel(for state: HabitIdentityState) -> String {
        CadenceCopyCatalog.shortLabel(for: state.cadenceStateKey)
    }

    static func identityLine(for state: HabitIdentityState) -> String {
        CadenceCopyCatalog.identityLine(for: state.cadenceStateKey)
    }

    static func insightLine(for state: HabitIdentityState) -> String {
        CadenceCopyCatalog.insightLine(for: state.cadenceStateKey)
    }

    static func behaviourLine(
        completions: Int?,
        window: Int?
    ) -> String {
        guard let completions, let window else {
            return "This is where the habit begins"
        }

        return "You’ve shown up \(completions) of the last \(window) days"
    }

    static func identityOutput(
        for habit: Habit,
        date: Date,
        calendar: Calendar = .current
    ) -> IdentityOutput {
        let snapshot = HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calendar,
            now: date,
            windowDays: 7
        )
        let metrics = HabitIdentityMetrics.from(snapshot: snapshot)
        let identityNarrative = HabitIdentityEngine.build(habit: habit, metrics: metrics)

        let title: String = {
            if let identityNarrative {
                return identityNarrative.identityLine
            }
            return habit.name
        }()
        let line1 = behaviourLine(
            completions: snapshot.activeDays,
            window: snapshot.windowDays
        )
        let line2 = identityNarrative?.emotionalLine ?? "This is becoming part of who you are"

        return IdentityOutput(
            title: title,
            line1: line1,
            line2: line2
        )
    }
}

private extension HabitIdentityState {
    var cadenceStateKey: CadenceStateKey {
        switch self {
        case .starting:
            return .starting
        case .building:
            return .building
        case .holding:
            return .holding
        case .returning:
            return .returning
        }
    }
}

struct HabitIdentityStateSnapshot: Equatable {
    let state: HabitIdentityState
    let completionRate: Double?
    let activeDays: Int
    let windowDays: Int
    let hasRecentData: Bool
}

enum HabitIdentityStateResolver {
    static func resolve(
        completionRate: Double?,
        hasRecentData: Bool
    ) -> HabitIdentityState {
        guard let rate = completionRate else {
            return .starting
        }

        switch rate {
        case 0.7...:
            return .holding
        case 0.4..<0.7:
            return .building
        default:
            return hasRecentData ? .returning : .starting
        }
    }

    static func recentSnapshot(
        for habit: Habit,
        calendar: Calendar,
        now: Date = .now,
        windowDays: Int = 7
    ) -> HabitIdentityStateSnapshot {
        let normalizedWindow = max(1, windowDays)
        let today = calendar.startOfDay(for: now)
        let window = (0..<normalizedWindow).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let windowSet = Set(window.map { calendar.startOfDay(for: $0) })
        let activeDays = Set(
            habit.logs.compactMap { log -> Date? in
                guard log.frequencyContribution > 0 else { return nil }
                let day = calendar.startOfDay(for: log.effectiveTimestamp)
                guard windowSet.contains(day) else { return nil }
                return day
            }
        ).count
        let hasRecentData = activeDays > 0
        let completionRate = Double(activeDays) / Double(normalizedWindow)

        return HabitIdentityStateSnapshot(
            state: resolve(completionRate: completionRate, hasRecentData: hasRecentData),
            completionRate: completionRate,
            activeDays: activeDays,
            windowDays: normalizedWindow,
            hasRecentData: hasRecentData
        )
    }
}
