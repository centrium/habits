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

        let foundation = habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            now: now
        )

        let streakSnapshot = snapshot(
            for: habit,
            anchorDate: now,
            respectCreatedAtBoundary: true,
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            now: now
        ).streak

        let metrics = MetricsCalculator.calculate(
            foundation: foundation,
            streak: streakSnapshot
        )
        let behaviour = BehaviourAnalyzer.analyze(
            metrics: metrics,
            foundation: foundation
        )
        let generatedInsights = InsightGenerator.generate(
            metrics: metrics,
            behaviour: behaviour
        )

        let isOpenEnded = foundation.achievement.target == nil

        let progressText: String = {
            if let target = foundation.achievement.target {
                return "\(habit.formatProgressValue(foundation.achievement.progressClamped)) / \(habit.formatProgressValue(target))"
            }
            return habit.formatProgressValue(foundation.achievement.progress)
        }()

        let statusText: String = {
            guard foundation.achievement.target != nil else { return "In progress" }
            guard foundation.achievement.isComplete else { return "In progress" }
            if now < foundation.currentPeriodEnd {
                return "🎉 You hit your goal early this \(habit.goalPeriod.unit)"
            }
            return "🎉 Goal achieved"
        }()

        let overflowText: String? = {
            guard foundation.achievement.surplus > 0 else { return nil }
            if habit.goalType == .frequency {
                return "+\(Int(foundation.achievement.surplus.rounded())) extra"
            }
            return "+\(habit.formatProgressValue(foundation.achievement.surplus)) extra"
        }()

        let trendPoints: [HabitInsightsTrendPoint] = foundation.trend.months.map { month in
            HabitInsightsTrendPoint(
                periodStart: month.monthStart,
                label: month.label,
                value: trendValue(for: month, mode: foundation.mode)
            )
        }

        let trendUsesCompletionRatios = shouldUseCompletionRatios(mode: foundation.mode)
        let trendTargetLine: Double? = trendUsesCompletionRatios ? 1 : foundation.trend.months.last?.target
        let trendUnitText: String? = {
            guard habit.goalType == .cumulative, !trendUsesCompletionRatios else { return nil }
            return habit.trimmedUnit
        }()

        var cards: [HabitInsightsCard] = []

        let headlineMessage = headlineInsight(
            habit: habit,
            metrics: metrics,
            behaviour: behaviour,
            generatedInsights: generatedInsights
        )
        cards.append(
            .motivation(
                MotivationCard(
                    message: headlineMessage,
                    tone: headlineMessage.contains("🎉") ? .celebration : .encouragement
                )
            )
        )

        if isOpenEnded {
            let activityPrimary = openEndedActivityPrimaryText(behaviour.activitySummary)
            let projection = "Average \(behaviour.activitySummary?.averageEntriesPerWeek.formatted(.number.precision(.fractionLength(1))) ?? "0.0") entries per week"
            cards.append(
                .intent(
                    HabitInsightsIntentBlock(
                        heading: "Activity",
                        primaryText: activityPrimary,
                        secondaryText: nil,
                        projectionText: projection
                    )
                )
            )
        } else {
            cards.append(
                .achievement(
                    HabitInsightsAchievementBlock(
                        progressText: progressText,
                        statusText: statusText,
                        overflowText: overflowText,
                        progressRatio: metrics.completionRatio ?? 0
                    )
                )
            )
        }

        cards.append(
            .momentum(
                HabitInsightsMomentumBlock(
                    currentStreakText: momentumStreakText(streakSnapshot.current, cadence: habit.goalPeriod),
                    longestStreakText: "Best: \(streakSnapshot.longest) \(pluralized(unit: habit.goalPeriod.streakUnit, count: streakSnapshot.longest))",
                    paceText: momentumSupportText(
                        current: streakSnapshot.current,
                        longest: streakSnapshot.longest,
                        cadence: habit.goalPeriod,
                        behaviour: behaviour,
                        headlineMessage: headlineMessage
                    )
                )
            )
        )

        if shouldShowConsistencyCard(for: habit, now: now, calendar: calendar) {
            cards.append(
                .consistency(
                    HabitInsightsConsistencyBlock(
                        scoreText: consistencyRhythmText(metrics.averageDaysPerWeek ?? 0),
                        averageText: nil
                    )
                )
            )
        }

        cards.append(
            .trend(
                HabitInsightsTrendBlock(
                    heading: "Last 6 months",
                    points: trendPoints,
                    targetLine: trendTargetLine,
                    unitText: trendUnitText,
                    insightText: trendInsightText(points: trendPoints, isOpenEnded: isOpenEnded),
                    isValueBased: trendUnitText != nil,
                    isCompletionRatioBars: trendUsesCompletionRatios
                )
            )
        )

        if !behaviour.patternItems.isEmpty {
            cards.append(
                .patterns(
                    HabitInsightsPatternBlock(
                        heading: "Patterns",
                        items: behaviour.patternItems
                    )
                )
            )
        }

        if !behaviour.retentionItems.isEmpty {
            cards.append(
                .retention(
                    HabitInsightsRetentionBlock(
                        heading: "Retention Insights",
                        items: behaviour.retentionItems
                    )
                )
            )
        }

        return HabitInsightsViewModel(
            title: "Insights",
            cards: cards,
            notes: []
        )
    }

    private static func shouldUseCompletionRatios(
        mode: HabitInsightMode
    ) -> Bool {
        switch mode {
        case .openEnded:
            return false
        case .frequency, .cumulative:
            return true
        }
    }

    private static func trendValue(
        for month: TrendMonth,
        mode: HabitInsightMode
    ) -> Double {
        switch mode {
        case .openEnded:
            return month.total
        case .frequency, .cumulative:
            return month.completionRatio ?? 0
        }
    }

    private static func headlineInsight(
        habit: Habit,
        metrics: HabitMetricsSnapshot,
        behaviour: HabitBehaviourSnapshot,
        generatedInsights: [HabitInsight]
    ) -> String {
        if metrics.currentStreak > 0 {
            return "🔥 You're on a \(metrics.currentStreak) \(streakUnit(habit.goalPeriod, count: metrics.currentStreak)) streak"
        }

        if let target = metrics.target, metrics.progress >= target {
            return "🎉 Goal achieved"
        }

        if let target = metrics.target, habit.goalType == .frequency {
            let remaining = Int(max(target - metrics.progress, 0))
            if remaining == 1 {
                return "Just one more this \(habit.goalPeriod.unit) to hit your goal"
            }
        }

        if let paceStatus = behaviour.paceStatus {
            switch paceStatus {
            case .completed:
                return "🎉 Goal achieved"
            case .likelyToHitTarget:
                return "🚀 You're ahead of pace this \(habit.goalPeriod.unit)"
            case .likelyShort:
                return "Keep going — you can still catch up this \(habit.goalPeriod.unit)"
            case .paceOnly:
                break
            }
        }

        if let activity = behaviour.activitySummary {
            return "📓 You've logged this habit \(activity.entriesThisWeek) \(activity.entriesThisWeek == 1 ? "time" : "times") this week"
        }

        if (metrics.averageDaysPerWeek ?? 0) > 0 {
            return "You're building a steady weekly rhythm"
        }

        return generatedInsights.first?.message ?? "You're building momentum."
    }

    private static func openEndedActivityPrimaryText(
        _ summary: ActivitySummaryInsight?
    ) -> String {
        guard let summary else { return "No entries this week yet" }
        if summary.entriesThisWeek > 0 {
            return "\(summary.entriesThisWeek) \(summary.entriesThisWeek == 1 ? "entry" : "entries") this week"
        }
        if summary.entriesThisMonth > 0 {
            return "\(summary.entriesThisMonth) \(summary.entriesThisMonth == 1 ? "entry" : "entries") this month"
        }
        return "No entries this week yet"
    }

    private static func momentumStreakText(
        _ streak: Int,
        cadence: GoalPeriod
    ) -> String {
        "\(streak) \(streakUnit(cadence, count: streak)) streak"
    }

    private static func momentumSupportText(
        current: Int,
        longest: Int,
        cadence: GoalPeriod,
        behaviour: HabitBehaviourSnapshot,
        headlineMessage: String
    ) -> String {
        if current > 0, current == longest {
            return "You're matching your longest streak"
        }

        if longest > current {
            let delta = longest - current
            let unit = streakUnit(cadence, count: delta)
            if delta == 1 {
                return "You're one \(unit) away from a new record"
            }
            return "\(delta) \(unit)s away from your record"
        }

        if behaviour.momentumMessage != headlineMessage {
            return behaviour.momentumMessage
        }

        return "Keep your routine going"
    }

    private static func streakUnit(
        _ cadence: GoalPeriod,
        count: Int
    ) -> String {
        _ = count
        switch cadence {
        case .daily:
            return "day"
        case .weekly:
            return "week"
        case .monthly:
            return "month"
        case .yearly:
            return "year"
        }
    }

    private static func pluralized(
        unit: String,
        count: Int
    ) -> String {
        count == 1 ? unit : "\(unit)s"
    }

    private static func consistencyRhythmText(_ averageDaysPerWeek: Double) -> String {
        if averageDaysPerWeek < 0.75 {
            return "Less than once per week"
        }
        if averageDaysPerWeek < 1.5 {
            return "About once per week"
        }
        if averageDaysPerWeek < 2.5 {
            return "About twice per week"
        }
        return "\(averageDaysPerWeek.formatted(.number.precision(.fractionLength(1)))) days per week"
    }

    private static func shouldShowConsistencyCard(
        for habit: Habit,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let daysActive = (calendar.dateComponents([.day], from: calendar.startOfDay(for: habit.createdAt), to: calendar.startOfDay(for: now)).day ?? 0) + 1
        return daysActive >= 7
    }

    private static func trendInsightText(
        points: [HabitInsightsTrendPoint],
        isOpenEnded: Bool
    ) -> String? {
        guard points.count >= 2 else { return nil }
        let last = points[points.count - 1].value
        let previous = points[points.count - 2].value
        let previousMax = points.dropLast().map(\.value).max() ?? 0
        let epsilon = 0.0001

        if last > previousMax + epsilon {
            return "This was your strongest month yet"
        }

        if last > previous + epsilon {
            return isOpenEnded ? "You're building a routine" : "You're improving month to month"
        }

        if abs(last - previous) <= epsilon {
            return "You've stayed consistent recently"
        }

        return "Activity dipped slightly this month"
    }
}
