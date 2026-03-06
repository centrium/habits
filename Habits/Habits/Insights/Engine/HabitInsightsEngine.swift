import Foundation

struct HabitInsightsEngine {

    static func insights(
        for habit: Habit,
        logAnchorDate: Date? = nil,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        timezone: TimeZone? = nil,
        now: Date = .now
    ) -> HabitInsightsViewModel {

        var calendar = calendar
        if let timezone {
            calendar.timeZone = timezone
        }

        let cadence = habit.goalPeriod
        let target = habit.hasGoal ? habit.effectiveTargetValue : nil

        // ---- 1. NORMALISE LOGS ----

        struct InsightLog {
            let date: Date
            let value: Double
        }

        let logs: [InsightLog] = habit.logs.map {
            InsightLog(
                date: $0.effectiveTimestamp,
                value: max(Double($0.frequencyContribution), max(1, $0.numericValue))
            )
        }

        // ---- 2. GROUP LOGS BY PERIOD ----

        var buckets: [Date: Double] = [:]

        for log in logs {

            let start = cadence.periodStart(
                for: log.date,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )

            buckets[start, default: 0] += log.value
        }

        // ---- 3. CURRENT PERIOD ----

        let periodStart = cadence.periodStart(
            for: now,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let periodEnd = cadence.nextPeriodStart(
            after: periodStart,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let progress = buckets[periodStart] ?? 0

        let clampedProgress = target != nil ? min(progress, target!) : progress
        let overflow = target != nil ? max(progress - target!, 0) : 0

        // ---- 4. PROGRESS SO FAR ----

        let progressSoFar = logs
            .filter { $0.date >= periodStart && $0.date < now }
            .reduce(0) { $0 + $1.value }

        // ---- 5. PACE PROJECTION ----

        let elapsed = now.timeIntervalSince(periodStart)
        let total = periodEnd.timeIntervalSince(periodStart)

        let projectedTotal: Double = {
            guard elapsed > 0 else { return progressSoFar }
            return (progressSoFar / elapsed) * total
        }()

        // ---- 6. STREAK ----

        let sortedPeriods = buckets.keys.sorted()

        var currentStreak = 0
        var longestStreak = 0
        var running = 0

        for period in sortedPeriods {

            let value = buckets[period] ?? 0
            let completed = target != nil ? value >= target! : value > 0

            if completed {
                running += 1
                longestStreak = max(longestStreak, running)
            } else {
                running = 0
            }

            if period == periodStart {
                currentStreak = running
            }
        }

        // ---- 7. CONSISTENCY ----

        let firstLogDate = logs.map { $0.date }.min() ?? now

        let totalDays = calendar.dateComponents([.day], from: firstLogDate, to: now).day ?? 1

        let activeDays = Set(
            logs.map { calendar.startOfDay(for: $0.date) }
        ).count

        let consistencyScore = Double(activeDays) / Double(max(totalDays, 1))
        let averagePerWeek = consistencyScore * 7

        // ---- 8. TREND ----

        let trendWindow = 6

        let trendPeriods = sortedPeriods.suffix(trendWindow)

        let trendPoints: [HabitInsightsTrendPoint] = trendPeriods.map {

            HabitInsightsTrendPoint(
                periodStart: $0,
                label: trendLabel(for: $0, cadence: cadence, calendar: calendar),
                value: buckets[$0] ?? 0
            )
        }

        // ---- 9. ACHIEVEMENT CARD ----

        let progressText: String

        if let target {
            progressText = "\(Int(clampedProgress)) / \(Int(target))"
        } else {
            progressText = "\(Int(progress))"
        }

        let statusText: String = {
            guard let target else { return "In progress" }
            return progress >= target ? "Goal achieved" : "In progress"
        }()

        let progressRatio = target != nil ? clampedProgress / target! : 0

        var cards: [HabitInsightsCard] = []

        cards.append(
            .achievement(
                HabitInsightsAchievementBlock(
                    progressText: progressText,
                    statusText: statusText,
                    overflowText: overflow > 0 ? "+\(Int(overflow)) extra" : nil,
                    progressRatio: progressRatio
                )
            )
        )

        // ---- 10. MOMENTUM ----

        cards.append(
            .momentum(
                HabitInsightsMomentumBlock(
                    currentStreakText: "Current streak: \(currentStreak)",
                    longestStreakText: "Longest streak: \(longestStreak)",
                    paceText: paceText(
                        projected: projectedTotal,
                        target: target,
                        cadence: cadence
                    )
                )
            )
        )

        // ---- 11. CONSISTENCY ----

        cards.append(
            .consistency(
                HabitInsightsConsistencyBlock(
                    scoreText: "\(Int((consistencyScore * 100).rounded()))%",
                    averageText: "You log this habit \(averagePerWeek.formatted(.number.precision(.fractionLength(1)))) days per week."
                )
            )
        )

        // ---- 12. TREND ----

        cards.append(
            .trend(
                HabitInsightsTrendBlock(
                    heading: "Last 6 months",
                    points: trendPoints,
                    targetLine: target,
                    unitText: nil,
                    isValueBased: false,
                    isCompletionRatioBars: false
                )
            )
        )

        return HabitInsightsViewModel(
            title: "Insights",
            cards: cards,
            notes: []
        )
    }

    // MARK: - Helpers

    private static func paceText(
        projected: Double,
        target: Double?,
        cadence: GoalPeriod
    ) -> String {

        guard let target else {
            return "At this pace you'll reach about \(Int(projected))."
        }

        if projected >= target {
            return "At this pace you'll exceed your goal."
        }

        let gap = Int(target - projected)

        return "You need \(gap) more this \(cadence.unit) to reach your goal."
    }

    private static func trendLabel(
        for date: Date,
        cadence: GoalPeriod,
        calendar: Calendar
    ) -> String {

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone

        switch cadence {
        case .daily:
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        case .weekly:
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        case .monthly:
            formatter.setLocalizedDateFormatFromTemplate("MMM")
        case .yearly:
            formatter.setLocalizedDateFormatFromTemplate("yyyy")
        }

        return formatter.string(from: date)
    }
}
