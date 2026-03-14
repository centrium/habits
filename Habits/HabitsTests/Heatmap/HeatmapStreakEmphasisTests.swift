import XCTest
@testable import Habits

final class HeatmapStreakEmphasisTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testCurrentStreakDaysIncludeOnlyConsecutiveDaysEndingToday() {
        // Given
        let day5 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 5, calendar: calendar))
        let day9 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 9, calendar: calendar))
        let day10 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 10, calendar: calendar))
        let day11 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 11, calendar: calendar))
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: day5, value: 1),
                .init(timestamp: day9, value: 1),
                .init(timestamp: day10, value: 1),
                .init(timestamp: day11, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streakDays = HeatmapStreakCellsResolver.currentStreakDays(
            for: habit,
            endingAt: day11,
            calendar: calendar
        )

        // Then
        XCTAssertEqual(Set(streakDays), Set([day9, day10, day11]))
    }

    func testCurrentStreakDaysAreEmptyWhenTodayIsNotLogged() {
        // Given
        let day9 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 9, calendar: calendar))
        let day10 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 10, calendar: calendar))
        let day11 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 11, calendar: calendar))
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: day9, value: 1),
                .init(timestamp: day10, value: 1),
            ],
            calendar: calendar
        )

        // When
        let streakDays = HeatmapStreakCellsResolver.currentStreakDays(
            for: habit,
            endingAt: day11,
            calendar: calendar
        )

        // Then
        XCTAssertEqual(streakDays, [])
    }

    func testEmphasisMarksTodayAsStrongestLevel() {
        // Given
        let day9 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 9, calendar: calendar))
        let day10 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 10, calendar: calendar))
        let day11 = calendar.startOfDay(for: TestDateFactory.date(2026, 3, 11, calendar: calendar))

        // When
        let emphasisByDay = HeatmapStreakCellsResolver.emphasisByDay(
            streakDays: [day11, day10, day9],
            endingAt: day11,
            calendar: calendar
        )

        // Then
        XCTAssertEqual(emphasisByDay[day11], .today)
        XCTAssertEqual(emphasisByDay[day10], .streak)
        XCTAssertEqual(emphasisByDay[day9], .streak)
    }

    func testTodayIntensityAdjustmentIsStrongerThanPriorStreakCell() {
        // Given
        let baseIntensity = 0.55

        // When
        let streakIntensity = HeatmapStreakEmphasis.streak.adjustedIntensity(from: baseIntensity)
        let todayIntensity = HeatmapStreakEmphasis.today.adjustedIntensity(from: baseIntensity)

        // Then
        XCTAssertGreaterThan(streakIntensity, baseIntensity)
        XCTAssertGreaterThan(todayIntensity, streakIntensity)
    }
}
