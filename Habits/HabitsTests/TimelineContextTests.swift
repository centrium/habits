import XCTest
@testable import Habits

final class TimelineContextTests: XCTestCase {
    func testIsViewingPastIsTrueForPastDate() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let timelineContext = TimelineContext(calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        let today = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, calendar: calendar)

        XCTAssertTrue(timelineContext.isViewingPast(selectedDate: selectedDate, today: today))
    }

    func testAsOfExclusiveUpperBoundReturnsNextDayStartForPastDate() {
        let timeZone = TimeZone(secondsFromGMT: 2 * 60 * 60) ?? .current
        let calendar = HabitDetailTestFixtures.makeCalendar(timeZone: timeZone)
        let timelineContext = TimelineContext(calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, hour: 12, minute: 30, calendar: calendar)
        let today = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8, minute: 0, calendar: calendar)

        let upperBound = timelineContext.asOfExclusiveUpperBound(for: selectedDate, today: today)

        XCTAssertEqual(
            upperBound,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, calendar: calendar)
        )
    }

    func testAsOfExclusiveUpperBoundReturnsLiveTimeForToday() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let timelineContext = TimelineContext(calendar: calendar)
        let today = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8, minute: 0, calendar: calendar)

        XCTAssertEqual(timelineContext.asOfExclusiveUpperBound(for: today, today: today), today)
    }

    func testPeriodContextLabelUsesExplicitPastPeriodLabel() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let timelineContext = TimelineContext(calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        let today = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 15, calendar: calendar)

        XCTAssertEqual(
            timelineContext.periodContextLabel(for: .monthly, selectedDate: selectedDate, today: today),
            "March 2026"
        )
    }
}
