import Foundation

enum HabitRiskState: Equatable {
    case earlyStage
    case low
    case moderate
    case high
    case critical
}

enum PerformanceSignalsCalculator {
    private static let identityStateLabels = ["Start", "Build", "Steady", "Strong", "Slip", "Rebuild"]
    private static let riskLabels = ["Low", "Moderate", "High", "Critical"]
    private static let strengthLabels = ["Weak", "Developing", "Strong", "Automatic"]

    static func calculate(
        for habit: Habit,
        calendar: Calendar,
        now: Date
    ) -> [HabitInsightsPerformanceSignal] {
        let logs = InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar)
        return calculate(
            for: habit,
            logs: logs,
            identityState: identityState(for: habit, logs: logs, calendar: calendar, now: now),
            calendar: calendar,
            now: now
        )
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
        identityState _: HabitIdentityState,
        calendar: Calendar,
        now: Date
    ) -> [HabitInsightsPerformanceSignal] {
        let identity = identityAssessment(
            for: habit,
            logs: logs,
            calendar: calendar,
            now: now
        )
        debugValidateIdentityAlignment(identity)

        let risk = habitRiskAssessment(
            for: habit,
            logs: logs,
            identityState: identity.state,
            calendar: calendar,
            now: now
        )
        let strength = habitStrengthScore(for: habit, logs: logs, calendar: calendar, now: now)

        return [
            HabitInsightsPerformanceSignal(
                gauge: InsightGauge(
                    title: "Identity Signal",
                    value: identity.score,
                    labels: identityStateLabels,
                    explanation: identityBehaviourDescription(for: identity.state)
                ),
                displayValue: identityScaleLabel(for: identity.state)
            ),
            HabitInsightsPerformanceSignal(
                gauge: InsightGauge(
                    title: "Habit Risk",
                    value: clamp(risk.score, lower: 0, upper: 1),
                    labels: riskLabels,
                    explanation: risk.explanation
                ),
                displayValue: risk.displayValue
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
        riskExplanation(
            for: riskState(for: score, totalLogs: 3),
            showsDecline: false
        )
    }

    static func riskExplanation(
        for state: HabitRiskState,
        showsDecline: Bool
    ) -> String {
        switch state {
        case .earlyStage:
            return CadenceLanguage.riskEarlyStage()
        case .low:
            return "This habit is currently stable with very low drop-off risk."
        case .moderate:
            return "Your habit is holding steady but could benefit from continued consistency."
        case .high:
            if showsDecline {
                return "Consistency has dropped recently. Logging today would help stabilise the routine."
            }
            return "Recent consistency is uneven. Logging today would help stabilise the routine."
        case .critical:
            return "This habit is at risk of fading. A small action today can support a return."
        }
    }

    static func riskState(
        for score: Double,
        totalLogs: Int
    ) -> HabitRiskState {
        if totalLogs < 3 {
            return .earlyStage
        }

        switch score {
        case ..<0.25:
            return .low
        case ..<0.5:
            return .moderate
        case ..<0.75:
            return .high
        default:
            return .critical
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
    struct HabitRiskAssessment {
        let state: HabitRiskState
        let score: Double
        let explanation: String
        let displayValue: String
    }

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

    static func habitRiskAssessment(
        for habit: Habit,
        logs: [InsightLog],
        identityState: HabitIdentityState,
        calendar: Calendar,
        now: Date
    ) -> HabitRiskAssessment {
        let today = calendar.startOfDay(for: now)
        let pastOrTodayLogs = logs.filter { $0.dayStart <= today }
        let totalLogs = pastOrTodayLogs.count
        let score = habitRiskScore(
            for: habit,
            logs: logs,
            calendar: calendar,
            now: now
        )
        let state = riskState(for: score, totalLogs: totalLogs)
        let declineDetected = hasRecentDecline(
            for: habit,
            logs: pastOrTodayLogs,
            calendar: calendar,
            now: now
        ) && identityState != .gettingStarted && state != .earlyStage
        let explanation = riskExplanation(
            for: state,
            showsDecline: declineDetected
        )
        let displayValue: String = {
            if state == .earlyStage {
                return ""
            }
            return unsignedDisplayValue(score)
        }()

        return HabitRiskAssessment(
            state: state,
            score: score,
            explanation: explanation,
            displayValue: displayValue
        )
    }

    static func hasRecentDecline(
        for habit: Habit,
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        guard logs.count >= 6 else { return false }

        let windows = signalWindows(calendar: calendar, now: now)
        let trackingStart = calendar.startOfDay(for: habit.createdAt)
        let activity = activitySummary(logs: logs, windowEnd: windows.windowEnd)

        let previousRate = completionRate(
            in: windows.previous,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )
        let recentRate = completionRate(
            in: windows.recent,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )
        let previousDays = availableDays(
            in: windows.previous,
            trackingStart: trackingStart,
            calendar: calendar
        )
        let recentDays = availableDays(
            in: windows.recent,
            trackingStart: trackingStart,
            calendar: calendar
        )
        guard previousDays > 0, recentDays > 0 else { return false }

        return (previousRate - recentRate) >= 0.2 && previousRate >= 0.4
    }

    static func identityState(
        for habit: Habit,
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> HabitIdentityState {
        let baselineState = HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calendar,
            now: now,
            windowDays: 7
        ).state
        let assessment = identityAssessment(
            for: habit,
            logs: logs,
            calendar: calendar,
            now: now
        )
        let bandState = state(for: assessment.score, allowsDegradationBands: assessment.allowsDegradationBands)
        #if DEBUG
        if baselineState != bandState {
            print(
                "[IdentitySignal] baseline_state=\(baselineState) overridden_state=\(bandState) " +
                    "score=\(String(format: "%.3f", assessment.score))"
            )
        }
        #endif
        return bandState
    }

    static func identitySignalValue(for state: HabitIdentityState) -> Double {
        switch state {
        case .gettingStarted:
            return 0.1
        case .building:
            return 0.3
        case .steady:
            return 0.5
        case .strong:
            return 0.7
        case .slipping:
            return 0.85
        case .rebuilding:
            return 0.95
        }
    }

    static func identityScaleLabel(for state: HabitIdentityState) -> String {
        switch state {
        case .gettingStarted:
            return "Start"
        case .building:
            return "Build"
        case .steady:
            return "Steady"
        case .strong:
            return "Strong"
        case .slipping:
            return "Slip"
        case .rebuilding:
            return "Rebuild"
        }
    }

    static func identityBehaviourDescription(for state: HabitIdentityState) -> String {
        switch state {
        case .gettingStarted:
            return "You are beginning to establish this habit."
        case .building:
            return "This habit is taking shape."
        case .steady:
            return "You have built a reliable pattern."
        case .strong:
            return "You are showing up consistently."
        case .slipping:
            return "Recent consistency has softened."
        case .rebuilding:
            return "Recent follow-through has been interrupted."
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

    struct IdentityAssessment {
        let score: Double
        let state: HabitIdentityState
        let allowsDegradationBands: Bool
        let longTermConsistency: Double
        let recentCompletion: Double
    }

    static func identityAssessment(
        for habit: Habit,
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> IdentityAssessment {
        let windows = signalWindows(calendar: calendar, now: now)
        let trackingStart = calendar.startOfDay(for: habit.createdAt)
        let activity = activitySummary(logs: logs, windowEnd: windows.windowEnd)
        if activity.activeDays.count <= 2 {
            return IdentityAssessment(
                score: 0.1,
                state: .gettingStarted,
                allowsDegradationBands: false,
                longTermConsistency: 0,
                recentCompletion: 0
            )
        }
        let lifecycleInterval = DateInterval(start: trackingStart, end: windows.windowEnd)
        let longTermConsistency = completionRate(
            in: lifecycleInterval,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )
        let trendStability = trendStabilityScore(
            trackingStart: trackingStart,
            windowEnd: windows.windowEnd,
            activeDays: activity.activeDays,
            calendar: calendar
        )
        let recentCompletion = completionRate(
            in: windows.recent,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )
        let previousCompletion = completionRate(
            in: windows.previous,
            trackingStart: trackingStart,
            activeDays: activity.activeDays,
            calendar: calendar
        )

        let weightedScore = clamp(
            (longTermConsistency * 0.7) + (trendStability * 0.2) + (recentCompletion * 0.1),
            lower: 0,
            upper: 1
        )

        let streakAverage = averageStreakLength(from: activity.activeDays, calendar: calendar)
        let downwardTrendConfirmed = previousCompletion - recentCompletion >= 0.15
        let recentBelowBaseline = recentCompletion <= max(0, longTermConsistency - 0.2)
        let slipAllowed = longTermConsistency >= 0.5 && recentBelowBaseline && downwardTrendConfirmed
        let continuityLost = streakAverage < 1.6 || trendStability < 0.45
        let rebuildAllowed = longTermConsistency < 0.4 && recentCompletion <= 0.2 && continuityLost
        let allowsDegradationBands = slipAllowed || rebuildAllowed

        let score: Double = {
            if rebuildAllowed {
                return max(weightedScore, 0.92)
            }
            if slipAllowed {
                return max(weightedScore, 0.82)
            }
            return min(weightedScore, 0.799)
        }()
        let state = state(for: score, allowsDegradationBands: allowsDegradationBands)
        return IdentityAssessment(
            score: score,
            state: state,
            allowsDegradationBands: allowsDegradationBands,
            longTermConsistency: longTermConsistency,
            recentCompletion: recentCompletion
        )
    }

    static func state(
        for score: Double,
        allowsDegradationBands: Bool
    ) -> HabitIdentityState {
        let normalized = clamp(score, lower: 0, upper: 1)
        if normalized < 0.2 {
            return .gettingStarted
        }
        if normalized < 0.4 {
            return .building
        }
        if normalized < 0.6 {
            return .steady
        }
        if normalized < 0.8 {
            return .strong
        }
        if !allowsDegradationBands {
            return .strong
        }
        if normalized < 0.9 {
            return .slipping
        }
        return .rebuilding
    }

    static func trendStabilityScore(
        trackingStart: Date,
        windowEnd: Date,
        activeDays: Set<Date>,
        calendar: Calendar
    ) -> Double {
        let totalDays = max(calendar.dateComponents([.day], from: trackingStart, to: windowEnd).day ?? 0, 0)
        guard totalDays > 0 else { return 0 }

        let windowDays = max(min(totalDays, 56), 30)
        let effectiveStart = calendar.date(byAdding: .day, value: -windowDays, to: windowEnd) ?? trackingStart
        var weeklyRates: [Double] = []
        var cursor = effectiveStart

        while cursor < windowEnd {
            let next = calendar.date(byAdding: .day, value: 7, to: cursor) ?? windowEnd
            let interval = DateInterval(start: cursor, end: min(next, windowEnd))
            let rate = completionRate(
                in: interval,
                trackingStart: trackingStart,
                activeDays: activeDays,
                calendar: calendar
            )
            weeklyRates.append(rate)
            cursor = next
        }

        guard !weeklyRates.isEmpty else { return 0 }
        let mean = weeklyRates.reduce(0, +) / Double(weeklyRates.count)
        let variance = weeklyRates.reduce(0) { partial, value in
            let delta = value - mean
            return partial + (delta * delta)
        } / Double(weeklyRates.count)
        return clamp(1 - sqrt(variance), lower: 0, upper: 1)
    }

    static func debugValidateIdentityAlignment(_ identity: IdentityAssessment) {
        #if DEBUG
        let label = CadenceLanguage.shortLabel(for: identity.state)
        let line = CadenceLanguage.insightLine(for: identity.state)
        let expectedState = state(for: identity.score, allowsDegradationBands: identity.allowsDegradationBands)
        if expectedState != identity.state {
            print(
                "[IdentitySignal] mismatch band_state=\(expectedState) state=\(identity.state) " +
                    "score=\(String(format: "%.3f", identity.score)) label=\(label) line=\(line)"
            )
        }
        if (identity.state == .slipping || identity.state == .rebuilding), identity.longTermConsistency >= 0.7 {
            print(
                "[IdentitySignal] suspicious_degradation state=\(identity.state) " +
                    "long_term=\(String(format: "%.3f", identity.longTermConsistency)) " +
                    "recent=\(String(format: "%.3f", identity.recentCompletion))"
            )
        }
        #endif
    }
}
