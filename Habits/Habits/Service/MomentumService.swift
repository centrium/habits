import Foundation

enum MomentumBand: String {
    case low = "Low Momentum"
    case building = "Building Momentum"
    case strong = "Strong Momentum"
    case high = "High Momentum"

    init(score: Int) {
        switch score {
        case ...30:
            self = .low
        case ...60:
            self = .building
        case ...80:
            self = .strong
        default:
            self = .high
        }
    }
}

struct MomentumBreakdown {
    let score: Int
    let streak: Int
    let completionRate: Double
    let consistency: Double
    let completedDays: Int
    let totalDays: Int
    let band: MomentumBand
    let isMomentumDropping: Bool

    var momentumLabel: String {
        band.rawValue
    }
}

struct MomentumService {
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
        for goal: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> Int {
        breakdown(for: goal, now: now, windowDays: windowDays).score
    }

    func breakdown(
        for goal: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> MomentumBreakdown {
        let totalDays = clampedWindowDays(windowDays)
        let today = calendar.startOfDay(for: now)
        let completedDays = completionCount(
            for: goal,
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
            for: goal,
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
            isMomentumDropping: isMomentumDropping(for: goal, today: today, windowDays: totalDays)
        )
    }
}

private extension MomentumService {
    func completionCount(
        for goal: Habit,
        today: Date,
        windowDays: Int
    ) -> Int {
        var completed = 0

        for offset in 0..<windowDays {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            if streakService.isDayComplete(goal: goal, on: date) {
                completed += 1
            }
        }

        return completed
    }

    func isMomentumDropping(
        for goal: Habit,
        today: Date,
        windowDays: Int
    ) -> Bool {
        let halfWindow = max(windowDays / 2, 1)
        guard halfWindow > 1 else { return false }

        let recentCompleted = completionCount(
            for: goal,
            today: today,
            windowDays: halfWindow
        )

        guard let previousWindowEnd = calendar.date(byAdding: .day, value: -halfWindow, to: today) else {
            return false
        }
        let previousCompleted = completionCount(
            for: goal,
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
