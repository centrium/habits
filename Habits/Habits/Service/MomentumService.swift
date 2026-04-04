import Foundation

struct HabitStateBreakdown {
    let streak: Int
    let completionRate: Double
    let completedDays: Int
    let totalDays: Int
    let state: HabitIdentityState
}

struct HabitStateService {
    private let scoreService: HabitStateScoreService

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.scoreService = HabitStateScoreService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }

    func state(
        for goal: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> HabitIdentityState {
        scoreService.breakdown(for: goal, now: now, windowDays: windowDays).state
    }

    func breakdown(
        for goal: Habit,
        now: Date = .now,
        windowDays: Int = 7
    ) -> HabitStateBreakdown {
        scoreService.breakdown(for: goal, now: now, windowDays: windowDays)
    }
}
