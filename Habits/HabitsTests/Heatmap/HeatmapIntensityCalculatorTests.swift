import XCTest
@testable import Habits

final class HeatmapIntensityCalculatorTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testOpenGoalWithoutLogsHasZeroIntensity() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.openEnded(calendar: calendar)

        let intensity = HeatmapIntensityCalculator.intensity(
            for: day,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )

        XCTAssertEqual(intensity, 0)
    }

    func testOpenGoalWithAnyCompletionHasFullIntensity() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [TestHabitFactory.entry(on: day, value: 1)],
            calendar: calendar
        )

        let intensity = HeatmapIntensityCalculator.intensity(
            for: day,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )

        XCTAssertEqual(intensity, 1)
    }

    func testFrequencyGoalUsesProgressRatio() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 4,
            entries: [
                TestHabitFactory.entry(on: day, value: 1),
                TestHabitFactory.entry(on: day, value: 1),
            ],
            calendar: calendar
        )

        let intensity = HeatmapIntensityCalculator.intensity(
            for: day,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )

        XCTAssertEqual(intensity, 0.5)
    }

    func testFrequencyGoalClampsOverCompletionToOne() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                TestHabitFactory.entry(on: day, value: 1),
                TestHabitFactory.entry(on: day, value: 1),
                TestHabitFactory.entry(on: day, value: 1),
            ],
            calendar: calendar
        )

        let intensity = HeatmapIntensityCalculator.intensity(
            for: day,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )

        XCTAssertEqual(intensity, 1)
    }

    func testCumulativeGoalUsesProgressRatio() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                TestHabitFactory.entry(on: day, value: 10),
                TestHabitFactory.entry(on: day, value: 20),
            ],
            calendar: calendar
        )

        let intensity = HeatmapIntensityCalculator.intensity(
            for: day,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )

        XCTAssertEqual(intensity, 0.3)
    }

    func testCumulativeGoalClampsOverTargetToOne() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                TestHabitFactory.entry(on: day, value: 150),
            ],
            calendar: calendar
        )

        let intensity = HeatmapIntensityCalculator.intensity(
            for: day,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )

        XCTAssertEqual(intensity, 1)
    }

    func testInvalidTargetReturnsZero() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 0,
            hasGoal: true,
            entries: [TestHabitFactory.entry(on: day, value: 20)],
            calendar: calendar
        )

        let intensity = HeatmapIntensityCalculator.intensity(
            for: day,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )

        XCTAssertEqual(intensity, 0)
    }

    func testNoLogsAlwaysReturnsZeroAcrossGoalTypes() {
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habits: [Habit] = [
            TestHabitFactory.openEnded(calendar: calendar),
            TestHabitFactory.frequency(calendar: calendar),
            TestHabitFactory.cumulative(calendar: calendar),
        ]

        for habit in habits {
            let intensity = HeatmapIntensityCalculator.intensity(
                for: day,
                habit: habit,
                logs: habit.logs,
                calendar: calendar
            )
            XCTAssertEqual(intensity, 0)
        }
    }

    func testIntensityGroupingRespectsProvidedCalendarDayBoundaries() {
        var localCalendar = TestDateFactory.utcCalendar
        localCalendar.timeZone = TimeZone(secondsFromGMT: 2 * 60 * 60)!

        let day10 = TestDateFactory.date(2026, 3, 10, hour: 12, calendar: localCalendar)
        let day11 = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: localCalendar)
        let logAtEndOfDay10 = TestHabitFactory.entry(on: TestDateFactory.date(2026, 3, 10, hour: 23, minute: 30, calendar: localCalendar))
        let logAtStartOfDay11 = TestHabitFactory.entry(on: TestDateFactory.date(2026, 3, 11, hour: 0, minute: 30, calendar: localCalendar))
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [logAtEndOfDay10, logAtStartOfDay11],
            calendar: localCalendar
        )

        let day10Intensity = HeatmapIntensityCalculator.intensity(
            for: day10,
            habit: habit,
            logs: habit.logs,
            calendar: localCalendar
        )
        let day11Intensity = HeatmapIntensityCalculator.intensity(
            for: day11,
            habit: habit,
            logs: habit.logs,
            calendar: localCalendar
        )

        XCTAssertEqual(day10Intensity, 0.5)
        XCTAssertEqual(day11Intensity, 0.5)
    }

    func testLevelMappingUsesExpectedBuckets() {
        XCTAssertEqual(HeatmapIntensityCalculator.level(for: 0), 0)
        XCTAssertEqual(HeatmapIntensityCalculator.level(for: 0.1), 0.25)
        XCTAssertEqual(HeatmapIntensityCalculator.level(for: 0.3), 0.5)
        XCTAssertEqual(HeatmapIntensityCalculator.level(for: 0.6), 0.75)
        XCTAssertEqual(HeatmapIntensityCalculator.level(for: 0.9), 1)
    }
}
