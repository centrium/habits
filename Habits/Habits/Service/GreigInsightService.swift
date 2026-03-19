import Foundation

struct GreigInsight: Equatable {
    let title: String
    let body: String?
    let confidence: ConfidenceLevel
    let status: InsightStatus
}

enum ConfidenceLevel: Equatable {
    case low
    case medium
    case high
}

enum InsightStatus: Equatable {
    case ahead
    case onTrack
    case atRisk
    case neutral
}

struct GreigInsightGoal {
    enum Kind {
        case open
        case frequency(target: Double)
        case cumulative(target: Double)
    }

    let kind: Kind
    let period: GoalPeriod
}

struct GreigInsightProgress {
    let currentTotal: Double
    let periodStart: Date
    let periodEnd: Date
    let now: Date
    let logs: [HabitLog]
    let unit: String
    let formatValue: (Double) -> String

    init(
        currentTotal: Double,
        periodStart: Date,
        periodEnd: Date,
        now: Date,
        logs: [HabitLog],
        unit: String = "",
        formatValue: @escaping (Double) -> String = { value in
            if value.rounded() == value {
                return String(Int(value))
            }
            return value.formatted(.number.precision(.fractionLength(1)))
        }
    ) {
        self.currentTotal = currentTotal
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.now = now
        self.logs = logs
        self.unit = unit
        self.formatValue = formatValue
    }
}

struct GreigInsightService {
    private enum Constants {
        static let minimumProjectionDataPoints = 3
        static let rollingWindowDays = 7
        static let dailyLookbackDays = 7
    }

    private let calendar: Calendar
    private let copyProvider: GreigCopyProvider

    init(
        calendar: Calendar = .current,
        copyProvider: GreigCopyProvider? = nil
    ) {
        self.calendar = calendar
        self.copyProvider = copyProvider ?? GreigCopyProvider(calendar: calendar)
    }

    func generateInsight(
        for goal: GreigInsightGoal,
        progress: GreigInsightProgress
    ) -> GreigInsight? {
        guard progress.periodEnd > progress.periodStart else { return nil }

        switch goal.kind {
        case .open:
            return generateOpenInsight(progress: progress)
        case .frequency(let target):
            guard target > 0 else { return nil }
            return generateFrequencyInsight(goal: goal, target: target, progress: progress)
        case .cumulative(let target):
            guard target > 0 else { return nil }
            return generateCumulativeInsight(goal: goal, target: target, progress: progress)
        }
    }
}

private extension GreigInsightService {
    func generateCumulativeInsight(
        goal: GreigInsightGoal,
        target: Double,
        progress: GreigInsightProgress
    ) -> GreigInsight {
        let timeline = projectionTimeline(for: .cumulative, progress: progress)
        let confidence = projectionConfidence(signals: timeline.confidenceSignals)

        guard timeline.dataPoints >= Constants.minimumProjectionDataPoints else {
            return copyBackedInsight(
                goalType: .cumulative,
                status: .neutral,
                confidence: .low,
                date: progress.now
            )
        }

        let expected = expectedProgressValue(
            target: target,
            timeline: timeline,
            progress: progress
        )
        let projected = timeline.smoothedDailyPace * Double(timeline.totalDays)
        let status: InsightStatus = {
            if projected >= target * 1.05 && progress.currentTotal >= expected {
                return .ahead
            }
            if projected >= target || progress.currentTotal >= expected * 0.95 {
                return .onTrack
            }
            return .atRisk
        }()
        let remaining = max(target - progress.currentTotal, 0)
        let remainingDays = max(timeline.totalDays - timeline.daysElapsed, 1)
        let nudge = cumulativeNudge(
            projected: projected,
            target: target,
            timeline: timeline,
            progress: progress,
            confidence: confidence
        )
        let context = GreigContext(
            projectedValue: projected,
            nudgedProjection: nudge?.nudgedProjection,
            deltaFromTarget: projected - target,
            suggestedIncrement: nudge?.suggestedIncrement,
            requiredRate: remaining / Double(remainingDays),
            currentRate: timeline.smoothedDailyPace,
            unit: progress.unit,
            targetValue: target,
            currentValue: progress.currentTotal,
            periodLabel: goal.period.relativeLabel
        )
        return copyBackedInsight(
            goalType: goalType(for: goal),
            status: status,
            confidence: confidence,
            date: progress.now,
            context: context
        )
    }

    func generateFrequencyInsight(
        goal: GreigInsightGoal,
        target: Double,
        progress: GreigInsightProgress
    ) -> GreigInsight {
        let timeline = projectionTimeline(for: .frequency, progress: progress)
        let confidence = projectionConfidence(signals: timeline.confidenceSignals)

        guard timeline.dataPoints >= Constants.minimumProjectionDataPoints else {
            return copyBackedInsight(
                goalType: .frequency,
                status: .neutral,
                confidence: .low,
                date: progress.now
            )
        }

        let expected = expectedProgressValue(
            target: target,
            timeline: timeline,
            progress: progress
        )
        let projected = timeline.smoothedDailyPace * Double(timeline.totalDays)
        let status: InsightStatus = {
            if timeline.confidenceSignals.activeRatio < 0.25 {
                return .atRisk
            }
            if projected >= target + 0.5 || progress.currentTotal > expected + 0.5 {
                return .ahead
            }
            if projected >= target || progress.currentTotal >= expected {
                return .onTrack
            }
            return .atRisk
        }()
        let remainingActions = max(Int(ceil(target - progress.currentTotal)), 0)
        let remainingDays = max(timeline.totalDays - timeline.daysElapsed, 1)
        let nudge = frequencyNudge(
            status: status,
            target: target,
            projected: projected,
            currentTotal: progress.currentTotal,
            remainingActions: remainingActions,
            confidence: confidence,
            signals: timeline.confidenceSignals
        )
        let context = GreigContext(
            projectedValue: projected,
            nudgedProjection: nudge?.nudgedProjection,
            deltaFromTarget: projected - target,
            suggestedIncrement: nudge?.suggestedIncrement,
            requiredRate: Double(remainingActions) / Double(remainingDays),
            currentRate: timeline.smoothedDailyPace,
            unit: "sessions",
            targetValue: target,
            currentValue: progress.currentTotal,
            remainingActions: remainingActions,
            periodLabel: goal.period.relativeLabel
        )
        return copyBackedInsight(
            goalType: goalType(for: goal),
            status: status,
            confidence: confidence,
            date: progress.now,
            context: context
        )
    }

    func generateOpenInsight(
        progress: GreigInsightProgress
    ) -> GreigInsight {
        let daySet = Set(
            progress.logs.compactMap { log -> Date? in
                guard log.effectiveTimestamp <= progress.now, log.frequencyContribution > 0 else { return nil }
                return calendar.startOfDay(for: log.effectiveTimestamp)
            }
        )

        let streak = currentStreak(from: daySet, asOf: progress.now)
        let recentStats = openRecentStats(daySet: daySet, asOf: progress.now)
        let openSignals = openConfidenceSignals(progress: progress)
        let confidence = projectionConfidence(signals: openSignals)
        let recentWindowDays = 5
        let recentCompletedDays = recentCompletionCount(
            daySet: daySet,
            asOf: progress.now,
            windowDays: recentWindowDays
        )
        let status: InsightStatus = {
            if streak >= 3 {
                return .ahead
            }
            if recentStats.completionRate >= 0.6 {
                return .onTrack
            }
            if recentStats.completionRate >= 0.25 {
                return .neutral
            }
            return .atRisk
        }()
        let context = GreigContext(
            suggestedIncrement: openNudgeIncrement(
                status: status,
                confidence: confidence,
                signals: openSignals
            ), currentRate: recentStats.completionRate,
            unit: "days",
            streakLength: streak,
            recentCompletedDays: recentCompletedDays,
            recentWindowDays: recentWindowDays
        )
        return copyBackedInsight(
            goalType: .open,
            status: status,
            confidence: confidence,
            date: progress.now,
            context: context
        )
    }

    struct ProjectionTimeline {
        let totalDays: Int
        let daysElapsed: Int
        let dataPoints: Int
        let smoothedDailyPace: Double
        let confidenceSignals: ConfidenceSignals
    }

    struct ConfidenceSignals {
        let dataPoints: Int
        let daysElapsed: Int
        let activeRatio: Double
        let coefficientOfVariation: Double
        let spikeRatio: Double
        let daysSinceLastLog: Int?
        let isEarlyPeriod: Bool
    }

    enum ProjectionValueKind {
        case frequency
        case cumulative
    }

    struct ProjectionNudge {
        let suggestedIncrement: Double
        let nudgedProjection: Double
    }

    func projectionTimeline(
        for kind: ProjectionValueKind,
        progress: GreigInsightProgress
    ) -> ProjectionTimeline {
        let nowClamped = min(max(progress.now, progress.periodStart), progress.periodEnd)
        let periodStartBoundary = calendar.startOfDay(for: progress.periodStart)
        let periodEndBoundary = calendar.startOfDay(for: progress.periodEnd)
        let totalDays = periodDayCount(start: progress.periodStart, end: progress.periodEnd)
        if totalDays == 1 {
            return singleDayProjectionTimeline(
                for: kind,
                nowClamped: nowClamped,
                progress: progress
            )
        }
        let daysElapsed = elapsedDayCount(
            start: progress.periodStart,
            now: nowClamped,
            periodEnd: progress.periodEnd
        )
        let inPeriodLogs = progress.logs.filter {
            $0.effectiveTimestamp >= periodStartBoundary &&
                $0.effectiveTimestamp < periodEndBoundary &&
                $0.effectiveTimestamp <= nowClamped
        }
        let contributingLogs = inPeriodLogs.filter { projectionContribution(for: kind, log: $0) > 0 }
        let dataPoints = contributingLogs.count

        let dayTotals = dailyTotals(
            logs: contributingLogs,
            kind: kind,
            periodStart: progress.periodStart,
            daysElapsed: daysElapsed
        )
        let periodAverage = dayTotals.reduce(0, +) / Double(max(dayTotals.count, 1))
        let rollingWindow = min(Constants.rollingWindowDays, dayTotals.count)
        let rollingAverage = dayTotals.suffix(rollingWindow).reduce(0, +) / Double(max(rollingWindow, 1))
        let smoothedDailyPace = dayTotals.count >= Constants.rollingWindowDays ? rollingAverage : periodAverage
        let mostRecentLog = contributingLogs.map(\.effectiveTimestamp).max()
        let confidenceSignals = confidenceSignals(
            dataPoints: dataPoints,
            daysElapsed: daysElapsed,
            dayTotals: dayTotals,
            now: nowClamped,
            mostRecentLogDate: mostRecentLog,
            applyEarlyPeriodOverride: true
        )

        return ProjectionTimeline(
            totalDays: totalDays,
            daysElapsed: daysElapsed,
            dataPoints: dataPoints,
            smoothedDailyPace: smoothedDailyPace,
            confidenceSignals: confidenceSignals
        )
    }

    func singleDayProjectionTimeline(
        for kind: ProjectionValueKind,
        nowClamped: Date,
        progress: GreigInsightProgress
    ) -> ProjectionTimeline {
        let todayStart = calendar.startOfDay(for: nowClamped)
        let analysisStart = calendar.date(byAdding: .day, value: -(Constants.dailyLookbackDays - 1), to: todayStart) ?? todayStart
        let analysisEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? progress.periodEnd
        let inWindowLogs = progress.logs.filter {
            $0.effectiveTimestamp >= analysisStart &&
                $0.effectiveTimestamp < analysisEnd &&
                $0.effectiveTimestamp <= nowClamped
        }
        let contributingLogs = inWindowLogs.filter { projectionContribution(for: kind, log: $0) > 0 }
        let dataPoints = contributingLogs.count
        let dayTotals = dailyTotals(
            logs: contributingLogs,
            kind: kind,
            periodStart: analysisStart,
            daysElapsed: Constants.dailyLookbackDays
        )
        let periodAverage = dayTotals.reduce(0, +) / Double(max(dayTotals.count, 1))
        let rollingWindow = min(Constants.rollingWindowDays, dayTotals.count)
        let rollingAverage = dayTotals.suffix(rollingWindow).reduce(0, +) / Double(max(rollingWindow, 1))
        let smoothedDailyPace = dayTotals.count >= Constants.rollingWindowDays ? rollingAverage : periodAverage
        let mostRecentLog = contributingLogs.map(\.effectiveTimestamp).max()
        let confidenceSignals = confidenceSignals(
            dataPoints: dataPoints,
            daysElapsed: Constants.dailyLookbackDays,
            dayTotals: dayTotals,
            now: nowClamped,
            mostRecentLogDate: mostRecentLog,
            applyEarlyPeriodOverride: false
        )

        return ProjectionTimeline(
            totalDays: 1,
            daysElapsed: 1,
            dataPoints: dataPoints,
            smoothedDailyPace: smoothedDailyPace,
            confidenceSignals: confidenceSignals
        )
    }

    func expectedProgressValue(
        target: Double,
        timeline: ProjectionTimeline,
        progress: GreigInsightProgress
    ) -> Double {
        if timeline.totalDays == 1 {
            let totalSeconds = progress.periodEnd.timeIntervalSince(progress.periodStart)
            guard totalSeconds > 0 else { return target }
            let elapsedSeconds = min(max(progress.now.timeIntervalSince(progress.periodStart), 0), totalSeconds)
            return (elapsedSeconds / totalSeconds) * target
        }
        return (Double(timeline.daysElapsed) / Double(timeline.totalDays)) * target
    }

    func periodDayCount(start: Date, end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let raw = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(raw, 1)
    }

    func elapsedDayCount(start: Date, now: Date, periodEnd: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let nowDay = calendar.startOfDay(for: now)
        let raw = calendar.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
        return min(max(raw + 1, 1), periodDayCount(start: start, end: periodEnd))
    }

    func dailyTotals(
        logs: [HabitLog],
        kind: ProjectionValueKind,
        periodStart: Date,
        daysElapsed: Int
    ) -> [Double] {
        var values = Array(repeating: 0.0, count: max(daysElapsed, 1))
        let startDay = calendar.startOfDay(for: periodStart)

        for log in logs {
            let logDay = calendar.startOfDay(for: log.effectiveTimestamp)
            let index = calendar.dateComponents([.day], from: startDay, to: logDay).day ?? -1
            guard index >= 0, index < values.count else { continue }
            values[index] += projectionContribution(for: kind, log: log)
        }

        return values
    }

    func projectionContribution(
        for kind: ProjectionValueKind,
        log: HabitLog
    ) -> Double {
        switch kind {
        case .frequency:
            return Double(max(0, log.frequencyContribution))
        case .cumulative:
            return max(0, log.numericValue)
        }
    }

    func projectionConfidence(signals: ConfidenceSignals) -> ConfidenceLevel {
        if signals.isEarlyPeriod {
            return .low
        }
        if signals.dataPoints < Constants.minimumProjectionDataPoints {
            return .low
        }
        if let daysSinceLastLog = signals.daysSinceLastLog, daysSinceLastLog > 4 {
            return .low
        }
        if signals.activeRatio < 0.15 {
            return .low
        }
        if signals.coefficientOfVariation > 1.8 || signals.spikeRatio > 6.0 {
            return .low
        }

        let recentlyActive = (signals.daysSinceLastLog ?? Int.max) <= 2
        let lowVariance = signals.coefficientOfVariation <= 0.8
        let lowSpike = signals.spikeRatio <= 2.0
        let stableActiveRatio = signals.activeRatio >= 0.4

        if signals.dataPoints >= 7, lowVariance, lowSpike, stableActiveRatio, recentlyActive {
            return .high
        }
        if signals.dataPoints >= 7,
           signals.activeRatio >= 0.4,
           recentlyActive,
           signals.spikeRatio <= 3.5 {
            return .high
        }
        return .medium
    }

    func shouldShowNudge(
        confidence: ConfidenceLevel,
        signals: ConfidenceSignals
    ) -> Bool {
        guard confidence != .low else { return false }
        guard signals.dataPoints >= Constants.minimumProjectionDataPoints else { return false }
        guard (signals.daysSinceLastLog ?? Int.max) <= 2 else { return false }
        guard signals.coefficientOfVariation <= 1.2 else { return false }
        guard signals.spikeRatio <= 3.5 else { return false }
        guard signals.activeRatio >= 0.25 else { return false }
        return true
    }

    func cumulativeNudge(
        projected: Double,
        target: Double,
        timeline: ProjectionTimeline,
        progress: GreigInsightProgress,
        confidence: ConfidenceLevel
    ) -> ProjectionNudge? {
        guard shouldShowNudge(confidence: confidence, signals: timeline.confidenceSignals) else {
            return nil
        }
        guard projected < target * 1.2 else { return nil }

        let remainingDays = max(timeline.totalDays - timeline.daysElapsed, 1)
        let daysElapsed = max(timeline.daysElapsed, 1)
        let averagePerDay = max(timeline.smoothedDailyPace, progress.currentTotal / Double(daysElapsed))
        let currency = CurrencyDetection.detect(unit: progress.unit).isCurrency
        let rawIncrement = averagePerDay * 0.1
        let baselineIncrement: Double = {
            if currency {
                return min(max(rawIncrement, 5), 20)
            }
            return min(max(rawIncrement, 1), 5)
        }()
        let maxProjectedGain = max(target * 0.3, currency ? 20 : 5)
        let suggestedIncrement = min(baselineIncrement, maxProjectedGain / Double(remainingDays))
        guard suggestedIncrement > 0 else { return nil }

        let nudgedProjection = projected + (suggestedIncrement * Double(remainingDays))
        guard nudgedProjection > projected else { return nil }
        return ProjectionNudge(
            suggestedIncrement: suggestedIncrement,
            nudgedProjection: nudgedProjection
        )
    }

    func frequencyNudge(
        status: InsightStatus,
        target: Double,
        projected: Double,
        currentTotal: Double,
        remainingActions: Int,
        confidence: ConfidenceLevel,
        signals: ConfidenceSignals
    ) -> ProjectionNudge? {
        guard shouldShowNudge(confidence: confidence, signals: signals) else { return nil }

        switch status {
        case .ahead:
            guard currentTotal < target + 3 else { return nil }
            return ProjectionNudge(
                suggestedIncrement: 1,
                nudgedProjection: projected + 1
            )
        case .onTrack:
            return ProjectionNudge(
                suggestedIncrement: 1,
                nudgedProjection: projected + 1
            )
        case .atRisk:
            let suggested = Double(min(max(remainingActions, 1), 2))
            return ProjectionNudge(
                suggestedIncrement: suggested,
                nudgedProjection: projected + suggested
            )
        case .neutral:
            return nil
        }
    }

    func openNudgeIncrement(
        status: InsightStatus,
        confidence: ConfidenceLevel,
        signals: ConfidenceSignals
    ) -> Double? {
        guard shouldShowNudge(confidence: confidence, signals: signals) else { return nil }
        switch status {
        case .ahead, .onTrack, .atRisk, .neutral:
            return 1
        }
    }

    struct OpenRecentStats {
        let completionRate: Double
        let recentTrend: Double
    }

    func openRecentStats(
        daySet: Set<Date>,
        asOf now: Date
    ) -> OpenRecentStats {
        let today = calendar.startOfDay(for: now)
        let last7Start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let previous7Start = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let previous7End = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        let recentCompleted = daySet.filter { $0 >= last7Start && $0 <= today }.count
        let previousCompleted = daySet.filter { $0 >= previous7Start && $0 <= previous7End }.count
        let completionRate = Double(recentCompleted) / 7.0
        let trend = Double(recentCompleted - previousCompleted) / 7.0

        return OpenRecentStats(
            completionRate: completionRate,
            recentTrend: trend
        )
    }

    func recentCompletionCount(
        daySet: Set<Date>,
        asOf now: Date,
        windowDays: Int
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        return daySet.filter { $0 >= start && $0 <= today }.count
    }

    func currentStreak(
        from daySet: Set<Date>,
        asOf now: Date
    ) -> Int {
        var day = calendar.startOfDay(for: now)
        var streak = 0

        while daySet.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    func openConfidenceSignals(
        progress: GreigInsightProgress
    ) -> ConfidenceSignals {
        let nowClamped = min(max(progress.now, progress.periodStart), progress.periodEnd)
        let periodStartBoundary = calendar.startOfDay(for: progress.periodStart)
        let periodEndBoundary = calendar.startOfDay(for: progress.periodEnd)
        let daysElapsed = elapsedDayCount(
            start: progress.periodStart,
            now: nowClamped,
            periodEnd: progress.periodEnd
        )
        let logsInPeriod = progress.logs.filter {
            $0.effectiveTimestamp >= periodStartBoundary &&
                $0.effectiveTimestamp < periodEndBoundary &&
                $0.effectiveTimestamp <= nowClamped &&
                $0.frequencyContribution > 0
        }
        let completionFlags = openDailyCompletionFlags(
            logs: logsInPeriod,
            periodStart: progress.periodStart,
            daysElapsed: daysElapsed
        )
        let dataPoints = completionFlags.filter { $0 > 0 }.count
        let mostRecentLog = logsInPeriod.map(\.effectiveTimestamp).max()
        let signals = confidenceSignals(
            dataPoints: dataPoints,
            daysElapsed: daysElapsed,
            dayTotals: completionFlags,
            now: nowClamped,
            mostRecentLogDate: mostRecentLog,
            applyEarlyPeriodOverride: false
        )
        return signals
    }

    func openDailyCompletionFlags(
        logs: [HabitLog],
        periodStart: Date,
        daysElapsed: Int
    ) -> [Double] {
        var values = Array(repeating: 0.0, count: max(daysElapsed, 1))
        let startDay = calendar.startOfDay(for: periodStart)
        let loggedDays = Set(logs.map { calendar.startOfDay(for: $0.effectiveTimestamp) })
        for day in loggedDays {
            let index = calendar.dateComponents([.day], from: startDay, to: day).day ?? -1
            guard index >= 0, index < values.count else { continue }
            values[index] = 1
        }
        return values
    }

    func confidenceSignals(
        dataPoints: Int,
        daysElapsed: Int,
        dayTotals: [Double],
        now: Date,
        mostRecentLogDate: Date?,
        applyEarlyPeriodOverride: Bool
    ) -> ConfidenceSignals {
        let activeDays = dayTotals.filter { $0 > 0 }.count
        let activeRatio = Double(activeDays) / Double(max(daysElapsed, 1))
        let nonZeroTotals = dayTotals.filter { $0 > 0 }
        let mean = nonZeroTotals.reduce(0, +) / Double(max(nonZeroTotals.count, 1))
        let variance = nonZeroTotals.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(max(nonZeroTotals.count, 1))
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation: Double = {
            guard mean > 0 else { return 999 }
            return standardDeviation / mean
        }()
        let spikeRatio: Double = {
            guard mean > 0 else { return 999 }
            return (nonZeroTotals.max() ?? 0) / mean
        }()
        let daysSinceLastLog: Int? = {
            guard let mostRecentLogDate else { return nil }
            let recentDay = calendar.startOfDay(for: mostRecentLogDate)
            let nowDay = calendar.startOfDay(for: now)
            return max(0, calendar.dateComponents([.day], from: recentDay, to: nowDay).day ?? 0)
        }()
        let isEarlyPeriod = applyEarlyPeriodOverride && daysElapsed <= 2

        return ConfidenceSignals(
            dataPoints: dataPoints,
            daysElapsed: daysElapsed,
            activeRatio: activeRatio,
            coefficientOfVariation: coefficientOfVariation,
            spikeRatio: spikeRatio,
            daysSinceLastLog: daysSinceLastLog,
            isEarlyPeriod: isEarlyPeriod
        )
    }

    func copyBackedInsight(
        goalType: GreigCopyGoalType,
        status: InsightStatus,
        confidence: ConfidenceLevel,
        date: Date,
        context: GreigContext? = nil
    ) -> GreigInsight {
        let copy = copyProvider.copy(
            for: goalType,
            status: status,
            confidence: confidence,
            date: date,
            context: context
        )
        return GreigInsight(
            title: copy.title,
            body: copy.body,
            confidence: confidence,
            status: status
        )
    }

    func goalType(for goal: GreigInsightGoal) -> GreigCopyGoalType {
        switch goal.kind {
        case .open:
            return .open
        case .frequency:
            return .frequency
        case .cumulative:
            return .cumulative
        }
    }
}
