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

struct StreakStateEngine {
    private enum ResolvedGoalType {
        case open
        case frequency
        case cumulative
    }

    private let calendar: Calendar
    private let weekStartPreference: WeekStartPreference

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.calendar = calendar
        self.weekStartPreference = weekStartPreference
    }

    func streakState(
        for habit: Habit,
        referenceDate: Date = .now,
        progressOverride: Double? = nil,
        isCompleteOverride: Bool? = nil,
        hasActivityOverride: Bool? = nil
    ) -> StreakState {
        let currentInterval = periodRange(for: habit, containing: referenceDate)
        let hasMetCurrentRequirement = requirementMet(
            for: habit,
            in: currentInterval,
            referenceDate: referenceDate,
            progressOverride: progressOverride,
            isCompleteOverride: isCompleteOverride,
            hasActivityOverride: hasActivityOverride
        )
        let currentStreak = currentStreak(
            for: habit,
            referenceDate: referenceDate,
            currentInterval: currentInterval,
            hasMetCurrentRequirement: hasMetCurrentRequirement
        )
        let longestStreak = longestStreak(for: habit, referenceDate: referenceDate)
        let priorPeriodIntact = priorPeriodKeepsStreakIntact(
            for: habit,
            currentIntervalStart: currentInterval.start
        )
        let status: StreakStatus = {
            if hasMetCurrentRequirement {
                return .safe
            }
            if referenceDate < currentInterval.end, priorPeriodIntact {
                return .atRisk
            }
            return .broken
        }()

        return StreakState(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            hasMetRequirementToday: hasMetCurrentRequirement,
            isRequiredToday: isRequiredToday(
                for: habit,
                referenceDate: referenceDate,
                currentInterval: currentInterval,
                hasMetCurrentRequirement: hasMetCurrentRequirement
            ),
            isAtRisk: status == .atRisk,
            isBroken: status == .broken,
            status: status
        )
    }

    func currentStreak(
        for habit: Habit,
        referenceDate: Date = .now
    ) -> Int {
        streakState(for: habit, referenceDate: referenceDate).currentStreak
    }

    func bestStreak(
        for habit: Habit,
        referenceDate: Date = .now
    ) -> Int {
        streakState(for: habit, referenceDate: referenceDate).longestStreak
    }

    private func currentStreak(
        for habit: Habit,
        referenceDate: Date,
        currentInterval: DateInterval,
        hasMetCurrentRequirement: Bool
    ) -> Int {
        var streak = 0
        var cursor = hasMetCurrentRequirement
            ? currentInterval.start
            : previousPeriodStart(for: habit, before: currentInterval.start)

        while let periodStart = cursor, isRelevantPeriod(periodStart, for: habit) {
            let interval = periodRange(for: habit, startingAt: periodStart)
            guard requirementMet(for: habit, in: interval, referenceDate: referenceDate) else {
                break
            }
            streak += 1
            cursor = previousPeriodStart(for: habit, before: periodStart)
        }

        return streak
    }

    private func longestStreak(
        for habit: Habit,
        referenceDate: Date
    ) -> Int {
        let firstPeriodStart = periodRange(for: habit, containing: habit.createdAt).start
        let currentPeriod = periodRange(for: habit, containing: referenceDate)
        var longest = 0
        var active = 0
        var cursor = firstPeriodStart

        while cursor <= currentPeriod.start {
            let interval = periodRange(for: habit, startingAt: cursor)
            let periodClosed = interval.end <= referenceDate
            let includeCurrentOpenPeriod = interval.start == currentPeriod.start &&
                requirementMet(for: habit, in: interval, referenceDate: referenceDate)

            if periodClosed || includeCurrentOpenPeriod {
                if requirementMet(for: habit, in: interval, referenceDate: referenceDate) {
                    active += 1
                    longest = max(longest, active)
                } else {
                    active = 0
                }
            }

            guard let next = nextPeriodStart(for: habit, after: cursor) else {
                break
            }
            cursor = next
        }

        return longest
    }

    private func priorPeriodKeepsStreakIntact(
        for habit: Habit,
        currentIntervalStart: Date
    ) -> Bool {
        guard let previousStart = previousPeriodStart(for: habit, before: currentIntervalStart) else {
            return true
        }
        guard isRelevantPeriod(previousStart, for: habit) else {
            return true
        }
        return requirementMet(
            for: habit,
            in: periodRange(for: habit, startingAt: previousStart),
            referenceDate: currentIntervalStart
        )
    }

    private func requirementMet(
        for habit: Habit,
        in interval: DateInterval,
        referenceDate: Date,
        progressOverride: Double? = nil,
        isCompleteOverride: Bool? = nil,
        hasActivityOverride: Bool? = nil
    ) -> Bool {
        let goalType = resolvedGoalType(for: habit)
        let isCurrentPeriod = periodRange(for: habit, containing: referenceDate).start == interval.start

        if isCurrentPeriod {
            if let isCompleteOverride, goalType != .open {
                return isCompleteOverride
            }

            if let progressOverride, goalType != .open {
                return progressOverride >= 1
            }

            if let hasActivityOverride, goalType == .open {
                return hasActivityOverride
            }
        }

        switch goalType {
        case .open:
            return habit.logs.contains { log in
                log.effectiveTimestamp >= interval.start && log.effectiveTimestamp < interval.end
            }
        case .frequency, .cumulative:
            guard let target = habit.effectiveTargetValue else { return false }
            return habit.progressTotal(in: interval) >= target
        }
    }

    private func isRequiredToday(
        for habit: Habit,
        referenceDate: Date,
        currentInterval: DateInterval,
        hasMetCurrentRequirement: Bool
    ) -> Bool {
        guard !hasMetCurrentRequirement, referenceDate < currentInterval.end else {
            return false
        }

        let goalType = resolvedGoalType(for: habit)
        if habit.goalPeriod == .daily {
            return true
        }

        let today = calendar.startOfDay(for: referenceDate)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return false
        }

        switch goalType {
        case .open:
            return tomorrow >= currentInterval.end
        case .frequency:
            let remainingSessions = max(0, Int(ceil((habit.effectiveTargetValue ?? 0) - habit.progressTotal(in: currentInterval))))
            let remainingDays = max(0, calendar.dateComponents([.day], from: today, to: currentInterval.end).day ?? 0)
            return remainingSessions >= remainingDays
        case .cumulative:
            return tomorrow >= currentInterval.end
        }
    }

    private func resolvedGoalType(for habit: Habit) -> ResolvedGoalType {
        guard habit.hasGoal else { return .open }

        switch habit.goalType {
        case .frequency:
            return .frequency
        case .cumulative:
            return .cumulative
        }
    }

    private func isRelevantPeriod(
        _ periodStart: Date,
        for habit: Habit
    ) -> Bool {
        periodRange(for: habit, startingAt: periodStart).end > habit.createdAt
    }

    private func periodRange(
        for habit: Habit,
        containing date: Date
    ) -> DateInterval {
        habit.goalPeriod.periodRange(
            for: date,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }

    private func periodRange(
        for habit: Habit,
        startingAt start: Date
    ) -> DateInterval {
        let end = nextPeriodStart(for: habit, after: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func previousPeriodStart(
        for habit: Habit,
        before date: Date
    ) -> Date? {
        let previous = habit.goalPeriod.previousPeriodStart(
            before: date,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        return previous < date ? previous : nil
    }

    private func nextPeriodStart(
        for habit: Habit,
        after date: Date
    ) -> Date? {
        let next = habit.goalPeriod.nextPeriodStart(
            after: date,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        return next > date ? next : nil
    }
}
