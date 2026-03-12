import XCTest
@testable import Habits

final class StreakCalculationTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testDailyStreakCountsConsecutiveCompletedDays() {
        // Given
        let day1 = TestDateFactory.date(2026, 3, 3, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 3, 4, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 3, 5, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day2, value: 1),
                .init(timestamp: day3, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: day3,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 3)
    }

    func testDailyStreakResetsAfterMissedDay() {
        // Given
        let day1 = TestDateFactory.date(2026, 3, 3, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 3, 5, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day3, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: day3,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 1)
    }

    func testWeeklyStreakRequiresTargetEveryWeek() {
        // Given
        let week3Monday = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let week2Monday = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let week1Monday = TestDateFactory.date(2026, 3, 2, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .weekly,
            target: 2,
            entries: [
                .init(timestamp: week3Monday, value: 1),
                .init(timestamp: TestDateFactory.addingDays(1, to: week3Monday, calendar: calendar), value: 1),
                .init(timestamp: week2Monday, value: 1),
                .init(timestamp: TestDateFactory.addingDays(1, to: week2Monday, calendar: calendar), value: 1),
                .init(timestamp: week1Monday, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: week3Monday,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 2)
    }

    func testOpenEndedHabitHasZeroCurrentStreak() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: day, value: 1)],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(referenceDate: day, calendar: calendar)

        // Then
        XCTAssertEqual(streak, 0)
    }

    func testCurrentStreakIsZeroWhenCurrentPeriodIsIncomplete() {
        // Given
        let day1 = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 3, 10, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day2, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: day3,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 0)
    }

    func testFirstCompletedPeriodStartsStreakAtOne() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [.init(timestamp: day, value: 1)],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: day,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 1)
    }

    func testCumulativeStreakUsesSummedValueWithinEachDay() {
        // Given
        let day1 = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 3, 10, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: day1, value: 40),
                .init(timestamp: day2, value: 60),
                .init(timestamp: day2, value: 40),
                .init(timestamp: day3, value: 55),
                .init(timestamp: day3, value: 45),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: day3,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 2)
    }

    func testDailyStreakContinuesAcrossMonthBoundary() {
        // Given
        let feb28 = TestDateFactory.date(2026, 2, 28, calendar: calendar)
        let mar1 = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let mar2 = TestDateFactory.date(2026, 3, 2, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: feb28, value: 1),
                .init(timestamp: mar1, value: 1),
                .init(timestamp: mar2, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: mar2,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 3)
    }

    func testDailyStreakContinuesAcrossYearBoundary() {
        // Given
        let dec31 = TestDateFactory.date(2025, 12, 31, calendar: calendar)
        let jan1 = TestDateFactory.date(2026, 1, 1, calendar: calendar)
        let jan2 = TestDateFactory.date(2026, 1, 2, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: dec31, value: 1),
                .init(timestamp: jan1, value: 1),
                .init(timestamp: jan2, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: jan2,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 3)
    }

    func testDailyStreakContinuesAcrossLeapDay() {
        // Given
        let feb28 = TestDateFactory.date(2024, 2, 28, calendar: calendar)
        let feb29 = TestDateFactory.date(2024, 2, 29, calendar: calendar)
        let mar1 = TestDateFactory.date(2024, 3, 1, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: feb28, value: 1),
                .init(timestamp: feb29, value: 1),
                .init(timestamp: mar1, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: mar1,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 3)
    }

    func testDailyStreakCountsSinglePeriodWhenMultipleLogsExistOnSameDay() {
        // Given
        let day1 = TestDateFactory.date(2026, 3, 10, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day1, value: 1),
                .init(timestamp: day2, value: 1),
                .init(timestamp: day2, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: day2,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 2)
    }

    func testFirstLogBelowTargetDoesNotStartStreak() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [.init(timestamp: day, value: 1)],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: day,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 0)
    }

    func testWeeklyStreakContinuesAcrossYearBoundary() {
        // Given
        let week2Start = TestDateFactory.date(2026, 1, 2, calendar: calendar)
        let week1Start = TestDateFactory.date(2025, 12, 26, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .weekly,
            target: 2,
            entries: [
                .init(timestamp: week1Start, value: 1),
                .init(timestamp: TestDateFactory.addingDays(1, to: week1Start, calendar: calendar), value: 1),
                .init(timestamp: week2Start, value: 1),
                .init(timestamp: TestDateFactory.addingDays(1, to: week2Start, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        // When
        let streak = habit.currentStreak(
            referenceDate: week2Start,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(streak, 2)
    }
}
