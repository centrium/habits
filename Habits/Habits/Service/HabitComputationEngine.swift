import Foundation

typealias IdentityState = HabitIdentityState

typealias TimingInsight = PeakTimingSummary

struct CompletionStats: Equatable {
    let totalLogs: Int
    let uniqueCompletedDays: Int
    let recentActiveDays: Int
    let validTimingSamples: Int
}

struct RhythmState: Equatable {
    let rhythm: HabitRhythm?
    let isForming: Bool
    let visualConfidence: Double

    var authoritativePeakHour: Int? {
        guard !isForming else { return nil }
        return rhythm?.peakHour
    }
}

enum Weekday: Int, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

struct WeeklyPattern: Equatable {
    let recentTopDay: Weekday?
    let historicalTopDay: Weekday?
    let weekdayDistribution: [Weekday: Double]
    let weekdayActiveDayCounts: [Weekday: Int]
    let sampleSize: Int
}

struct HabitComputedConsistency: Equatable {
    let percentage: Int
    let daysCompleted: Int
    let daysAvailable: Int
    let windowDays: Int
}

struct HabitComputedState: Equatable {
    let identityState: IdentityState
    let streakState: StreakState
    let consistency: HabitComputedConsistency
    let rhythmState: RhythmState
    let timingInsight: TimingInsight?
    let completionStats: CompletionStats
    let weeklyPattern: WeeklyPattern
}

struct HabitComputationLog: Equatable {
    let id: UUID
    let day: Date
    let effectiveTimestamp: Date
    let createdAt: Date
    let kind: HabitLogKind
    let numericValue: Double
    let frequencyContribution: Int
    let rawTimestamp: Date?
}

final class HabitComputationEngine {
    private static let perfTraceEnabled: Bool = {
#if DEBUG
        ProcessInfo.processInfo.environment["COMPUTED_STATE_PERF_DEBUG"]?.lowercased() == "1"
#else
        false
#endif
    }()

    private let calendar: Calendar
    private let weekStartPreference: WeekStartPreference

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.calendar = calendar
        self.weekStartPreference = weekStartPreference
    }

    func compute(
        habit: Habit,
        logs: [HabitLog],
        globalLogs: [HabitLog] = [],
        now: Date = .now
    ) -> HabitComputedState {
        let logSnapshots = logs.map { log in
            HabitComputationLog(
                id: log.id,
                day: log.day,
                effectiveTimestamp: log.effectiveTimestamp,
                createdAt: log.createdAt,
                kind: log.kind,
                numericValue: log.numericValue,
                frequencyContribution: log.frequencyContribution,
                rawTimestamp: log.timestamp
            )
        }
        return compute(
            habit: habit,
            logSnapshots: logSnapshots,
            timingLogSnapshots: logSnapshots,
            timingGlobalLogSnapshots: globalLogs.map { log in
                HabitComputationLog(
                    id: log.id,
                    day: log.day,
                    effectiveTimestamp: log.effectiveTimestamp,
                    createdAt: log.createdAt,
                    kind: log.kind,
                    numericValue: log.numericValue,
                    frequencyContribution: log.frequencyContribution,
                    rawTimestamp: log.timestamp
                )
            },
            now: now
        )
    }

    func compute(
        habit: Habit,
        logSnapshots: [HabitComputationLog],
        timingLogSnapshots: [HabitComputationLog],
        timingGlobalLogSnapshots: [HabitComputationLog] = [],
        now: Date = .now
    ) -> HabitComputedState {
        let startedAt = CFAbsoluteTimeGetCurrent()
        LoggingPerformanceMonitor.assertHeavyPathOffMainThread(#function)
        // 1) Normalise logs
        let normalizedLogs = normalized(logs: logSnapshots, now: now)

        // 2) Compute evaluator-driven successful days
        let successfulDays = successfulDayStarts(for: habit, logs: normalizedLogs, now: now)

        // 3) Compute streak (goal-aware)
        let streakState = computedStreakState(
            for: habit,
            successfulDays: successfulDays,
            now: now
        )

        // 4) Compute timing (TimeInsightEngine)
        let timingComputation = computeTiming(
            logs: timingLogSnapshots,
            globalLogs: timingGlobalLogSnapshots,
            habitName: habit.name,
            habitGoalType: habit.goalType,
            now: now
        )

        let completionStats = completionStats(
            from: normalizedLogs,
            successfulDays: successfulDays,
            timingDiagnostics: timingComputation.diagnostics,
            now: now
        )
        let consistency = computedConsistency(
            successfulDays: successfulDays,
            createdAt: habit.createdAt,
            now: now
        )
        let weeklyPattern = computeWeeklyPattern(
            logs: normalizedLogs,
            goalType: habit.goalType,
            now: now
        )

        let timingInsight: TimingInsight? = {
            guard completionStats.validTimingSamples >= 5 else { return nil }
            return PeakTimingSummary(
                peakHour: timingComputation.result.peakHour,
                confidence: timingComputation.result.confidence,
                uniqueEventCount: timingComputation.diagnostics.uniqueEventCount,
                uniqueActiveDays: timingComputation.diagnostics.uniqueActiveDays
            )
        }()

        let rhythm = buildRhythm(
            from: timingComputation,
            lastUpdated: now
        )
        let rhythmState = RhythmState(
            rhythm: rhythm,
            isForming: completionStats.validTimingSamples < 5,
            visualConfidence: completionStats.validTimingSamples < 5
                ? min(rhythm.confidence, 0.2)
                : rhythm.confidence
        )

        // 5) Compute raw identity
        let rawIdentity = rawIdentityState(
            successfulDays: successfulDays,
            now: now
        )

        // 6) APPLY IDENTITY GATING (hard caps)
        let gatedIdentity = IdentityStateEngine.gatedIdentityState(
            rawState: rawIdentity,
            totalLogs: completionStats.totalLogs,
            uniqueDays: completionStats.uniqueCompletedDays,
            activeDaysLast14: completionStats.recentActiveDays
        ).identityState

        // 7) Assemble snapshot
        let state = HabitComputedState(
            identityState: gatedIdentity,
            streakState: streakState,
            consistency: consistency,
            rhythmState: rhythmState,
            timingInsight: timingInsight,
            completionStats: completionStats,
            weeklyPattern: weeklyPattern
        )

        if Self.perfTraceEnabled {
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
            print(
                String(
                    format: "COMPUTED_STATE_PERF: habit=%@ input=%d normalized=%d completedDays=%d timingHabit=%d timingGlobal=%d elapsedMs=%.1f",
                    habit.id.uuidString,
                    logSnapshots.count,
                    normalizedLogs.count,
                    successfulDays.count,
                    timingLogSnapshots.count,
                    timingGlobalLogSnapshots.count,
                    elapsedMs
                )
            )
        }

        return state
    }

}

private extension HabitComputationEngine {
    func normalized(logs: [HabitComputationLog], now: Date) -> [HabitComputationLog] {
        let today = calendar.startOfDay(for: now)
        return logs
            .filter { calendar.startOfDay(for: $0.effectiveTimestamp) <= today }
            .sorted { lhs, rhs in
                if lhs.effectiveTimestamp == rhs.effectiveTimestamp {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.effectiveTimestamp < rhs.effectiveTimestamp
            }
    }

    func successfulDayStarts(
        for habit: Habit,
        logs: [HabitComputationLog],
        now: Date
    ) -> Set<Date> {
        let today = calendar.startOfDay(for: now)
        let firstLogDay = logs.map { calendar.startOfDay(for: $0.day) }.min()
        let startDay = min(calendar.startOfDay(for: habit.createdAt), firstLogDay ?? today)
        guard startDay <= today else { return [] }

        let evaluator = HabitEvaluator(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let dayActivity = Set(logs.map { calendar.startOfDay(for: $0.day) })

        var successful: Set<Date> = []
        var cursor = startDay
        while cursor <= today {
            let isSuccessful: Bool
            if habit.hasGoal {
                let hasMeaningfulActivity = dayActivity.contains(cursor)
                isSuccessful = evaluatorStatus(
                    evaluator: evaluator,
                    habit: habit,
                    day: cursor
                ) != .broken && hasMeaningfulActivity
            } else {
                isSuccessful = dayActivity.contains(cursor)
            }

            if isSuccessful {
                successful.insert(cursor)
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return successful
    }

    func computedStreakState(
        for habit: Habit,
        successfulDays: Set<Date>,
        now: Date
    ) -> StreakState {
        let evaluator = HabitEvaluator(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let today = calendar.startOfDay(for: now)
        let metToday = successfulDays.contains(today)
        let todayStatus = evaluatorStatus(
            evaluator: evaluator,
            habit: habit,
            day: today
        )

        let currentStreak = streakLengthEnding(
            at: today,
            successfulDays: successfulDays
        )
        let longestStreak = longestRunLength(in: successfulDays)

        let status: StreakStatus = {
            switch todayStatus {
            case .met:
                return .safe
            case .atRisk:
                return .atRisk
            case .broken:
                return .broken
            case .none:
                return metToday ? .safe : .broken
            }
        }()

        return StreakState(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            hasMetRequirementToday: metToday,
            isRequiredToday: !metToday,
            isAtRisk: status == .atRisk,
            isBroken: status == .broken,
            status: status
        )
    }

    func completionStats(
        from logs: [HabitComputationLog],
        successfulDays: Set<Date>,
        timingDiagnostics: TimeInsightDiagnostics,
        now: Date
    ) -> CompletionStats {
        let today = calendar.startOfDay(for: now)
        let earliestLast14 = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let recentActiveDays = successfulDays.filter { $0 >= earliestLast14 && $0 <= today }.count

        return CompletionStats(
            totalLogs: logs.count,
            uniqueCompletedDays: successfulDays.count,
            recentActiveDays: recentActiveDays,
            validTimingSamples: timingDiagnostics.uniqueEventCount
        )
    }

    func computedConsistency(
        successfulDays: Set<Date>,
        createdAt: Date,
        now: Date
    ) -> HabitComputedConsistency {
        let today = calendar.startOfDay(for: now)
        let windowDays = 7
        let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        let trackingStart = min(calendar.startOfDay(for: createdAt), today)
        let effectiveStart = max(windowStart, trackingStart)
        let daysAvailable = daySpan(start: effectiveStart, end: today)
        let daysCompleted = successfulDays.filter { $0 >= effectiveStart && $0 <= today }.count
        let adherenceRate = Double(daysCompleted) / Double(max(1, daysAvailable))
        return HabitComputedConsistency(
            percentage: Int((min(max(adherenceRate, 0), 1) * 100).rounded()),
            daysCompleted: daysCompleted,
            daysAvailable: max(1, daysAvailable),
            windowDays: windowDays
        )
    }

    func computeWeeklyPattern(
        logs: [HabitComputationLog],
        goalType: GoalType,
        now: Date
    ) -> WeeklyPattern {
        let today = calendar.startOfDay(for: now)
        let recentWindowStart = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let recentLogs = logs.filter { log in
            let day = calendar.startOfDay(for: log.effectiveTimestamp)
            return day >= recentWindowStart && day <= today
        }
        let historicalLogs = logs.filter { log in
            let day = calendar.startOfDay(for: log.effectiveTimestamp)
            return day <= today
        }

        let recentStats = weekdayStats(
            from: recentLogs,
            goalType: goalType
        )
        let historicalStats = weekdayStats(
            from: historicalLogs,
            goalType: goalType
        )
        let distribution = blendedWeekdayDistribution(from: recentStats)

        return WeeklyPattern(
            recentTopDay: mostFrequentDay(from: distribution),
            historicalTopDay: mostFrequentDay(from: blendedWeekdayDistribution(from: historicalStats)),
            weekdayDistribution: distribution,
            weekdayActiveDayCounts: recentStats.activeDayCounts,
            sampleSize: recentStats.sampleSize
        )
    }

    func weekdayStats(
        from logs: [HabitComputationLog],
        goalType: GoalType
    ) -> WeekdayStats {
        let qualifyingLogs = logs.filter { intensityContribution(for: $0, goalType: goalType) > 0 }
        let activeDayStarts = Set(qualifyingLogs.map { calendar.startOfDay(for: $0.effectiveTimestamp) })
        let activeDayCounts = weekdayCounts(for: activeDayStarts)
        let sampleSize = activeDayStarts.count
        let intensityTotals = qualifyingLogs.reduce(into: [Weekday: Double]()) { result, log in
            let weekdayNumber = calendar.component(.weekday, from: log.effectiveTimestamp)
            guard let weekday = Weekday(rawValue: weekdayNumber) else { return }
            result[weekday, default: 0] += intensityContribution(for: log, goalType: goalType)
        }
        return WeekdayStats(
            activeDayCounts: activeDayCounts,
            intensityTotals: intensityTotals,
            sampleSize: sampleSize
        )
    }

    func blendedWeekdayDistribution(
        from stats: WeekdayStats,
        consistencyWeight: Double = 0.7,
        intensityWeight: Double = 0.3
    ) -> [Weekday: Double] {
        let maxIntensity = max(stats.intensityTotals.values.max() ?? 0, 0)
        return Weekday.allCases.reduce(into: [:]) { result, weekday in
            let activeDayCount = stats.activeDayCounts[weekday, default: 0]
            let activeDayScore: Double = {
                guard stats.sampleSize > 0 else { return 0 }
                return Double(activeDayCount) / Double(stats.sampleSize)
            }()
            let intensity = stats.intensityTotals[weekday, default: 0]
            let normalizedIntensity = maxIntensity > 0 ? intensity / maxIntensity : 0
            result[weekday] = (consistencyWeight * activeDayScore) + (intensityWeight * normalizedIntensity)
        }
    }

    func intensityContribution(
        for log: HabitComputationLog,
        goalType: GoalType
    ) -> Double {
        switch goalType {
        case .frequency:
            return Double(max(0, log.frequencyContribution))
        case .cumulative:
            return max(0, log.numericValue)
        }
    }

    func weekdayCounts(for dayStarts: Set<Date>) -> [Weekday: Int] {
        dayStarts.reduce(into: [Weekday: Int]()) { result, day in
            let weekdayNumber = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayNumber) else { return }
            result[weekday, default: 0] += 1
        }
    }

    func mostFrequentDay(from scores: [Weekday: Double]) -> Weekday? {
        guard !scores.isEmpty else { return nil }

        let sorted = scores.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return weekdayTieBreakRank(lhs.key) < weekdayTieBreakRank(rhs.key)
            }
            return lhs.value > rhs.value
        }

        guard let best = sorted.first else { return nil }
        guard best.value > 0 else { return nil }
        if sorted.count > 1, abs(sorted[1].value - best.value) < 0.000_001 {
            // No clear winner in this window.
            return nil
        }
        return best.key
    }

    func weekdayTieBreakRank(_ weekday: Weekday) -> Int {
        switch weekday {
        case .monday:
            return 0
        case .tuesday:
            return 1
        case .wednesday:
            return 2
        case .thursday:
            return 3
        case .friday:
            return 4
        case .saturday:
            return 5
        case .sunday:
            return 6
        }
    }

    func rawIdentityState(
        successfulDays: Set<Date>,
        now: Date
    ) -> HabitState {
        let today = calendar.startOfDay(for: now)
        let earliestLast14 = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let recentActive = successfulDays.filter { $0 >= earliestLast14 && $0 <= today }.count
        let consistency = Int((Double(recentActive) / 14.0) * 100.0)

        let lastCompletedDay = successfulDays.max()
        let inactivityDays: Int = {
            guard let lastCompletedDay else { return 0 }
            return max(calendar.dateComponents([.day], from: lastCompletedDay, to: today).day ?? 0, 0)
        }()

        let risk: Double = {
            if successfulDays.isEmpty { return 0.2 }
            if inactivityDays >= 14 { return 0.85 }
            if inactivityDays >= 7 { return 0.65 }
            if recentActive <= 1 { return 0.5 }
            return 0.2
        }()

        return HabitStateResolver.deriveState(
            consistency: consistency,
            habitStrength: min(max(Double(recentActive) / 14.0, 0), 1),
            risk: risk,
            streakState: "derived"
        )
    }

    func evaluatorStatus(
        evaluator: HabitEvaluator,
        habit: Habit,
        day: Date
    ) -> EvaluatedHabitStatus? {
        let dayStart = calendar.startOfDay(for: day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let endOfDay = nextDay.addingTimeInterval(-1)
        return evaluator.evaluate(
            habit: habit,
            asOfDate: endOfDay,
            selectedDateContext: dayStart
        )?.status
    }

    func streakLengthEnding(
        at endDay: Date,
        successfulDays: Set<Date>
    ) -> Int {
        var cursor = endDay
        var length = 0
        while successfulDays.contains(cursor) {
            length += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return length
    }

    func longestRunLength(in successfulDays: Set<Date>) -> Int {
        let ordered = successfulDays.sorted()
        guard !ordered.isEmpty else { return 0 }
        var best = 0
        var run = 0
        var previous: Date?
        for day in ordered {
            if let previous,
               let expected = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(day, inSameDayAs: expected) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    func computeTiming(
        logs: [HabitComputationLog],
        globalLogs: [HabitComputationLog],
        habitName: String,
        habitGoalType: GoalType,
        now: Date
    ) -> TimeInsightComputation {
        let rawHabitLogs = logs.filter { $0.kind == .entry && $0.rawTimestamp != nil }
        let rawGlobalLogs = globalLogs.filter { $0.kind == .entry && $0.rawTimestamp != nil }
        let resolvedGlobal = rawGlobalLogs.isEmpty ? rawHabitLogs : rawGlobalLogs
        let habitTimingLogs = rawHabitLogs.compactMap { snapshot -> HabitLog? in
            guard let timestamp = snapshot.rawTimestamp else { return nil }
            return HabitLog(
                timestamp: timestamp,
                value: snapshot.numericValue,
                createdAt: snapshot.createdAt,
                calendar: calendar
            )
        }
        let globalTimingLogs = resolvedGlobal.compactMap { snapshot -> HabitLog? in
            guard let timestamp = snapshot.rawTimestamp else { return nil }
            return HabitLog(
                timestamp: timestamp,
                value: snapshot.numericValue,
                createdAt: snapshot.createdAt,
                calendar: calendar
            )
        }

        return TimeInsightEngine.computeDetails(
            logs: habitTimingLogs,
            globalLogs: globalTimingLogs,
            allowGlobalBlending: false,
            debugLabel: "\(habitName) | goalType=\(habitGoalType.rawValue)",
            now: now,
            calendar: calendar
        )
    }

    func buildRhythm(
        from computation: TimeInsightComputation,
        lastUpdated: Date
    ) -> HabitRhythm {
        let insight = generateRhythmInsight(from: computation.result)
        let consistency = rhythmConsistencyScore(
            from: computation.result.hourlyScores,
            peakHour: computation.result.peakHour
        )

        return HabitRhythm(
            timeInsight: computation.result,
            dipStart: insight.lowRange.0,
            dipEnd: insight.lowRange.1,
            consistencyScore: consistency,
            uniqueEventCount: computation.diagnostics.uniqueEventCount,
            uniqueActiveDays: computation.diagnostics.uniqueActiveDays,
            lastUpdated: lastUpdated
        )
    }

    func rhythmConsistencyScore(
        from hourlyScores: [Double],
        peakHour: Int
    ) -> Double {
        guard !hourlyScores.isEmpty else { return 0 }

        let sorted = hourlyScores.sorted(by: >)
        let primary = sorted.first ?? 0
        let secondary = sorted.dropFirst().first ?? 0
        let separation = max(0, primary - secondary)
        let concentration = neighborhoodAverage(around: peakHour, scores: hourlyScores)
        return min(1, max(0, (separation * 0.6) + (concentration * 0.4)))
    }

    func neighborhoodAverage(around hour: Int, scores: [Double]) -> Double {
        guard scores.count == 24 else { return 0 }
        let previous = scores[(hour + 23) % 24]
        let current = scores[hour]
        let next = scores[(hour + 1) % 24]
        return (previous + current + next) / 3.0
    }

    func daySpan(start: Date, end: Date) -> Int {
        let elapsedDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
        return max(1, elapsedDays + 1)
    }
}

private struct WeekdayStats {
    let activeDayCounts: [Weekday: Int]
    let intensityTotals: [Weekday: Double]
    let sampleSize: Int
}
