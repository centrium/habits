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

struct HabitComputedState: Equatable {
    let identityState: IdentityState
    let streakState: StreakState
    let rhythmState: RhythmState
    let timingInsight: TimingInsight?
    let completionStats: CompletionStats
}

final class HabitComputationEngine {
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
        // 1) Normalise logs
        let normalizedLogs = normalized(logs: logs, now: now)

        // 2) Compute completion per day (goal-aware)
        let completedDays = completedDayStarts(for: habit, logs: normalizedLogs, now: now)

        // 3) Compute streak (goal-aware)
        let streakState = computedStreakState(
            for: habit,
            logs: normalizedLogs,
            completedDays: completedDays,
            now: now
        )

        // 4) Compute timing (TimeInsightEngine)
        let timingComputation = computeTiming(
            logs: normalizedLogs,
            globalLogs: globalLogs,
            habitName: habit.name,
            habitGoalType: habit.goalType,
            now: now
        )

        let completionStats = completionStats(
            from: normalizedLogs,
            completedDays: completedDays,
            timingDiagnostics: timingComputation.diagnostics,
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
            completedDays: completedDays,
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
        return HabitComputedState(
            identityState: gatedIdentity,
            streakState: streakState,
            rhythmState: rhythmState,
            timingInsight: timingInsight,
            completionStats: completionStats
        )
    }
}

private extension HabitComputationEngine {
    func normalized(logs: [HabitLog], now: Date) -> [HabitLog] {
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

    func completedDayStarts(
        for habit: Habit,
        logs: [HabitLog],
        now: Date
    ) -> Set<Date> {
        let today = calendar.startOfDay(for: now)
        let days = Set(logs.map { calendar.startOfDay(for: $0.day) })

        // Completion invariant: only goal-satisfied days count.
        return Set(days.filter { day in
            guard day <= today else { return false }
            return isDayComplete(for: habit, logs: logs, day: day)
        })
    }

    func isDayComplete(
        for habit: Habit,
        logs: [HabitLog],
        day: Date
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let dayLogs = logs.filter { log in
            let logDay = calendar.startOfDay(for: log.day)
            return logDay >= dayStart && logDay < dayEnd
        }

        if !habit.hasGoal {
            return !dayLogs.isEmpty
        }

        guard let target = habit.effectiveTargetValue else {
            return false
        }

        switch habit.goalType {
        case .frequency:
            let count = dayLogs.reduce(0.0) { total, log in
                total + Double(max(0, log.frequencyContribution))
            }
            return count >= target
        case .cumulative:
            let value = dayLogs.reduce(0.0) { total, log in
                total + max(0, log.numericValue)
            }
            return value >= target
        }
    }

    func computedStreakState(
        for habit: Habit,
        logs: [HabitLog],
        completedDays: Set<Date>,
        now: Date
    ) -> StreakState {
        let engine = StreakStateEngine(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let result = engine.calculateStreak(
            for: habit,
            logs: logs,
            asOf: now,
            period: nil
        )

        let today = calendar.startOfDay(for: now)
        let metToday = completedDays.contains(today)
        let status: StreakStatus = {
            if metToday { return .safe }
            if result.isAtRisk { return .atRisk }
            return .broken
        }()

        return StreakState(
            currentStreak: result.current,
            longestStreak: result.best,
            hasMetRequirementToday: metToday,
            isRequiredToday: !metToday,
            isAtRisk: result.isAtRisk,
            isBroken: result.isBroken,
            status: status
        )
    }

    func completionStats(
        from logs: [HabitLog],
        completedDays: Set<Date>,
        timingDiagnostics: TimeInsightDiagnostics,
        now: Date
    ) -> CompletionStats {
        let today = calendar.startOfDay(for: now)
        let earliestLast14 = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let recentActiveDays = completedDays.filter { $0 >= earliestLast14 && $0 <= today }.count

        return CompletionStats(
            totalLogs: logs.count,
            uniqueCompletedDays: completedDays.count,
            recentActiveDays: recentActiveDays,
            validTimingSamples: timingDiagnostics.uniqueActiveDays
        )
    }

    func rawIdentityState(
        completedDays: Set<Date>,
        now: Date
    ) -> HabitState {
        let today = calendar.startOfDay(for: now)
        let earliestLast14 = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let recentActive = completedDays.filter { $0 >= earliestLast14 && $0 <= today }.count
        let consistency = Int((Double(recentActive) / 14.0) * 100.0)

        let lastCompletedDay = completedDays.max()
        let inactivityDays: Int = {
            guard let lastCompletedDay else { return 0 }
            return max(calendar.dateComponents([.day], from: lastCompletedDay, to: today).day ?? 0, 0)
        }()

        let risk: Double = {
            if completedDays.isEmpty { return 0.2 }
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

    func computeTiming(
        logs: [HabitLog],
        globalLogs: [HabitLog],
        habitName: String,
        habitGoalType: GoalType,
        now: Date
    ) -> TimeInsightComputation {
        let rawHabitLogs = logs.filter { $0.kind == .entry && $0.timestamp != nil }
        let rawGlobalLogs = globalLogs.filter { $0.kind == .entry && $0.timestamp != nil }
        let resolvedGlobal = rawGlobalLogs.isEmpty ? rawHabitLogs : rawGlobalLogs

        return TimeInsightEngine.computeDetails(
            logs: rawHabitLogs,
            globalLogs: resolvedGlobal,
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
}
