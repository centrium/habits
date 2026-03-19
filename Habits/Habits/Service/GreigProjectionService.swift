import Foundation

struct GreigProjectionResult {
    let goalType: GreigCopyGoalType
    let confidence: ConfidenceLevel
    let totalDaysInPeriod: Int
    let daysElapsed: Int
    let activeDays: Int
    let currentStreak: Int
    let recentActiveDays: Int
    let recentWindowDays: Int
    let totalSoFar: Double
    let dailyAverage: Double?
    let projectedTotal: Double?
    let targetValue: Double?
    let deltaFromGoal: Double?
    let behaviourWindowDays: Int
    let behaviourCompletedDays: Int
    let behaviourCompletionRate: Double
    let recentStreak: Int
    let loggedToday: Bool
}

struct GreigProjectionService {
    private enum Constants {
        static let lowConfidenceDayThreshold = 2
        static let highConfidenceStreakThreshold = 3
        static let minimumBehaviourWindowDays = 7
        static let maximumBehaviourWindowDays = 14
        static let capMultiplier = 1.5
        static let outlierLookbackDays = 28
    }

    private enum ProjectionKind {
        case open
        case frequency
        case cumulative
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func projection(
        for goal: GreigInsightGoal,
        progress: GreigInsightProgress
    ) -> GreigProjectionResult? {
        guard progress.periodEnd > progress.periodStart else { return nil }

        let goalType = goalType(for: goal)
        let kind = projectionKind(for: goal)
        let now = min(max(progress.now, progress.periodStart), progress.periodEnd)

        let periodDayStart = calendar.startOfDay(for: progress.periodStart)
        let periodDayEnd = calendar.startOfDay(for: progress.periodEnd)
        let totalDays = periodDayCount(start: progress.periodStart, end: progress.periodEnd)
        let daysElapsed = elapsedDayCount(start: progress.periodStart, now: now, periodEnd: progress.periodEnd)

        let periodLogs = progress.logs.filter {
            $0.effectiveTimestamp >= periodDayStart &&
                $0.effectiveTimestamp < periodDayEnd &&
                $0.effectiveTimestamp <= now
        }

        let positiveLogs = periodLogs.filter { contribution(for: $0, kind: kind) > 0 }
        let dayTotals = totalsByDay(logs: positiveLogs, kind: kind)
        let activeDays = dayTotals.count
        let totalSoFar = dayTotals.values.reduce(0, +)

        let streak = currentStreak(from: progress.logs, now: now, kind: kind)
        let behaviour = behaviourWindowSummary(
            logs: progress.logs,
            now: now,
            kind: kind
        )
        let recentWindowDays = behaviour.windowDays
        let recentActiveDays = behaviour.completedDays

        let confidence = confidenceLevel(
            activeDays: activeDays,
            currentStreak: streak,
            completedDays: behaviour.completedDays,
            completionRate: behaviour.completionRate,
            recentStreak: behaviour.recentStreak
        )

        guard goalType != .open else {
            return GreigProjectionResult(
                goalType: goalType,
                confidence: confidence,
                totalDaysInPeriod: totalDays,
                daysElapsed: daysElapsed,
                activeDays: activeDays,
                currentStreak: streak,
                recentActiveDays: recentActiveDays,
                recentWindowDays: recentWindowDays,
                totalSoFar: totalSoFar,
                dailyAverage: nil,
                projectedTotal: nil,
                targetValue: nil,
                deltaFromGoal: nil,
                behaviourWindowDays: behaviour.windowDays,
                behaviourCompletedDays: behaviour.completedDays,
                behaviourCompletionRate: behaviour.completionRate,
                recentStreak: behaviour.recentStreak,
                loggedToday: behaviour.loggedToday
            )
        }

        guard activeDays > 0 else {
            return GreigProjectionResult(
                goalType: goalType,
                confidence: confidence,
                totalDaysInPeriod: totalDays,
                daysElapsed: daysElapsed,
                activeDays: activeDays,
                currentStreak: streak,
                recentActiveDays: recentActiveDays,
                recentWindowDays: recentWindowDays,
                totalSoFar: 0,
                dailyAverage: nil,
                projectedTotal: nil,
                targetValue: targetValue(for: goal),
                deltaFromGoal: nil,
                behaviourWindowDays: behaviour.windowDays,
                behaviourCompletedDays: behaviour.completedDays,
                behaviourCompletionRate: behaviour.completionRate,
                recentStreak: behaviour.recentStreak,
                loggedToday: behaviour.loggedToday
            )
        }

        let rawDailyAverage = totalSoFar / Double(activeDays)
        let cappedAverage = cappedDailyAverage(
            rawDailyAverage: rawDailyAverage,
            kind: kind,
            logs: progress.logs,
            now: now
        )
        let projectedTotal = cappedAverage * Double(totalDays)
        let targetValue = targetValue(for: goal)
        let deltaFromGoal = targetValue.map { projectedTotal - $0 }

        return GreigProjectionResult(
            goalType: goalType,
            confidence: confidence,
            totalDaysInPeriod: totalDays,
            daysElapsed: daysElapsed,
            activeDays: activeDays,
            currentStreak: streak,
            recentActiveDays: recentActiveDays,
            recentWindowDays: recentWindowDays,
            totalSoFar: totalSoFar,
            dailyAverage: cappedAverage,
            projectedTotal: projectedTotal,
            targetValue: targetValue,
            deltaFromGoal: deltaFromGoal,
            behaviourWindowDays: behaviour.windowDays,
            behaviourCompletedDays: behaviour.completedDays,
            behaviourCompletionRate: behaviour.completionRate,
            recentStreak: behaviour.recentStreak,
            loggedToday: behaviour.loggedToday
        )
    }
}

private extension GreigProjectionService {
    struct BehaviourWindowSummary {
        let windowDays: Int
        let completedDays: Int
        let completionRate: Double
        let recentStreak: Int
        let loggedToday: Bool
    }

    private func projectionKind(for goal: GreigInsightGoal) -> ProjectionKind {
        switch goal.kind {
        case .open:
            return .open
        case .frequency:
            return .frequency
        case .cumulative:
            return .cumulative
        }
    }

    private func goalType(for goal: GreigInsightGoal) -> GreigCopyGoalType {
        switch goal.kind {
        case .open:
            return .open
        case .frequency:
            return .frequency
        case .cumulative:
            return .cumulative
        }
    }

    private func targetValue(for goal: GreigInsightGoal) -> Double? {
        switch goal.kind {
        case .open:
            return nil
        case .frequency(let target):
            return target
        case .cumulative(let target):
            return target
        }
    }

    private func confidenceLevel(
        activeDays: Int,
        currentStreak: Int,
        completedDays: Int,
        completionRate: Double,
        recentStreak: Int
    ) -> ConfidenceLevel {
        if completedDays <= Constants.lowConfidenceDayThreshold {
            return .low
        }
        if max(currentStreak, recentStreak) >= Constants.highConfidenceStreakThreshold {
            return .high
        }
        if completionRate < 0.4 {
            return .low
        }
        if activeDays <= Constants.lowConfidenceDayThreshold {
            return .low
        }
        return .medium
    }

    private func contribution(
        for log: HabitLog,
        kind: ProjectionKind
    ) -> Double {
        switch kind {
        case .open, .frequency:
            return Double(max(0, log.frequencyContribution))
        case .cumulative:
            return max(0, log.numericValue)
        }
    }

    private func totalsByDay(
        logs: [HabitLog],
        kind: ProjectionKind
    ) -> [Date: Double] {
        var totals: [Date: Double] = [:]

        for log in logs {
            let day = calendar.startOfDay(for: log.effectiveTimestamp)
            totals[day, default: 0] += contribution(for: log, kind: kind)
        }

        return totals
    }

    private func cappedDailyAverage(
        rawDailyAverage: Double,
        kind: ProjectionKind,
        logs: [HabitLog],
        now: Date
    ) -> Double {
        guard let median = recentMedianContribution(kind: kind, logs: logs, now: now), median > 0 else {
            return rawDailyAverage
        }
        return min(rawDailyAverage, median * Constants.capMultiplier)
    }

    private func recentMedianContribution(
        kind: ProjectionKind,
        logs: [HabitLog],
        now: Date
    ) -> Double? {
        let today = calendar.startOfDay(for: now)
        let lookbackStart = calendar.date(
            byAdding: .day,
            value: -(Constants.outlierLookbackDays - 1),
            to: today
        ) ?? today

        let inRange = logs.filter {
            $0.effectiveTimestamp >= lookbackStart &&
                $0.effectiveTimestamp <= now &&
                contribution(for: $0, kind: kind) > 0
        }

        let dayTotals = totalsByDay(logs: inRange, kind: kind)
        let values = dayTotals.values.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return median(values)
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func currentStreak(
        from logs: [HabitLog],
        now: Date,
        kind: ProjectionKind
    ) -> Int {
        let completedDays = Set(
            logs.compactMap { log -> Date? in
                guard log.effectiveTimestamp <= now, contribution(for: log, kind: kind) > 0 else { return nil }
                return calendar.startOfDay(for: log.effectiveTimestamp)
            }
        )

        return StreakService(calendar: calendar).currentStreak(from: completedDays, asOf: now)
    }

    private func behaviourWindowSummary(
        logs: [HabitLog],
        now: Date,
        kind: ProjectionKind
    ) -> BehaviourWindowSummary {
        let completedDays = Set(
            logs.compactMap { log -> Date? in
                guard log.effectiveTimestamp <= now, contribution(for: log, kind: kind) > 0 else { return nil }
                return calendar.startOfDay(for: log.effectiveTimestamp)
            }
        )
        let availableDays = availableBehaviourDays(
            completedDays: completedDays,
            now: now
        )
        let windowDays = min(
            Constants.maximumBehaviourWindowDays,
            max(Constants.minimumBehaviourWindowDays, availableDays)
        )

        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        let windowCompletedDays = completedDays.filter { $0 >= start && $0 <= today }
        let completionCount = windowCompletedDays.count
        let completionRate = Double(completionCount) / Double(max(windowDays, 1))
        let recentStreak = longestStreak(from: windowCompletedDays)
        let loggedToday = windowCompletedDays.contains(today)

        return BehaviourWindowSummary(
            windowDays: windowDays,
            completedDays: completionCount,
            completionRate: completionRate,
            recentStreak: recentStreak,
            loggedToday: loggedToday
        )
    }

    private func availableBehaviourDays(
        completedDays: Set<Date>,
        now: Date
    ) -> Int {
        guard let earliest = completedDays.min() else { return 1 }
        let today = calendar.startOfDay(for: now)
        let raw = calendar.dateComponents([.day], from: earliest, to: today).day ?? 0
        return max(raw + 1, 1)
    }

    private func longestStreak(from completedDays: Set<Date>) -> Int {
        StreakService(calendar: calendar).streakLengths(from: completedDays).max() ?? 0
    }

    private func periodDayCount(start: Date, end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let raw = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(raw, 1)
    }

    private func elapsedDayCount(start: Date, now: Date, periodEnd: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let nowDay = calendar.startOfDay(for: now)
        let raw = calendar.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
        return min(max(raw + 1, 1), periodDayCount(start: start, end: periodEnd))
    }
}
