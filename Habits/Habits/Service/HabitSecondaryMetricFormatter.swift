import Foundation

enum HabitSecondaryMetricFormatter {
    static func text(
        habit: Habit,
        service: HabitLogService,
        asOf now: Date,
        weekStartPreference: WeekStartPreference
    ) -> String {
        let today = service.calendar.startOfDay(for: now)
        let recent = service.recentActivity(for: habit, asOfDate: today)

        guard habit.hasGoal else {
            return recent.isActiveToday ? "Logged today" : "No activity today"
        }

        guard let evaluated = service.evaluatedState(
            for: habit,
            asOfDate: today,
            selectedDateContext: today,
            weekStartPreference: weekStartPreference
        ) else {
            return "Not yet today"
        }

        if evaluated.recentActivity.lastActiveDate == nil {
            return "No activity yet"
        }

        if evaluated.status == .met, !evaluated.recentActivity.isActiveToday {
            return "Goal complete • \(lastActiveText(evaluated.recentActivity.lastActiveDate))"
        }

        if evaluated.status != .broken, !evaluated.recentActivity.isActiveRecently {
            return "Pick this up again • \(lastActiveText(evaluated.recentActivity.lastActiveDate))"
        }

        if habit.goalPeriod == .daily {
            return evaluated.progress >= evaluated.target ? "Done today" : "Not yet today"
        }

        switch habit.goalType {
        case .frequency:
            let checkIns = max(0, Int(evaluated.progress.rounded(.down)))
            return "\(checkIns) \(checkIns == 1 ? "check-in" : "check-ins") \(frequencyWindowLabel(for: habit.goalPeriod))"
        case .cumulative:
            let current = service.formatValue(max(0, evaluated.progress), for: habit)
            let target = service.formatValue(max(0, evaluated.target), for: habit)
            return "\(current) of \(target) \(cumulativeWindowLabel(for: habit.goalPeriod))"
        }
    }

    private static func frequencyWindowLabel(for period: GoalPeriod) -> String {
        switch period {
        case .daily:
            return "today"
        case .weekly:
            return "in last 7 days"
        case .monthly:
            return "this month"
        case .yearly:
            return "in last 12 months"
        }
    }

    private static func cumulativeWindowLabel(for period: GoalPeriod) -> String {
        switch period {
        case .daily:
            return "today"
        case .weekly:
            return "in last 7 days"
        case .monthly:
            return "this month"
        case .yearly:
            return "in last 12 months"
        }
    }

    private static func lastActiveText(_ date: Date?) -> String {
        guard let date else { return "Last active —" }
        let formatter = Date.FormatStyle().day().month(.abbreviated)
        return "Last active \(date.formatted(formatter))"
    }
}
