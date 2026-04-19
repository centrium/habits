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
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let interval = DateInterval(start: dayStart, end: dayEnd)

        if !goal.hasGoal {
            return goal.totalCount(in: interval) > 0
        }

        switch goal.goalType {
        case .frequency:
            guard let target = goal.effectiveTargetValue else { return false }
            return goal.progressTotal(in: interval) >= target
        case .cumulative:
            guard let target = goal.effectiveTargetValue else { return false }
            let periodTotal = goal.totalValue(in: interval)
            return periodTotal >= target
        }
    }

    func currentStreak(
        for goal: Habit,
        referenceDate: Date = .now
    ) -> Int {
        calculateStreak(
            for: goal,
            logs: goal.logs,
            asOf: referenceDate
        ).current
    }

    func bestStreak(
        for goal: Habit,
        through referenceDate: Date = .now
    ) -> Int {
        calculateStreak(
            for: goal,
            logs: goal.logs,
            asOf: referenceDate
        ).best
    }

    func calculateStreak(
        for goal: Habit,
        logs: [HabitLog],
        asOf referenceDate: Date = .now,
        period: DateInterval? = nil
    ) -> StreakResult {
        StreakStateEngine(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).calculateStreak(
            for: goal,
            logs: logs,
            asOf: referenceDate,
            period: period
        )
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
        currentStreak(for: goal, referenceDate: referenceDate)
    }

    func streakLengths(
        for goal: Habit,
        through referenceDate: Date = .now
    ) -> [Int] {
        let completedDays = completedDayStarts(for: goal, through: referenceDate)
        return streakLengths(from: Set(completedDays))
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
    func completedDayStarts(
        for goal: Habit,
        through referenceDate: Date
    ) -> [Date] {
        let days: Set<Date> = Set(
            goal.logs.compactMap { log -> Date? in
                let timestamp = log.effectiveTimestamp
                guard timestamp <= referenceDate else { return nil }
                return calendar.startOfDay(for: timestamp)
            }
        )

        let completed = days.filter { day in
            isDayComplete(goal: goal, on: day)
        }

        return completed.sorted()
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
