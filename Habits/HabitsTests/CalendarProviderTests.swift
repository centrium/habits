import XCTest
@testable import Habits

final class CalendarProviderTests: XCTestCase {
    func testCalendarViewHeaderOrderFollowsWeekStartPreference() {
        let baseCalendar = HabitDetailTestFixtures.makeCalendar(firstWeekday: 1)
        let mondayProvider = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .monday
        ).calendarProviderForCalendarView()
        let sundayProvider = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .sunday
        ).calendarProviderForCalendarView()

        XCTAssertEqual(mondayProvider.orderedVeryShortStandaloneWeekdaySymbols.joined(), "MTWTFSS")
        XCTAssertEqual(sundayProvider.orderedVeryShortStandaloneWeekdaySymbols.joined(), "SMTWTFS")
    }

    func testHeatmapHeaderOrderRemainsMondayFirstWhenWeekStartPreferenceChanges() {
        let baseCalendar = HabitDetailTestFixtures.makeCalendar(firstWeekday: 1)
        let mondayProvider = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .monday
        ).calendarProviderForHeatmap()
        let sundayProvider = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .sunday
        ).calendarProviderForHeatmap()

        XCTAssertEqual(mondayProvider.orderedVeryShortStandaloneWeekdaySymbols.joined(), "MTWTFSS")
        XCTAssertEqual(sundayProvider.orderedVeryShortStandaloneWeekdaySymbols.joined(), "MTWTFSS")
    }

    func testOrderedWeekdaySymbolsStartWithConfiguredFirstWeekday() {
        let mondayProvider = CalendarProvider(
            calendar: HabitDetailTestFixtures.makeCalendar(firstWeekday: 2)
        )
        let sundayProvider = CalendarProvider(
            calendar: HabitDetailTestFixtures.makeCalendar(firstWeekday: 1)
        )

        XCTAssertEqual(mondayProvider.orderedVeryShortStandaloneWeekdaySymbols.joined(), "MTWTFSS")
        XCTAssertEqual(sundayProvider.orderedVeryShortStandaloneWeekdaySymbols.joined(), "SMTWTFS")
    }

    func testMonthGridStartsOnConfiguredWeekBoundaryForMonday() {
        let provider = CalendarProvider(
            calendar: HabitDetailTestFixtures.makeCalendar(firstWeekday: 2)
        )
        let march = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: provider.calendar)

        let days = CalendarGridHelper.daysForMonth(march, calendarProvider: provider)

        XCTAssertEqual(
            days.first,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 2, day: 23, calendar: provider.calendar)
        )
        XCTAssertEqual(
            days[6],
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: provider.calendar)
        )
    }

    func testMonthGridStartsOnConfiguredWeekBoundaryForSunday() {
        let provider = CalendarProvider(
            calendar: HabitDetailTestFixtures.makeCalendar(firstWeekday: 1)
        )
        let march = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: provider.calendar)

        let days = CalendarGridHelper.daysForMonth(march, calendarProvider: provider)

        XCTAssertEqual(
            days.first,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: provider.calendar)
        )
    }
}
