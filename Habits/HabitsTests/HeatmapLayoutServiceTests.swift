import XCTest
@testable import Habits

final class HeatmapLayoutServiceTests: XCTestCase {
    func testHeatmapLayoutStartsWeekOnMondayWhenConfigured() {
        let provider = CalendarProvider(
            calendar: HabitDetailTestFixtures.makeCalendar(firstWeekday: 2)
        )
        let layoutService = HeatmapLayoutService(calendarProvider: provider)
        let endDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, calendar: provider.calendar)

        let weeks = layoutService.makeWeeks(endingAt: endDate, numberOfWeeks: 1)
        let week = try! XCTUnwrap(weeks.first)

        XCTAssertEqual(
            week.id,
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 9, calendar: provider.calendar)
        )
        XCTAssertEqual(
            week.days[0],
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 9, calendar: provider.calendar)
        )
        XCTAssertEqual(
            week.days[2],
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, calendar: provider.calendar)
        )
    }

    func testHeatmapLayoutRemainsIdenticalWhenWeekStartPreferenceChanges() {
        let baseCalendar = HabitDetailTestFixtures.makeCalendar(firstWeekday: 1)
        let mondayProvider = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .monday
        ).calendarProviderForHeatmap()
        let sundayProvider = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .sunday
        ).calendarProviderForHeatmap()
        let endDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, calendar: baseCalendar)

        let mondayWeeks = HeatmapLayoutService(calendarProvider: mondayProvider)
            .makeWeeks(endingAt: endDate, numberOfWeeks: 3)
        let sundayWeeks = HeatmapLayoutService(calendarProvider: sundayProvider)
            .makeWeeks(endingAt: endDate, numberOfWeeks: 3)

        XCTAssertEqual(mondayWeeks.map(\.id), sundayWeeks.map(\.id))
        XCTAssertEqual(
            mondayWeeks.map { $0.days.map(\.self) },
            sundayWeeks.map { $0.days.map(\.self) }
        )
    }

    func testWeekGroupingChangesWhileHeatmapVisualIndexRemainsFixed() {
        let baseCalendar = HabitDetailTestFixtures.makeCalendar(firstWeekday: 1)
        let targetDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 8, calendar: baseCalendar)

        let mondayStrategy = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .monday
        )
        let sundayStrategy = WeekLayoutStrategy(
            baseCalendar: baseCalendar,
            weekStartPreference: .sunday
        )

        XCTAssertEqual(
            mondayStrategy.calendarProviderForCalculations().startOfWeek(for: targetDate),
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, calendar: baseCalendar)
        )
        XCTAssertEqual(
            sundayStrategy.calendarProviderForCalculations().startOfWeek(for: targetDate),
            HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 8, calendar: baseCalendar)
        )
        XCTAssertEqual(
            mondayStrategy.calendarProviderForHeatmap().rowIndex(for: targetDate),
            sundayStrategy.calendarProviderForHeatmap().rowIndex(for: targetDate)
        )
        XCTAssertEqual(mondayStrategy.calendarProviderForHeatmap().rowIndex(for: targetDate), 6)
    }
}
