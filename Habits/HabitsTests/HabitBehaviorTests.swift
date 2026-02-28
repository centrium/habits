import XCTest
import SwiftData
@testable import Habits

final class HabitBehaviorTests: XCTestCase {
    private struct Fixtures {
        static let calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            return cal
        }()

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

    private func makeGoalHabit(goalType: StreakGoalType, target: Int) -> Habit {
        Habit(
            name: "Test",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            streakGoalType: goalType,
            streakTarget: target,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )
    }

    private func makeOpenEndedHabit() -> Habit {
        Habit(
            name: "Open",
            colorHex: "#FFFFFF",
            hasStreakGoal: false,
            streakGoalType: .daily,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )
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
        XCTAssertEqual(habit.logs.first?.count, 1)
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
        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.count, 2)
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
        XCTAssertEqual(habit.logs.first?.count, 2)
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
        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.count, 5)
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

    func testOpenEndedIntensityScalesBasedOnCount() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.setCount(for: habit, on: day, to: 5)

        let intensity = service.intensity(for: habit, on: day)

        XCTAssertEqual(intensity, 0.20 + (0.80 * 0.5), accuracy: 0.0001)
    }

    // MARK: - Intensity Behavior

    func testGoalBasedIntensityIsMinimumWhenCountIsZero() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)

        let intensity = service.intensity(for: habit, on: day)

        XCTAssertEqual(intensity, 0.10, accuracy: 0.0001)
    }

    func testGoalBasedIntensityIncreasesWithProgress() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 4)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.setCount(for: habit, on: day, to: 2)

        let intensity = service.intensity(for: habit, on: day)

        XCTAssertEqual(intensity, 0.20 + (0.80 * 0.5), accuracy: 0.0001)
    }

    func testGoalBasedIntensityCapsAtOneWhenOverTarget() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeGoalHabit(goalType: .daily, target: 3)
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.setCount(for: habit, on: day, to: 6)

        let intensity = service.intensity(for: habit, on: day)

        XCTAssertEqual(intensity, 1.0, accuracy: 0.0001)
    }

    func testOpenEndedIntensityCapsAtDefinedMaximum() {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeOpenEndedHabit()
        context.insert(habit)

        let day = Fixtures.makeDate(year: 2025, month: 6, day: 10)
        _ = service.setCount(for: habit, on: day, to: 25)

        let intensity = service.intensity(for: habit, on: day)

        XCTAssertEqual(intensity, 1.0, accuracy: 0.0001)
    }
}
