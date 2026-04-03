import XCTest
@testable import Habits

final class GlobalInsightsServiceTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testSnapshotAggregatesRiskCountBestStreakAndStripSummary() {
        let now = TestDateFactory.date(2026, 3, 20, hour: 18, calendar: calendar)

        let strongHabit = TestHabitFactory.frequency(
            name: "Workout",
            createdAt: TestDateFactory.date(2026, 3, 10, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 17, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 18, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 19, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 20, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let atRiskHabit = TestHabitFactory.frequency(
            name: "Read",
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let snapshot = makeService().snapshot(for: [strongHabit, atRiskHabit], now: now)

        XCTAssertEqual(snapshot?.metrics.atRiskCount, 1)
        XCTAssertEqual(snapshot?.metrics.bestCurrentStreak, 4)
        XCTAssertEqual(snapshot?.stripSummary.secondarySuffix, "1 needs attention")
    }

    func testBestDayOfWeekCountsCompletedHabitDaysInsteadOfRawLogs() {
        let now = TestDateFactory.date(2026, 3, 18, hour: 12, calendar: calendar)
        let monday = TestDateFactory.date(2026, 3, 16, hour: 8, calendar: calendar)
        let tuesdayMorning = TestDateFactory.date(2026, 3, 17, hour: 8, calendar: calendar)
        let tuesdayEvening = TestDateFactory.date(2026, 3, 17, hour: 18, calendar: calendar)

        let cumulativeHabit = TestHabitFactory.cumulative(
            name: "Deep Work",
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: monday, value: 25),
                .init(timestamp: monday.addingTimeInterval(60 * 60), value: 25),
                .init(timestamp: tuesdayMorning, value: 30),
            ],
            calendar: calendar
        )

        let frequencyHabit = TestHabitFactory.frequency(
            name: "Walk",
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: tuesdayEvening, value: 1),
            ],
            calendar: calendar
        )

        let snapshot = makeService().snapshot(for: [cumulativeHabit, frequencyHabit], now: now)

        XCTAssertEqual(snapshot?.metrics.bestDayOfWeek, "Tuesday")
    }

    func testTopHabitRankingPrioritizesRiskThenProgressThenConsistency() {
        let now = TestDateFactory.date(2026, 3, 20, hour: 18, calendar: calendar)

        let atRisk = TestHabitFactory.frequency(
            name: "At Risk",
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let nearGoal = TestHabitFactory.frequency(
            name: "Near Goal",
            period: .weekly,
            target: 4,
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 16, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 17, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 18, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let strong = TestHabitFactory.frequency(
            name: "Strong",
            createdAt: TestDateFactory.date(2026, 3, 11, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 13, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 14, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 15, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 16, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 17, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 18, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 19, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 20, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let filler = TestHabitFactory.openEnded(
            name: "Filler",
            createdAt: TestDateFactory.date(2026, 3, 10, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 19, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let snapshot = makeService().snapshot(for: [strong, atRisk, filler, nearGoal], now: now)

        XCTAssertEqual(snapshot?.topHabits.map(\.name), ["At Risk", "Filler", "Strong"])
        XCTAssertEqual(snapshot?.topHabits.map(\.statusLabel), ["Starting", "Starting", "Holding"])
    }

    func testGreigProjectionUsesMonthlyCompletedSessionsAndWeeklyLift() {
        let now = TestDateFactory.date(2026, 3, 16, hour: 18, calendar: calendar)

        let habitOne = TestHabitFactory.frequency(
            name: "Habit One",
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 1, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 3, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let habitTwo = TestHabitFactory.frequency(
            name: "Habit Two",
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 1, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 5, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        let snapshot = makeService().snapshot(for: [habitOne, habitTwo], now: now)

        XCTAssertEqual(snapshot?.greig.trajectoryText, "At this pace, you'll complete ~12 sessions this month.")
        XCTAssertEqual(snapshot?.greig.suggestionText, "One extra session a week gets you to")
        XCTAssertEqual(snapshot?.greig.outcomeText, "~15 sessions this month.")
    }

    private func makeService() -> GlobalInsightsService {
        GlobalInsightsService(
            calendar: calendar,
            weekStartPreference: .monday
        )
    }
}
