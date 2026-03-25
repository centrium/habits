import Foundation

struct MomentumScoreService {
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

    func score(
        for habit: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> Int {
        breakdown(for: habit, now: now, windowDays: windowDays).score
    }

    func breakdown(
        for habit: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> MomentumBreakdown {
        let totalDays = clampedWindowDays(windowDays)
        let today = calendar.startOfDay(for: now)
        let completedDays = completionCount(
            for: habit,
            today: today,
            windowDays: totalDays
        )

        let completionRate = rate(numerator: completedDays, denominator: totalDays)
        let gaps = max(totalDays - completedDays, 0)
        let consistency = clamp(
            1 - rate(numerator: gaps, denominator: totalDays),
            lower: 0,
            upper: 1
        )

        let currentStreak = streakService.currentStreak(
            for: habit,
            referenceDate: today
        )
        let streakScore = Double(min(currentStreak, 7)) / 7.0

        let momentum =
            (streakScore * 0.4) +
            (completionRate * 0.4) +
            (consistency * 0.2)
        let score = Int(clamp(momentum, lower: 0, upper: 1) * 100)

        return MomentumBreakdown(
            score: score,
            streak: currentStreak,
            completionRate: completionRate,
            consistency: consistency,
            completedDays: completedDays,
            totalDays: totalDays,
            band: MomentumBand(score: score),
            isMomentumDropping: isMomentumDropping(for: habit, today: today, windowDays: totalDays)
        )
    }
}

private extension MomentumScoreService {
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

    func isMomentumDropping(
        for habit: Habit,
        today: Date,
        windowDays: Int
    ) -> Bool {
        let halfWindow = max(windowDays / 2, 1)
        guard halfWindow > 1 else { return false }

        let recentCompleted = completionCount(
            for: habit,
            today: today,
            windowDays: halfWindow
        )

        guard let previousWindowEnd = calendar.date(byAdding: .day, value: -halfWindow, to: today) else {
            return false
        }
        let previousCompleted = completionCount(
            for: habit,
            today: previousWindowEnd,
            windowDays: halfWindow
        )

        let recentRate = rate(numerator: recentCompleted, denominator: halfWindow)
        let previousRate = rate(numerator: previousCompleted, denominator: halfWindow)
        return recentRate < previousRate
    }

    func clampedWindowDays(_ value: Int) -> Int {
        min(max(value, 1), 14)
    }

    func rate(numerator: Int, denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(max(numerator, 0)) / Double(denominator)
    }

    func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
