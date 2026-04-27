import XCTest
@testable import Habits

final class InsightsStreakCalculationTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testSimpleStreak() {
        // Given
        let now = TestDateFactory.date(2026, 3, 20, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 3, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 4, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 5, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let streaks = service.streakLengths(for: habit, now: now)
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(streaks, [4])
        XCTAssertEqual(snapshot.averageStreak, 4)
    }

    func testTwoStreaks() {
        // Given
        let now = TestDateFactory.date(2026, 3, 20, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 3, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 4, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 5, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let streaks = service.streakLengths(for: habit, now: now)
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(streaks, [4, 4])
        XCTAssertEqual(snapshot.averageStreak, 4)
    }

    func testMultipleLogsSameDayFormSingleDayInStreak() {
        // Given
        let now = TestDateFactory.date(2026, 3, 20, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 5, hour: 8, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 5, hour: 21, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 6, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let streaks = service.streakLengths(for: habit, now: now)
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(streaks, [2])
        XCTAssertEqual(snapshot.averageStreak, 2)
    }

    func testSparseCompletionsProduceSingleDayStreaks() {
        // Given
        let now = TestDateFactory.date(2026, 3, 20, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 1, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 5, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let streaks = service.streakLengths(for: habit, now: now)
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(streaks, [1, 1, 1])
        XCTAssertEqual(snapshot.averageStreak, 1)
    }

    func testNoLogsReturnsZeroAverageStreak() {
        // Given
        let now = TestDateFactory.date(2026, 3, 20, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: TestDateFactory.date(2026, 3, 1, calendar: calendar),
            entries: [],
            calendar: calendar
        )
        let service = HabitInsightsService(calendar: calendar)

        // When
        let streaks = service.streakLengths(for: habit, now: now)
        let snapshot = service.snapshot(for: habit, now: now)

        // Then
        XCTAssertEqual(streaks, [])
        XCTAssertEqual(snapshot.averageStreak, 0)
    }
}
