import XCTest
@testable import Habits

final class WeekBoundaryCalculatorTests: XCTestCase {
    func testMondayWeekStartReturnsMondayForWednesday() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let date = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, calendar: calendar)

        let start = WeekBoundaryCalculator.startOfWeek(for: date, calendar: calendar, weekStart: .monday)

        XCTAssertEqual(
            start,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 9, calendar: calendar)
        )
    }

    func testSundayWeekStartReturnsSundayForWednesday() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let date = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, calendar: calendar)

        let start = WeekBoundaryCalculator.startOfWeek(for: date, calendar: calendar, weekStart: .sunday)

        XCTAssertEqual(
            start,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 8, calendar: calendar)
        )
    }

    func testCrossMonthBoundaryReturnsStartInPreviousMonth() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let date = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)

        let start = WeekBoundaryCalculator.startOfWeek(for: date, calendar: calendar, weekStart: .monday)

        XCTAssertEqual(
            start,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 2, day: 23, calendar: calendar)
        )
    }

    func testCrossYearBoundaryReturnsStartInPreviousYear() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let date = HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)

        let start = WeekBoundaryCalculator.startOfWeek(for: date, calendar: calendar, weekStart: .monday)

        XCTAssertEqual(
            start,
            HabitDetailTestFixtures.makeDate(year: 2025, month: 12, day: 29, calendar: calendar)
        )
    }

    func testWeekIntervalContainsSelectedDayAndSpansSevenDays() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let date = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, hour: 15, minute: 30, calendar: calendar)

        let interval = WeekBoundaryCalculator.weekInterval(containing: date, calendar: calendar, weekStart: .sunday)

        XCTAssertTrue(interval.contains(date))
        XCTAssertEqual(
            interval.start,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 8, calendar: calendar)
        )
        XCTAssertEqual(
            interval.end,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 15, calendar: calendar)
        )
    }

    func testWeekStartUsesStartOfDayInCalendarTimezone() {
        let timeZone = TimeZone(secondsFromGMT: 2 * 60 * 60) ?? .current
        let calendar = HabitDetailTestFixtures.makeCalendar(timeZone: timeZone)
        let date = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, hour: 23, minute: 30, calendar: calendar)

        let start = WeekBoundaryCalculator.startOfWeek(for: date, calendar: calendar, weekStart: .monday)

        XCTAssertEqual(
            start,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 9, calendar: calendar)
        )
    }
}
