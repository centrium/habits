import XCTest
@testable import Habits

final class HabitInsightsServiceTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testConsistencyCalculationRoundsToWholePercentage() {
        // Given
        let createdAt = TestDateFactory.date(2026, 3, 1, hour: 9, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: createdAt,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 1, hour: 8, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 1, hour: 20, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 4, hour: 10, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 7, hour: 7, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 15, hour: 9, calendar: calendar), value: 1), // Future log, ignored
            ],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(snapshot.consistency, 30)
    }

    func testBestMonthReturnsMonthWithMostCompletionDays() {
        // Given
        let createdAt = TestDateFactory.date(2026, 1, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 31, hour: 18, calendar: calendar)

        var entries: [TestHabitFactory.Entry] = []
        for day in 1...10 {
            entries.append(.init(timestamp: TestDateFactory.date(2026, 1, day, calendar: calendar), value: 1))
        }
        for day in 1...18 {
            entries.append(.init(timestamp: TestDateFactory.date(2026, 2, day, calendar: calendar), value: 1))
        }
        for day in 1...12 {
            entries.append(.init(timestamp: TestDateFactory.date(2026, 3, day, calendar: calendar), value: 1))
        }

        let habit = TestHabitFactory.frequency(
            createdAt: createdAt,
            entries: entries,
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(snapshot.bestMonth, "February")
    }

    func testMostMissedDayReturnsWeekdayWithLowestCompletionRate() {
        // Given
        let createdAt = TestDateFactory.date(2026, 3, 2, calendar: calendar) // Monday
        let now = TestDateFactory.date(2026, 3, 29, hour: 18, calendar: calendar) // Sunday

        var entries: [TestHabitFactory.Entry] = []
        for offset in 0..<28 {
            let day = TestDateFactory.addingDays(offset, to: createdAt, calendar: calendar)
            let weekday = calendar.component(.weekday, from: day)

            if weekday != 1 || calendar.component(.day, from: day) == 8 {
                entries.append(.init(timestamp: day, value: 1))
            }
        }

        let habit = TestHabitFactory.frequency(
            createdAt: createdAt,
            entries: entries,
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(snapshot.mostMissedDay, "Sunday")
    }

    func testAverageStreakReturnsRoundedAverageAcrossStreakSegments() {
        // Given
        let createdAt = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 25, hour: 18, calendar: calendar)

        var entries: [TestHabitFactory.Entry] = []
        for day in 1...3 {
            entries.append(.init(timestamp: TestDateFactory.date(2026, 3, day, calendar: calendar), value: 1))
        }
        for day in 5...9 {
            entries.append(.init(timestamp: TestDateFactory.date(2026, 3, day, calendar: calendar), value: 1))
        }
        for day in 11...20 {
            entries.append(.init(timestamp: TestDateFactory.date(2026, 3, day, calendar: calendar), value: 1))
        }

        let habit = TestHabitFactory.frequency(
            createdAt: createdAt,
            entries: entries,
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(snapshot.averageStreak, 6)
    }

    func testInsightsWithNoLogsReturnSafeDefaults() {
        // Given
        let createdAt = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: createdAt,
            entries: [],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(snapshot.consistency, 0)
        XCTAssertEqual(snapshot.bestMonth, "March")
        XCTAssertEqual(snapshot.mostMissedDay, "Tuesday")
        XCTAssertEqual(snapshot.averageStreak, 0)
    }

    func testConsistencyUsesOneAvailableDayWhenHabitCreatedToday() {
        // Given
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: now,
            entries: [
                .init(timestamp: now, value: 1)
            ],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(snapshot.consistency, 100)
    }
}
