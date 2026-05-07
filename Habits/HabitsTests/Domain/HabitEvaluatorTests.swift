import XCTest
@testable import Habits

final class HabitEvaluatorTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testWeeklyUsesRollingSevenDays() {
        let asOf = TestDateFactory.date(2026, 5, 10, calendar: calendar)
        let insideWindow = TestDateFactory.date(2026, 5, 4, calendar: calendar) // -6 days
        let outsideWindow = TestDateFactory.date(2026, 5, 3, calendar: calendar) // -7 days

        let habit = TestHabitFactory.frequency(
            target: 2,
            period: .weekly,
            entries: [
                TestHabitFactory.entry(on: insideWindow),
                TestHabitFactory.entry(on: outsideWindow),
            ],
            calendar: calendar
        )

        let state = HabitEvaluator(calendar: calendar).evaluate(habit: habit, asOfDate: asOf)
        XCTAssertEqual(state?.progress, 1)
        XCTAssertEqual(state?.target, 2)
        XCTAssertEqual(state?.status, .atRisk)
    }

    func testMonthlyUsesMonthToDate() {
        let asOf = TestDateFactory.date(2026, 5, 15, calendar: calendar)
        let inMonth = TestDateFactory.date(2026, 5, 2, calendar: calendar)
        let priorMonth = TestDateFactory.date(2026, 4, 30, calendar: calendar)

        let habit = TestHabitFactory.cumulative(
            target: 10,
            period: .monthly,
            entries: [
                TestHabitFactory.entry(on: inMonth, value: 6),
                TestHabitFactory.entry(on: priorMonth, value: 8),
            ],
            calendar: calendar
        )

        let state = HabitEvaluator(calendar: calendar).evaluate(habit: habit, asOfDate: asOf)
        XCTAssertEqual(state?.progress, 6)
        XCTAssertEqual(state?.target, 10)
        XCTAssertEqual(state?.remaining, 4)
    }

    func testYearlyUsesRollingTwelveMonths() {
        let asOf = TestDateFactory.date(2026, 5, 15, calendar: calendar)
        let insideWindow = TestDateFactory.date(2025, 6, 1, calendar: calendar)   // included
        let outsideWindow = TestDateFactory.date(2025, 5, 31, calendar: calendar)  // excluded

        let habit = TestHabitFactory.cumulative(
            target: 20,
            period: .yearly,
            entries: [
                TestHabitFactory.entry(on: insideWindow, value: 7),
                TestHabitFactory.entry(on: outsideWindow, value: 9),
            ],
            calendar: calendar
        )

        let state = HabitEvaluator(calendar: calendar).evaluate(habit: habit, asOfDate: asOf)
        XCTAssertEqual(state?.progress, 7)
        XCTAssertEqual(state?.remaining, 13)
    }
}
