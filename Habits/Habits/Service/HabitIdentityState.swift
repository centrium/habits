import Foundation

enum HabitIdentityState: Equatable {
    case starting
    case building
    case holding
    case returning
}

struct HabitIdentityStateFormatter {
    static func shortLabel(_ state: HabitIdentityState) -> String {
        switch state {
        case .starting:
            return "Starting"
        case .building:
            return "Building"
        case .holding:
            return "Holding"
        case .returning:
            return "Returning"
        }
    }

    static func detailLine(_ state: HabitIdentityState) -> String {
        switch state {
        case .starting:
            return "This is where the habit begins to take shape"
        case .building:
            return "You’re building this identity"
        case .holding:
            return "This is becoming part of who you are"
        case .returning:
            return "Getting back to this keeps the identity intact"
        }
    }

    static func insightLine(_ state: HabitIdentityState) -> String {
        switch state {
        case .starting:
            return "This habit is just getting started"
        case .building:
            return "You’re building consistency with this habit"
        case .holding:
            return "This habit is holding strong"
        case .returning:
            return "You’re in the process of returning to this habit"
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
    static func state(
        from completionRate: Double?,
        hasRecentData: Bool
    ) -> HabitIdentityState {
        guard let rate = completionRate else { return .starting }

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
            state: state(from: completionRate, hasRecentData: hasRecentData),
            completionRate: completionRate,
            activeDays: activeDays,
            windowDays: normalizedWindow,
            hasRecentData: hasRecentData
        )
    }
}
