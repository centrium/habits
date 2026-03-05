import XCTest
@testable import Habits

final class HabitSelectionStateTests: XCTestCase {
    func testSelectingHeatmapDateUpdatesSelectedDateAndVisibleMonth() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let initialDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, calendar: calendar)
        let heatmapDate = HabitDetailTestFixtures.makeDate(year: 2025, month: 12, day: 24, calendar: calendar)
        let selectionState = HabitSelectionState(selectedDate: initialDate, calendar: calendar)

        selectionState.select(heatmapDate: heatmapDate)

        XCTAssertEqual(selectionState.selectedDate, heatmapDate)
        XCTAssertEqual(
            selectionState.visibleMonth,
            HabitDetailTestFixtures.makeDate(year: 2025, month: 12, day: 1, calendar: calendar)
        )
    }

    func testSelectingCalendarDateUpdatesSelectedDateAndVisibleMonth() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let initialDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 12, calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        let selectionState = HabitSelectionState(selectedDate: initialDate, calendar: calendar)

        selectionState.select(date: selectedDate)

        XCTAssertEqual(selectionState.selectedDate, selectedDate)
        XCTAssertEqual(
            selectionState.visibleMonth,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        )
    }

    func testSelectingCalendarMonthUsesLastDayForPastMonth() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let today = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 10, calendar: calendar)
        let selectionState = HabitSelectionState(selectedDate: today, calendar: calendar)
        let january = HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 20, calendar: calendar)

        selectionState.selectCalendarMonth(january, today: today)

        XCTAssertEqual(
            selectionState.selectedDate,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 31, calendar: calendar)
        )
        XCTAssertEqual(
            selectionState.visibleMonth,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        )
    }

    func testSelectingCalendarMonthUsesTodayForCurrentMonth() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let today = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 10, calendar: calendar)
        let selectionState = HabitSelectionState(
            selectedDate: HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 1, calendar: calendar),
            calendar: calendar
        )

        selectionState.selectCalendarMonth(today, today: today)

        XCTAssertEqual(selectionState.selectedDate, today)
        XCTAssertEqual(
            selectionState.visibleMonth,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        )
    }

    func testSelectingCalendarMonthPreservesExistingSelectionInThatMonth() {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 18, calendar: calendar)
        let selectionState = HabitSelectionState(selectedDate: selectedDate, calendar: calendar)

        selectionState.selectCalendarMonth(
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar),
            today: HabitDetailTestFixtures.makeDate(year: 2026, month: 4, day: 2, calendar: calendar)
        )

        XCTAssertEqual(selectionState.selectedDate, selectedDate)
        XCTAssertEqual(
            selectionState.visibleMonth,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        )
    }
}
