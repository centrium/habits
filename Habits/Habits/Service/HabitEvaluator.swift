import Foundation

enum EvaluatedHabitStatus: Equatable {
    case met
    case atRisk
    case broken
}

struct EvaluatedHabitState: Equatable {
    let progress: Double
    let target: Double
    let status: EvaluatedHabitStatus
    let remaining: Double
    let periodLabel: String
    let recentActivity: RecentActivity
}

struct RecentActivity: Equatable {
    let lastActiveDate: Date?
    let daysSinceLastActive: Int?
    let isActiveToday: Bool
    let isActiveRecently: Bool
}

struct HabitEvaluator {
    let calendar: Calendar
    let weekStartPreference: WeekStartPreference

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.calendar = calendar
        self.weekStartPreference = weekStartPreference
    }

    func evaluate(
        habit: Habit,
        asOfDate: Date,
        selectedDateContext: Date? = nil
    ) -> EvaluatedHabitState? {
        guard habit.hasGoal, let target = habit.effectiveTargetValue, target > 0 else {
            return nil
        }

        let asOfDay = calendar.startOfDay(for: asOfDate)
        let window = evaluationWindow(for: habit.goalPeriod, asOf: asOfDay)
        let progress = progress(for: habit, in: window)
        let remaining = max(0, target - progress)
        let status = statusFor(
            progress: progress,
            target: target,
            asOfDay: asOfDay,
            window: window,
            goalPeriod: habit.goalPeriod
        )
        let labelAnchor = selectedDateContext ?? asOfDate
        let periodLabel = habit.goalPeriod.displayLabel(
            for: labelAnchor,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let recentActivity = computeRecentActivity(
            habit: habit,
            asOfDay: asOfDay
        )

        return EvaluatedHabitState(
            progress: progress,
            target: target,
            status: status,
            remaining: remaining,
            periodLabel: periodLabel,
            recentActivity: recentActivity
        )
    }

    func computeRecentActivity(
        habit: Habit,
        asOfDay: Date
    ) -> RecentActivity {
        let daySet = Set(
            habit.logs.map { calendar.startOfDay(for: $0.day) }
        )
        let lastActiveDate = daySet
            .filter { $0 <= asOfDay }
            .max()
        let daysSinceLastActive: Int? = {
            guard let lastActiveDate else { return nil }
            return max(0, calendar.dateComponents([.day], from: lastActiveDate, to: asOfDay).day ?? 0)
        }()
        let isActiveToday = daySet.contains(asOfDay)
        let isActiveRecently = {
            guard let daysSinceLastActive else { return false }
            return daysSinceLastActive <= 2
        }()
        return RecentActivity(
            lastActiveDate: lastActiveDate,
            daysSinceLastActive: daysSinceLastActive,
            isActiveToday: isActiveToday,
            isActiveRecently: isActiveRecently
        )
    }

    private func progress(for habit: Habit, in window: DateInterval) -> Double {
        switch habit.goalType {
        case .frequency:
            return Double(habit.totalCount(in: window))
        case .cumulative:
            return habit.totalValue(in: window)
        }
    }

    private func statusFor(
        progress: Double,
        target: Double,
        asOfDay: Date,
        window: DateInterval,
        goalPeriod: GoalPeriod
    ) -> EvaluatedHabitStatus {
        if progress >= target {
            return .met
        }

        if periodClosed(goalPeriod: goalPeriod, asOfDay: asOfDay, window: window) {
            return .broken
        }
        return .atRisk
    }

    private func periodClosed(
        goalPeriod: GoalPeriod,
        asOfDay: Date,
        window: DateInterval
    ) -> Bool {
        switch goalPeriod {
        case .daily:
            return true
        case .weekly, .monthly, .yearly:
            return asOfDay >= calendar.startOfDay(for: window.end)
        }
    }

    private func evaluationWindow(for period: GoalPeriod, asOf day: Date) -> DateInterval {
        switch period {
        case .daily:
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .weekly:
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let start = calendar.date(byAdding: .day, value: -6, to: day) ?? day
            return DateInterval(start: calendar.startOfDay(for: start), end: end)
        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: day)?.start ?? calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return DateInterval(start: monthStart, end: end)
        case .yearly:
            let monthStart = calendar.dateInterval(of: .month, for: day)?.start ?? calendar.startOfDay(for: day)
            let start = calendar.date(byAdding: .month, value: -11, to: monthStart) ?? monthStart
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return DateInterval(start: start, end: end)
        }
    }
}
