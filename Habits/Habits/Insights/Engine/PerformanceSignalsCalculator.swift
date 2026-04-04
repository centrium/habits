import Foundation

enum PerformanceSignalsCalculator {
    private static let identityStateLabels: [String] = [
        CadenceLanguage.shortLabel(for: .starting),
        CadenceLanguage.shortLabel(for: .building),
        CadenceLanguage.shortLabel(for: .holding),
        CadenceLanguage.shortLabel(for: .returning),
    ]
    private static let riskLabels = ["Low", "Moderate", "High", "Critical"]
    private static let strengthLabels = ["Weak", "Developing", "Strong", "Automatic"]

    static func calculate(
        for habit: Habit,
        calendar: Calendar,
        now: Date
    ) -> [HabitInsightsPerformanceSignal] {
        let logs = InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar)
        return calculate(for: habit, logs: logs, calendar: calendar, now: now)
    }

    static func identityState(
        for habit: Habit,
        calendar: Calendar,
        now: Date
    ) -> HabitIdentityState {
        let logs = InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar)
        return identityState(for: habit, logs: logs, calendar: calendar, now: now)
    }

    static func calculate(
        for habit: Habit,
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> [HabitInsightsPerformanceSignal] {
        let identityState = identityState(for: habit, logs: logs, calendar: calendar, now: now)
        let risk = habitRiskScore(for: habit, logs: logs, calendar: calendar, now: now)
        let strength = habitStrengthScore(for: habit, logs: logs, calendar: calendar, now: now)

        return [
            HabitInsightsPerformanceSignal(
                gauge: InsightGauge(
                    title: "Identity Signal",
                    value: identitySignalValue(for: identityState),
                    labels: identityStateLabels,
                    explanation: CadenceLanguage.insightLine(for: identityState)
                ),
                displayValue: CadenceLanguage.shortLabel(for: identityState)
            ),
            HabitInsightsPerformanceSignal(
                gauge: InsightGauge(
                    title: "Habit Risk",
                    value: clamp(risk, lower: 0, upper: 1),
                    labels: riskLabels,
                    explanation: riskExplanation(for: risk)
                ),
                displayValue: unsignedDisplayValue(risk)
            ),
            HabitInsightsPerformanceSignal(
                gauge: InsightGauge(
                    title: "Habit Strength",
                    value: strength,
                    labels: strengthLabels,
                    explanation: strengthExplanation(for: strength)
                ),
                displayValue: unsignedDisplayValue(strength)
            )
        ]
    }

    static func habitRiskScore(
        for habit: Habit,
        calendar: Calendar,
        now: Date
    ) -> Double {
        let logs = InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar)
        return habitRiskScore(for: habit, logs: logs, calendar: calendar, now: now)
    }

    static func habitRiskScore(
        for habit: Habit,
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> Double {
        let windows = signalWindows(calendar: calendar, now: now)
        let trackingStart = calendar.startOfDay(for: habit.createdAt)
        let activity = activitySummary(logs: logs, windowEnd: windows.windowEnd)
        let recentRate = completionRate(
            in: windows.recent,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )

        let daysSinceLastLog: Double = {
            if let lastLoggedDay = activity.lastLoggedDay {
                let dayCount = calendar.dateComponents([.day], from: lastLoggedDay, to: windows.todayStart).day ?? 0
                return Double(max(dayCount, 0))
            }

            let trackedDays = availableDays(
                in: DateInterval(start: trackingStart, end: windows.windowEnd),
                trackingStart: trackingStart,
                calendar: calendar
            )
            return Double(max(trackedDays - 1, 0))
        }()

        let rawRisk = ((daysSinceLastLog / 7) * 0.4) + ((1 - recentRate) * 0.6)
        return clamp(rawRisk, lower: 0, upper: 1)
    }

    static func habitStrengthScore(
        for habit: Habit,
        calendar: Calendar,
        now: Date
    ) -> Double {
        let logs = InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar)
        return habitStrengthScore(for: habit, logs: logs, calendar: calendar, now: now)
    }

    static func habitStrengthScore(
        for habit: Habit,
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> Double {
        let windows = signalWindows(calendar: calendar, now: now)
        let trackingStart = calendar.startOfDay(for: habit.createdAt)
        let activity = activitySummary(logs: logs, windowEnd: windows.windowEnd)
        let lifecycleInterval = DateInterval(start: trackingStart, end: windows.windowEnd)
        let last30Start = calendar.date(byAdding: .day, value: -30, to: windows.windowEnd) ?? trackingStart
        let last30Interval = DateInterval(start: last30Start, end: windows.windowEnd)

        let consistency = completionRate(
            in: lifecycleInterval,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )
        let averageStreak = averageStreakLength(from: activity.activeDays, calendar: calendar)
        let normalizedStreak = clamp(averageStreak / 14, lower: 0, upper: 1)
        let completionFrequency = completionRate(
            in: last30Interval,
            trackingStart: .distantPast,
            activeDays: activity.activeDays,
            calendar: calendar
        )

        let strength = (consistency * 0.5) + (normalizedStreak * 0.3) + (completionFrequency * 0.2)
        return clamp(strength, lower: 0, upper: 1)
    }

    static func riskExplanation(for score: Double) -> String {
        switch score {
        case ..<0.25:
            return "This habit is currently stable with very low drop-off risk."
        case ..<0.5:
            return "Your habit is holding steady but could benefit from continued consistency."
        case ..<0.75:
            return "Your activity has declined recently. Logging today would help stabilise the routine."
        default:
            return "This habit is at risk of fading. A small action today can support a return."
        }
    }

    static func strengthExplanation(for score: Double) -> String {
        switch score {
        case ..<0.25:
            return "This habit is still forming. Repeating the behaviour regularly will help establish the routine."
        case ..<0.5:
            return "Your habit is developing and gaining consistency. Continued repetition will strengthen it."
        case ..<0.75:
            return "This habit is becoming a stable part of your routine."
        default:
            return "This habit is highly consistent and approaching automatic behaviour."
        }
    }
}

private extension PerformanceSignalsCalculator {
    struct SignalWindows {
        let previous: DateInterval
        let recent: DateInterval
        let todayStart: Date
        let windowEnd: Date
    }

    struct ActivitySummary {
        let activeDays: Set<Date>
        let lastLoggedDay: Date?
    }

    static func signalWindows(calendar: Calendar, now: Date) -> SignalWindows {
        let todayStart = calendar.startOfDay(for: now)
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let recentStart = calendar.date(byAdding: .day, value: -7, to: windowEnd) ?? todayStart
        let previousStart = calendar.date(byAdding: .day, value: -21, to: recentStart) ?? recentStart

        return SignalWindows(
            previous: DateInterval(start: previousStart, end: recentStart),
            recent: DateInterval(start: recentStart, end: windowEnd),
            todayStart: todayStart,
            windowEnd: windowEnd
        )
    }

    static func activitySummary(
        logs: [InsightLog],
        windowEnd: Date
    ) -> ActivitySummary {
        var activeDays = Set<Date>()
        var lastLoggedDay: Date?

        for log in logs where log.dayStart < windowEnd {
            activeDays.insert(log.dayStart)
            if let currentLastLoggedDay = lastLoggedDay {
                lastLoggedDay = max(currentLastLoggedDay, log.dayStart)
            } else {
                lastLoggedDay = log.dayStart
            }
        }

        return ActivitySummary(activeDays: activeDays, lastLoggedDay: lastLoggedDay)
    }

    static func completionRate(
        in interval: DateInterval,
        trackingStart: Date,
        activeDays: Set<Date>,
        calendar: Calendar
    ) -> Double {
        let available = availableDays(in: interval, trackingStart: trackingStart, calendar: calendar)
        guard available > 0 else { return 0 }

        let completedDays = activeDays.reduce(into: 0) { count, day in
            if day >= interval.start && day < interval.end {
                count += 1
            }
        }

        return clamp(Double(completedDays) / Double(available), lower: 0, upper: 1)
    }

    static func availableDays(
        in interval: DateInterval,
        trackingStart: Date,
        calendar: Calendar
    ) -> Int {
        let effectiveStart = max(interval.start, trackingStart)
        guard effectiveStart < interval.end else { return 0 }
        return max(calendar.dateComponents([.day], from: effectiveStart, to: interval.end).day ?? 0, 0)
    }

    static func averageStreakLength(
        from activeDays: Set<Date>,
        calendar: Calendar
    ) -> Double {
        let streakLengths = StreakService(calendar: calendar).streakLengths(from: activeDays)
        guard !streakLengths.isEmpty else { return 0 }
        let total = streakLengths.reduce(0, +)
        return Double(total) / Double(streakLengths.count)
    }

    static func identityState(
        for habit: Habit,
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> HabitIdentityState {
        let windows = signalWindows(calendar: calendar, now: now)
        let trackingStart = calendar.startOfDay(for: habit.createdAt)
        let activity = activitySummary(logs: logs, windowEnd: windows.windowEnd)
        let recentInterval = windows.recent
        let recentCompletionRate = completionRate(
            in: recentInterval,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )
        let recentAvailableDays = availableDays(
            in: recentInterval,
            trackingStart: trackingStart,
            calendar: calendar
        )
        let hasRecentData = activity.activeDays.contains { day in
            day >= recentInterval.start && day < recentInterval.end
        }

        return HabitIdentityStateResolver.resolve(
            completionRate: recentAvailableDays > 0 ? recentCompletionRate : nil,
            hasRecentData: hasRecentData
        )
    }

    static func identitySignalValue(for state: HabitIdentityState) -> Double {
        switch state {
        case .starting:
            return 0
        case .building:
            return 0.33
        case .holding:
            return 0.66
        case .returning:
            return 1
        }
    }

    static func signedDisplayValue(_ value: Double) -> String {
        String(format: "%+.2f", value)
    }

    static func unsignedDisplayValue(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
