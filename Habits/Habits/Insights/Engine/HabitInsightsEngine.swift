import Foundation

private enum CoachingType {
    case streakProtection
    case nearCompletion
    case behindPace
    case streakMilestone
    case milestone
    case weeklyActivity
    case behaviourInsight
    case generalEncouragement
}

private struct CoachingTemplate {
    let id: CoachingType
    let priority: Int
    let headline: String
    let supportingText: String
    let iconName: String
    let tone: Tone
}

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

        let coaching = coachingTemplate(
            habit: habit,
            metrics: metrics,
            behaviour: behaviour,
            generatedInsights: generatedInsights,
            calendar: calendar,
            now: now
        )

        let isOpenEnded = foundation.achievement.target == nil

        let progressText: String = {
            if let target = foundation.achievement.target {
                return "\(habit.formatProgressValue(foundation.achievement.progressClamped)) / \(habit.formatProgressValue(target))"
            }
            return habit.formatProgressValue(foundation.achievement.progress)
        }()

        let statusText: String = achievementSupportingText(
            habit: habit,
            foundation: foundation,
            now: now
        )

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

        cards.append(
            .motivation(
                MotivationCard(
                    headline: coaching.headline,
                    supportingText: coaching.supportingText,
                    iconName: coaching.iconName,
                    tone: coaching.tone
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
                    currentStreakText: momentumPrimaryText(streakSnapshot.current, cadence: habit.goalPeriod),
                    longestStreakText: momentumBestText(streakSnapshot.longest, cadence: habit.goalPeriod),
                    paceText: momentumSupportText(
                        current: streakSnapshot.current,
                        longest: streakSnapshot.longest,
                        cadence: habit.goalPeriod,
                        behaviour: behaviour,
                        coaching: coaching
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
                    insightSupportingText: trendInsightSupportingText(points: trendPoints, isOpenEnded: isOpenEnded),
                    isValueBased: trendUnitText != nil,
                    isCompletionRatioBars: trendUsesCompletionRatios
                )
            )
        )

        let patternItems = patternCoachingItems(from: behaviour)
        if !patternItems.isEmpty {
            cards.append(
                .patterns(
                    HabitInsightsPatternBlock(
                        heading: "Patterns",
                        items: patternItems
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

    private static func coachingTemplate(
        habit: Habit,
        metrics: HabitMetricsSnapshot,
        behaviour: HabitBehaviourSnapshot,
        generatedInsights: [HabitInsight],
        calendar: Calendar,
        now: Date
    ) -> CoachingTemplate {
        if let streakProtection = streakProtectionMessage(habit: habit, metrics: metrics, calendar: calendar, now: now) {
            return CoachingTemplate(
                id: .streakProtection,
                priority: 1,
                headline: "Your streak is active",
                supportingText: streakProtection,
                iconName: "sparkles",
                tone: .encouragement
            )
        }

        if let streakGuard = streakGuardMessage(habit: habit, metrics: metrics, calendar: calendar, now: now) {
            return CoachingTemplate(
                id: .streakProtection,
                priority: 1,
                headline: "Streak guard update",
                supportingText: streakGuard,
                iconName: "shield",
                tone: .encouragement
            )
        }

        if let nearCompletion = nearCompletionTemplate(habit: habit, metrics: metrics) {
            return nearCompletion
        }

        if let behindPace = behindPaceTemplate(habit: habit, metrics: metrics, behaviour: behaviour) {
            return behindPace
        }

        if let streakMilestone = streakMilestoneTemplate(current: metrics.currentStreak, longest: metrics.longestStreak, cadence: habit.goalPeriod) {
            return streakMilestone
        }

        if let behaviourTemplate = behaviourInsightTemplate(from: behaviour) {
            return behaviourTemplate
        }

        if let milestone = milestoneMessage(habit: habit, metrics: metrics) {
            return CoachingTemplate(
                id: .milestone,
                priority: 5,
                headline: "Milestone reached",
                supportingText: milestone,
                iconName: "sparkles",
                tone: .celebration
            )
        }

        if let activity = behaviour.activitySummary {
            return CoachingTemplate(
                id: .weeklyActivity,
                priority: 6,
                headline: "You've logged this habit \(activity.entriesThisWeek) \(activity.entriesThisWeek == 1 ? "time" : "times") this week",
                supportingText: "Average \(activity.averageEntriesPerWeek.formatted(.number.precision(.fractionLength(1)))) entries per week",
                iconName: "sparkles",
                tone: .encouragement
            )
        }

        if let topInsight = generatedInsights.first {
            return CoachingTemplate(
                id: .generalEncouragement,
                priority: 7,
                headline: topInsight.message,
                supportingText: "Keep going with a small check-in today",
                iconName: "sparkles",
                tone: .encouragement
            )
        }

        return CoachingTemplate(
            id: .generalEncouragement,
            priority: 7,
            headline: "You're building momentum",
            supportingText: "A quick check-in today keeps your routine strong",
            iconName: "sparkles",
            tone: .encouragement
        )
    }

    private static func nearCompletionTemplate(
        habit: Habit,
        metrics: HabitMetricsSnapshot
    ) -> CoachingTemplate? {
        guard let target = metrics.target, target > 0 else { return nil }
        let ratio = metrics.progress / target
        guard ratio >= 0.8, ratio < 1 else { return nil }

        let remaining = max(target - metrics.progress, 0)
        let support: String = {
            if habit.goalType == .frequency {
                let sessions = max(Int(ceil(remaining)), 1)
                if sessions == 1 {
                    return "Just one more session this \(habit.goalPeriod.unit) will do it"
                }
                return "\(sessions) sessions this \(habit.goalPeriod.unit) will complete your goal"
            }
            let remainingText = habit.formatProgressValue(remaining)
            if let unit = habit.trimmedUnit {
                return "\(remainingText) \(unit) remaining this \(habit.goalPeriod.unit)"
            }
            return "\(remainingText) remaining this \(habit.goalPeriod.unit)"
        }()

        return CoachingTemplate(
            id: .nearCompletion,
            priority: 2,
            headline: "You're close to your goal",
            supportingText: support,
            iconName: "sparkles",
            tone: .encouragement
        )
    }

    private static func behindPaceTemplate(
        habit: Habit,
        metrics: HabitMetricsSnapshot,
        behaviour: HabitBehaviourSnapshot
    ) -> CoachingTemplate? {
        guard behaviour.paceStatus == .likelyShort else { return nil }

        let support: String = {
            if habit.goalType == .frequency, let target = metrics.target {
                let remaining = max(Int(ceil(target - metrics.progress)), 1)
                return "\(remaining) sessions will put you back on track this \(habit.goalPeriod.unit)"
            }
            if let target = metrics.target {
                let remaining = max(target - metrics.progress, 0)
                let remainingText = habit.formatProgressValue(remaining)
                if let unit = habit.trimmedUnit {
                    return "\(remainingText) \(unit) remaining this \(habit.goalPeriod.unit)"
                }
                return "\(remainingText) remaining this \(habit.goalPeriod.unit)"
            }
            return "A small check-in this \(habit.goalPeriod.unit) can rebuild momentum"
        }()

        return CoachingTemplate(
            id: .behindPace,
            priority: 3,
            headline: "You're slightly behind pace",
            supportingText: support,
            iconName: "sparkles",
            tone: .nudge
        )
    }

    private static func streakMilestoneTemplate(
        current: Int,
        longest: Int,
        cadence: GoalPeriod
    ) -> CoachingTemplate? {
        guard current > 0, longest > current else { return nil }
        let delta = longest - current
        guard delta <= 2 else { return nil }
        let support = delta == 1
            ? "One more log will beat your longest \(streakUnit(cadence, count: longest)) streak"
            : "\(delta) more logs will beat your longest streak"
        return CoachingTemplate(
            id: .streakMilestone,
            priority: 4,
            headline: "You're close to your record",
            supportingText: support,
            iconName: "sparkles",
            tone: .encouragement
        )
    }

    private static func behaviourInsightTemplate(
        from behaviour: HabitBehaviourSnapshot
    ) -> CoachingTemplate? {
        if let strongest = behaviour.strongestWeekday, let weakest = behaviour.weakestWeekday {
            return CoachingTemplate(
                id: .behaviourInsight,
                priority: 5,
                headline: "You show up best on \(strongest)",
                supportingText: "Plan a small check-in this \(weakest)",
                iconName: "sparkles",
                tone: .encouragement
            )
        }

        if let window = behaviour.commonLogWindow {
            return CoachingTemplate(
                id: .behaviourInsight,
                priority: 5,
                headline: "\(window) is your strongest logging window",
                supportingText: "A quick \(window.lowercased()) check-in can keep your routine steady",
                iconName: "sparkles",
                tone: .encouragement
            )
        }

        return nil
    }

    private static func achievementSupportingText(
        habit: Habit,
        foundation: HabitInsightSnapshot,
        now: Date
    ) -> String {
        guard let target = foundation.achievement.target else { return "In progress" }

        if foundation.achievement.isComplete {
            if now < foundation.currentPeriodEnd {
                return "🎉 You hit your goal early this \(habit.goalPeriod.unit)"
            }
            return "🎉 Goal achieved"
        }

        if habit.goalType == .frequency {
            let remaining = max(Int(ceil(target - foundation.achievement.progress)), 1)
            if remaining == 1 {
                return "One remaining this \(habit.goalPeriod.unit)"
            }
            return "\(remaining) remaining this \(habit.goalPeriod.unit)"
        }

        let remainingValue = max(target - foundation.achievement.progress, 0)
        if remainingValue > 0 {
            let remainingText = habit.formatProgressValue(remainingValue)
            if let unit = habit.trimmedUnit {
                return "\(remainingText) \(unit) remaining"
            }
            return "\(remainingText) remaining"
        }

        let percent = Int(((foundation.achievement.progress / target) * 100).rounded())
        return "\(percent)% complete"
    }

    private static func streakProtectionMessage(
        habit: Habit,
        metrics: HabitMetricsSnapshot,
        calendar: Calendar,
        now: Date
    ) -> String? {
        guard metrics.currentStreak > 0 else { return nil }
        let todayStart = calendar.startOfDay(for: now)
        let loggedToday = habit.logs.contains { calendar.startOfDay(for: $0.effectiveTimestamp) == todayStart }
        guard !loggedToday else { return nil }

        if let target = metrics.target, metrics.progress >= target {
            return nil
        }

        let unit = streakUnit(habit.goalPeriod, count: metrics.currentStreak)
        return "Log today to keep your \(metrics.currentStreak) \(unit) streak alive"
    }

    private static func streakGuardMessage(
        habit: Habit,
        metrics: HabitMetricsSnapshot,
        calendar: Calendar,
        now: Date
    ) -> String? {
        guard metrics.currentStreak > 3 else { return nil }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        let daySet = Set(habit.logs.map { calendar.startOfDay(for: $0.effectiveTimestamp) })
        let hasToday = daySet.contains(today)
        let hasYesterday = daySet.contains(yesterday)
        let hasDayBeforeYesterday = daySet.contains(dayBeforeYesterday)

        if hasToday && !hasYesterday && hasDayBeforeYesterday {
            return "Your streak was protected yesterday"
        }
        if hasToday && hasYesterday {
            return "Your streak is safe today"
        }
        return nil
    }

    private static func milestoneMessage(
        habit: Habit,
        metrics: HabitMetricsSnapshot
    ) -> String? {
        let totalLogs = habit.logs.count
        if [50, 100, 200].contains(totalLogs) {
            return "🎉 \(totalLogs) total logs"
        }

        if metrics.currentStreak > 0, metrics.currentStreak == metrics.longestStreak, metrics.currentStreak >= 3 {
            return "🎉 Your longest streak yet"
        }

        if habit.goalType == .cumulative, let unit = habit.trimmedUnit {
            let totalValue = habit.logs.reduce(0.0) { $0 + $1.numericValue }
            if totalValue >= 100, totalValue < 110 {
                return "🎉 \(Int(totalValue.rounded()))\(unit) completed"
            }
        }

        return nil
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

    private static func momentumPrimaryText(
        _ streak: Int,
        cadence: GoalPeriod
    ) -> String {
        guard streak > 0 else { return "No streak yet" }
        return "\(streak) \(streakUnit(cadence, count: streak)) streak"
    }

    private static func momentumBestText(
        _ longest: Int,
        cadence: GoalPeriod
    ) -> String {
        guard longest > 0 else { return "Start today to begin your streak" }
        return "Best: \(longest) \(pluralized(unit: cadence.streakUnit, count: longest))"
    }

    private static func momentumSupportText(
        current: Int,
        longest: Int,
        cadence: GoalPeriod,
        behaviour: HabitBehaviourSnapshot,
        coaching: CoachingTemplate
    ) -> String {
        if current == 0 {
            return "Your streak begins with the next log"
        }

        if current == longest, current > 0 {
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

        if behaviour.momentumMessage != coaching.headline {
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
        return "Your activity dipped slightly this month"
    }

    private static func trendInsightSupportingText(
        points: [HabitInsightsTrendPoint],
        isOpenEnded: Bool
    ) -> String? {
        guard points.count >= 2 else { return nil }
        let last = points[points.count - 1].value
        let previous = points[points.count - 2].value
        let previousMax = points.dropLast().map(\.value).max() ?? 0
        let epsilon = 0.0001

        if last > previousMax + epsilon {
            return "You're building consistency"
        }
        if last > previous + epsilon {
            return isOpenEnded ? "A quick check-in can keep this routine growing" : "You're gaining momentum each month"
        }
        if abs(last - previous) <= epsilon {
            return "Keep this steady rhythm going"
        }
        return "A quick check-in could rebuild momentum"
    }

    private static func patternCoachingItems(
        from behaviour: HabitBehaviourSnapshot
    ) -> [String] {
        var items: [String] = []
        if let strongest = behaviour.strongestWeekday {
            items.append("You show up best on \(strongest)")
        }
        if let window = behaviour.commonLogWindow {
            items.append("\(window) is your most consistent logging window")
        }
        if let weakest = behaviour.weakestWeekday {
            items.append("A quick \(weakest) check-in could strengthen your routine")
        }
        return Array(items.prefix(3))
    }
}
