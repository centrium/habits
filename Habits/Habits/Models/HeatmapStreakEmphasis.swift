import CoreGraphics
import Foundation

enum HeatmapStreakEmphasis: Int {
    case none
    case streak
    case today

    var shadowOpacity: Double {
        switch self {
        case .none:
            return 0
        case .streak:
            return 0.14
        case .today:
            return 0.22
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .none:
            return 0
        case .streak:
            return 1.2
        case .today:
            return 1.8
        }
    }

    func adjustedIntensity(from base: Double) -> Double {
        guard base > 0 else { return 0 }

        switch self {
        case .none:
            return base
        case .streak:
            return min(max((base * 1.12) + 0.04, base), 1)
        case .today:
            return min(max((base * 1.20) + 0.08, base), 1)
        }
    }
}

enum HeatmapStreakCellsResolver {
    static func loggedDays(
        for habit: Habit,
        calendar: Calendar
    ) -> Set<Date> {
        Set(
            habit.logs.compactMap { log in
                guard log.frequencyContribution > 0 || log.numericValue > 0 else { return nil }
                return calendar.startOfDay(for: log.effectiveTimestamp)
            }
        )
    }

    static func currentStreakDays(
        for habit: Habit,
        endingAt endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        currentStreakDays(
            loggedDays: loggedDays(for: habit, calendar: calendar),
            endingAt: endDate,
            calendar: calendar
        )
    }

    static func currentStreakDays(
        loggedDays: Set<Date>,
        endingAt endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        var streakDays: [Date] = []
        let today = calendar.startOfDay(for: endDate)
        guard loggedDays.contains(today) else { return [] }

        var cursor = today
        while loggedDays.contains(cursor) {
            streakDays.append(cursor)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: previous)
        }

        return streakDays
    }

    static func emphasisByDay(
        streakDays: [Date],
        endingAt endDate: Date,
        calendar: Calendar
    ) -> [Date: HeatmapStreakEmphasis] {
        let today = calendar.startOfDay(for: endDate)
        return streakDays.reduce(into: [Date: HeatmapStreakEmphasis]()) { result, day in
            let normalized = calendar.startOfDay(for: day)
            result[normalized] = normalized == today ? .today : .streak
        }
    }
}
