import XCTest
@testable import Habits

final class HabitComputedStateConsistencyTests: XCTestCase {
    func testComputedConsistencyUsesCanonicalSevenDayWindowAndTrackingStartClamp() async {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 20, hour: 12, minute: 0, second: 0, calendar: calendar)

        let createdAt = TestDateFactory.date(2026, 4, 18, hour: 9, minute: 0, second: 0, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: createdAt,
            entries: [
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 18, hour: 10, minute: 0, second: 0, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 20, hour: 10, minute: 0, second: 0, calendar: calendar)),
            ],
            calendar: calendar
        )

        let computed = await Task.detached(priority: .userInitiated) {
            HabitComputationEngine(
                calendar: calendar,
                weekStartPreference: .system
            ).compute(
                habit: habit,
                logs: habit.logs,
                globalLogs: habit.logs,
                now: now
            )
        }.value

        XCTAssertEqual(computed.consistency.windowDays, 7)
        XCTAssertEqual(computed.consistency.daysAvailable, 3)
        XCTAssertEqual(computed.consistency.daysCompleted, 2)
        XCTAssertEqual(computed.consistency.percentage, 67)
    }

    func testHabitStateResolverConsistencyMatchesComputedStateConsistency() async {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 20, hour: 12, minute: 0, second: 0, calendar: calendar)

        let habit = TestHabitFactory.frequency(
            entries: [
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 8, minute: 0, second: 0, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 16, hour: 8, minute: 0, second: 0, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 19, hour: 8, minute: 0, second: 0, calendar: calendar)),
            ],
            calendar: calendar
        )

        let computed = await Task.detached(priority: .userInitiated) {
            HabitComputationEngine(
                calendar: calendar,
                weekStartPreference: .system
            ).compute(
                habit: habit,
                logs: habit.logs,
                globalLogs: habit.logs,
                now: now
            )
        }.value

        let stateModel = await Task.detached(priority: .userInitiated) {
            HabitStateResolver.resolve(
                for: habit,
                calendar: calendar,
                now: now
            )
        }.value

        XCTAssertEqual(stateModel.consistency, computed.consistency.percentage)
    }
}
