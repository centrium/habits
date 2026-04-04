import Foundation

struct HabitStateScoreService {
    private let calendar: Calendar
    private let streakService: StreakService

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.calendar = calendar
        self.streakService = StreakService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }

    func breakdown(
        for habit: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> HabitStateBreakdown {
        let totalDays = clampedWindowDays(windowDays)
        let today = calendar.startOfDay(for: now)
        let completedDays = completionCount(
            for: habit,
            today: today,
            windowDays: totalDays
        )

        let completionRate = rate(numerator: completedDays, denominator: totalDays)

        let currentStreak = streakService.currentStreak(
            for: habit,
            referenceDate: today
        )

        return HabitStateBreakdown(
            streak: currentStreak,
            completionRate: completionRate,
            completedDays: completedDays,
            totalDays: totalDays,
            state: HabitIdentityStateResolver.resolve(
                completionRate: completionRate,
                hasRecentData: completedDays > 0
            )
        )
    }
}

private extension HabitStateScoreService {
    func completionCount(
        for habit: Habit,
        today: Date,
        windowDays: Int
    ) -> Int {
        var completed = 0

        for offset in 0..<windowDays {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            if streakService.isDayComplete(goal: habit, on: date) {
                completed += 1
            }
        }

        return completed
    }

    func clampedWindowDays(_ value: Int) -> Int {
        min(max(value, 1), 14)
    }

    func rate(numerator: Int, denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(max(numerator, 0)) / Double(denominator)
    }

}
