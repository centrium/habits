import Foundation

struct StreakService {
    struct Summary {
        let current: Int
        let best: Int

        var isOnStreak: Bool {
            current >= 2
        }
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

    // Goal-type completion rules are centralized here.
    func isDayComplete(
        goal: Habit,
        on date: Date
    ) -> Bool {
        let interval = goal.periodRange(
            for: date,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        if !goal.hasGoal {
            return goal.totalCount(in: interval) > 0
        }

        switch goal.goalType {
        case .frequency:
            guard let target = goal.effectiveTargetValue else { return false }
            return goal.progressTotal(in: interval) >= target
        case .cumulative:
            return goal.totalValue(in: interval) > 0
        }
    }

    func currentStreak(
        for goal: Habit,
        referenceDate: Date = .now
    ) -> Int {
        var streak = 0
        var cursor = periodStart(for: goal, date: referenceDate)

        while isDayComplete(goal: goal, on: cursor) {
            streak += 1
            cursor = previousPeriodStart(for: goal, before: cursor)
        }

        return streak
    }

    func bestStreak(
        for goal: Habit,
        through referenceDate: Date = .now
    ) -> Int {
        streakLengths(for: goal, through: referenceDate).max() ?? 0
    }

    func streak(
        for goal: Habit,
        referenceDate: Date = .now
    ) -> Summary {
        Summary(
            current: currentStreak(for: goal, referenceDate: referenceDate),
            best: bestStreak(for: goal, through: referenceDate)
        )
    }

    func displayStreak(
        for goal: Habit,
        referenceDate: Date = .now
    ) -> Int {
        let activeStreak = currentStreak(for: goal, referenceDate: referenceDate)
        if activeStreak > 0 {
            return activeStreak
        }

        let currentPeriodStart = periodStart(for: goal, date: referenceDate)
        let previousPeriodStart = previousPeriodStart(for: goal, before: currentPeriodStart)
        guard previousPeriodStart < currentPeriodStart else { return 0 }

        return currentStreak(for: goal, referenceDate: previousPeriodStart)
    }

    func streakLengths(
        for goal: Habit,
        through referenceDate: Date = .now
    ) -> [Int] {
        let completedStarts = completedPeriodStarts(for: goal, through: referenceDate)
        return streakLengths(from: completedStarts, cadence: goal.goalPeriod)
    }

    func currentStreak(
        from completionDays: Set<Date>,
        asOf referenceDate: Date = .now
    ) -> Int {
        var day = calendar.startOfDay(for: referenceDate)
        var streak = 0

        while completionDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }

        return streak
    }

    func streakLengths(
        from completionDays: Set<Date>
    ) -> [Int] {
        let sortedDays = completionDays.sorted()
        return streakLengths(
            from: sortedDays
        ) { previous in
            calendar.date(byAdding: .day, value: 1, to: previous)
        }
    }
}

private extension StreakService {
    func periodStart(for goal: Habit, date: Date) -> Date {
        goal.goalPeriod.periodStart(
            for: date,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }

    func previousPeriodStart(for goal: Habit, before date: Date) -> Date {
        goal.goalPeriod.previousPeriodStart(
            before: date,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }

    func completedPeriodStarts(
        for goal: Habit,
        through referenceDate: Date
    ) -> [Date] {
        let periodStarts: Set<Date> = Set(
            goal.logs.compactMap { log -> Date? in
                let timestamp = log.effectiveTimestamp
                guard timestamp <= referenceDate else { return nil }
                return periodStart(for: goal, date: timestamp)
            }
        )

        let completed = periodStarts.filter { start in
            isDayComplete(goal: goal, on: start)
        }

        return completed.sorted()
    }

    func streakLengths(
        from sortedStarts: [Date],
        cadence: GoalPeriod
    ) -> [Int] {
        streakLengths(from: sortedStarts) { previous in
            cadence.nextPeriodStart(
                after: previous,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
        }
    }

    func streakLengths(
        from sortedStarts: [Date],
        next: (Date) -> Date?
    ) -> [Int] {
        guard !sortedStarts.isEmpty else { return [] }

        var lengths: [Int] = []
        var currentLength = 1

        for index in 1..<sortedStarts.count {
            let previous = sortedStarts[index - 1]
            let current = sortedStarts[index]

            if let expectedNext = next(previous), expectedNext == current {
                currentLength += 1
            } else {
                lengths.append(currentLength)
                currentLength = 1
            }
        }

        lengths.append(currentLength)
        return lengths
    }
}
