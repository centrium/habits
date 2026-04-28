import Foundation

struct HabitConsistencyMetrics: Codable, Equatable {
    let adherenceRate: Double
    let daysCompleted: Int
    let daysAvailable: Int
    let window: Int

    var consistencyPercentage: Int {
        Int((min(max(adherenceRate, 0), 1) * 100).rounded())
    }
}

struct HabitInsightsMetricsSnapshot: Codable, Equatable {
    let consistency: Int
    let bestMonth: String
    let mostMissedDay: String
    let averageStreak: Int
}

struct HabitInsightsService {
    static let canonicalConsistencyWindowDays = 7

    private var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(
        for habit: Habit,
        logs: [HabitLog]? = nil,
        now: Date = .now
    ) -> HabitInsightsMetricsSnapshot {
        let resolvedLogs = logs ?? habit.logs
        let today = calendar.startOfDay(for: now)
        let trackingStart = normalizedTrackingStart(createdAt: habit.createdAt, today: today)
        let consistencyMetrics = consistencyMetrics(
            for: habit,
            logs: resolvedLogs,
            now: now
        )
        let allCompletionDays = normalizedCompletionDays(
            for: habit,
            logs: resolvedLogs,
            today: today
        )
        let completionDaysWithinLifetime = normalizedCompletionDays(
            for: habit,
            logs: resolvedLogs,
            trackingStart: trackingStart,
            today: today
        )
        let streaks = streakLengths(for: habit, logs: logs, now: now)

        return HabitInsightsMetricsSnapshot(
            consistency: consistencyMetrics.consistencyPercentage,
            bestMonth: bestMonthName(completionDays: allCompletionDays, today: today),
            mostMissedDay: mostMissedWeekdayName(
                completionDays: completionDaysWithinLifetime,
                trackingStart: trackingStart,
                today: today
            ),
            averageStreak: averageStreakLength(streaks: streaks)
        )
    }

    func consistencyMetrics(
        for habit: Habit,
        logs: [HabitLog]? = nil,
        now: Date = .now
    ) -> HabitConsistencyMetrics {
        let today = calendar.startOfDay(for: now)
        let window = Self.canonicalConsistencyWindowDays
        let windowStart = calendar.date(
            byAdding: .day,
            value: -(window - 1),
            to: today
        ) ?? today
        let trackingStart = normalizedTrackingStart(createdAt: habit.createdAt, today: today)
        let effectiveStart = max(windowStart, trackingStart)
        let daysAvailable = max(1, daySpan(start: effectiveStart, end: today))
        let completedDays = completedDayStarts(
            for: habit,
            logs: logs ?? habit.logs,
            start: effectiveStart,
            end: today
        )
        let adherenceRate = Double(completedDays.count) / Double(daysAvailable)

        return HabitConsistencyMetrics(
            adherenceRate: min(max(adherenceRate, 0), 1),
            daysCompleted: completedDays.count,
            daysAvailable: daysAvailable,
            window: window
        )
    }

    func streakLengths(
        for habit: Habit,
        logs: [HabitLog]? = nil,
        now: Date = .now
    ) -> [Int] {
        let streakService = StreakService(calendar: calendar)
        if let logs {
            let today = calendar.startOfDay(for: now)
            let completionDays = normalizedCompletionDays(
                for: habit,
                logs: logs,
                today: today
            )
            return streakService.streakLengths(from: completionDays)
        }

        return streakService.streakLengths(for: habit, through: now)
    }
}

private extension HabitInsightsService {
    func normalizedTrackingStart(createdAt: Date, today: Date) -> Date {
        min(calendar.startOfDay(for: createdAt), today)
    }

    func normalizedCompletionDays(
        for habit: Habit,
        logs: [HabitLog],
        today: Date
    ) -> Set<Date> {
        completedDayStarts(
            for: habit,
            logs: logs,
            start: .distantPast,
            end: today
        )
    }

    func normalizedCompletionDays(
        for habit: Habit,
        logs: [HabitLog],
        trackingStart: Date,
        today: Date
    ) -> Set<Date> {
        completedDayStarts(
            for: habit,
            logs: logs,
            start: trackingStart,
            end: today
        )
    }

    func completedDayStarts(
        for habit: Habit,
        logs: [HabitLog],
        start: Date,
        end: Date
    ) -> Set<Date> {
        let streakService = StreakService(calendar: calendar)
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        let candidateDays = Set(
            logs.compactMap { log -> Date? in
                let day = calendar.startOfDay(for: log.effectiveTimestamp)
                guard day >= normalizedStart, day <= normalizedEnd else { return nil }
                return day
            }
        )

        return Set(
            candidateDays.filter { day in
                streakService.isDayComplete(goal: habit, on: day)
            }
        )
    }

    func daySpan(start: Date, end: Date) -> Int {
        let elapsedDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
        return max(1, elapsedDays + 1)
    }

    func bestMonthName(
        completionDays: Set<Date>,
        today: Date
    ) -> String {
        guard !completionDays.isEmpty else {
            return monthName(for: today)
        }

        var monthCompletions: [Date: Int] = [:]
        for day in completionDays {
            let monthStart = calendar.dateInterval(of: .month, for: day)?.start ?? day
            monthCompletions[monthStart, default: 0] += 1
        }

        guard let best = monthCompletions.max(
            by: { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value < rhs.value
                }
                return lhs.key < rhs.key
            }
        ) else {
            return monthName(for: today)
        }

        return monthName(for: best.key)
    }

    func mostMissedWeekdayName(
        completionDays: Set<Date>,
        trackingStart: Date,
        today: Date
    ) -> String {
        guard !completionDays.isEmpty else {
            return weekdayName(for: today)
        }

        var weekdayTotals = Array(repeating: 0, count: 7)
        var cursor = trackingStart
        while cursor <= today {
            weekdayTotals[mondayFirstWeekdayIndex(for: cursor)] += 1
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        var weekdayCompletions = Array(repeating: 0, count: 7)
        for day in completionDays {
            weekdayCompletions[mondayFirstWeekdayIndex(for: day)] += 1
        }

        var lowestRate = Double.greatestFiniteMagnitude
        var mostMissedIndex = 0
        for index in 0..<7 {
            guard weekdayTotals[index] > 0 else { continue }
            let completionRate = Double(weekdayCompletions[index]) / Double(weekdayTotals[index])
            if completionRate < lowestRate {
                lowestRate = completionRate
                mostMissedIndex = index
            }
        }

        return weekdayName(forMondayFirstIndex: mostMissedIndex)
    }

    func averageStreakLength(streaks: [Int]) -> Int {
        guard !streaks.isEmpty else { return 0 }
        let total = streaks.reduce(0, +)
        let average = Double(total) / Double(streaks.count)
        return Int(average.rounded())
    }

    func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    func weekdayName(for date: Date) -> String {
        weekdayName(forMondayFirstIndex: mondayFirstWeekdayIndex(for: date))
    }

    func weekdayName(forMondayFirstIndex index: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone

        let symbols = formatter.weekdaySymbols ?? []
        guard symbols.count == 7 else { return "" }

        // DateFormatter weekdaySymbols are Sunday-first, convert from Monday-first index.
        let sundayFirstIndex = (index + 1) % 7
        return symbols[sundayFirstIndex]
    }

    func mondayFirstWeekdayIndex(for date: Date) -> Int {
        // Calendar weekday: Sunday = 1 ... Saturday = 7.
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7
    }
}
