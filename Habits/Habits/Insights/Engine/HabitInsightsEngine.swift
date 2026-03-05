//
//  HabitInsightsEngine.swift
//  Habits
//
//  Created by Matt Adams on 04/03/2026.
//

import Foundation

struct HabitInsightsEngine {

    static func snapshot(
        for habit: Habit,
        anchorDate: Date,
        logAnchorDate: Date? = nil,
        respectCreatedAtBoundary: Bool = true,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        timezone: TimeZone? = nil,
        now: Date = .now
    ) -> HabitInsightsSnapshot {
        var resolvedCalendar = calendar
        if let timezone {
            resolvedCalendar.timeZone = timezone
        }

        let cadence = habit.goalPeriod
        let goalMode = goalMode(for: habit)
        let target = targetValue(for: habit, goalMode: goalMode)
        let isValueBased = usesValueMetric(for: habit, goalMode: goalMode)
        let createdAtStart = resolvedCalendar.startOfDay(for: habit.createdAt)
        let earliestLogStart = habit.logs
            .map { resolvedCalendar.startOfDay(for: $0.effectiveTimestamp) }
            .min()
        let effectiveStartDate: Date
        if respectCreatedAtBoundary {
            effectiveStartDate = createdAtStart
        } else {
            effectiveStartDate = min(createdAtStart, earliestLogStart ?? createdAtStart)
        }

        let timelineContext = TimelineContext(calendar: resolvedCalendar)
        let asOfUpperBound = timelineContext.asOfExclusiveUpperBound(for: anchorDate, today: now)

        let fullCanonicalLogs = canonicalLogs(
            for: habit,
            effectiveStartDate: effectiveStartDate,
            asOfUpperBound: nil,
            cadence: cadence,
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let canonicalLogsSoFar = canonicalLogs(
            for: habit,
            effectiveStartDate: effectiveStartDate,
            asOfUpperBound: asOfUpperBound,
            cadence: cadence,
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let currentStart = cadence.periodStart(
            for: anchorDate,
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let firstTrackedStart = cadence.periodStart(
            for: effectiveStartDate,
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let historyStarts: [Date]
        if firstTrackedStart <= currentStart {
            historyStarts = periodStarts(
                from: firstTrackedStart,
                through: currentStart,
                cadence: cadence,
                calendar: resolvedCalendar,
                weekStartPreference: weekStartPreference
            )
        } else {
            historyStarts = []
        }

        let historySnapshots = historyStarts.map {
            periodSnapshot(
                for: $0,
                cadence: cadence,
                target: target,
                isValueBased: isValueBased,
                bucketTotals: canonicalLogsSoFar.bucketTotalsByStart[$0],
                calendar: resolvedCalendar,
                weekStartPreference: weekStartPreference
            )
        }

        let currentPeriod = periodSnapshot(
            for: currentStart,
            cadence: cadence,
            target: target,
            isValueBased: isValueBased,
            bucketTotals: fullCanonicalLogs.bucketTotalsByStart[currentStart],
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let currentPeriodSoFar = periodSnapshot(
            for: currentStart,
            cadence: cadence,
            target: target,
            isValueBased: isValueBased,
            bucketTotals: canonicalLogsSoFar.bucketTotalsByStart[currentStart],
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let pace = paceSnapshot(
            for: currentPeriodSoFar,
            cadence: cadence,
            anchorUpperBound: min(asOfUpperBound, currentPeriod.end),
            target: target,
            calendar: resolvedCalendar
        )

        let streak = streakSnapshot(
            from: historySnapshots,
            goalMode: goalMode
        )

        let completionHistory = completionHistorySnapshot(
            from: historySnapshots,
            goalMode: goalMode,
            asOfUpperBound: asOfUpperBound
        )

        let trendWindow = trendWindowCount(for: cadence)
        let trendStarts = trendStarts(
            endingAt: currentStart,
            windowCount: trendWindow,
            cadence: cadence,
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let trendBuckets = trendStarts.map {
            periodSnapshot(
                for: $0,
                cadence: cadence,
                target: target,
                isValueBased: isValueBased,
                bucketTotals: fullCanonicalLogs.bucketTotalsByStart[$0],
                calendar: resolvedCalendar,
                weekStartPreference: weekStartPreference
            )
        }

        let debugRows = trendBuckets.map {
            HabitInsightsDebugRow(
                key: debugPeriodKey(for: $0.start, cadence: cadence, calendar: resolvedCalendar),
                periodStart: $0.start,
                periodEnd: $0.end,
                countTotal: $0.progressCount,
                valueTotal: $0.progressValue
            )
        }

        let debug = HabitInsightsDebugSnapshot(
            anchorDate: anchorDate,
            logAnchorDate: logAnchorDate,
            asOfUpperBound: asOfUpperBound,
            periodStart: currentPeriod.start,
            periodEnd: currentPeriod.end,
            periodProgressCount: currentPeriod.progressCount,
            periodProgressValue: currentPeriod.progressValue,
            progressSoFarCount: currentPeriodSoFar.progressCount,
            progressSoFarValue: currentPeriodSoFar.progressValue,
            target: target,
            elapsedUnits: pace.elapsedUnits,
            remainingUnits: pace.remainingUnits,
            projected: pace.projectedTotal,
            periodRows: debugRows
        )

        return HabitInsightsSnapshot(
            anchorDate: anchorDate,
            cadence: cadence,
            goalMode: goalMode,
            isValueBased: isValueBased,
            target: target,
            effectiveStartDate: effectiveStartDate,
            currentPeriod: currentPeriod,
            currentPeriodSoFar: currentPeriodSoFar,
            pace: pace,
            streak: streak,
            completionHistory: completionHistory,
            trendBuckets: trendBuckets,
            debug: debug
        )
    }

    static func insights(
        for habit: Habit,
        logAnchorDate: Date? = nil,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        timezone: TimeZone? = nil,
        now: Date = .now
    ) -> HabitInsightsViewModel {
        let insightAnchorDate = now
        let snapshot = snapshot(
            for: habit,
            anchorDate: insightAnchorDate,
            logAnchorDate: logAnchorDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            timezone: timezone,
            now: now
        )

        var resolvedCalendar = calendar
        if let timezone {
            resolvedCalendar.timeZone = timezone
        }

        let heading = headingForCurrentPeriod(snapshot.cadence)
        let periodLabel = snapshot.cadence.displayLabel(
            for: snapshot.currentPeriod.start,
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        var cards: [HabitInsightsCard] = []

        if snapshot.goalMode == .openEnded {
            let previous = snapshot.trendBuckets.dropLast().last
            let comparisonText: String?
            if let previous {
                let delta = snapshot.currentPeriodSoFar.progress - previous.progress
                if abs(delta) < 0.0001 {
                    comparisonText = "In line with last \(snapshot.cadence.unit)"
                } else {
                    let direction = delta > 0 ? "Up" : "Down"
                    let deltaText = formattedProgress(abs(delta), habit: habit, isValueBased: snapshot.isValueBased)
                    comparisonText = "\(direction) \(deltaText) vs last \(snapshot.cadence.unit)"
                }
            } else {
                comparisonText = nil
            }

            cards.append(
                .hero(
                    HabitInsightsHeroBlock(
                        heading: heading,
                        valueText: openEndedValueText(for: snapshot.currentPeriodSoFar.progress, habit: habit, isValueBased: snapshot.isValueBased),
                        statusText: nil,
                        surplusText: nil,
                        periodLabel: periodLabel,
                        comparisonText: comparisonText
                    )
                )
            )
        } else {
            let progressText = formattedProgress(snapshot.currentPeriodSoFar.progressClamped, habit: habit, isValueBased: snapshot.isValueBased)
            let targetText = formattedProgress(snapshot.currentPeriodSoFar.target ?? 0, habit: habit, isValueBased: snapshot.isValueBased)

            let statusText: String
            switch snapshot.pace.status {
            case .completed:
                statusText = "Completed"
            case .likelyToHitTarget:
                statusText = "On track"
            case .likelyShort:
                statusText = "Behind"
            case .paceOnly:
                statusText = "On track"
            }

            let surplusText: String?
            if snapshot.currentPeriodSoFar.surplus > 0 {
                surplusText = "+\(formattedProgress(snapshot.currentPeriodSoFar.surplus, habit: habit, isValueBased: snapshot.isValueBased)) extra"
            } else {
                surplusText = nil
            }

            cards.append(
                .hero(
                    HabitInsightsHeroBlock(
                        heading: heading,
                        valueText: "\(progressText) / \(targetText)",
                        statusText: statusText,
                        surplusText: surplusText,
                        periodLabel: periodLabel,
                        comparisonText: nil
                    )
                )
            )
        }

        cards.append(
            .motivation(
                motivationCard(
                    snapshot: snapshot
                )
            )
        )

        cards.append(
            .intent(
                intentBlock(
                    snapshot: snapshot,
                    habit: habit
                )
            )
        )

        let trendWindow = trendWindowCount(for: snapshot.cadence)
        cards.append(
            .trend(
                HabitInsightsTrendBlock(
                    heading: trendHeading(for: snapshot.cadence, windowCount: trendWindow),
                    points: snapshot.trendBuckets.map {
                        HabitInsightsTrendPoint(
                            periodStart: $0.start,
                            label: trendPointLabel(for: $0.start, cadence: snapshot.cadence, calendar: resolvedCalendar),
                            value: $0.progress
                        )
                    },
                    targetLine: snapshot.target,
                    unitText: snapshot.isValueBased ? habit.trimmedUnit : nil,
                    isValueBased: snapshot.isValueBased
                )
            )
        )

        let canonicalLogsForPatterns = canonicalLogs(
            for: habit,
            effectiveStartDate: snapshot.effectiveStartDate,
            asOfUpperBound: snapshot.debug.asOfUpperBound,
            cadence: snapshot.cadence,
            calendar: resolvedCalendar,
            weekStartPreference: weekStartPreference
        )

        let patterns = patternsBlock(
            cadence: snapshot.cadence,
            goalMode: snapshot.goalMode,
            periodSnapshots: snapshot.trendBuckets,
            logs: canonicalLogsForPatterns.logs,
            calendar: resolvedCalendar
        )
        cards.append(.patterns(patterns))

        #if DEBUG
        cards.append(
            .debug(
                HabitInsightsDebugBlock(
                    heading: "Debug",
                    lines: debugLines(from: snapshot, calendar: resolvedCalendar)
                )
            )
        )
        #endif

        return HabitInsightsViewModel(
            title: "Insights",
            cards: cards,
            notes: []
        )
    }
}

private extension HabitInsightsEngine {
    struct CanonicalLog {
        let timestamp: Date
        let dayStart: Date
        let frequencyContribution: Int
        let valueContribution: Double
        let hasTimestamp: Bool
    }

    struct BucketTotals {
        let countTotal: Int
        let valueTotal: Double
        let activeDays: Int
        let dayFrequencyDistribution: [Date: Int]
    }

    struct CanonicalLogAggregation {
        let logs: [CanonicalLog]
        let bucketTotalsByStart: [Date: BucketTotals]
    }

    static let weekdayPatternMinimumSampleCount = 10
    static let timeOfDayPatternMinimumSampleCount = 15
    static let distributionPatternMinimumSampleCount = 20
    static let projectionTolerance = 0.98

    static func goalMode(for habit: Habit) -> HabitInsightGoalMode {
        guard habit.hasGoal else { return .openEnded }
        return habit.goalType == .frequency ? .frequency : .cumulative
    }

    static func usesValueMetric(for habit: Habit, goalMode: HabitInsightGoalMode) -> Bool {
        switch goalMode {
        case .cumulative:
            return true
        case .frequency:
            return false
        case .openEnded:
            return habit.goalType == .cumulative
        }
    }

    static func targetValue(for habit: Habit, goalMode: HabitInsightGoalMode) -> Double? {
        switch goalMode {
        case .openEnded:
            return nil
        case .frequency, .cumulative:
            return habit.effectiveTargetValue
        }
    }

    static func canonicalLogs(
        for habit: Habit,
        effectiveStartDate: Date,
        asOfUpperBound: Date?,
        cadence: GoalPeriod,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> CanonicalLogAggregation {
        let logs: [CanonicalLog] = habit.logs.compactMap { log in
            let timestamp = log.effectiveTimestamp
            guard timestamp >= effectiveStartDate else { return nil }
            if let asOfUpperBound {
                guard timestamp < asOfUpperBound else { return nil }
            }

            return CanonicalLog(
                timestamp: timestamp,
                dayStart: calendar.startOfDay(for: timestamp),
                frequencyContribution: max(0, log.frequencyContribution),
                valueContribution: max(0, log.numericValue),
                hasTimestamp: log.timestamp != nil
            )
        }

        var grouped: [Date: [CanonicalLog]] = [:]
        for log in logs {
            let start = cadence.periodStart(
                for: log.timestamp,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
            grouped[start, default: []].append(log)
        }

        var bucketTotals: [Date: BucketTotals] = [:]
        for (start, bucketLogs) in grouped {
            let countTotal = bucketLogs.reduce(0) { $0 + $1.frequencyContribution }
            let valueTotal = bucketLogs.reduce(0.0) { $0 + $1.valueContribution }
            let activeDays = Set(bucketLogs.map(\.dayStart)).count
            var dayFrequency: [Date: Int] = [:]
            for log in bucketLogs {
                dayFrequency[log.dayStart, default: 0] += log.frequencyContribution
            }
            bucketTotals[start] = BucketTotals(
                countTotal: countTotal,
                valueTotal: sanitize(valueTotal),
                activeDays: activeDays,
                dayFrequencyDistribution: dayFrequency
            )
        }

        return CanonicalLogAggregation(logs: logs, bucketTotalsByStart: bucketTotals)
    }

    static func periodStarts(
        from start: Date,
        through end: Date,
        cadence: GoalPeriod,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> [Date] {
        guard start <= end else { return [] }

        var starts: [Date] = []
        var cursor = start
        var guardCounter = 0

        while cursor <= end {
            starts.append(cursor)
            let next = cadence.nextPeriodStart(
                after: cursor,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
            if next <= cursor { break }
            cursor = next
            guardCounter += 1
            if guardCounter > 10_000 { break }
        }

        return starts
    }

    static func periodSnapshot(
        for periodStart: Date,
        cadence: GoalPeriod,
        target: Double?,
        isValueBased: Bool,
        bucketTotals: BucketTotals?,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> HabitInsightsPeriodSnapshot {
        let range = cadence.periodRange(
            for: periodStart,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let countTotal = bucketTotals?.countTotal ?? 0
        let valueTotal = bucketTotals?.valueTotal ?? 0
        let activeDays = bucketTotals?.activeDays ?? 0

        let progress = isValueBased ? valueTotal : Double(countTotal)
        let sanitizedProgress = sanitize(max(0, progress))

        guard let target, target > 0 else {
            return HabitInsightsPeriodSnapshot(
                start: range.start,
                end: range.end,
                progressCount: countTotal,
                progressValue: sanitize(valueTotal),
                target: nil,
                progress: sanitizedProgress,
                progressClamped: sanitizedProgress,
                surplus: 0,
                completionRatio: nil,
                isCompleted: nil,
                activeDays: activeDays
            )
        }

        let clamped = min(sanitizedProgress, target)
        let surplus = max(sanitizedProgress - target, 0)
        let ratio = min(max(safeDivide(sanitizedProgress, target), 0), 1)

        return HabitInsightsPeriodSnapshot(
            start: range.start,
            end: range.end,
            progressCount: countTotal,
            progressValue: sanitize(valueTotal),
            target: target,
            progress: sanitizedProgress,
            progressClamped: clamped,
            surplus: sanitize(surplus),
            completionRatio: ratio,
            isCompleted: sanitizedProgress >= target,
            activeDays: activeDays
        )
    }

    static func paceSnapshot(
        for currentPeriod: HabitInsightsPeriodSnapshot,
        cadence: GoalPeriod,
        anchorUpperBound: Date,
        target: Double?,
        calendar: Calendar
    ) -> HabitInsightsPaceSnapshot {
        let measurement: (name: String, seconds: Double)
        if cadence == .daily {
            measurement = ("hour", 3600)
        } else {
            measurement = ("day", 86400)
        }

        let boundedAnchor = min(max(anchorUpperBound, currentPeriod.start), currentPeriod.end)
        let elapsedSeconds = max(boundedAnchor.timeIntervalSince(currentPeriod.start), 0)
        let remainingSeconds = max(currentPeriod.end.timeIntervalSince(boundedAnchor), 0)

        let elapsedUnits = sanitize(elapsedSeconds / measurement.seconds)
        let remainingUnits = sanitize(remainingSeconds / measurement.seconds)

        let pacePerUnit = safeDivide(currentPeriod.progress, max(elapsedUnits, 0.0001))
        let projectedTotal = sanitize(currentPeriod.progress + (pacePerUnit * remainingUnits))

        let requiredPerUnit: Double?
        if let target, target > 0 {
            requiredPerUnit = safeDivide(max(target - currentPeriod.progress, 0), max(remainingUnits, 1))
        } else {
            requiredPerUnit = nil
        }

        let status: HabitInsightsPaceStatus
        if target == nil {
            status = .paceOnly
        } else if currentPeriod.isCompleted == true {
            status = .completed
        } else if projectedTotal >= (target ?? 0) * projectionTolerance {
            status = .likelyToHitTarget
        } else {
            status = .likelyShort
        }

        return HabitInsightsPaceSnapshot(
            unitName: measurement.name,
            elapsedUnits: elapsedUnits,
            remainingUnits: remainingUnits,
            requiredPerUnit: requiredPerUnit,
            projectedTotal: projectedTotal,
            status: status
        )
    }

    static func streakSnapshot(
        from history: [HabitInsightsPeriodSnapshot],
        goalMode: HabitInsightGoalMode
    ) -> HabitInsightsStreakSnapshot {
        guard goalMode != .openEnded else {
            return HabitInsightsStreakSnapshot(current: 0, longest: 0)
        }

        var current = 0
        for bucket in history.reversed() {
            if bucket.isCompleted == true {
                current += 1
            } else {
                break
            }
        }

        var longest = 0
        var running = 0
        for bucket in history {
            if bucket.isCompleted == true {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }

        return HabitInsightsStreakSnapshot(current: current, longest: longest)
    }

    static func completionHistorySnapshot(
        from history: [HabitInsightsPeriodSnapshot],
        goalMode: HabitInsightGoalMode,
        asOfUpperBound: Date
    ) -> HabitInsightsCompletionHistorySnapshot? {
        guard goalMode != .openEnded else { return nil }

        let eligible = history.filter {
            let ended = $0.end <= asOfUpperBound
            return ended || $0.isCompleted == true
        }

        guard !eligible.isEmpty else {
            return HabitInsightsCompletionHistorySnapshot(completed: 0, total: 0)
        }

        let completed = eligible.filter { $0.isCompleted == true }.count
        return HabitInsightsCompletionHistorySnapshot(completed: completed, total: eligible.count)
    }

    static func trendWindowCount(for cadence: GoalPeriod) -> Int {
        switch cadence {
        case .daily:
            return 30
        case .weekly:
            return 12
        case .monthly:
            return 6
        case .yearly:
            return 5
        }
    }

    static func trendHeading(for cadence: GoalPeriod, windowCount: Int) -> String {
        switch cadence {
        case .daily:
            return "Last \(windowCount) days"
        case .weekly:
            return "Last \(windowCount) weeks"
        case .monthly:
            return "Last \(windowCount) months"
        case .yearly:
            return "Last \(windowCount) years"
        }
    }

    static func trendStarts(
        endingAt currentStart: Date,
        windowCount: Int,
        cadence: GoalPeriod,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> [Date] {
        guard windowCount > 1 else { return [currentStart] }

        var starts = [currentStart]
        var cursor = currentStart

        for _ in 1..<windowCount {
            let previous = cadence.previousPeriodStart(
                before: cursor,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
            starts.append(previous)
            cursor = previous
        }

        return starts.reversed()
    }

    static func headingForCurrentPeriod(_ cadence: GoalPeriod) -> String {
        switch cadence {
        case .daily:
            return "Today"
        case .weekly:
            return "This week"
        case .monthly:
            return "This month"
        case .yearly:
            return "This year"
        }
    }

    static func periodQualifier(_ cadence: GoalPeriod) -> String {
        switch cadence {
        case .daily:
            return "today"
        case .weekly:
            return "this week"
        case .monthly:
            return "this month"
        case .yearly:
            return "this year"
        }
    }

    static func motivationCard(snapshot: HabitInsightsSnapshot) -> MotivationCard {
        switch snapshot.goalMode {
        case .openEnded:
            let previous = snapshot.trendBuckets.dropLast().last
            if let previous, snapshot.currentPeriodSoFar.progress > previous.progress {
                return MotivationCard(
                    message: "You're building momentum. Keep this rhythm going.",
                    tone: .encouragement
                )
            }

            if snapshot.currentPeriodSoFar.progress > 0 {
                return MotivationCard(
                    message: "Good consistency so far this \(snapshot.cadence.unit).",
                    tone: .encouragement
                )
            }

            return MotivationCard(
                message: "This period has been quiet so far. Starting today will rebuild momentum.",
                tone: .nudge
            )

        case .frequency, .cumulative:
            let target = snapshot.currentPeriodSoFar.target ?? 0
            guard target > 0 else {
                return MotivationCard(
                    message: "Keep going. Each entry strengthens your routine.",
                    tone: .encouragement
                )
            }

            if snapshot.currentPeriodSoFar.progress >= target {
                let message = snapshot.currentPeriodSoFar.surplus > 0
                    ? "You're ahead of target. Consistency like this builds real habits."
                    : "Goal achieved for this period."
                return MotivationCard(message: message, tone: .celebration)
            }

            if snapshot.pace.projectedTotal >= target * projectionTolerance {
                return MotivationCard(
                    message: "You're on track to hit your goal. Keep this pace.",
                    tone: .encouragement
                )
            }

            let completionRatio = safeDivide(snapshot.currentPeriodSoFar.progress, target)
            let recoverable = completionRatio >= 0.35 || snapshot.pace.projectedTotal >= target * 0.65
            if recoverable {
                return MotivationCard(
                    message: "A small push will get you back on track. There's still time this \(snapshot.cadence.unit).",
                    tone: .nudge
                )
            }

            return MotivationCard(
                message: "This period has been quiet so far. Starting today would rebuild momentum.",
                tone: .nudge
            )
        }
    }

    static func intentBlock(
        snapshot: HabitInsightsSnapshot,
        habit: Habit
    ) -> HabitInsightsIntentBlock {
        switch snapshot.goalMode {
        case .openEnded:
            let completedTrend = snapshot.trendBuckets.dropLast()
            let secondaryText: String?
            if completedTrend.count >= 2 {
                let best = completedTrend.map(\.progress).max() ?? 0
                let typical = safeDivide(completedTrend.reduce(0) { $0 + $1.progress }, Double(completedTrend.count))
                let bestText = formattedProgress(best, habit: habit, isValueBased: snapshot.isValueBased)
                let typicalText = formattedProgress(typical, habit: habit, isValueBased: snapshot.isValueBased)
                secondaryText = "Best \(snapshot.cadence.unit): \(bestText), typical: \(typicalText)"
            } else {
                secondaryText = nil
            }

            return HabitInsightsIntentBlock(
                heading: "Intent",
                primaryText: shouldShowProjection(snapshot)
                    ? openEndedProjectionText(snapshot: snapshot, habit: habit)
                    : "Keep logging this \(snapshot.cadence.unit) to unlock a reliable projection.",
                secondaryText: secondaryText,
                projectionText: shouldShowProjection(snapshot)
                    ? "Projection is based on pace so far in \(periodQualifier(snapshot.cadence))."
                    : "Projection appears after more activity in this period."
            )

        case .frequency, .cumulative:
            let target = snapshot.currentPeriodSoFar.target ?? 0
            let remaining = max(target - snapshot.currentPeriodSoFar.progress, 0)
            let remainingText = formattedProgress(remaining, habit: habit, isValueBased: snapshot.isValueBased)

            let primaryText: String
            let secondaryText: String?
            if remaining <= 0 {
                primaryText = "You're already ahead of target."
                secondaryText = "Anything extra strengthens the streak."
            } else {
                primaryText = "\(remainingText) remaining \(periodQualifier(snapshot.cadence))."
                secondaryText = requiredPaceText(
                    cadence: snapshot.cadence,
                    pace: snapshot.pace,
                    habit: habit,
                    isValueBased: snapshot.isValueBased
                )
            }

            return HabitInsightsIntentBlock(
                heading: "Intent",
                primaryText: primaryText,
                secondaryText: secondaryText,
                projectionText: targetProjectionText(
                    snapshot: snapshot,
                    habit: habit
                )
            )
        }
    }

    static func requiredPaceText(
        cadence: GoalPeriod,
        pace: HabitInsightsPaceSnapshot,
        habit: Habit,
        isValueBased: Bool
    ) -> String {
        switch cadence {
        case .daily:
            let rate = formattedProgress(max(pace.requiredPerUnit ?? 0, 0), habit: habit, isValueBased: isValueBased)
            return "About \(rate) per remaining hour will reach your goal."
        case .weekly:
            let rate = formattedProgress(max(pace.requiredPerUnit ?? 0, 0), habit: habit, isValueBased: isValueBased)
            return "About \(rate) per day will reach your goal."
        case .monthly:
            let rate = formattedProgress(max(pace.requiredPerUnit ?? 0, 0) * 7, habit: habit, isValueBased: isValueBased)
            return "About \(rate) per week will reach your goal."
        case .yearly:
            let rate = formattedProgress(max(pace.requiredPerUnit ?? 0, 0) * 30, habit: habit, isValueBased: isValueBased)
            return "About \(rate) per month will reach your goal."
        }
    }

    static func shouldShowProjection(_ snapshot: HabitInsightsSnapshot) -> Bool {
        snapshot.pace.elapsedUnits > 1
    }

    static func targetProjectionText(
        snapshot: HabitInsightsSnapshot,
        habit: Habit
    ) -> String {
        guard shouldShowProjection(snapshot) else {
            return "Log a bit more this \(snapshot.cadence.unit) to get a stable projection."
        }

        let projected = formattedProgress(
            snapshot.pace.projectedTotal,
            habit: habit,
            isValueBased: snapshot.isValueBased
        )

        switch snapshot.pace.status {
        case .completed:
            return "At this pace you'll comfortably exceed your goal."
        case .likelyToHitTarget:
            return "At your current pace you'll reach about \(projected)."
        case .likelyShort:
            return "At this pace you'll land around \(projected), so a small boost can close the gap."
        case .paceOnly:
            return "At your current pace you'll reach about \(projected)."
        }
    }

    static func openEndedProjectionText(
        snapshot: HabitInsightsSnapshot,
        habit: Habit
    ) -> String {
        let projected = formattedProgress(
            snapshot.pace.projectedTotal,
            habit: habit,
            isValueBased: snapshot.isValueBased
        )
        let suffix = snapshot.isValueBased ? "" : " sessions"
        return "At your current pace you'll reach about \(projected)\(suffix) by period end."
    }

    static func openEndedValueText(for progress: Double, habit: Habit, isValueBased: Bool) -> String {
        let base = formattedProgress(progress, habit: habit, isValueBased: isValueBased)
        return isValueBased ? base : "\(base) sessions"
    }

    static func patternsBlock(
        cadence: GoalPeriod,
        goalMode: HabitInsightGoalMode,
        periodSnapshots: [HabitInsightsPeriodSnapshot],
        logs: [CanonicalLog],
        calendar: Calendar
    ) -> HabitInsightsPatternBlock {
        guard !logs.isEmpty else {
            return HabitInsightsPatternBlock(
                heading: "Patterns",
                items: ["Keep logging to unlock behaviour patterns."]
            )
        }

        var items: [String] = []

        if logs.count >= weekdayPatternMinimumSampleCount {
            var weekdayCounts: [Int: Int] = [:]
            for log in logs {
                let weekday = calendar.component(.weekday, from: log.timestamp)
                weekdayCounts[weekday, default: 0] += log.frequencyContribution
            }
            if let topWeekday = weekdayCounts.max(by: { $0.value < $1.value })?.key {
                let index = max(0, min(topWeekday - 1, calendar.weekdaySymbols.count - 1))
                items.append("Most common day: \(calendar.weekdaySymbols[index])")
            }
        }

        let timestamped = logs.filter(\.hasTimestamp)
        if timestamped.count >= timeOfDayPatternMinimumSampleCount {
            var buckets: [String: Int] = ["Morning": 0, "Afternoon": 0, "Evening": 0, "Night": 0]
            for log in timestamped {
                let hour = calendar.component(.hour, from: log.timestamp)
                buckets[timeBucket(for: hour), default: 0] += 1
            }
            if let top = buckets.max(by: { $0.value < $1.value })?.key,
               (buckets[top] ?? 0) > 0 {
                items.append("Most common time: \(top)")
            }
        }

        if logs.count >= distributionPatternMinimumSampleCount {
            let activeAvg = safeDivide(
                Double(periodSnapshots.reduce(0) { $0 + $1.activeDays }),
                Double(max(periodSnapshots.count, 1))
            )
            items.append("Typical active days: \(Int(activeAvg.rounded())) days/\(cadence.unit)")
        }

        if goalMode == .frequency && logs.count >= distributionPatternMinimumSampleCount {
            let nonEmpty = periodSnapshots.filter { $0.progressCount > 0 }
            if !nonEmpty.isEmpty {
                // Approximate batching with active days concentration.
                let avgConcentration = safeDivide(
                    nonEmpty.reduce(0.0) { partial, period in
                        let concentration = safeDivide(Double(period.progressCount), Double(max(period.activeDays, 1)))
                        return partial + concentration
                    },
                    Double(nonEmpty.count)
                )
                if avgConcentration >= 2 {
                    items.append("You tend to batch logs into fewer active days")
                }
            }
        }

        if items.isEmpty {
            items = ["Keep logging to unlock behaviour patterns."]
        }

        return HabitInsightsPatternBlock(heading: "Patterns", items: items)
    }

    static func trendPointLabel(
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
            formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        case .yearly:
            formatter.setLocalizedDateFormatFromTemplate("yyyy")
        }

        return formatter.string(from: date)
    }

    static func debugPeriodKey(for date: Date, cadence: GoalPeriod, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone

        switch cadence {
        case .daily:
            formatter.dateFormat = "yyyy-MM-dd"
        case .weekly:
            formatter.dateFormat = "yyyy-'W'ww"
        case .monthly:
            formatter.dateFormat = "yyyy-MM"
        case .yearly:
            formatter.dateFormat = "yyyy"
        }

        return formatter.string(from: date)
    }

    static func debugLines(from snapshot: HabitInsightsSnapshot, calendar: Calendar) -> [String] {
        var lines: [String] = []
        lines.append("Insight Anchor: today (\(formattedDate(snapshot.debug.anchorDate, calendar: calendar)))")
        if let logAnchorDate = snapshot.debug.logAnchorDate {
            lines.append("Log Anchor: \(formattedDate(logAnchorDate, calendar: calendar))")
        } else {
            lines.append("Log Anchor: none")
        }
        lines.append("As-of bound: \(formattedDate(snapshot.debug.asOfUpperBound, calendar: calendar))")
        lines.append("Current Period: \(formattedDate(snapshot.debug.periodStart, calendar: calendar)) → \(formattedDate(snapshot.debug.periodEnd, calendar: calendar))")
        lines.append("Period Progress: count \(snapshot.debug.periodProgressCount), value \(snapshot.debug.periodProgressValue.formatted(.number.precision(.fractionLength(2))))")
        lines.append("Progress so far: count \(snapshot.debug.progressSoFarCount), value \(snapshot.debug.progressSoFarValue.formatted(.number.precision(.fractionLength(2))))")
        if let target = snapshot.debug.target {
            lines.append("Target: \(target.formatted(.number.precision(.fractionLength(2))))")
        } else {
            lines.append("Target: none")
        }
        lines.append("Projected: \(snapshot.debug.projected.formatted(.number.precision(.fractionLength(2))))")
        lines.append("Elapsed units: \(snapshot.debug.elapsedUnits.formatted(.number.precision(.fractionLength(2))))")
        lines.append("Remaining units: \(snapshot.debug.remainingUnits.formatted(.number.precision(.fractionLength(2))))")
        lines.append("Buckets:")
        for row in snapshot.debug.periodRows {
            lines.append("\(row.key): count \(row.countTotal), value \(row.valueTotal.formatted(.number.precision(.fractionLength(2))))")
        }
        return lines
    }

    static func formattedDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func timeBucket(for hour: Int) -> String {
        switch hour {
        case 5..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<22:
            return "Evening"
        default:
            return "Night"
        }
    }

    static func formattedProgress(
        _ value: Double,
        habit: Habit,
        isValueBased: Bool
    ) -> String {
        if !isValueBased {
            return String(Int(value.rounded()))
        }

        let context = ValueFormattingContext(habit: habit)
        let number = HabitValueFormatter.string(for: value, context: context)

        if context.showsUnitSuffix, let unit = habit.trimmedUnit {
            return "\(number) \(unit)"
        }

        return number
    }

    static func sanitize(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    static func safeDivide(_ numerator: Double, _ denominator: Double) -> Double {
        guard denominator > 0 else { return 0 }
        return sanitize(numerator / denominator)
    }
}
