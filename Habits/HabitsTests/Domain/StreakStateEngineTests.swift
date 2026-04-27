import XCTest
@testable import Habits

final class StreakStateEngineTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar
    private lazy var engine = StreakStateEngine(
        calendar: calendar,
        weekStartPreference: .monday
    )

    func testOpenGoalNotLoggedTodayIsAtRisk() {
        let yesterday = TestDateFactory.date(2026, 4, 14, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [TestHabitFactory.entry(on: yesterday)],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .atRisk)
        XCTAssertEqual(state.currentStreak, 1)
        XCTAssertFalse(state.hasMetRequirementToday)
    }

    func testOpenGoalLoggedTodayIsSafe() {
        let yesterday = TestDateFactory.date(2026, 4, 14, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                TestHabitFactory.entry(on: yesterday),
                TestHabitFactory.entry(on: today),
            ],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .safe)
        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertTrue(state.hasMetRequirementToday)
    }

    func testOpenGoalMissedDayIsBroken() {
        let twoDaysAgo = TestDateFactory.date(2026, 4, 13, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [TestHabitFactory.entry(on: twoDaysAgo)],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .broken)
        XCTAssertEqual(state.currentStreak, 0)
    }

    func testFrequencyGoalNotLoggedTodayIsAtRisk() {
        let yesterday = TestDateFactory.date(2026, 4, 14, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let twoDaysAgo = TestDateFactory.date(2026, 4, 13, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [
                TestHabitFactory.entry(on: twoDaysAgo),
                TestHabitFactory.entry(on: twoDaysAgo),
                TestHabitFactory.entry(on: twoDaysAgo),
                TestHabitFactory.entry(on: yesterday),
                TestHabitFactory.entry(on: yesterday),
                TestHabitFactory.entry(on: yesterday),
            ],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .atRisk)
        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertFalse(state.hasMetRequirementToday)
    }

    func testFrequencyGoalAtTargetTodayIsSafe() {
        let yesterday = TestDateFactory.date(2026, 4, 14, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [
                TestHabitFactory.entry(on: yesterday),
                TestHabitFactory.entry(on: yesterday),
                TestHabitFactory.entry(on: yesterday),
                TestHabitFactory.entry(on: today),
                TestHabitFactory.entry(on: today),
                TestHabitFactory.entry(on: today),
            ],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .safe)
        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertTrue(state.hasMetRequirementToday)
    }

    func testFrequencyGoalMissedYesterdayIsBroken() {
        let twoDaysAgo = TestDateFactory.date(2026, 4, 13, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [
                TestHabitFactory.entry(on: twoDaysAgo),
                TestHabitFactory.entry(on: twoDaysAgo),
                TestHabitFactory.entry(on: twoDaysAgo),
            ],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .broken)
        XCTAssertEqual(state.currentStreak, 0)
    }

    func testCumulativeGoalBelowTargetDuringDayIsAtRisk() {
        let yesterday = TestDateFactory.date(2026, 4, 14, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 10,
            entries: [
                TestHabitFactory.entry(on: yesterday, value: 10),
                TestHabitFactory.entry(on: today, value: 7),
            ],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .atRisk)
        XCTAssertEqual(state.currentStreak, 1)
        XCTAssertFalse(state.hasMetRequirementToday)
    }

    func testCumulativeGoalAtTargetIsSafe() {
        let yesterday = TestDateFactory.date(2026, 4, 14, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 10,
            entries: [
                TestHabitFactory.entry(on: yesterday, value: 10),
                TestHabitFactory.entry(on: today, value: 7),
                TestHabitFactory.entry(on: today, value: 3),
            ],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .safe)
        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertTrue(state.hasMetRequirementToday)
    }

    func testCumulativeGoalMissedPreviousDayIsBroken() {
        let twoDaysAgo = TestDateFactory.date(2026, 4, 13, calendar: calendar)
        let today = TestDateFactory.date(2026, 4, 15, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 10,
            entries: [TestHabitFactory.entry(on: twoDaysAgo, value: 10)],
            calendar: calendar
        )

        let state = engine.streakState(for: habit, referenceDate: today)

        XCTAssertEqual(state.status, .broken)
        XCTAssertEqual(state.currentStreak, 0)
    }
}
