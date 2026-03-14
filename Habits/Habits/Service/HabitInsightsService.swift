import Foundation

struct HabitInsightsMetricsSnapshot: Codable, Equatable {
    let consistency: Int
    let bestMonth: String
    let mostMissedDay: String
    let averageStreak: Int
}

struct HabitInsightsService {
    private var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(
        for habit: Habit,
        logs: [HabitLog]? = nil,
        now: Date = .now
    ) -> HabitInsightsMetricsSnapshot {
        let today = calendar.startOfDay(for: now)
        let trackingStart = normalizedTrackingStart(createdAt: habit.createdAt, today: today)
        let allCompletionDays = normalizedCompletionDays(
            from: logs ?? habit.logs,
            today: today
        )
        let completionDaysWithinLifetime = normalizedCompletionDays(
            from: logs ?? habit.logs,
            trackingStart: trackingStart,
            today: today
        )
        let streaks = streakLengths(from: allCompletionDays)

        return HabitInsightsMetricsSnapshot(
            consistency: consistencyPercentage(
                completionDays: completionDaysWithinLifetime,
                trackingStart: trackingStart,
                today: today
            ),
            bestMonth: bestMonthName(completionDays: allCompletionDays, today: today),
            mostMissedDay: mostMissedWeekdayName(
                completionDays: completionDaysWithinLifetime,
                trackingStart: trackingStart,
                today: today
            ),
            averageStreak: averageStreakLength(streaks: streaks)
        )
    }

    func streakLengths(
        for habit: Habit,
        logs: [HabitLog]? = nil,
        now: Date = .now
    ) -> [Int] {
        let today = calendar.startOfDay(for: now)
        let completionDays = normalizedCompletionDays(
            from: logs ?? habit.logs,
            today: today
        )
        return streakLengths(from: completionDays)
    }
}

private extension HabitInsightsService {
    func normalizedTrackingStart(createdAt: Date, today: Date) -> Date {
        min(calendar.startOfDay(for: createdAt), today)
    }

    func normalizedCompletionDays(
        from logs: [HabitLog],
        today: Date
    ) -> Set<Date> {
        Set(
            logs.compactMap { log in
                guard log.frequencyContribution > 0 else { return nil }
                let day = calendar.startOfDay(for: log.effectiveTimestamp)
                guard day <= today else { return nil }
                return day
            }
        )
    }

    func normalizedCompletionDays(
        from logs: [HabitLog],
        trackingStart: Date,
        today: Date
    ) -> Set<Date> {
        Set(
            logs.compactMap { log in
                guard log.frequencyContribution > 0 else { return nil }
                let day = calendar.startOfDay(for: log.effectiveTimestamp)
                guard day >= trackingStart, day <= today else { return nil }
                return day
            }
        )
    }

    func consistencyPercentage(
        completionDays: Set<Date>,
        trackingStart: Date,
        today: Date
    ) -> Int {
        let elapsedDays = calendar.dateComponents([.day], from: trackingStart, to: today).day ?? 0
        let availableDays = max(1, elapsedDays + 1)
        let ratio = Double(completionDays.count) / Double(availableDays)
        let clamped = min(max(ratio, 0), 1)
        return Int((clamped * 100).rounded())
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

    func streakLengths(from completionDays: Set<Date>) -> [Int] {
        let sortedDays = completionDays.sorted()
        guard !sortedDays.isEmpty else { return [] }

        var streakLengths: [Int] = []
        var currentLength = 1

        for index in 1..<sortedDays.count {
            let previousDay = sortedDays[index - 1]
            let currentDay = sortedDays[index]

            if isNextCalendarDay(previousDay, currentDay) {
                currentLength += 1
            } else {
                streakLengths.append(currentLength)
                currentLength = 1
            }
        }

        streakLengths.append(currentLength)
        return streakLengths
    }

    func averageStreakLength(streaks: [Int]) -> Int {
        guard !streaks.isEmpty else { return 0 }
        let total = streaks.reduce(0, +)
        let average = Double(total) / Double(streaks.count)
        return Int(average.rounded())
    }

    func isNextCalendarDay(_ previousDay: Date, _ currentDay: Date) -> Bool {
        guard let expectedNextDay = calendar.date(byAdding: .day, value: 1, to: previousDay) else {
            return false
        }
        return calendar.isDate(expectedNextDay, inSameDayAs: currentDay)
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
