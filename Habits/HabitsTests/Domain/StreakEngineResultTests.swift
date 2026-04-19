import XCTest
@testable import Habits

final class StreakEngineResultTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testGrowingStreakReturnsMatchingCurrentAndBest() {
        let start = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let entries = (0..<10).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.addingDays(9, to: start, calendar: calendar)
        let habit = TestHabitFactory.frequency(target: 1, entries: entries, calendar: calendar)

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: asOf)

        XCTAssertEqual(result.best, 10)
        XCTAssertEqual(result.current, 10)
    }

    func testBrokenThenLongerRunUpdatesBest() {
        let start = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        var entries: [TestHabitFactory.Entry] = []
        entries += (0..<5).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        entries += (6..<14).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.addingDays(13, to: start, calendar: calendar)
        let habit = TestHabitFactory.frequency(target: 1, entries: entries, calendar: calendar)

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: asOf)

        XCTAssertEqual(result.best, 8)
        XCTAssertEqual(result.current, 8)
    }

    func testCurrentCanBeLowerThanBest() {
        let start = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        var entries: [TestHabitFactory.Entry] = []
        entries += (0..<10).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        entries += (11..<14).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.addingDays(13, to: start, calendar: calendar)
        let habit = TestHabitFactory.frequency(target: 1, entries: entries, calendar: calendar)

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: asOf)

        XCTAssertEqual(result.best, 10)
        XCTAssertEqual(result.current, 3)
    }

    func testFrequencyTargetMustBeMetPerDay() {
        let day1 = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 4, 2, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 4, 3, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day1, value: 1),
                .init(timestamp: day1, value: 1),
                .init(timestamp: day2, value: 1),
                .init(timestamp: day2, value: 1),
                .init(timestamp: day3, value: 1),
                .init(timestamp: day3, value: 1),
                .init(timestamp: day3, value: 1),
            ],
            calendar: calendar
        )

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: day3)

        XCTAssertEqual(result.best, 1)
        XCTAssertEqual(result.current, 1)
    }

    func testCumulativeTargetMustBeMetPerDay() {
        let day1 = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 4, 2, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 4, 3, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: day1, value: 80),
                .init(timestamp: day1, value: 20),
                .init(timestamp: day2, value: 90),
                .init(timestamp: day3, value: 60),
                .init(timestamp: day3, value: 40),
            ],
            calendar: calendar
        )

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: day3)

        XCTAssertEqual(result.best, 1)
        XCTAssertEqual(result.current, 1)
    }

    func testFrequencyStreakUsesLogicalDayInsteadOfTimestamp() {
        let day1 = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 4, 2, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 4, 3, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day2, value: 1),
            ],
            calendar: calendar
        )

        habit.logs[0].day = day2
        habit.logs[1].day = day3

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: day3)

        XCTAssertEqual(result.best, 2)
        XCTAssertEqual(result.current, 2)
    }

    func testCumulativeStreakUsesLogicalDayInsteadOfTimestamp() {
        let day1 = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 4, 2, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 4, 3, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 10,
            entries: [
                .init(timestamp: day1, value: 10),
                .init(timestamp: day2, value: 10),
            ],
            calendar: calendar
        )

        habit.logs[0].day = day2
        habit.logs[1].day = day3

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: day3)

        XCTAssertEqual(result.best, 2)
        XCTAssertEqual(result.current, 2)
    }

    func testPeriodScopeResetsAtWindowStart() {
        let start = TestDateFactory.date(2026, 3, 28, calendar: calendar)
        let entries = (0..<14).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.date(2026, 4, 10, calendar: calendar)
        let habit = TestHabitFactory.openEnded(entries: entries, calendar: calendar)

        let global = engine.calculateStreak(for: habit, logs: habit.logs, asOf: asOf)
        let aprilInterval = calendar.dateInterval(of: .month, for: TestDateFactory.date(2026, 4, 1, calendar: calendar))
        let april = engine.calculateStreak(
            for: habit,
            logs: habit.logs,
            asOf: asOf,
            period: aprilInterval
        )

        XCTAssertEqual(global.best, 14)
        XCTAssertEqual(april.best, 10)
        XCTAssertEqual(april.current, 10)
    }

    func testOpenHabitLongRunIsNotCappedWithMultipleEntriesPerDay() {
        let start = TestDateFactory.date(2026, 2, 1, calendar: calendar)
        var entries: [TestHabitFactory.Entry] = []
        for dayOffset in 0..<30 {
            let day = TestDateFactory.addingDays(dayOffset, to: start, calendar: calendar)
            entries.append(.init(timestamp: day, value: 1))
            entries.append(.init(timestamp: day, value: 2))
        }
        let asOf = TestDateFactory.addingDays(29, to: start, calendar: calendar)
        let habit = TestHabitFactory.openEnded(entries: entries, calendar: calendar)

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: asOf)

        XCTAssertEqual(result.best, 30)
        XCTAssertEqual(result.current, 30)
    }

    func testOpenGoalContinuousActivityProducesMatchingBestAndCurrent() {
        let start = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let entries = (0..<11).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.addingDays(10, to: start, calendar: calendar)
        let habit = TestHabitFactory.openEnded(entries: entries, calendar: calendar)

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: asOf)

        XCTAssertEqual(result.best, 11)
        XCTAssertEqual(result.current, 11)
    }

    func testOpenGoalBreakInActivitySetsBestAndCurrentRuns() {
        let start = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        var entries: [TestHabitFactory.Entry] = []
        entries += (0..<5).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        entries += (6..<10).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.addingDays(9, to: start, calendar: calendar)
        let habit = TestHabitFactory.openEnded(entries: entries, calendar: calendar)

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: asOf)

        XCTAssertEqual(result.best, 5)
        XCTAssertEqual(result.current, 4)
    }

    func testOpenGoalMultipleLogsPerDayStillCountsSingleSuccessfulDay() {
        let day1 = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 4, 2, calendar: calendar)
        let day3 = TestDateFactory.date(2026, 4, 3, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day1, value: 2),
                .init(timestamp: day1, value: 3),
                .init(timestamp: day1, value: 4),
                .init(timestamp: day1, value: 5),
                .init(timestamp: day1, value: 6),
                .init(timestamp: day1, value: 7),
                .init(timestamp: day1, value: 8),
                .init(timestamp: day1, value: 9),
                .init(timestamp: day1, value: 10),
                .init(timestamp: day2, value: 1),
                .init(timestamp: day3, value: 1),
                .init(timestamp: day3, value: 2),
                .init(timestamp: day3, value: 3),
                .init(timestamp: day3, value: 4),
                .init(timestamp: day3, value: 5),
            ],
            calendar: calendar
        )

        let result = engine.calculateStreak(for: habit, logs: habit.logs, asOf: day3)

        XCTAssertEqual(result.best, 3)
        XCTAssertEqual(result.current, 3)
    }

    func testOpenGoalMonthlyPeriodLongestRunMatchesVisibleContinuousDays() {
        let start = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let entries = (0..<11).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.addingDays(10, to: start, calendar: calendar)
        let month = calendar.dateInterval(of: .month, for: start)
        let habit = TestHabitFactory.openEnded(entries: entries, calendar: calendar)

        let result = engine.calculateStreak(
            for: habit,
            logs: habit.logs,
            asOf: asOf,
            period: month
        )

        XCTAssertEqual(result.best, 11)
        XCTAssertEqual(result.current, 11)
    }

    func testPeriodEndAsAsOfDateIsInclusiveForCurrentDay() {
        let start = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let entries = (0..<20).map { offset in
            TestHabitFactory.entry(on: TestDateFactory.addingDays(offset, to: start, calendar: calendar))
        }
        let asOf = TestDateFactory.date(2026, 4, 20, hour: 18, calendar: calendar)
        let period = DateInterval(start: start, end: asOf)
        let habit = TestHabitFactory.openEnded(entries: entries, calendar: calendar)

        let result = engine.calculateStreak(
            for: habit,
            logs: habit.logs,
            asOf: asOf,
            period: period
        )

        XCTAssertEqual(result.current, 20)
        XCTAssertEqual(result.best, 20)
    }

    private var engine: StreakStateEngine {
        StreakStateEngine(calendar: calendar, weekStartPreference: .monday)
    }
}
