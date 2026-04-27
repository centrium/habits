import XCTest
@testable import Habits

final class CalendarLogicTests: BaseTestCase {
    private var calendar: Calendar {
        TestDateFactory.utcCalendar
    }

    func testWeekIntervalRespectsMondayStartAtMonthBoundary() {
        // Given
        let date = TestDateFactory.date(2026, 3, 1, calendar: calendar)

        // When
        let week = WeekBoundaryCalculator.weekInterval(
            containing: date,
            calendar: calendar,
            weekStart: .monday
        )

        // Then
        XCTAssertEqual(week.start, TestDateFactory.date(2026, 2, 23, hour: 0, calendar: calendar))
        XCTAssertEqual(week.end, TestDateFactory.date(2026, 3, 2, hour: 0, calendar: calendar))
    }

    func testWeekIntervalRespectsSundayStartAtMonthBoundary() {
        // Given
        let date = TestDateFactory.date(2026, 3, 1, calendar: calendar)

        // When
        let week = WeekBoundaryCalculator.weekInterval(
            containing: date,
            calendar: calendar,
            weekStart: .sunday
        )

        // Then
        XCTAssertEqual(week.start, TestDateFactory.date(2026, 3, 1, hour: 0, calendar: calendar))
        XCTAssertEqual(week.end, TestDateFactory.date(2026, 3, 8, hour: 0, calendar: calendar))
    }

    func testCalendarGridProducesStableSixWeekLayout() {
        // Given
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let provider = CalendarProvider(calendar: mondayCalendar)
        let month = TestDateFactory.date(2026, 3, 11, calendar: mondayCalendar)

        // When
        let days = CalendarGridHelper.daysForMonth(month, calendarProvider: provider)

        // Then
        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(days.first, TestDateFactory.date(2026, 2, 23, hour: 0, calendar: mondayCalendar))
        XCTAssertEqual(days.last, TestDateFactory.date(2026, 4, 5, hour: 0, calendar: mondayCalendar))
    }

    func testWeeklyGoalPeriodRangeChangesWithWeekStartPreference() {
        // Given
        let date = TestDateFactory.date(2026, 3, 2, calendar: calendar)

        // When
        let mondayRange = GoalPeriod.weekly.periodRange(
            for: date,
            calendar: calendar,
            weekStartPreference: .monday
        )
        let sundayRange = GoalPeriod.weekly.periodRange(
            for: date,
            calendar: calendar,
            weekStartPreference: .sunday
        )

        // Then
        XCTAssertEqual(mondayRange.start, TestDateFactory.date(2026, 3, 2, hour: 0, calendar: calendar))
        XCTAssertEqual(sundayRange.start, TestDateFactory.date(2026, 3, 1, hour: 0, calendar: calendar))
    }

    func testCalendarGridForLeapYearFebruaryIncludesLeapDayInStableLayout() {
        // Given
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let provider = CalendarProvider(calendar: mondayCalendar)
        let leapMonth = TestDateFactory.date(2024, 2, 15, calendar: mondayCalendar)

        // When
        let days = CalendarGridHelper.daysForMonth(leapMonth, calendarProvider: provider)

        // Then
        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(days.first, TestDateFactory.date(2024, 1, 29, hour: 0, calendar: mondayCalendar))
        XCTAssertEqual(days.last, TestDateFactory.date(2024, 3, 10, hour: 0, calendar: mondayCalendar))
        XCTAssertTrue(days.contains(TestDateFactory.date(2024, 2, 29, hour: 0, calendar: mondayCalendar)))
    }

    func testWeekIntervalAtYearBoundaryHonorsWeekStartPreference() {
        // Given
        let date = TestDateFactory.date(2027, 1, 1, calendar: calendar)

        // When
        let mondayWeek = WeekBoundaryCalculator.weekInterval(
            containing: date,
            calendar: calendar,
            weekStart: .monday
        )
        let sundayWeek = WeekBoundaryCalculator.weekInterval(
            containing: date,
            calendar: calendar,
            weekStart: .sunday
        )

        // Then
        XCTAssertEqual(mondayWeek.start, TestDateFactory.date(2026, 12, 28, hour: 0, calendar: calendar))
        XCTAssertEqual(mondayWeek.end, TestDateFactory.date(2027, 1, 4, hour: 0, calendar: calendar))
        XCTAssertEqual(sundayWeek.start, TestDateFactory.date(2026, 12, 27, hour: 0, calendar: calendar))
        XCTAssertEqual(sundayWeek.end, TestDateFactory.date(2027, 1, 3, hour: 0, calendar: calendar))
    }

    func testWeeklyGoalPeriodRangeAtYearBoundaryRespectsWeekStartPreference() {
        // Given
        let date = TestDateFactory.date(2027, 1, 1, hour: 22, calendar: calendar)

        // When
        let mondayRange = GoalPeriod.weekly.periodRange(
            for: date,
            calendar: calendar,
            weekStartPreference: .monday
        )
        let sundayRange = GoalPeriod.weekly.periodRange(
            for: date,
            calendar: calendar,
            weekStartPreference: .sunday
        )

        // Then
        XCTAssertEqual(mondayRange.start, TestDateFactory.date(2026, 12, 28, hour: 0, calendar: calendar))
        XCTAssertEqual(sundayRange.start, TestDateFactory.date(2026, 12, 27, hour: 0, calendar: calendar))
    }
}
