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
    private enum BehaviourInsightsGuard {
        static let minimumLogs = 20
        static let minimumWeeks = 3
        static let neutralMessage = "We’ll start showing behaviour insights once we have a little more data."
    }

    static func insights(
        for habit: Habit,
        logAnchorDate: Date? = nil,
        globalLogs: [HabitLog] = [],
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        greigModeEnabled: Bool = true,
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
            globalLogs: globalLogs,
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
        let streakState = StreakStateEngine(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).streakState(for: habit, referenceDate: now)

        let metrics = MetricsCalculator.calculate(
            foundation: foundation,
            streak: streakSnapshot
        )
        let analysedBehaviour = BehaviourAnalyzer.analyze(
            metrics: metrics,
            foundation: foundation
        )
        let behaviourInsightsReady = behaviourInsightsReadiness(
            for: habit,
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            now: now
        )
        let behaviour = behaviourInsightsReady
            ? analysedBehaviour
            : behaviourWithoutPatternSignals(analysedBehaviour)

        let coaching = coachingTemplate(
            habit: habit,
            metrics: metrics,
            streakState: streakState
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
        let goalPaceBlock = goalPaceBlock(
            for: habit,
            foundation: foundation,
            statusText: statusText,
            now: now
        )
        let identitySnapshot = HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calendar,
            now: now,
            windowDays: 7
        )
        let identityState = identitySnapshot.state
        let weeklyRhythmBlock = weeklyRhythmBlock(
            for: habit,
            calendar: calendar,
            now: now
        )
        let greigModeBlock = greigModeBlock(
            for: habit,
            foundation: foundation,
            identityState: identityState,
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            now: now
        )
        let overviewSnapshot = HabitInsightsService(calendar: calendar).snapshot(
            for: habit,
            now: now
        )
        let performanceSignals = PerformanceSignalsCalculator.calculate(
            for: habit,
            logs: InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar),
            identityState: identityState,
            calendar: calendar,
            now: now
        )

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

        cards.append(
            .overview(
                HabitInsightsOverviewBlock(
                    consistency: overviewSnapshot.consistency,
                    bestMonth: overviewSnapshot.bestMonth,
                    mostMissedDay: overviewSnapshot.mostMissedDay,
                    averageStreak: overviewSnapshot.averageStreak,
                    entriesThisWeek: behaviour.activitySummary?.entriesThisWeek ?? 0
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

        if let goalPaceBlock {
            cards.append(.goalPace(goalPaceBlock))
        }

        cards.append(
                .identityState(
                HabitInsightsIdentityStateBlock(
                    state: identityState,
                    line: CadenceLanguage.insightLine(for: identityState)
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
                    insightText: trendInsightText(
                        points: trendPoints,
                        isOpenEnded: isOpenEnded,
                        referenceDate: now,
                        calendar: calendar
                    ),
                    insightSupportingText: trendInsightSupportingText(
                        points: trendPoints,
                        isOpenEnded: isOpenEnded,
                        referenceDate: now,
                        calendar: calendar
                    ),
                    isValueBased: trendUnitText != nil,
                    isCompletionRatioBars: trendUsesCompletionRatios
                )
            )
        )

        cards.append(
            .performanceSignals(
                HabitInsightsPerformanceSignalsBlock(
                    heading: "Signals",
                    signals: performanceSignals
                )
            )
        )

        if let weeklyRhythmBlock {
            cards.append(.weeklyRhythm(weeklyRhythmBlock))
        }

        if behaviourInsightsReady {
            if let behaviourInsights = behaviourInsightsBlock(
                habit: habit,
                isOpenEnded: isOpenEnded,
                from: behaviour,
                calendar: calendar,
                now: now
            ) {
                cards.append(
                    .behaviourInsights(behaviourInsights)
                )
            }
        } else {
            cards.append(
                .behaviourInsights(
                    HabitInsightsBehaviourBlock(
                        heading: "Behaviour Insights",
                        observations: [],
                        suggestion: BehaviourInsightsGuard.neutralMessage
                    )
                )
            )
        }

        if greigModeEnabled, let greigModeBlock {
            cards.append(.greigMode(greigModeBlock))
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
        streakState: StreakState
    ) -> CoachingTemplate {
        _ = habit

        if streakState.status == .atRisk, metrics.currentStreak >= 1 {
            return CoachingTemplate(
                id: .streakProtection,
                priority: 1,
                headline: "You've shown up \(metrics.currentStreak) days in a row",
                supportingText: "Ready to continue today",
                iconName: "sparkles",
                tone: .encouragement
            )
        }

        if streakState.status == .safe {
            return CoachingTemplate(
                id: .generalEncouragement,
                priority: 1,
                headline: "Nice - your streak is secure today",
                supportingText: "Strong rhythm - keep it going",
                iconName: "sparkles",
                tone: .encouragement
            )
        }

        return CoachingTemplate(
            id: .generalEncouragement,
            priority: 1,
            headline: "A fresh check-in starts the next streak",
            supportingText: "Start a new streak today",
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
                return "\(remaining) sessions will put you back into rhythm this \(habit.goalPeriod.unit)"
            }
            if let target = metrics.target {
                let remaining = max(target - metrics.progress, 0)
                let remainingText = habit.formatProgressValue(remaining)
                if let unit = habit.trimmedUnit {
                    return "\(remainingText) \(unit) remaining this \(habit.goalPeriod.unit)"
                }
                return "\(remainingText) remaining this \(habit.goalPeriod.unit)"
            }
            return "A small check-in this \(habit.goalPeriod.unit) can help you return to this routine"
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
        _ = cadence
        guard current > 0, longest > current else { return nil }
        let delta = longest - current
        guard delta <= 2 else { return nil }
        let support = delta == 1
            ? "One more log will beat your longest \(longest)-day streak"
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
        from behaviour: HabitBehaviourSnapshot,
        calendar: Calendar,
        now: Date
    ) -> CoachingTemplate? {
        if let strongest = behaviour.strongestWeekday, let weakest = behaviour.weakestWeekday {
            return CoachingTemplate(
                id: .behaviourInsight,
                priority: 5,
                headline: "You show up best on \(strongest)",
                supportingText: behaviourInsightSupportingText(
                    weakestWeekday: weakest,
                    calendar: calendar,
                    now: now
                ),
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

    private static func behaviourInsightSupportingText(
        weakestWeekday: String,
        calendar: Calendar,
        now: Date
    ) -> String {
        guard let weakestWeekdayNumber = weekdayNumber(for: weakestWeekday, calendar: calendar) else {
            return "A quick check-in later this week could strengthen your routine"
        }

        let todayWeekdayNumber = calendar.component(.weekday, from: now)
        if weakestWeekdayNumber == todayWeekdayNumber {
            return "Today is a great day for a quick check-in"
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowWeekdayNumber = calendar.component(.weekday, from: tomorrow)
        if weakestWeekdayNumber == tomorrowWeekdayNumber {
            return "Try a quick check-in tomorrow"
        }

        if isLaterThisWeek(
            targetWeekday: weakestWeekdayNumber,
            todayWeekday: todayWeekdayNumber,
            calendar: calendar
        ) {
            return "A quick check-in later this week could strengthen your routine"
        }

        return "A quick check-in early next week could strengthen your routine"
    }

    private static func weekdayNumber(
        for weekdayName: String,
        calendar: Calendar
    ) -> Int? {
        for (index, symbol) in calendar.weekdaySymbols.enumerated() where symbol.caseInsensitiveCompare(weekdayName) == .orderedSame {
            return index + 1
        }
        for (index, symbol) in calendar.standaloneWeekdaySymbols.enumerated() where symbol.caseInsensitiveCompare(weekdayName) == .orderedSame {
            return index + 1
        }

        return nil
    }

    private static func isLaterThisWeek(
        targetWeekday: Int,
        todayWeekday: Int,
        calendar: Calendar
    ) -> Bool {
        let orderedWeekdays = orderedWeekdayNumbers(firstWeekday: calendar.firstWeekday)
        guard
            let targetIndex = orderedWeekdays.firstIndex(of: targetWeekday),
            let todayIndex = orderedWeekdays.firstIndex(of: todayWeekday)
        else {
            return false
        }
        return targetIndex > todayIndex
    }

    private static func orderedWeekdayNumbers(firstWeekday: Int) -> [Int] {
        let normalizedFirst = max(1, min(7, firstWeekday))
        let tail = Array(normalizedFirst...7)
        let head = normalizedFirst > 1 ? Array(1..<(normalizedFirst)) : []
        return tail + head
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
                return "🎉 \(Int(totalValue.rounded()))\(unit) total"
            }
        }

        return nil
    }

    private static func openEndedActivityPrimaryText(
        _ summary: ActivitySummaryInsight?
    ) -> String {
        guard let summary else { return "Getting started this week" }
        if summary.entriesThisWeek > 0 {
            return BehaviourCopyFormatter.activityCount(
                summary.entriesThisWeek,
                timeframe: .weekly
            )
        }
        if summary.entriesThisMonth > 0 {
            return BehaviourCopyFormatter.activityCount(
                summary.entriesThisMonth,
                timeframe: .monthly
            )
        }
        return "Getting started this week"
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
        isOpenEnded: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> String? {
        guard let insightInput = trendInsightInput(
            points: points,
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            return nil
        }
        let current = insightInput.candidateValue
        let previous = insightInput.previousValue
        let epsilon = 0.0001
        let threshold = 0.02

        guard previous > epsilon else { return nil }

        let deltaRatio = (current - previous) / previous
        if deltaRatio > threshold {
            return "Your activity improved this month"
        }
        if deltaRatio < -threshold {
            return "Your activity dipped this month"
        }
        _ = isOpenEnded
        return "Your activity is steady this month"
    }

    private static func trendInsightSupportingText(
        points: [HabitInsightsTrendPoint],
        isOpenEnded: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> String? {
        guard let insightInput = trendInsightInput(
            points: points,
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            return nil
        }
        let current = insightInput.candidateValue
        let previous = insightInput.previousValue
        let epsilon = 0.0001
        let threshold = 0.02

        guard previous > epsilon else { return nil }

        let deltaRatio = (current - previous) / previous
        if deltaRatio > threshold {
            return isOpenEnded ? "You're building consistency" : "You're building consistency"
        }
        if deltaRatio < -threshold {
            return "A quick check-in could support your return to this routine"
        }
        return "Keep this steady rhythm going"
    }

    private struct TrendInsightInput {
        let candidateValue: Double
        let previousValue: Double
    }

    private static func trendInsightInput(
        points: [HabitInsightsTrendPoint],
        referenceDate: Date,
        calendar: Calendar
    ) -> TrendInsightInput? {
        guard points.count >= 2 else { return nil }
        let currentMonthStart = calendar.dateInterval(of: .month, for: referenceDate)?.start

        let candidateIndex: Int = {
            guard let currentMonthStart else { return points.count - 1 }
            let lastIndex = points.count - 1
            let lastPointMonth = points[lastIndex].periodStart
            let isLastPointCurrentMonth = calendar.isDate(
                lastPointMonth,
                equalTo: currentMonthStart,
                toGranularity: .month
            )
            if isLastPointCurrentMonth {
                return points.count - 2
            }
            return lastIndex
        }()

        guard candidateIndex >= 1 else { return nil }
        guard !points[..<candidateIndex].isEmpty else { return nil }

        return TrendInsightInput(
            candidateValue: points[candidateIndex].value,
            previousValue: points[candidateIndex - 1].value
        )
    }

    private static func goalPaceBlock(
        for habit: Habit,
        foundation: HabitInsightSnapshot,
        statusText: String,
        now: Date
    ) -> HabitInsightsGoalPaceBlock? {
        guard let target = foundation.achievement.target, target > 0 else {
            return nil
        }

        let periodStart = foundation.currentPeriodStart
        let periodEnd = foundation.currentPeriodEnd
        let periodLength = max(periodEnd.timeIntervalSince(periodStart), 1)
        let nowClamped = min(max(now, periodStart), periodEnd)
        let nowRatio = min(max(nowClamped.timeIntervalSince(periodStart) / periodLength, 0), 1)

        let expectedNow = target * nowRatio
        let expectedLine = [
            HabitInsightsChartPoint(x: 0, y: 0),
            HabitInsightsChartPoint(x: nowRatio, y: expectedNow),
            HabitInsightsChartPoint(x: 1, y: target)
        ]

        let logs = habit.logs
            .filter { $0.effectiveTimestamp >= periodStart && $0.effectiveTimestamp <= nowClamped }
            .sorted { $0.effectiveTimestamp < $1.effectiveTimestamp }

        var running: Double = 0
        var actualLine: [HabitInsightsChartPoint] = [HabitInsightsChartPoint(x: 0, y: 0)]
        for log in logs {
            let contribution = valueContribution(for: log, goalType: habit.goalType)
            running += contribution
            let x = min(max(log.effectiveTimestamp.timeIntervalSince(periodStart) / periodLength, 0), 1)
            actualLine.append(HabitInsightsChartPoint(x: x, y: running))
        }
        let actualNow = foundation.achievement.progress
        actualLine.append(HabitInsightsChartPoint(x: nowRatio, y: actualNow))

        let projectedTotal = foundation.pace?.projectedTotal ?? actualNow
        let projectionLine = [
            HabitInsightsChartPoint(x: nowRatio, y: actualNow),
            HabitInsightsChartPoint(x: 1, y: projectedTotal)
        ]

        return HabitInsightsGoalPaceBlock(
            heading: "Goal Pace",
            expectedLine: expectedLine,
            actualLine: deduplicatedLine(actualLine),
            projectionLine: projectionLine,
            targetValue: target,
            statusText: statusText,
            targetText: "Goal \(habit.formatProgressValue(target))"
        )
    }

    private static func weeklyRhythmBlock(
        for habit: Habit,
        calendar: Calendar,
        now: Date
    ) -> HabitInsightsWeeklyRhythmBlock? {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -83, to: today) ?? today
        let logs = habit.logs.filter {
            $0.frequencyContribution > 0 && $0.day >= windowStart && $0.day <= today
        }
        guard !logs.isEmpty else { return nil }

        let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
        let shortLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE")

        let rawLogsPerWeekday = logs.reduce(into: [Int: Int]()) { partialResult, log in
            let weekday = calendar.component(.weekday, from: log.effectiveTimestamp)
            partialResult[weekday, default: 0] += 1
        }

        let uniqueDaysPerWeekday = logs.reduce(into: [Int: Set<Date>]()) { partialResult, log in
            let dayStart = calendar.startOfDay(for: log.effectiveTimestamp)
            let weekday = calendar.component(.weekday, from: dayStart)
            partialResult[weekday, default: []].insert(dayStart)
        }

        let maxPossibleScore = max(1, weeksInRange(start: windowStart, end: today, calendar: calendar))
        let weekdayScores = weekdayOrder.map { weekday -> Double in
            let uniqueDays = uniqueDaysPerWeekday[weekday]?.count ?? 0
            return min(1.0, Double(uniqueDays) / Double(maxPossibleScore))
        }

        let smoothedScores = lightlySmoothedWeekdayScores(weekdayScores)

        #if DEBUG
        if ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1" {
            print("[WeeklyRhythm DEBUG]")
            for (index, weekday) in weekdayOrder.enumerated() {
                let uniqueDays = uniqueDaysPerWeekday[weekday]?.count ?? 0
                let logsCount = rawLogsPerWeekday[weekday, default: 0]
                print(
                    "\(shortLabels[index]): logs=\(logsCount), uniqueDays=\(uniqueDays), score=\(String(format: "%.4f", smoothedScores[index]))"
                )
            }
        }
        #endif

        let days = weekdayOrder.enumerated().map { index, weekday in
            let referenceDate = referenceDateForWeekday(weekday, calendar: calendar, anchor: now)
            let fullName = formatter.string(from: referenceDate)
            let uniqueDays = uniqueDaysPerWeekday[weekday]?.count ?? 0
            return HabitInsightsWeeklyRhythmDay(
                index: index,
                dayLabel: shortLabels[index],
                fullDayLabel: fullName,
                entries: uniqueDays,
                score: smoothedScores[index]
            )
        }

        return HabitInsightsWeeklyRhythmBlock(
            heading: "Weekly Rhythm",
            days: days,
            maxPossibleEntries: maxPossibleScore
        )
    }

    private static func weeksInRange(
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let elapsedDays = max(0, (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)
        return Int(ceil(Double(elapsedDays) / 7.0))
    }

    private static func lightlySmoothedWeekdayScores(_ rawScores: [Double]) -> [Double] {
        guard rawScores.count == 7 else { return rawScores }

        let smoothed = (0..<7).map { index -> Double in
            let current = rawScores[index]
            guard current > 0 else { return 0 }

            let previous = rawScores[(index + 6) % 7]
            let next = rawScores[(index + 1) % 7]
            return min(1.0, (current * 0.7) + (previous * 0.15) + (next * 0.15))
        }

        // Keep visual smoothing non-destructive for dominant-day ordering.
        return argmax(smoothed) == argmax(rawScores) ? smoothed : rawScores
    }

    private static func argmax(_ values: [Double]) -> Int {
        guard !values.isEmpty else { return 0 }
        var bestIndex = 0
        var bestValue = values[0]
        for index in 1..<values.count where values[index] > bestValue {
            bestValue = values[index]
            bestIndex = index
        }
        return bestIndex
    }

    private static func valueContribution(
        for log: HabitLog,
        goalType: GoalType
    ) -> Double {
        switch goalType {
        case .frequency:
            return Double(max(1, log.frequencyContribution))
        case .cumulative:
            return max(0, log.numericValue)
        }
    }

    private static func deduplicatedLine(
        _ points: [HabitInsightsChartPoint]
    ) -> [HabitInsightsChartPoint] {
        var result: [HabitInsightsChartPoint] = []
        for point in points {
            if let last = result.last, abs(last.x - point.x) < 0.0001, abs(last.y - point.y) < 0.0001 {
                continue
            }
            result.append(point)
        }
        return result
    }

    private static func referenceDateForWeekday(
        _ weekday: Int,
        calendar: Calendar,
        anchor: Date
    ) -> Date {
        let anchorWeekday = calendar.component(.weekday, from: anchor)
        let delta = (weekday - anchorWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: delta, to: anchor) ?? anchor
    }

    private static func greigModeBlock(
        for habit: Habit,
        foundation: HabitInsightSnapshot,
        identityState: HabitIdentityState,
        calendar: Calendar,
        weekStartPreference _: WeekStartPreference,
        now: Date
    ) -> HabitInsightsGreigModeBlock? {
        let goal: GreigInsightGoal = {
            switch foundation.mode {
            case .openEnded:
                return GreigInsightGoal(kind: .open, period: habit.goalPeriod)
            case .frequency(let target, _):
                return GreigInsightGoal(kind: .frequency(target: target), period: habit.goalPeriod)
            case .cumulative(let target, _):
                return GreigInsightGoal(kind: .cumulative(target: target), period: habit.goalPeriod)
            }
        }()

        let progress = GreigInsightProgress(
            currentTotal: foundation.achievement.progress,
            periodStart: foundation.currentPeriodStart,
            periodEnd: foundation.currentPeriodEnd,
            now: now,
            logs: habit.logs,
            unit: habit.trimmedUnit ?? "",
            formatValue: { value in habit.formatProgressValue(value) }
        )

        let service = GreigInsightService(calendar: calendar)
        guard let insight = service.generateInsight(
            for: goal,
            progress: progress,
            identityState: identityState
        ) else {
            return nil
        }

        let supportText = insight.body ?? "Keep logging to build a clearer projection."

        return HabitInsightsGreigModeBlock(
            heading: "Greig Mode",
            headline: insight.title,
            supportText: supportText,
            iconName: "brain",
            confidence: insight.confidence,
            status: insight.status
        )
    }

    private static func behaviourInsightsBlock(
        habit: Habit,
        isOpenEnded: Bool,
        from behaviour: HabitBehaviourSnapshot,
        calendar: Calendar,
        now: Date
    ) -> HabitInsightsBehaviourBlock? {
        var observations: [String] = []
        if let strongest = behaviour.strongestWeekday, let window = behaviour.commonLogWindow {
            observations.append("You tend to log most often on \(pluralizedWeekday(strongest)) \(windowPlural(window)).")
        } else if let strongest = behaviour.strongestWeekday {
            observations.append("You show up best on \(pluralizedWeekday(strongest)).")
        } else if let window = behaviour.commonLogWindow {
            observations.append("\(window) is your most consistent logging window.")
        }

        if observations.count < 2, let weakest = behaviour.weakestWeekday {
            observations.append("\(pluralizedWeekday(weakest)) tend to be quieter for you.")
        }

        if observations.count < 2, let summary = secondaryBehaviourObservation(from: behaviour) {
            observations.append(summary)
        }

        let suggestion = behaviourSuggestion(
            habit: habit,
            isOpenEnded: isOpenEnded,
            weakestWeekday: behaviour.weakestWeekday,
            commonLogWindow: behaviour.commonLogWindow,
            calendar: calendar,
            now: now
        )

        let trimmedObservations = Array(observations.prefix(2))
        if trimmedObservations.isEmpty {
            return nil
        }

        return HabitInsightsBehaviourBlock(
            heading: "Behaviour Insights",
            observations: trimmedObservations,
            suggestion: suggestion
        )
    }

    private static func behaviourSuggestion(
        habit: Habit,
        isOpenEnded: Bool,
        weakestWeekday: String?,
        commonLogWindow: String?,
        calendar: Calendar,
        now: Date
    ) -> String {
        let timeframe: BehaviourSuggestionTimeframe
        if let weakestWeekday {
            timeframe = suggestionTimeframe(
                weakestWeekday: weakestWeekday,
                calendar: calendar,
                now: now
            )
        } else {
            timeframe = .tomorrow
        }

        let when = naturalTimePhrase(
            timeframe: timeframe,
            window: commonLogWindow
        )

        if isOpenEnded || !habit.hasGoal {
            return "A quick entry \(when) would keep this routine steady."
        }

        if habit.goalType == .cumulative, CurrencyDetection.detect(unit: habit.trimmedUnit).isCurrency {
            return "A quick check-in \(when) would move you closer to your savings goal."
        }

        return "Logging \(when) would move you closer to your \(habit.goalPeriod.unit) goal."
    }

    private enum BehaviourSuggestionTimeframe {
        case today
        case tomorrow
        case laterThisWeek
        case earlyNextWeek
    }

    private static func suggestionTimeframe(
        weakestWeekday: String,
        calendar: Calendar,
        now: Date
    ) -> BehaviourSuggestionTimeframe {
        guard let weakestWeekdayNumber = weekdayNumber(for: weakestWeekday, calendar: calendar) else {
            return .laterThisWeek
        }

        let todayWeekdayNumber = calendar.component(.weekday, from: now)
        if weakestWeekdayNumber == todayWeekdayNumber {
            return .today
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowWeekdayNumber = calendar.component(.weekday, from: tomorrow)
        if weakestWeekdayNumber == tomorrowWeekdayNumber {
            return .tomorrow
        }

        if isLaterThisWeek(
            targetWeekday: weakestWeekdayNumber,
            todayWeekday: todayWeekdayNumber,
            calendar: calendar
        ) {
            return .laterThisWeek
        }

        return .earlyNextWeek
    }

    private static func naturalTimePhrase(
        timeframe: BehaviourSuggestionTimeframe,
        window: String?
    ) -> String {
        let loweredWindow = window?.lowercased()
        switch timeframe {
        case .today:
            if loweredWindow == "night" || loweredWindow == "evening" {
                return "tonight"
            }
            if loweredWindow == "morning" {
                return "this morning"
            }
            if loweredWindow == "afternoon" {
                return "this afternoon"
            }
            return "today"
        case .tomorrow:
            if loweredWindow == "night" || loweredWindow == "evening" {
                return "tomorrow evening"
            }
            if loweredWindow == "morning" {
                return "tomorrow morning"
            }
            if loweredWindow == "afternoon" {
                return "tomorrow afternoon"
            }
            return "tomorrow"
        case .laterThisWeek:
            return "later this week"
        case .earlyNextWeek:
            return "early next week"
        }
    }

    private static func secondaryBehaviourObservation(
        from behaviour: HabitBehaviourSnapshot
    ) -> String? {
        guard let activity = behaviour.activitySummary else { return nil }
        if activity.entriesThisWeek > 0 {
            return BehaviourCopyFormatter.activityCount(
                activity.entriesThisWeek,
                timeframe: .weekly
            )
        }
        if activity.entriesThisMonth > 0 {
            return BehaviourCopyFormatter.activityCount(
                activity.entriesThisMonth,
                timeframe: .monthly
            )
        }
        return nil
    }

    private static func windowPlural(_ window: String) -> String {
        switch window.lowercased() {
        case "night":
            return "nights"
        case "evening":
            return "evenings"
        case "morning":
            return "mornings"
        case "afternoon":
            return "afternoons"
        default:
            return "\(window.lowercased())s"
        }
    }

    private static func pluralizedWeekday(_ weekday: String) -> String {
        weekday.hasSuffix("s") ? weekday : "\(weekday)s"
    }

    private static func behaviourWithoutPatternSignals(
        _ behaviour: HabitBehaviourSnapshot
    ) -> HabitBehaviourSnapshot {
        HabitBehaviourSnapshot(
            paceStatus: behaviour.paceStatus,
            projectedTotal: behaviour.projectedTotal,
            strongestWeekday: nil,
            weakestWeekday: nil,
            commonLogWindow: nil,
            activitySummary: behaviour.activitySummary,
            cadenceMessage: behaviour.cadenceMessage,
            patternItems: [],
            retentionItems: []
        )
    }

    private static func behaviourInsightsReadiness(
        for habit: Habit,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference,
        now: Date
    ) -> Bool {
        let today = calendar.startOfDay(for: now)
        let qualifyingLogs = habit.logs.filter {
            $0.frequencyContribution > 0 && $0.day <= today
        }

        let weekStarts = Set(
            qualifyingLogs.map { log in
                WeekBoundaryCalculator.weekInterval(
                    containing: log.day,
                    calendar: calendar,
                    weekStart: weekStartPreference
                ).start
            }
        )

        return qualifyingLogs.count >= BehaviourInsightsGuard.minimumLogs
            && weekStarts.count >= BehaviourInsightsGuard.minimumWeeks
    }
}
