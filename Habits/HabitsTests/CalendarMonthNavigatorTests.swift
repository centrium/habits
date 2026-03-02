import XCTest
@testable import Habits

final class CalendarMonthNavigatorTests: XCTestCase {
    func testVisibleMonthNormalizesToFirstDayOfMonth() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let navigator = CalendarMonthNavigator(calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(
            year: 2026,
            month: 3,
            day: 17,
            calendar: calendar
        )

        let visibleMonth = navigator.visibleMonth(for: selectedDate)

        XCTAssertEqual(
            visibleMonth,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        )
    }

    func testAdjacentMonthMovesAcrossYearBoundaryForward() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let navigator = CalendarMonthNavigator(calendar: calendar)
        let december = HabitDetailTestFixtures.makeDate(year: 2025, month: 12, day: 1, calendar: calendar)

        let january = navigator.adjacentMonth(from: december, offset: 1)

        XCTAssertEqual(
            january,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        )
    }

    func testAdjacentMonthMovesAcrossYearBoundaryBackward() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let navigator = CalendarMonthNavigator(calendar: calendar)
        let january = HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)

        let december = navigator.adjacentMonth(from: january, offset: -1)

        XCTAssertEqual(
            december,
            HabitDetailTestFixtures.makeDate(year: 2025, month: 12, day: 1, calendar: calendar)
        )
    }
}
