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

        let achievement = foundation.achievement

        let progressText: String = {
            if let target = achievement.target {
                return "\(habit.formatProgressValue(achievement.progressClamped)) / \(habit.formatProgressValue(target))"
            }
            return habit.formatProgressValue(achievement.progress)
        }()

        let statusText: String = {
            guard achievement.target != nil else { return "In progress" }
            return achievement.isComplete ? "Goal achieved" : "In progress"
        }()

        let overflowText: String? = {
            guard achievement.surplus > 0 else { return nil }
            if habit.goalType == .frequency {
                return "+\(Int(achievement.surplus.rounded())) extra"
            }
            return "+\(habit.formatProgressValue(achievement.surplus)) extra"
        }()

        let trendPoints: [HabitInsightsTrendPoint] = foundation.trend.months.map { month in
            HabitInsightsTrendPoint(
                periodStart: month.monthStart,
                label: month.label,
                value: trendValue(for: month, mode: foundation.mode)
            )
        }

        let trendUsesCompletionRatios = shouldUseCompletionRatios(mode: foundation.mode)

        let trendTargetLine: Double? = trendUsesCompletionRatios
            ? 1
            : foundation.trend.months.last?.target

        let trendUnitText: String? = {
            guard habit.goalType == .cumulative, !trendUsesCompletionRatios else { return nil }
            return habit.trimmedUnit
        }()

        var cards: [HabitInsightsCard] = []

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

        cards.append(
            .momentum(
                HabitInsightsMomentumBlock(
                    currentStreakText: "Current streak: \(streakSnapshot.current)",
                    longestStreakText: "Longest streak: \(streakSnapshot.longest)",
                    paceText: behaviour.momentumMessage
                )
            )
        )

        cards.append(
            .consistency(
                HabitInsightsConsistencyBlock(
                    scoreText: "\(Int(((metrics.consistencyScore ?? 0) * 100).rounded()))%",
                    averageText: "You log this habit \((metrics.averageDaysPerWeek ?? 0).formatted(.number.precision(.fractionLength(1)))) days per week."
                )
            )
        )

        cards.append(
            .trend(
                HabitInsightsTrendBlock(
                    heading: "Last 6 months",
                    points: trendPoints,
                    targetLine: trendTargetLine,
                    unitText: trendUnitText,
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

        _ = generatedInsights

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
}
