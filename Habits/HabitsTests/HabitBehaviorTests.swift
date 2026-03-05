import XCTest
import SwiftData
@testable import Habits

final class HabitBehaviorTests: XCTestCase {
    private enum HeatmapLevels {
        static let none = 0.0
        static let low = 0.24
        static let medium = 0.40
        static let high = 0.56
        static let bright = 0.86
    }

    private struct Fixtures {
        static let calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            return cal
        }()

        static func makeCalendar(
            firstWeekday: Int,
            timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current
        ) -> Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = timeZone
            cal.firstWeekday = firstWeekday
            return cal
        }

        static func makeDate(year: Int, month: Int, day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
        }

        static func consecutiveDays(starting start: Date, count: Int) -> [Date] {
            (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }

        static func makeContainer() -> ModelContainer {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: Habit.self, HabitLog.self, configurations: config)
        }
    }

    private func makeGoalHabit(goalType: GoalPeriod, target: Int) -> Habit {
        Habit(
            name: "Test",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: goalType,
            goalType: .frequency,
            streakTarget: target,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )
    }

    private func makeCumulativeHabit(
        goalPeriod: GoalPeriod,
        target: Double,
        unit: String = "books",
        allowsDecimals: Bool = false
    ) -> Habit {
        Habit(
            name: "Cumulative",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: goalPeriod,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: target,
            unit: unit,
            allowsDecimals: allowsDecimals,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )
    }

    private func makeOpenEndedCumulativeHabit(
        unit: String = "pages",
        allowsDecimals: Bool = false
    ) -> Habit {
        Habit(
            name: "Open Cumulative",
            colorHex: "#FFFFFF",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .cumulative,
            streakTarget: 1,
            unit: unit,
            allowsDecimals: allowsDecimals,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )
    }

    private func makeOpenEndedHabit() -> Habit {
        Habit(
            name: "Open",
            colorHex: "#FFFFFF",
            hasStreakGoal: false,
            goalPeriod: .daily,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )
    }

    private func seedFrequencyCounts(_ counts: [Int], endingAt endDate: Date, into habit: Habit) {
        habit.logs.removeAll()

        for (index, count) in counts.enumerated() where count > 0 {
            let offset = counts.count - index - 1
            let day = Fixtures.calendar.date(byAdding: .day, value: -offset, to: endDate) ?? endDate
            habit.logs.append(HabitLog(day: day, count: count, calendar: Fixtures.calendar))
        }
    }

    private func seedCumulativeValues(_ values: [Double], endingAt endDate: Date, into habit: Habit) {
        habit.logs.removeAll()

        for (index, value) in values.enumerated() where value > 0 {
            let offset = values.count - index - 1
            let day = Fixtures.calendar.date(byAdding: .day, value: -offset, to: endDate) ?? endDate
            habit.logs.append(HabitLog(timestamp: day, value: value, calendar: Fixtures.calendar))
        }
    }

    private func heatmapTier(for intensity: Double) -> Int {
        switch intensity {
        case let value where abs(value - HeatmapLevels.none) < 0.0001:
            return 0
        case let value where abs(value - HeatmapLevels.low) < 0.0001:
            return 1
        case let value where abs(value - HeatmapLevels.medium) < 0.0001:
            return 2
        case let value where abs(value - HeatmapLevels.high) < 0.0001:
            return 3
        case let value where abs(value - HeatmapLevels.bright) < 0.0001:
            return 4
        default:
            XCTFail("Unexpected heatmap intensity \(intensity)")
            return -1
        }
    }

    private func heatmapTierCounts(
        for habit: Habit,
        service: HabitLogService,
        endingAt endDate: Date,
        days: Int = 90
    ) -> [Int] {
        let start = Fixtures.calendar.date(byAdding: .day, value: -(days - 1), to: endDate) ?? endDate
        var counts = Array(repeating: 0, count: 5)

        for offset in 0..<days {
            let day = Fixtures.calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let tier = heatmapTier(for: service.intensity(for: habit, on: day))
            counts[tier] += 1
        }

        return counts
    }

    private func activeShare(of tier: Int, in counts: [Int]) -> Double {
        let activeDays = counts.dropFirst().reduce(0, +)
        guard activeDays > 0 else { return 0 }
        return Double(counts[tier]) / Double(activeDays)
    }

    // MARK: - Logging Behavior

    func testIncrementCreatesLogWhenNoneExists() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let count = service.increment(for: habit, on: day)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.kind, .entry)
        XCTAssertEqual(habit.logs.first?.numericValue, 1)
    }

    func testIncrementIncreasesCountForExistingDay() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.increment(for: habit, on: day)
        let count = service.increment(for: habit, on: day)

        XCTAssertEqual(count, 2)
        XCTAssertEqual(habit.logs.count, 2)
        XCTAssertEqual(habit.count(on: day, calendar: Fixtures.calendar), 2)
    }

    func testDecrementReducesCount() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.setCount(for: habit, on: day, to: 3)

        let count = service.decrement(for: habit, on: day)

        XCTAssertEqual(count, 2)
        XCTAssertEqual(habit.count(on: day, calendar: Fixtures.calendar), 2)
    }

    func testDecrementRemovesLogWhenCountReachesZero() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.setCount(for: habit, on: day, to: 1)

        let count = service.decrement(for: habit, on: day)

        XCTAssertEqual(count, 0)
        XCTAssertTrue(habit.logs.isEmpty)
    }

    func testSetCountUpdatesExistingLog() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.increment(for: habit, on: day)

        let count = service.setCount(for: habit, on: day, to: 5)

        XCTAssertEqual(count, 5)
        XCTAssertEqual(habit.logs.count, 5)
        XCTAssertEqual(habit.count(on: day, calendar: Fixtures.calendar), 5)
    }

    func testSetCountRemovesLogWhenValueIsZero() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.increment(for: habit, on: day)

        let count = service.setCount(for: habit, on: day, to: 0)

        XCTAssertEqual(count, 0)
        XCTAssertTrue(habit.logs.isEmpty)
    }

    // MARK: - Daily Goal Behavior

    func testDailyProgressReturnsCorrectPercentage() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 2, calendar: Fixtures.calendar)]

        let progress = habit.progress(for: day, calendar: Fixtures.calendar)

        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testDailyProgressClampsAtOneWhenOverTarget() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 5, calendar: Fixtures.calendar)]

        let progress = habit.progress(for: day, calendar: Fixtures.calendar)

        XCTAssertEqual(progress, 1.0)
    }

    func testDailyProgressUsesProvidedDateContext() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let firstDay = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let secondDay = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        habit.logs = [
            HabitLog(day: firstDay, count: 1, calendar: Fixtures.calendar),
            HabitLog(day: secondDay, count: 3, calendar: Fixtures.calendar)
        ]

        let firstProgress = try! XCTUnwrap(habit.progress(for: firstDay, calendar: Fixtures.calendar))
        let secondProgress = try! XCTUnwrap(habit.progress(for: secondDay, calendar: Fixtures.calendar))

        XCTAssertEqual(firstProgress, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(secondProgress, 1.0, accuracy: 0.0001)
    }

    func testGoalStateHasGoalIsFalseForOpenEndedHabit() {
        let habit = makeOpenEndedHabit()

        XCTAssertFalse(habit.hasGoal)
    }

    func testGoalStateHasGoalIsTrueForConfiguredGoal() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)

        XCTAssertTrue(habit.hasGoal)
    }

    func testGoalStateProgressFractionIsNilForOpenEndedHabit() {
        let habit = makeOpenEndedHabit()
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        XCTAssertNil(habit.progressFraction(for: day, calendar: Fixtures.calendar))
    }

    func testGoalStateBinaryGoalCompletesAfterFirstLog() {
        let habit = makeGoalHabit(goalType: .daily, target: 1)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 1, calendar: Fixtures.calendar)]

        XCTAssertEqual(habit.progressFraction(for: day, calendar: Fixtures.calendar), 1.0)
        XCTAssertTrue(habit.isComplete(for: day, calendar: Fixtures.calendar))
    }

    func testGoalStateRemovingGoalClearsProgressFraction() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 2, calendar: Fixtures.calendar)]

        let progress = try! XCTUnwrap(habit.progressFraction(for: day, calendar: Fixtures.calendar))

        XCTAssertEqual(progress, 2.0 / 3.0, accuracy: 0.0001)

        habit.hasStreakGoal = false

        XCTAssertNil(habit.progressFraction(for: day, calendar: Fixtures.calendar))
        XCTAssertFalse(habit.isComplete(for: day, calendar: Fixtures.calendar))
    }

    func testGoalStateCompletionUsesProvidedDate() {
        let habit = makeGoalHabit(goalType: .daily, target: 2)
        let completeDay = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let incompleteDay = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        habit.logs = [
            HabitLog(day: completeDay, count: 2, calendar: Fixtures.calendar),
            HabitLog(day: incompleteDay, count: 1, calendar: Fixtures.calendar)
        ]

        XCTAssertTrue(habit.isComplete(for: completeDay, calendar: Fixtures.calendar))
        XCTAssertFalse(habit.isComplete(for: incompleteDay, calendar: Fixtures.calendar))
    }

    func testGoalStateFutureDateWithoutLogsReturnsZeroProgress() {
        let habit = makeGoalHabit(goalType: .daily, target: 2)
        let futureDay = Fixtures.makeDate(year: 2025, month: 6, day: 20)

        let progress = try! XCTUnwrap(habit.progress(for: futureDay, calendar: Fixtures.calendar))

        XCTAssertEqual(progress, 0.0)
        XCTAssertFalse(habit.isComplete(for: futureDay, calendar: Fixtures.calendar))
    }

    func testDailyHasHitTargetWhenCountMeetsTarget() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 3, calendar: Fixtures.calendar)]

        let interval = habit.periodRange(for: day, calendar: Fixtures.calendar)

        XCTAssertTrue(habit.hasHitTarget(in: interval))
    }

    func testDailyCurrentStreakIncrementsAcrossConsecutiveQualifyingDays() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let dates = Fixtures.consecutiveDays(starting: Fixtures.calendar.date(byAdding: .day, value: -2, to: reference)!, count: 3)

        habit.logs = [
            HabitLog(day: dates[0], count: 3, calendar: Fixtures.calendar),
            HabitLog(day: dates[1], count: 3, calendar: Fixtures.calendar),
            HabitLog(day: dates[2], count: 3, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 3)
    }

    func testDailyCurrentStreakStopsWhenDayDoesNotMeetTarget() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let dates = Fixtures.consecutiveDays(starting: Fixtures.calendar.date(byAdding: .day, value: -2, to: reference)!, count: 3)

        habit.logs = [
            HabitLog(day: dates[0], count: 2, calendar: Fixtures.calendar),
            HabitLog(day: dates[1], count: 3, calendar: Fixtures.calendar),
            HabitLog(day: dates[2], count: 3, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 2)
    }

    func testTotalCountTreatsIntervalEndAsExclusive() {
        let habit = makeGoalHabit(goalType: .daily, target: 1)
        let today = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let yesterdayStart = Fixtures.calendar.date(byAdding: .day, value: -1, to: today)!
        let yesterdayInterval = DateInterval(start: yesterdayStart, end: today)

        habit.logs = [HabitLog(day: today, count: 2, calendar: Fixtures.calendar)]

        XCTAssertEqual(habit.totalCount(in: yesterdayInterval), 0)
    }

    func testDailyCurrentStreakForBrandNewHabitCountsOnlyToday() {
        let habit = makeGoalHabit(goalType: .daily, target: 2)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: reference, count: 2, calendar: Fixtures.calendar)]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 1)
    }

    func testDailyCurrentStreakStopsImmediatelyWhenPreviousDayHasNoLogs() {
        let habit = makeGoalHabit(goalType: .daily, target: 2)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let olderCompletedDay = Fixtures.calendar.date(byAdding: .day, value: -2, to: reference)!

        habit.logs = [
            HabitLog(day: olderCompletedDay, count: 2, calendar: Fixtures.calendar),
            HabitLog(day: reference, count: 2, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 1)
    }

    func testDailyCurrentStreakIsZeroWhenCurrentDayIsIncomplete() {
        let habit = makeGoalHabit(goalType: .daily, target: 2)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let yesterday = Fixtures.calendar.date(byAdding: .day, value: -1, to: reference)!

        habit.logs = [
            HabitLog(day: yesterday, count: 2, calendar: Fixtures.calendar),
            HabitLog(day: reference, count: 1, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 0)
    }

    func testDailyCurrentStreakIsZeroWhenThereAreNoLogs() {
        let habit = makeGoalHabit(goalType: .daily, target: 2)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 0)
    }

    func testDailyCurrentStreakUsesProvidedCalendarBoundaries() {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current

        let habit = makeGoalHabit(goalType: .daily, target: 1)
        let reference = localCalendar.date(from: DateComponents(year: 2025, month: 3, day: 10, hour: 12))!
        let today = localCalendar.startOfDay(for: reference)
        let yesterday = localCalendar.date(byAdding: .day, value: -1, to: today)!

        habit.logs = [
            HabitLog(day: yesterday, count: 1, calendar: localCalendar),
            HabitLog(day: today, count: 1, calendar: localCalendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: localCalendar)

        XCTAssertEqual(streak, 2)
    }

    // MARK: - Weekly Goal Behavior

    func testWeeklyPeriodRangeReturnsMondayStartedWeekForMondayFirstCalendar() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        let interval = habit.periodRange(for: day, calendar: calendar)

        XCTAssertEqual(interval.start, Fixtures.makeDate(year: 2025, month: 6, day: 9))
        XCTAssertEqual(interval.end, Fixtures.makeDate(year: 2025, month: 6, day: 16))
    }

    func testWeeklyPeriodRangeReturnsSundayStartedWeekForSundayFirstCalendar() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 1)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        let interval = habit.periodRange(for: day, calendar: calendar)

        XCTAssertEqual(interval.start, Fixtures.makeDate(year: 2025, month: 6, day: 8))
        XCTAssertEqual(interval.end, Fixtures.makeDate(year: 2025, month: 6, day: 15))
    }

    func testWeeklyPeriodRangeIsStableForMultipleDatesInSameWeek() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let monday = Fixtures.makeDate(year: 2025, month: 6, day: 9)
        let friday = Fixtures.makeDate(year: 2025, month: 6, day: 13)

        let mondayInterval = habit.periodRange(for: monday, calendar: calendar)
        let fridayInterval = habit.periodRange(for: friday, calendar: calendar)

        XCTAssertEqual(mondayInterval.start, fridayInterval.start)
        XCTAssertEqual(mondayInterval.end, fridayInterval.end)
    }

    func testWeeklyProgressAccumulatesAcrossDaysInWeek() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 5)
        let tuesday = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let thursday = Fixtures.makeDate(year: 2025, month: 6, day: 12)

        habit.logs = [
            HabitLog(day: tuesday, count: 2, calendar: calendar),
            HabitLog(day: thursday, count: 1, calendar: calendar)
        ]

        let progress = try! XCTUnwrap(habit.progress(for: thursday, calendar: calendar))

        XCTAssertEqual(progress, 3.0 / 5.0, accuracy: 0.0001)
    }

    func testWeeklyProgressIgnoresLogsOutsideWeek() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 5)
        let previousWeek = Fixtures.makeDate(year: 2025, month: 6, day: 8)
        let currentWeek = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        habit.logs = [
            HabitLog(day: previousWeek, count: 4, calendar: calendar),
            HabitLog(day: currentWeek, count: 2, calendar: calendar)
        ]

        let progress = try! XCTUnwrap(habit.progress(for: currentWeek, calendar: calendar))

        XCTAssertEqual(progress, 2.0 / 5.0, accuracy: 0.0001)
    }

    func testWeeklyProgressClampsAtOneAndPreservesOverflowInDetails() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let monday = Fixtures.makeDate(year: 2025, month: 6, day: 9)
        let wednesday = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        habit.logs = [
            HabitLog(day: monday, count: 2, calendar: calendar),
            HabitLog(day: wednesday, count: 3, calendar: calendar)
        ]

        let progress = habit.progress(for: wednesday, calendar: calendar)
        let details = try! XCTUnwrap(habit.progressDetails(for: wednesday, calendar: calendar))

        XCTAssertEqual(progress, 1.0)
        XCTAssertEqual(details.current, 5)
        XCTAssertEqual(details.target, 3)
    }

    func testWeeklyHasHitTargetWhenWeekTotalMeetsTarget() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let monday = Fixtures.makeDate(year: 2025, month: 6, day: 9)
        let thursday = Fixtures.makeDate(year: 2025, month: 6, day: 12)

        habit.logs = [
            HabitLog(day: monday, count: 1, calendar: calendar),
            HabitLog(day: thursday, count: 2, calendar: calendar)
        ]

        let interval = habit.periodRange(for: thursday, calendar: calendar)

        XCTAssertTrue(habit.hasHitTarget(in: interval))
    }

    func testWeeklyCurrentStreakCountsConsecutiveCompletedWeeks() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        habit.logs = [
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 10), count: 3, calendar: calendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 17), count: 3, calendar: calendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 23), count: 3, calendar: calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: calendar)

        XCTAssertEqual(streak, 3)
    }

    func testWeeklyCurrentStreakBreaksWhenPreviousWeekMissesTarget() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        habit.logs = [
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 10), count: 3, calendar: calendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 17), count: 2, calendar: calendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 23), count: 3, calendar: calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: calendar)

        XCTAssertEqual(streak, 1)
    }

    func testWeeklyCurrentStreakIsZeroWhenCurrentWeekIncomplete() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        habit.logs = [
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 16), count: 3, calendar: calendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 23), count: 2, calendar: calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: calendar)

        XCTAssertEqual(streak, 0)
    }

    func testWeeklyCurrentStreakUsesProvidedCalendarBoundaries() {
        let mondayCalendar = Fixtures.makeCalendar(firstWeekday: 2)
        let sundayCalendar = Fixtures.makeCalendar(firstWeekday: 1)
        let habit = makeGoalHabit(goalType: .weekly, target: 2)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 9)

        habit.logs = [
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 8), count: 1, calendar: mondayCalendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 9), count: 1, calendar: mondayCalendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 15), count: 1, calendar: mondayCalendar)
        ]

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: mondayCalendar), 0)
        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: sundayCalendar), 1)
    }

    func testWeeklyRetroactiveLogIntoPreviousWeekRecalculatesCurrentStreak() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        habit.logs = [
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 10), count: 3, calendar: calendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 17), count: 2, calendar: calendar),
            HabitLog(day: Fixtures.makeDate(year: 2025, month: 6, day: 23), count: 3, calendar: calendar)
        ]

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: calendar), 1)

        habit.log(on: Fixtures.makeDate(year: 2025, month: 6, day: 18), amount: 1, calendar: calendar)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: calendar), 3)
    }

    func testWeeklyDeletingPastWeekLogRecalculatesCurrentStreak() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)
        context.insert(habit)

        _ = service.setCount(for: habit, on: Fixtures.makeDate(year: 2025, month: 6, day: 10), to: 3)
        _ = service.setCount(for: habit, on: Fixtures.makeDate(year: 2025, month: 6, day: 17), to: 3)
        _ = service.setCount(for: habit, on: Fixtures.makeDate(year: 2025, month: 6, day: 23), to: 3)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: calendar), 3)

        _ = service.setCount(for: habit, on: Fixtures.makeDate(year: 2025, month: 6, day: 17), to: 0)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: calendar), 1)
    }

    func testWeeklyIncreasingTargetRecalculatesCompletion() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        habit.logs = [HabitLog(day: day, count: 3, calendar: calendar)]

        XCTAssertTrue(habit.isComplete(for: day, calendar: calendar))

        habit.streakTarget = 4

        XCTAssertEqual(try! XCTUnwrap(habit.progress(for: day, calendar: calendar)), 0.75, accuracy: 0.0001)
        XCTAssertFalse(habit.isComplete(for: day, calendar: calendar))
    }

    func testWeeklyDecreasingTargetRecalculatesCompletion() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .weekly, target: 4)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        habit.logs = [HabitLog(day: day, count: 3, calendar: calendar)]

        XCTAssertFalse(habit.isComplete(for: day, calendar: calendar))

        habit.streakTarget = 3

        XCTAssertEqual(habit.progress(for: day, calendar: calendar), 1.0)
        XCTAssertTrue(habit.isComplete(for: day, calendar: calendar))
    }

    func testChangingHabitPeriodFromDailyToWeeklyReinterpretsExistingLogsWithoutMigration() {
        let calendar = Fixtures.makeCalendar(firstWeekday: 2)
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let monday = Fixtures.makeDate(year: 2025, month: 6, day: 9)
        let tuesday = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let wednesday = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        habit.logs = [
            HabitLog(day: monday, count: 1, calendar: calendar),
            HabitLog(day: tuesday, count: 1, calendar: calendar),
            HabitLog(day: wednesday, count: 1, calendar: calendar)
        ]

        XCTAssertEqual(try! XCTUnwrap(habit.progress(for: wednesday, calendar: calendar)), 1.0 / 3.0, accuracy: 0.0001)

        habit.goalPeriod = .weekly

        XCTAssertEqual(try! XCTUnwrap(habit.progress(for: wednesday, calendar: calendar)), 1.0, accuracy: 0.0001)
        XCTAssertTrue(habit.isComplete(for: wednesday, calendar: calendar))
    }

    // MARK: - Monthly Goal Behavior

    func testMonthlyProgressAccumulatesAcrossDaysInMonth() {
        let habit = makeGoalHabit(goalType: .monthly, target: 10)
        let day1 = Fixtures.makeDate(year: 2025, month: 2, day: 5)
        let day2 = Fixtures.makeDate(year: 2025, month: 2, day: 12)
        let day3 = Fixtures.makeDate(year: 2025, month: 2, day: 20)

        habit.logs = [
            HabitLog(day: day1, count: 3, calendar: Fixtures.calendar),
            HabitLog(day: day2, count: 4, calendar: Fixtures.calendar),
            HabitLog(day: day3, count: 2, calendar: Fixtures.calendar)
        ]

        let progress = habit.progress(for: day2, calendar: Fixtures.calendar)

        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 9.0 / 10.0, accuracy: 0.0001)
    }

    func testMonthlyProgressClampsAtOne() {
        let habit = makeGoalHabit(goalType: .monthly, target: 10)
        let day1 = Fixtures.makeDate(year: 2025, month: 2, day: 5)
        let day2 = Fixtures.makeDate(year: 2025, month: 2, day: 12)

        habit.logs = [
            HabitLog(day: day1, count: 7, calendar: Fixtures.calendar),
            HabitLog(day: day2, count: 6, calendar: Fixtures.calendar)
        ]

        let progress = habit.progress(for: day2, calendar: Fixtures.calendar)

        XCTAssertEqual(progress, 1.0)
    }

    func testMonthlyProgressFractionUsesCurrentMonthTotal() {
        let habit = makeGoalHabit(goalType: .monthly, target: 10)
        let jan = Fixtures.makeDate(year: 2025, month: 1, day: 30)
        let feb1 = Fixtures.makeDate(year: 2025, month: 2, day: 5)
        let feb2 = Fixtures.makeDate(year: 2025, month: 2, day: 12)

        habit.logs = [
            HabitLog(day: jan, count: 8, calendar: Fixtures.calendar),
            HabitLog(day: feb1, count: 2, calendar: Fixtures.calendar),
            HabitLog(day: feb2, count: 3, calendar: Fixtures.calendar)
        ]

        let progress = try! XCTUnwrap(habit.progressFraction(for: feb2, calendar: Fixtures.calendar))

        XCTAssertEqual(
            progress,
            0.5,
            accuracy: 0.0001
        )
    }

    func testMonthlyCurrentStreakCountsConsecutiveCompletedMonths() {
        let habit = makeGoalHabit(goalType: .monthly, target: 10)
        let reference = Fixtures.makeDate(year: 2025, month: 3, day: 15)
        let feb1 = Fixtures.makeDate(year: 2025, month: 2, day: 5)
        let feb2 = Fixtures.makeDate(year: 2025, month: 2, day: 15)
        let mar1 = Fixtures.makeDate(year: 2025, month: 3, day: 5)
        let mar2 = Fixtures.makeDate(year: 2025, month: 3, day: 18)

        habit.logs = [
            HabitLog(day: feb1, count: 6, calendar: Fixtures.calendar),
            HabitLog(day: feb2, count: 4, calendar: Fixtures.calendar),
            HabitLog(day: mar1, count: 6, calendar: Fixtures.calendar),
            HabitLog(day: mar2, count: 5, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 2)
    }

    func testMonthlyCurrentStreakBreaksWhenMonthDoesNotHitTarget() {
        let habit = makeGoalHabit(goalType: .monthly, target: 10)
        let reference = Fixtures.makeDate(year: 2025, month: 3, day: 15)
        let jan = Fixtures.makeDate(year: 2025, month: 1, day: 10)
        let feb1 = Fixtures.makeDate(year: 2025, month: 2, day: 5)
        let feb2 = Fixtures.makeDate(year: 2025, month: 2, day: 15)
        let mar1 = Fixtures.makeDate(year: 2025, month: 3, day: 5)

        habit.logs = [
            HabitLog(day: jan, count: 10, calendar: Fixtures.calendar),
            HabitLog(day: feb1, count: 4, calendar: Fixtures.calendar),
            HabitLog(day: feb2, count: 4, calendar: Fixtures.calendar),
            HabitLog(day: mar1, count: 10, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 1)
    }

    func testMonthlyCurrentStreakDoesNotDoubleCountAtMonthBoundary() {
        let habit = makeGoalHabit(goalType: .monthly, target: 5)
        let reference = Fixtures.makeDate(year: 2025, month: 3, day: 15)
        let marchStart = Fixtures.makeDate(year: 2025, month: 3, day: 1)

        habit.logs = [HabitLog(day: marchStart, count: 5, calendar: Fixtures.calendar)]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 1)
    }

    // MARK: - Yearly Goal Behavior

    func testYearlyProgressAccumulatesAcrossDaysInYear() {
        let habit = makeGoalHabit(goalType: .yearly, target: 10)
        let day1 = Fixtures.makeDate(year: 2024, month: 5, day: 5)
        let day2 = Fixtures.makeDate(year: 2024, month: 6, day: 5)

        habit.logs = [
            HabitLog(day: day1, count: 4, calendar: Fixtures.calendar),
            HabitLog(day: day2, count: 3, calendar: Fixtures.calendar)
        ]

        let progress = habit.progress(for: day2, calendar: Fixtures.calendar)

        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 7.0 / 10.0, accuracy: 0.0001)
    }

    func testYearlyProgressClampsAtOne() {
        let habit = makeGoalHabit(goalType: .yearly, target: 10)
        let day1 = Fixtures.makeDate(year: 2024, month: 5, day: 5)
        let day2 = Fixtures.makeDate(year: 2024, month: 7, day: 5)

        habit.logs = [
            HabitLog(day: day1, count: 7, calendar: Fixtures.calendar),
            HabitLog(day: day2, count: 6, calendar: Fixtures.calendar)
        ]

        let progress = habit.progress(for: day2, calendar: Fixtures.calendar)

        XCTAssertEqual(progress, 1.0)
    }

    func testYearlyProgressFractionUsesCurrentYearTotal() {
        let habit = makeGoalHabit(goalType: .yearly, target: 10)
        let year2024 = Fixtures.makeDate(year: 2024, month: 5, day: 5)
        let year2025a = Fixtures.makeDate(year: 2025, month: 2, day: 5)
        let year2025b = Fixtures.makeDate(year: 2025, month: 7, day: 5)

        habit.logs = [
            HabitLog(day: year2024, count: 9, calendar: Fixtures.calendar),
            HabitLog(day: year2025a, count: 2, calendar: Fixtures.calendar),
            HabitLog(day: year2025b, count: 5, calendar: Fixtures.calendar)
        ]

        let progress = try! XCTUnwrap(habit.progressFraction(for: year2025b, calendar: Fixtures.calendar))

        XCTAssertEqual(
            progress,
            0.7,
            accuracy: 0.0001
        )
    }

    func testYearlyCurrentStreakCountsConsecutiveCompletedYears() {
        let habit = makeGoalHabit(goalType: .yearly, target: 10)
        let reference = Fixtures.makeDate(year: 2025, month: 11, day: 1)
        let year2024a = Fixtures.makeDate(year: 2024, month: 3, day: 10)
        let year2024b = Fixtures.makeDate(year: 2024, month: 9, day: 10)
        let year2025a = Fixtures.makeDate(year: 2025, month: 2, day: 10)
        let year2025b = Fixtures.makeDate(year: 2025, month: 8, day: 10)

        habit.logs = [
            HabitLog(day: year2024a, count: 4, calendar: Fixtures.calendar),
            HabitLog(day: year2024b, count: 6, calendar: Fixtures.calendar),
            HabitLog(day: year2025a, count: 5, calendar: Fixtures.calendar),
            HabitLog(day: year2025b, count: 5, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 2)
    }

    func testYearlyCurrentStreakBreaksWhenYearDoesNotHitTarget() {
        let habit = makeGoalHabit(goalType: .yearly, target: 10)
        let reference = Fixtures.makeDate(year: 2025, month: 11, day: 1)
        let year2023 = Fixtures.makeDate(year: 2023, month: 7, day: 10)
        let year2024 = Fixtures.makeDate(year: 2024, month: 7, day: 10)
        let year2025 = Fixtures.makeDate(year: 2025, month: 7, day: 10)

        habit.logs = [
            HabitLog(day: year2023, count: 10, calendar: Fixtures.calendar),
            HabitLog(day: year2024, count: 3, calendar: Fixtures.calendar),
            HabitLog(day: year2025, count: 10, calendar: Fixtures.calendar)
        ]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 1)
    }

    func testYearlyCurrentStreakDoesNotDoubleCountAtYearBoundary() {
        let habit = makeGoalHabit(goalType: .yearly, target: 5)
        let reference = Fixtures.makeDate(year: 2025, month: 8, day: 1)
        let yearStart = Fixtures.makeDate(year: 2025, month: 1, day: 1)

        habit.logs = [HabitLog(day: yearStart, count: 5, calendar: Fixtures.calendar)]

        let streak = habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar)

        XCTAssertEqual(streak, 1)
    }

    // MARK: - Open-Ended Habit Behavior

    func testOpenEndedProgressIsNil() {
        let habit = makeOpenEndedHabit()
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        XCTAssertNil(habit.progress(for: day, calendar: Fixtures.calendar))
    }

    func testOpenEndedHasHitTargetReturnsFalse() {
        let habit = makeOpenEndedHabit()
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let interval = habit.periodRange(for: day, calendar: Fixtures.calendar)

        XCTAssertFalse(habit.hasHitTarget(in: interval))
    }

    func testOpenEndedIntensityUsesNoFillForEmptyDay() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let intensity = service.intensity(for: habit, on: day)

        XCTAssertEqual(intensity, HeatmapLevels.none, accuracy: 0.0001)
    }

    // MARK: - Intensity Behavior

    func testDailyFrequencyTargetOneMarksAnyActivityAsBright() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 1)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.setCount(for: habit, on: day, to: 1)

        XCTAssertEqual(service.intensity(for: habit, on: day), HeatmapLevels.bright, accuracy: 0.0001)
        XCTAssertEqual(service.intensity(for: habit, on: Fixtures.makeDate(year: 2025, month: 6, day: 9)), HeatmapLevels.none, accuracy: 0.0001)
    }

    func testDailyFrequencyTargetTwoUsesMediumAndBrightTiers() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 2)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let nextDay = Fixtures.makeDate(year: 2025, month: 6, day: 11)
        _ = service.setCount(for: habit, on: day, to: 1)
        _ = service.setCount(for: habit, on: nextDay, to: 2)

        XCTAssertEqual(service.intensity(for: habit, on: day), HeatmapLevels.medium, accuracy: 0.0001)
        XCTAssertEqual(service.intensity(for: habit, on: nextDay), HeatmapLevels.bright, accuracy: 0.0001)
    }

    func testDailyFrequencyTargetThreeUsesLowHighAndBrightTiers() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        context.insert(habit)

        let day1 = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let day2 = Fixtures.makeDate(year: 2025, month: 6, day: 11)
        let day3 = Fixtures.makeDate(year: 2025, month: 6, day: 12)
        let day4 = Fixtures.makeDate(year: 2025, month: 6, day: 13)
        _ = service.setCount(for: habit, on: day1, to: 1)
        _ = service.setCount(for: habit, on: day2, to: 2)
        _ = service.setCount(for: habit, on: day3, to: 3)
        _ = service.setCount(for: habit, on: day4, to: 5)

        XCTAssertEqual(service.intensity(for: habit, on: day1), HeatmapLevels.low, accuracy: 0.0001)
        XCTAssertEqual(service.intensity(for: habit, on: day2), HeatmapLevels.high, accuracy: 0.0001)
        XCTAssertEqual(service.intensity(for: habit, on: day3), HeatmapLevels.bright, accuracy: 0.0001)
        XCTAssertEqual(service.intensity(for: habit, on: day4), HeatmapLevels.bright, accuracy: 0.0001)
    }

    func testWeeklyGoalBasedIntensityUsesDailyCountNotWeeklyAggregate() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        context.insert(habit)

        let monday = Fixtures.makeDate(year: 2025, month: 6, day: 9)
        let tuesday = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        _ = service.setCount(for: habit, on: monday, to: 3)
        _ = service.setCount(for: habit, on: tuesday, to: 1)

        XCTAssertEqual(service.intensity(for: habit, on: monday), HeatmapLevels.bright, accuracy: 0.0001)
        XCTAssertEqual(service.intensity(for: habit, on: tuesday), HeatmapLevels.low, accuracy: 0.0001)
    }

    func testOpenEndedFrequencyDistributionKeepsBrightTierUncommon() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        seedFrequencyCounts(
            Array(repeating: 0, count: 52) +
            Array(repeating: 1, count: 16) +
            Array(repeating: 2, count: 12) +
            Array(repeating: 4, count: 6) +
            Array(repeating: 8, count: 4),
            endingAt: endDate,
            into: habit
        )

        let counts = heatmapTierCounts(for: habit, service: service, endingAt: endDate)

        XCTAssertGreaterThan(activeShare(of: 4, in: counts), 0)
        XCTAssertLessThan(activeShare(of: 4, in: counts), 0.20)
        XCTAssertGreaterThan(activeShare(of: 3, in: counts), 0.10)
    }

    func testWeeklyFrequencyDistributionKeepsClusteredActivityCalm() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .weekly, target: 3)
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        seedFrequencyCounts(
            Array(repeating: 0, count: 54) +
            Array(repeating: 1, count: 18) +
            Array(repeating: 2, count: 12) +
            Array(repeating: 3, count: 5) +
            [4],
            endingAt: endDate,
            into: habit
        )

        let counts = heatmapTierCounts(for: habit, service: service, endingAt: endDate)

        XCTAssertGreaterThan(activeShare(of: 4, in: counts), 0)
        XCTAssertLessThan(activeShare(of: 4, in: counts), 0.25)
        XCTAssertGreaterThan(activeShare(of: 3, in: counts), 0.20)
    }

    func testLargeTargetFrequencyUsesDistributionInsteadOfImmediateBrightTiles() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 6)
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        seedFrequencyCounts(
            Array(repeating: 0, count: 48) +
            Array(repeating: 1, count: 20) +
            Array(repeating: 2, count: 12) +
            Array(repeating: 4, count: 8) +
            Array(repeating: 6, count: 2),
            endingAt: endDate,
            into: habit
        )

        let counts = heatmapTierCounts(for: habit, service: service, endingAt: endDate)

        XCTAssertGreaterThan(activeShare(of: 4, in: counts), 0)
        XCTAssertLessThan(activeShare(of: 4, in: counts), 0.15)
        XCTAssertGreaterThan(service.intensity(for: habit, on: endDate), service.intensity(for: habit, on: Fixtures.makeDate(year: 2025, month: 6, day: 28)))
    }

    // MARK: - Cumulative Goal Behavior

    func testCumulativeGoalStoresConfiguration() {
        let habit = makeCumulativeHabit(goalPeriod: .monthly, target: 20, unit: "books")

        XCTAssertEqual(habit.goalType, .cumulative)
        XCTAssertEqual(habit.targetValue, 20)
        XCTAssertEqual(habit.unit, "books")
        XCTAssertFalse(habit.allowsDecimals)
    }

    func testCumulativeQuickLogCreatesValueEntry() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 5, unit: "km", allowsDecimals: true)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let total = service.quickLog(for: habit, on: day)

        XCTAssertEqual(total, 1)
        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.kind, .entry)
        XCTAssertEqual(habit.logs.first?.numericValue, 1)
    }

    func testCumulativeProgressSumsValuesWithinPeriod() {
        let habit = makeCumulativeHabit(goalPeriod: .weekly, target: 10, unit: "km", allowsDecimals: true)
        let monday = Fixtures.makeDate(year: 2025, month: 6, day: 9)
        let wednesday = Fixtures.makeDate(year: 2025, month: 6, day: 11)

        habit.logValue(on: monday, value: 2.5, calendar: Fixtures.calendar)
        habit.logValue(on: wednesday, value: 3.0, calendar: Fixtures.calendar)

        XCTAssertEqual(habit.progressTotal(for: wednesday, calendar: Fixtures.calendar), 5.5, accuracy: 0.0001)
        XCTAssertEqual(try! XCTUnwrap(habit.progress(for: wednesday, calendar: Fixtures.calendar)), 0.55, accuracy: 0.0001)
    }

    func testCumulativeProgressExcludesOtherPeriods() {
        let habit = makeCumulativeHabit(goalPeriod: .monthly, target: 10, unit: "km", allowsDecimals: true)
        let may = Fixtures.makeDate(year: 2025, month: 5, day: 30)
        let june = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        habit.logValue(on: may, value: 4, calendar: Fixtures.calendar)
        habit.logValue(on: june, value: 3.5, calendar: Fixtures.calendar)

        XCTAssertEqual(habit.progressTotal(for: june, calendar: Fixtures.calendar), 3.5, accuracy: 0.0001)
    }

    func testCumulativeDailyTotalsReconcileWithPeriodTotal() {
        let habit = makeCumulativeHabit(goalPeriod: .monthly, target: 20, unit: "books", allowsDecimals: true)
        let june10 = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        let june12 = Fixtures.makeDate(year: 2025, month: 6, day: 12)
        let june16 = Fixtures.makeDate(year: 2025, month: 6, day: 16)

        habit.logValue(on: june10, value: 2.5, calendar: Fixtures.calendar)
        habit.logValue(on: june12, value: 4, calendar: Fixtures.calendar)
        habit.logValue(on: june16, value: 1.5, calendar: Fixtures.calendar)

        let interval = habit.periodRange(for: june16, calendar: Fixtures.calendar)
        let dailyTotals = habit.dailyValueTotals(in: interval)
        let visibleSum = dailyTotals.values.reduce(0, +)

        XCTAssertEqual(visibleSum, habit.progressTotal(for: june16, calendar: Fixtures.calendar), accuracy: 0.0001)
    }

    func testCumulativeCompletionPreservesOverflowInDetails() {
        let habit = makeCumulativeHabit(goalPeriod: .weekly, target: 5, unit: "books")
        let monday = Fixtures.makeDate(year: 2025, month: 6, day: 9)
        let tuesday = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        habit.logValue(on: monday, value: 3, calendar: Fixtures.calendar)
        habit.logValue(on: tuesday, value: 4, calendar: Fixtures.calendar)

        let details = try! XCTUnwrap(habit.progressDetails(for: tuesday, calendar: Fixtures.calendar))

        XCTAssertTrue(habit.isComplete(for: tuesday, calendar: Fixtures.calendar))
        XCTAssertEqual(habit.progress(for: tuesday, calendar: Fixtures.calendar), 1.0)
        XCTAssertEqual(details.current, 7, accuracy: 0.0001)
        XCTAssertEqual(details.target, 5, accuracy: 0.0001)
    }

    func testCumulativeCurrentStreakCountsCompletedPeriods() {
        let habit = makeCumulativeHabit(goalPeriod: .weekly, target: 5, unit: "km")
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 10), value: 5, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 17), value: 5, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 23), value: 5, calendar: Fixtures.calendar)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar), 3)
    }

    func testCumulativeCurrentStreakBreaksWhenPeriodMissesTarget() {
        let habit = makeCumulativeHabit(goalPeriod: .weekly, target: 5, unit: "km")
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 10), value: 5, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 17), value: 4, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 23), value: 5, calendar: Fixtures.calendar)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar), 1)
    }

    func testCumulativeRetroactiveLogAdjustsCurrentStreak() {
        let habit = makeCumulativeHabit(goalPeriod: .weekly, target: 5, unit: "km")
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 10), value: 5, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 17), value: 4, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 23), value: 5, calendar: Fixtures.calendar)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar), 1)

        habit.logValue(on: Fixtures.makeDate(year: 2025, month: 6, day: 18), value: 1, calendar: Fixtures.calendar)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar), 3)
    }

    func testCumulativeIntensityUsesVisibleTierForPositiveValue() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 10, unit: "km", allowsDecimals: true)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.addLog(for: habit, on: day, value: 4.5)

        let intensity = service.intensity(for: habit, on: day)

        XCTAssertGreaterThan(intensity, HeatmapLevels.none)
    }

    func testCumulativeSuggestedQuickEntryDefaultsToOneWithoutHistory() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 10, unit: "pages", allowsDecimals: false)
        context.insert(habit)

        XCTAssertEqual(service.suggestedQuickEntryValue(for: habit), 1)
    }

    func testCumulativeSuggestedQuickEntryUsesMostRecentValue() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 10, unit: "km", allowsDecimals: true)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.addLog(for: habit, on: day, value: 2.5)
        _ = service.addLog(for: habit, on: day, value: 4.25)

        XCTAssertEqual(try! XCTUnwrap(service.suggestedQuickEntryValue(for: habit)), 4.25, accuracy: 0.0001)
    }

    func testCumulativeSuggestedQuickEntryPersistsFromStoredLogs() throws {
        let container = Fixtures.makeContainer()
        let writeContext = ModelContext(container)
        let writeService = HabitLogService(modelContext: writeContext)
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 10, unit: "km", allowsDecimals: true)
        writeContext.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = writeService.addLog(for: habit, on: day, value: 2.5)
        _ = writeService.addLog(for: habit, on: day, value: 4.25)
        try writeContext.save()

        let readContext = ModelContext(container)
        let descriptor = FetchDescriptor<Habit>()
        let storedHabit = try XCTUnwrap(readContext.fetch(descriptor).first)
        let readService = HabitLogService(modelContext: readContext)

        XCTAssertEqual(try XCTUnwrap(readService.suggestedQuickEntryValue(for: storedHabit)), 4.25, accuracy: 0.0001)
    }

    func testEditingEntryUpdatesSuggestedQuickEntryValue() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 10, unit: "km", allowsDecimals: true)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.addLog(for: habit, on: day, value: 2.5)
        let entry = try! XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.updateEntry(entry, for: habit, on: day, value: 3.75)

        XCTAssertEqual(try! XCTUnwrap(service.suggestedQuickEntryValue(for: habit)), 3.75, accuracy: 0.0001)
    }

    func testClearingAllEntriesResetsSuggestedQuickEntryValueToOne() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 10, unit: "km", allowsDecimals: true)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.addLog(for: habit, on: day, value: 2.5)
        _ = service.clearEntries(for: habit, on: day)

        XCTAssertEqual(service.suggestedQuickEntryValue(for: habit), 1)
    }

    func testTargetBoundCumulativeBooksDistributionKeepsBrightTierRare() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .yearly, target: 20, unit: "books", allowsDecimals: false)
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        let seededValues: [Double] =
            Array(repeating: 0.0, count: 40) +
            Array(repeating: 1.0, count: 20) +
            Array(repeating: 2.0, count: 18) +
            Array(repeating: 3.0, count: 8) +
            Array(repeating: 5.0, count: 4)
        seedCumulativeValues(
            seededValues,
            endingAt: endDate,
            into: habit
        )

        let counts = heatmapTierCounts(for: habit, service: service, endingAt: endDate)

        XCTAssertGreaterThan(activeShare(of: 4, in: counts), 0.02)
        XCTAssertLessThan(activeShare(of: 4, in: counts), 0.12)
        XCTAssertGreaterThan(activeShare(of: 3, in: counts), 0.10)
        XCTAssertLessThan(activeShare(of: 3, in: counts), 0.25)
    }

    func testTargetBoundCumulativeMoneyDistributionStaysCalmAndPerGoal() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let moneyHabit = makeCumulativeHabit(goalPeriod: .monthly, target: 500, unit: "usd", allowsDecimals: false)
        let booksHabit = makeCumulativeHabit(goalPeriod: .yearly, target: 20, unit: "books", allowsDecimals: false)
        context.insert(moneyHabit)
        context.insert(booksHabit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        let moneySeededValues: [Double] =
            Array(repeating: 0.0, count: 38) +
            Array(repeating: 25.0, count: 16) +
            Array(repeating: 50.0, count: 18) +
            Array(repeating: 100.0, count: 12) +
            Array(repeating: 150.0, count: 4) +
            Array(repeating: 300.0, count: 2)
        seedCumulativeValues(
            moneySeededValues,
            endingAt: endDate,
            into: moneyHabit
        )
        let booksSeededValues: [Double] =
            Array(repeating: 0.0, count: 40) +
            Array(repeating: 1.0, count: 20) +
            Array(repeating: 2.0, count: 18) +
            Array(repeating: 3.0, count: 8) +
            Array(repeating: 5.0, count: 4)
        seedCumulativeValues(
            booksSeededValues,
            endingAt: endDate,
            into: booksHabit
        )

        let moneyCounts = heatmapTierCounts(for: moneyHabit, service: service, endingAt: endDate)
        let booksCounts = heatmapTierCounts(for: booksHabit, service: service, endingAt: endDate)

        XCTAssertGreaterThan(activeShare(of: 4, in: moneyCounts), 0)
        XCTAssertLessThan(activeShare(of: 4, in: moneyCounts), 0.20)
        XCTAssertGreaterThan(activeShare(of: 3, in: moneyCounts), 0.10)
        XCTAssertGreaterThan(activeShare(of: 4, in: booksCounts), 0)
        XCTAssertGreaterThan(service.intensity(for: moneyHabit, on: endDate), HeatmapLevels.none)
        XCTAssertGreaterThan(service.intensity(for: booksHabit, on: endDate), HeatmapLevels.none)
    }

    func testOpenEndedCumulativePagesDistributionUsesMiddleTiersMostOften() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedCumulativeHabit(unit: "pages")
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        let seededValues: [Double] =
            Array(repeating: 0.0, count: 35) +
            Array(repeating: 10.0, count: 22) +
            Array(repeating: 20.0, count: 15) +
            Array(repeating: 35.0, count: 10) +
            Array(repeating: 50.0, count: 6) +
            Array(repeating: 80.0, count: 2)
        seedCumulativeValues(
            seededValues,
            endingAt: endDate,
            into: habit
        )

        let counts = heatmapTierCounts(for: habit, service: service, endingAt: endDate)
        let middleShare = activeShare(of: 2, in: counts) + activeShare(of: 3, in: counts)

        XCTAssertGreaterThan(middleShare, 0.30)
        XCTAssertGreaterThan(activeShare(of: 4, in: counts), 0)
        XCTAssertLessThan(activeShare(of: 4, in: counts), 0.20)
    }

    func testOpenEndedCumulativeSpikeDoesNotFlattenRemainingGrid() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedCumulativeHabit(unit: "pages")
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        seedCumulativeValues(
            Array(repeating: 0, count: 50) +
            Array(repeating: 1, count: 16) +
            Array(repeating: 2, count: 12) +
            Array(repeating: 3, count: 8) +
            [40, 60, 120, 250],
            endingAt: endDate,
            into: habit
        )

        let counts = heatmapTierCounts(for: habit, service: service, endingAt: endDate)

        XCTAssertGreaterThan(counts[1], 0)
        XCTAssertGreaterThan(counts[2], 0)
        XCTAssertGreaterThan(activeShare(of: 4, in: counts), 0)
        XCTAssertLessThan(activeShare(of: 4, in: counts), 0.20)
    }

    func testUpdatingCumulativeEntryUpdatesDayAndPeriodTotals() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .monthly, target: 10, unit: "km", allowsDecimals: true)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.addLog(for: habit, on: day, value: 2.5)
        let entry = try! XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.updateEntry(entry, for: habit, on: day, value: 4.25)

        XCTAssertEqual(service.value(for: habit, on: day), 4.25, accuracy: 0.0001)
        XCTAssertEqual(habit.progressTotal(for: day, calendar: Fixtures.calendar), 4.25, accuracy: 0.0001)
    }

    func testUpdatingPastCumulativeEntryRecalibratesHeatmapIntensity() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedCumulativeHabit(unit: "pages")
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        seedCumulativeValues(
            Array(repeating: 1, count: 6) +
            Array(repeating: 2, count: 2) +
            [5, 8],
            endingAt: endDate,
            into: habit
        )

        let editedDay = Fixtures.makeDate(year: 2025, month: 6, day: 21)
        let entry = try! XCTUnwrap(service.entries(for: habit, on: editedDay).first)
        let before = service.intensity(for: habit, on: editedDay)

        _ = service.updateEntry(entry, for: habit, on: editedDay, value: 6)

        let after = service.intensity(for: habit, on: editedDay)
        XCTAssertGreaterThan(after, before)
    }

    func testClearingCumulativeDayUpdatesTotalsAndStreak() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCumulativeHabit(goalPeriod: .weekly, target: 5, unit: "km", allowsDecimals: true)
        context.insert(habit)

        let june17 = Fixtures.makeDate(year: 2025, month: 6, day: 17)
        let june23 = Fixtures.makeDate(year: 2025, month: 6, day: 23)
        let reference = Fixtures.makeDate(year: 2025, month: 6, day: 24)

        _ = service.addLog(for: habit, on: june17, value: 5)
        _ = service.addLog(for: habit, on: june23, value: 5)

        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar), 2)

        _ = service.clearEntries(for: habit, on: june23)

        XCTAssertEqual(service.value(for: habit, on: june23), 0, accuracy: 0.0001)
        XCTAssertEqual(habit.progressTotal(for: june23, calendar: Fixtures.calendar), 0, accuracy: 0.0001)
        XCTAssertEqual(habit.currentStreak(referenceDate: reference, calendar: Fixtures.calendar), 0)
    }

    func testDeletingOutlierCumulativeEntryRecalibratesRemainingDays() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedCumulativeHabit(unit: "minutes")
        context.insert(habit)

        let endDate = Fixtures.makeDate(year: 2025, month: 6, day: 30)
        seedCumulativeValues(
            Array(repeating: 1, count: 7) +
            Array(repeating: 2, count: 2) +
            [20],
            endingAt: endDate,
            into: habit
        )

        let mediumDay = Fixtures.makeDate(year: 2025, month: 6, day: 29)
        let outlierDay = endDate
        let before = service.intensity(for: habit, on: mediumDay)
        let outlier = try! XCTUnwrap(service.entries(for: habit, on: outlierDay).first)

        _ = service.deleteEntry(outlier, for: habit, on: outlierDay)

        let after = service.intensity(for: habit, on: mediumDay)
        XCTAssertGreaterThan(after, before)
    }

    func testEditingLegacyFrequencyLogAfterSwitchingToCumulativeConvertsItToValueEntry() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 3, calendar: Fixtures.calendar)]
        habit.goalType = .cumulative
        habit.targetValue = 5
        habit.unit = "books"
        habit.allowsDecimals = true

        let legacyEntry = try! XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.updateEntry(legacyEntry, for: habit, on: day, value: 2.5)

        let updatedEntry = try! XCTUnwrap(service.entries(for: habit, on: day).first)
        XCTAssertEqual(updatedEntry.kind, .entry)
        XCTAssertEqual(updatedEntry.numericValue, 2.5, accuracy: 0.0001)
        XCTAssertEqual(habit.progressTotal(for: day, calendar: Fixtures.calendar), 2.5, accuracy: 0.0001)
    }

    func testFrequencyInlineProgressTextRemainsUnchanged() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 2, calendar: Fixtures.calendar)]

        XCTAssertEqual(habit.inlineProgressText(for: day, calendar: Fixtures.calendar), "2 / 3")
    }

    func testFrequencyInlineProgressTextClampsWhenOverGoal() {
        let habit = makeGoalHabit(goalType: .daily, target: 1)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 2, calendar: Fixtures.calendar)]

        XCTAssertEqual(habit.inlineProgressText(for: day, calendar: Fixtures.calendar), "1 / 1")
    }

    func testCumulativeInlineProgressTextIncludesUnit() {
        let habit = makeCumulativeHabit(goalPeriod: .daily, target: 20, unit: "books")
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logValue(on: day, value: 6, calendar: Fixtures.calendar)

        XCTAssertEqual(habit.inlineProgressText(for: day, calendar: Fixtures.calendar), "6 / 20 books")
    }

    func testSwitchingFromFrequencyToCumulativeReinterpretsExistingLogsWithoutDataLoss() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 4)
        context.insert(habit)
        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        habit.logs = [HabitLog(day: day, count: 3, calendar: Fixtures.calendar)]
        let beforeIntensity = service.intensity(for: habit, on: day)

        XCTAssertEqual(try! XCTUnwrap(habit.progress(for: day, calendar: Fixtures.calendar)), 0.75, accuracy: 0.0001)

        habit.goalType = .cumulative
        habit.targetValue = 5
        habit.unit = "books"

        XCTAssertEqual(try! XCTUnwrap(habit.progress(for: day, calendar: Fixtures.calendar)), 0.6, accuracy: 0.0001)
        XCTAssertEqual(habit.inlineProgressText(for: day, calendar: Fixtures.calendar), "3 / 5 books")
        XCTAssertGreaterThan(service.intensity(for: habit, on: day), HeatmapLevels.none)
        XCTAssertEqual(beforeIntensity, HeatmapLevels.bright, accuracy: 0.0001)
    }

    // MARK: - Persistence and Query Behavior

    func testGoalPeriodFallsBackToDailyForUnknownPersistedValue() {
        let habit = makeGoalHabit(goalType: .weekly, target: 3)

        habit.streakGoalTypeRaw = "mystery"

        XCTAssertEqual(habit.goalPeriod, .daily)
    }

    func testGoalPeriodReadsWeeklyPersistedValue() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)

        habit.streakGoalTypeRaw = GoalPeriod.weekly.rawValue

        XCTAssertEqual(habit.goalPeriod, .weekly)
    }

    func testGoalTypeFallsBackToFrequencyForUnknownPersistedValue() {
        let habit = makeGoalHabit(goalType: .daily, target: 3)

        habit.goalTypeRaw = "mystery"

        XCTAssertEqual(habit.goalType, .frequency)
    }

    func testHabitsListOrderRemainsCreatedAtDescendingWhenWeeklyHabitExists() throws {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)

        let oldest = Habit(
            name: "Oldest",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: .daily,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )
        let middle = Habit(
            name: "Middle",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            streakTarget: 3,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 2)
        )
        let newest = Habit(
            name: "Newest",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            streakTarget: 5,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 3)
        )

        context.insert(oldest)
        context.insert(middle)
        context.insert(newest)

        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.createdAt, order: .reverse)])
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.map(\.name), ["Newest", "Middle", "Oldest"])
    }
}
