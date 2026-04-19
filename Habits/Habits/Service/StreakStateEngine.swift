import Foundation

struct StreakState: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let hasMetRequirementToday: Bool
    let isRequiredToday: Bool
    let isAtRisk: Bool
    let isBroken: Bool
    let status: StreakStatus
}

enum StreakStatus: Equatable {
    case safe
    case atRisk
    case broken
}

struct StreakResult: Equatable {
    let current: Int
    let best: Int
    let lastCompletedDate: Date?
    let isAtRisk: Bool
    let isBroken: Bool
}

struct StreakStateEngine {
    private let calendar: Calendar
    private let weekStartPreference: WeekStartPreference

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.calendar = calendar
        self.weekStartPreference = weekStartPreference
    }

    func calculateStreak(
        for habit: Habit,
        logs: [HabitLog],
        asOf date: Date,
        period: DateInterval? = nil
    ) -> StreakResult {
        let asOfDay = calendar.startOfDay(for: date)
        let window = calculationWindow(
            logs: logs,
            asOfDay: asOfDay,
            period: period
        )

        guard let window else {
            return StreakResult(
                current: 0,
                best: 0,
                lastCompletedDate: nil,
                isAtRisk: false,
                isBroken: true
            )
        }

        let summary = successSummary(
            for: habit,
            logs: logs,
            from: window.startDay,
            through: window.endDay
        )

        let todaySuccessful = summary.successfulDays.contains(window.endDay)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: window.endDay)
        let previousSuccessful = previousDay.map { summary.successfulDays.contains($0) } ?? false

        return StreakResult(
            current: summary.current,
            best: summary.best,
            lastCompletedDate: summary.lastCompletedDate,
            isAtRisk: !todaySuccessful && previousSuccessful,
            isBroken: !todaySuccessful && !previousSuccessful
        )
    }

    func calculateStreak(
        for habit: Habit,
        asOf date: Date,
        period: DateInterval? = nil
    ) -> StreakResult {
        calculateStreak(
            for: habit,
            logs: habit.logs,
            asOf: date,
            period: period
        )
    }

    func streakState(
        for habit: Habit,
        referenceDate: Date = .now,
        progressOverride: Double? = nil,
        isCompleteOverride: Bool? = nil,
        hasActivityOverride: Bool? = nil
    ) -> StreakState {
        let asOfDay = calendar.startOfDay(for: referenceDate)
        let base = calculateStreak(
            for: habit,
            logs: habit.logs,
            asOf: referenceDate,
            period: nil
        )

        let overriddenTodaySuccess = resolvedTodayOverride(
            for: habit,
            progressOverride: progressOverride,
            isCompleteOverride: isCompleteOverride,
            hasActivityOverride: hasActivityOverride
        )

        guard let overriddenTodaySuccess else {
            return state(from: base, hasMetRequirementToday: !base.isAtRisk && !base.isBroken)
        }

        let previousDay = calendar.date(byAdding: .day, value: -1, to: asOfDay) ?? asOfDay
        let previous = calculateStreak(
            for: habit,
            logs: habit.logs,
            asOf: previousDay,
            period: nil
        )

        let current = overriddenTodaySuccess ? (previous.current + 1) : previous.current
        let best = max(base.best, current)
        let lastCompletedDate: Date? = {
            if overriddenTodaySuccess { return asOfDay }
            if base.lastCompletedDate == asOfDay { return previous.lastCompletedDate }
            return base.lastCompletedDate
        }()
        let result = StreakResult(
            current: current,
            best: best,
            lastCompletedDate: lastCompletedDate,
            isAtRisk: !overriddenTodaySuccess && previous.current > 0,
            isBroken: !overriddenTodaySuccess && previous.current == 0
        )

        return state(from: result, hasMetRequirementToday: overriddenTodaySuccess)
    }

    func currentStreak(
        for habit: Habit,
        referenceDate: Date = .now
    ) -> Int {
        calculateStreak(for: habit, logs: habit.logs, asOf: referenceDate).current
    }

    func bestStreak(
        for habit: Habit,
        referenceDate: Date = .now
    ) -> Int {
        calculateStreak(for: habit, logs: habit.logs, asOf: referenceDate).best
    }
}

private extension StreakStateEngine {
    struct CalculationWindow {
        let startDay: Date
        let endDay: Date
    }

    struct SuccessSummary {
        let current: Int
        let best: Int
        let lastCompletedDate: Date?
        let successfulDays: Set<Date>
    }

    func state(
        from result: StreakResult,
        hasMetRequirementToday: Bool
    ) -> StreakState {
        let status: StreakStatus = {
            if hasMetRequirementToday { return .safe }
            if result.isAtRisk { return .atRisk }
            return .broken
        }()

        return StreakState(
            currentStreak: result.current,
            longestStreak: result.best,
            hasMetRequirementToday: hasMetRequirementToday,
            isRequiredToday: !hasMetRequirementToday,
            isAtRisk: result.isAtRisk,
            isBroken: result.isBroken,
            status: status
        )
    }

    func resolvedTodayOverride(
        for habit: Habit,
        progressOverride: Double?,
        isCompleteOverride: Bool?,
        hasActivityOverride: Bool?
    ) -> Bool? {
        if !habit.hasGoal {
            return hasActivityOverride
        }

        if let isCompleteOverride {
            return isCompleteOverride
        }

        if let progressOverride {
            return progressOverride >= 1
        }

        return nil
    }

    func calculationWindow(
        logs: [HabitLog],
        asOfDay: Date,
        period: DateInterval?
    ) -> CalculationWindow? {
        let firstLogDay = logs
            .map(\.day)
            .map { calendar.startOfDay(for: $0) }
            .min()

        if let period {
            let periodStartDay = calendar.startOfDay(for: period.start)
            let periodLastDay = resolvedPeriodLastDay(for: period)
            guard periodStartDay <= periodLastDay else { return nil }
            let endDay = min(asOfDay, periodLastDay)
            guard periodStartDay <= endDay else { return nil }
            return CalculationWindow(startDay: periodStartDay, endDay: endDay)
        }

        guard let firstLogDay, firstLogDay <= asOfDay else { return nil }
        return CalculationWindow(startDay: firstLogDay, endDay: asOfDay)
    }

    func resolvedPeriodLastDay(for period: DateInterval) -> Date {
        let endStartOfDay = calendar.startOfDay(for: period.end)
        let endIsStartOfDay = period.end == endStartOfDay
        if endIsStartOfDay {
            return calendar.date(byAdding: .day, value: -1, to: endStartOfDay) ?? endStartOfDay
        }
        return endStartOfDay
    }

    func successSummary(
        for habit: Habit,
        logs: [HabitLog],
        from startDay: Date,
        through endDay: Date
    ) -> SuccessSummary {
        var frequencyByDay: [Date: Int] = [:]
        var cumulativeByDay: [Date: Double] = [:]
        var logsByDay: [Date: [HabitLog]] = [:]

        for log in logs {
            let openGoalDay = calendar.startOfDay(for: log.day)
            if openGoalDay >= startDay, openGoalDay <= endDay {
                logsByDay[openGoalDay, default: []].append(log)
            }

            // Streak math should follow the habit's logical day, matching progress/goal completion.
            let goalContributionDay = calendar.startOfDay(for: log.day)
            guard goalContributionDay >= startDay, goalContributionDay <= endDay else { continue }

            frequencyByDay[goalContributionDay, default: 0] += max(0, log.frequencyContribution)
            cumulativeByDay[goalContributionDay, default: 0] += max(0, log.numericValue)
        }

        let frequencyTarget = Int(ceil(habit.effectiveTargetValue ?? 1))
        let cumulativeTarget = habit.targetValue ?? 0

        var successfulDays: Set<Date> = []
        var cursor = startDay
        while cursor <= endDay {
            let isSuccessful: Bool = {
                if !habit.hasGoal {
                    // Open goals are successful when there is at least one log on that day.
                    return !(logsByDay[cursor]?.isEmpty ?? true)
                }

                switch habit.goalType {
                case .frequency:
                    return frequencyByDay[cursor, default: 0] >= max(1, frequencyTarget)
                case .cumulative:
                    return cumulativeByDay[cursor, default: 0] >= max(0, cumulativeTarget)
                }
            }()

            if isSuccessful {
                successfulDays.insert(cursor)
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        var best = 0
        var run = 0
        var lastCompletedDate: Date?
        cursor = startDay
        while cursor <= endDay {
            if successfulDays.contains(cursor) {
                run += 1
                best = max(best, run)
                lastCompletedDate = cursor
            } else {
                run = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        var current = 0
        cursor = endDay
        while cursor >= startDay, successfulDays.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return SuccessSummary(
            current: current,
            best: best,
            lastCompletedDate: lastCompletedDate,
            successfulDays: successfulDays
        )
    }
}
