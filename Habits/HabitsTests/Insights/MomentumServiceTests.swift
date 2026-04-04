import XCTest
@testable import Habits

@MainActor
final class HabitStateServiceTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testHoldingStateForHighRecentCompletionRate() {
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: TestDateFactory.addingDays(0, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-3, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-4, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-6, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitStateService(calendar: calendar, weekStartPreference: .monday)

        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        XCTAssertEqual(breakdown.state, .holding)
    }

    func testReturningStateForLowRateWithRecentData() {
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: TestDateFactory.addingDays(0, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-4, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitStateService(calendar: calendar, weekStartPreference: .monday)

        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        XCTAssertEqual(breakdown.state, .returning)
    }

    func testOpenGoalBreakdownUsesBinaryCompletion() {
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: now, value: 1),
                .init(timestamp: now, value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitStateService(calendar: calendar, weekStartPreference: .monday)

        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        XCTAssertEqual(breakdown.completedDays, 3)
        XCTAssertEqual(breakdown.completionRate, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testFrequencyGoalBreakdownRequiresTargetMet() {
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                .init(timestamp: now, value: 1),
                .init(timestamp: now, value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitStateService(calendar: calendar, weekStartPreference: .monday)

        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        XCTAssertEqual(breakdown.completedDays, 1)
        XCTAssertEqual(breakdown.completionRate, 1.0 / 7.0, accuracy: 0.0001)
    }

    func testCumulativeGoalBreakdownCountsAnyProgress() {
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: now, value: 0.5),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 12),
            ],
            calendar: calendar
        )
        let service = HabitStateService(calendar: calendar, weekStartPreference: .monday)

        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        XCTAssertEqual(breakdown.completedDays, 2)
        XCTAssertEqual(breakdown.completionRate, 2.0 / 7.0, accuracy: 0.0001)
    }

    func testBreakdownIncludesCurrentStreak() {
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: now, value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitStateService(calendar: calendar, weekStartPreference: .monday)

        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        XCTAssertEqual(breakdown.streak, 3)
        XCTAssertEqual(breakdown.state, .building)
    }
}
