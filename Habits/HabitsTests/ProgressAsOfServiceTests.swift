import XCTest
@testable import Habits

final class ProgressAsOfServiceTests: XCTestCase {
    func testMonthlySnapshotCapsTotalsAtSelectedDate() throws {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let habit = HabitDetailTestFixtures.makeCumulativeHabit(goalPeriod: .monthly, target: 10, calendar: calendar)
        let now = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 15, hour: 9, minute: 0, calendar: calendar)
        let march1 = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, hour: 10, minute: 0, calendar: calendar)
        let march2 = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, hour: 10, minute: 0, calendar: calendar)
        let march31 = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 31, hour: 10, minute: 0, calendar: calendar)
        let visibleMonth = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)

        habit.logs = [
            HabitLog(timestamp: march1, value: 4, calendar: calendar),
            HabitLog(timestamp: march2, value: 3, calendar: calendar),
            HabitLog(timestamp: march31, value: 5, calendar: calendar)
        ]

        let service = ProgressAsOfService(calendar: calendar) { now }

        let snapshot = try XCTUnwrap(service.snapshot(for: habit, visibleMonth: visibleMonth, selectedDate: march1))

        XCTAssertEqual(snapshot.current, 4, accuracy: 0.0001)
        XCTAssertEqual(snapshot.progressFraction, 0.4, accuracy: 0.0001)
        XCTAssertEqual(snapshot.headlineText, "4 of 10 pages")
        XCTAssertEqual(snapshot.contextText, "March 2026")
        XCTAssertEqual(snapshot.visibleMonthText, "March 2026: 4 pages")
    }

    func testMonthlySnapshotIncludesFullMonthWhenSelectedAtEndOfMonth() throws {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let habit = HabitDetailTestFixtures.makeCumulativeHabit(goalPeriod: .monthly, target: 10, calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 31, hour: 12, minute: 0, calendar: calendar)
        let visibleMonth = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)

        habit.logs = [
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, hour: 8, minute: 0, calendar: calendar), value: 4, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 15, hour: 8, minute: 0, calendar: calendar), value: 3, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 31, hour: 8, minute: 0, calendar: calendar), value: 5, calendar: calendar)
        ]

        let service = ProgressAsOfService(calendar: calendar) { selectedDate }

        let snapshot = try XCTUnwrap(service.snapshot(for: habit, visibleMonth: visibleMonth, selectedDate: selectedDate))

        XCTAssertEqual(snapshot.current, 12, accuracy: 0.0001)
        XCTAssertEqual(snapshot.progressFraction, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.overflowText, "+2 extra")
    }

    func testYearlySnapshotRespectsCrossYearBoundary() throws {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let habit = HabitDetailTestFixtures.makeCumulativeHabit(goalPeriod: .yearly, target: 10, calendar: calendar)
        let december31 = HabitDetailTestFixtures.makeDate(year: 2025, month: 12, day: 31, hour: 10, minute: 0, calendar: calendar)
        let january1 = HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 1, hour: 10, minute: 0, calendar: calendar)
        let now = HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 2, hour: 9, minute: 0, calendar: calendar)

        habit.logs = [
            HabitLog(timestamp: december31, value: 5, calendar: calendar),
            HabitLog(timestamp: january1, value: 7, calendar: calendar)
        ]

        let service = ProgressAsOfService(calendar: calendar) { now }

        let decemberSnapshot = try XCTUnwrap(
            service.snapshot(
                for: habit,
                visibleMonth: HabitDetailTestFixtures.makeDate(year: 2025, month: 12, day: 1, calendar: calendar),
                selectedDate: december31
            )
        )
        let januarySnapshot = try XCTUnwrap(
            service.snapshot(
                for: habit,
                visibleMonth: HabitDetailTestFixtures.makeDate(year: 2026, month: 1, day: 1, calendar: calendar),
                selectedDate: january1
            )
        )

        XCTAssertEqual(decemberSnapshot.current, 5, accuracy: 0.0001)
        XCTAssertEqual(januarySnapshot.current, 7, accuracy: 0.0001)
        XCTAssertEqual(decemberSnapshot.contextText, "2025")
        XCTAssertEqual(januarySnapshot.contextText, "2026")
    }

    func testFrequencySnapshotAndStreakIgnoreFutureLogsInSamePeriod() throws {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let habit = HabitDetailTestFixtures.makeFrequencyHabit(goalPeriod: .weekly, target: 2, calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, hour: 9, minute: 0, calendar: calendar)
        let now = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 15, hour: 9, minute: 0, calendar: calendar)

        habit.logs = [
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 10, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 13, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 3, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 4, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar)
        ]

        let service = ProgressAsOfService(calendar: calendar) { now }

        let snapshot = try XCTUnwrap(
            service.snapshot(
                for: habit,
                visibleMonth: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar),
                selectedDate: selectedDate
            )
        )

        XCTAssertEqual(snapshot.current, 2, accuracy: 0.0001)
        XCTAssertEqual(snapshot.progressFraction, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.streak, 2)
        XCTAssertTrue(snapshot.isComplete)
    }

    func testTimezoneBoundaryExcludesNextDayLog() throws {
        let timeZone = TimeZone(secondsFromGMT: 2 * 60 * 60) ?? .current
        let calendar = HabitDetailTestFixtures.makeCalendar(timeZone: timeZone)
        let habit = HabitDetailTestFixtures.makeCumulativeHabit(goalPeriod: .monthly, target: 10, calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, hour: 12, minute: 0, calendar: calendar)
        let now = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, hour: 9, minute: 0, calendar: calendar)

        habit.logs = [
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, hour: 23, minute: 30, calendar: calendar), value: 4, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, hour: 0, minute: 10, calendar: calendar), value: 6, calendar: calendar)
        ]

        let service = ProgressAsOfService(calendar: calendar) { now }

        let snapshot = try XCTUnwrap(
            service.snapshot(
                for: habit,
                visibleMonth: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar),
                selectedDate: selectedDate
            )
        )

        XCTAssertEqual(snapshot.current, 4, accuracy: 0.0001)
        XCTAssertEqual(snapshot.visibleMonthText, "March 2026: 4 pages")
    }

    func testWeeklySnapshotUsesConfiguredWeekStartForProgressTotals() throws {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let habit = HabitDetailTestFixtures.makeFrequencyHabit(goalPeriod: .weekly, target: 3, calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, hour: 9, minute: 0, calendar: calendar)
        let visibleMonth = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        let now = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 15, hour: 9, minute: 0, calendar: calendar)

        habit.logs = [
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 8, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 9, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar)
        ]

        let mondayService = ProgressAsOfService(calendar: calendar, weekStartPreference: .monday) { now }
        let sundayService = ProgressAsOfService(calendar: calendar, weekStartPreference: .sunday) { now }

        let mondaySnapshot = try XCTUnwrap(
            mondayService.snapshot(for: habit, visibleMonth: visibleMonth, selectedDate: selectedDate)
        )
        let sundaySnapshot = try XCTUnwrap(
            sundayService.snapshot(for: habit, visibleMonth: visibleMonth, selectedDate: selectedDate)
        )

        XCTAssertEqual(mondaySnapshot.current, 2, accuracy: 0.0001)
        XCTAssertEqual(sundaySnapshot.current, 3, accuracy: 0.0001)
        XCTAssertEqual(mondaySnapshot.contextText, "Week of Mar 9")
        XCTAssertEqual(sundaySnapshot.contextText, "Week of Mar 8")
    }

    func testWeeklyStreakUsesConfiguredWeekStart() throws {
        let calendar = HabitDetailTestFixtures.makeCalendar()
        let habit = HabitDetailTestFixtures.makeFrequencyHabit(goalPeriod: .weekly, target: 2, calendar: calendar)
        let selectedDate = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 11, hour: 9, minute: 0, calendar: calendar)
        let visibleMonth = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        let now = HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 15, hour: 9, minute: 0, calendar: calendar)

        habit.logs = [
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 2, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 8, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 9, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            HabitLog(timestamp: HabitDetailTestFixtures.makeDate(year: 2026, month: 3, day: 10, hour: 8, minute: 0, calendar: calendar), value: 1, calendar: calendar)
        ]

        let mondayService = ProgressAsOfService(calendar: calendar, weekStartPreference: .monday) { now }
        let sundayService = ProgressAsOfService(calendar: calendar, weekStartPreference: .sunday) { now }

        let mondaySnapshot = try XCTUnwrap(
            mondayService.snapshot(for: habit, visibleMonth: visibleMonth, selectedDate: selectedDate)
        )
        let sundaySnapshot = try XCTUnwrap(
            sundayService.snapshot(for: habit, visibleMonth: visibleMonth, selectedDate: selectedDate)
        )

        XCTAssertEqual(mondaySnapshot.streak, 2)
        XCTAssertEqual(sundaySnapshot.streak, 1)
    }
}
