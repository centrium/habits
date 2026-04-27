import XCTest
@testable import Habits

final class HabitGoalTests: BaseTestCase {
    func testFrequencyGoalEnforcesMinimumTargetOfOne() {
        // Given
        let habit = TestHabitFactory.frequency(target: 0)

        // When
        let target = habit.effectiveTargetValue

        // Then
        XCTAssertEqual(target, 1)
        XCTAssertTrue(habit.hasGoal)
    }

    func testCumulativeGoalRequiresPositiveTarget() {
        // Given
        let habit = TestHabitFactory.cumulative(target: 0)

        // When
        let hasGoal = habit.hasGoal
        let target = habit.effectiveTargetValue

        // Then
        XCTAssertFalse(hasGoal)
        XCTAssertNil(target)
    }

    func testOpenEndedHabitHasNoGoal() {
        // Given
        let habit = TestHabitFactory.openEnded()

        // When
        let hasGoal = habit.hasGoal
        let target = habit.effectiveTargetValue

        // Then
        XCTAssertFalse(hasGoal)
        XCTAssertNil(target)
    }

    func testGoalModeSwitchingUpdatesGoalAvailability() {
        // Given
        let habit = TestHabitFactory.frequency(target: 2)

        // When
        habit.goalType = .cumulative
        habit.targetValue = nil

        // Then
        XCTAssertFalse(habit.hasGoal)
        XCTAssertNil(habit.effectiveTargetValue)

        // When
        habit.targetValue = 75

        // Then
        XCTAssertTrue(habit.hasGoal)
        XCTAssertEqual(habit.effectiveTargetValue, 75)

        // When
        habit.goalType = .frequency
        habit.streakTarget = 0

        // Then
        XCTAssertEqual(habit.effectiveTargetValue, 1)
    }

    func testTrimmedUnitRemovesWhitespaceOnlyContent() {
        // Given
        let habit = TestHabitFactory.cumulative(unit: "   ")

        // When
        let trimmedUnit = habit.trimmedUnit

        // Then
        XCTAssertNil(trimmedUnit)
    }

    func testDisablingStreakGoalRemovesGoalEvenWithTargetsConfigured() {
        // Given
        let habit = TestHabitFactory.cumulative(target: 75)

        // When
        habit.hasStreakGoal = false

        // Then
        XCTAssertFalse(habit.hasGoal)
        XCTAssertNil(habit.effectiveTargetValue)
    }

    func testTrimmedUnitRetainsMeaningfulContent() {
        // Given
        let habit = TestHabitFactory.cumulative(unit: "  km  ")

        // When
        let trimmedUnit = habit.trimmedUnit

        // Then
        XCTAssertEqual(trimmedUnit, "km")
    }

    func testFrequencyModeUsesStreakTargetInsteadOfCumulativeTargetValue() {
        // Given
        let habit = TestHabitFactory.cumulative(target: 120)

        // When
        habit.goalType = .frequency
        habit.streakTarget = 3

        // Then
        XCTAssertEqual(habit.effectiveTargetValue, 3)
    }

    func testSwitchingFrequencyToCumulativeUsesExistingLogValuesForProgress() {
        // Given
        let calendar = TestDateFactory.utcCalendar
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                .init(timestamp: day, value: 10),
                .init(timestamp: day, value: 20),
            ],
            calendar: calendar
        )

        // When
        habit.goalType = .cumulative
        habit.targetValue = 50
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 0.6, accuracy: 0.0001)
    }

    func testSwitchingCumulativeToFrequencyCountsEntriesNotValueMagnitude() {
        // Given
        let calendar = TestDateFactory.utcCalendar
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: day, value: 60),
                .init(timestamp: day, value: 40),
            ],
            calendar: calendar
        )

        // When
        habit.goalType = .frequency
        habit.streakTarget = 3
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 2.0 / 3.0, accuracy: 0.0001)
    }

    func testSwitchingGoalModesDoesNotMutateExistingLogs() {
        // Given
        let calendar = TestDateFactory.utcCalendar
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [.init(timestamp: day, value: 7)],
            calendar: calendar
        )
        let originalLogID = habit.logs.first?.id
        let originalValue = habit.logs.first?.numericValue

        // When
        habit.goalType = .cumulative
        habit.targetValue = 10
        habit.goalType = .frequency

        // Then
        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.id, originalLogID)
        XCTAssertEqual(habit.logs.first?.numericValue, originalValue)
    }

    func testSwitchingToCumulativeWithoutTargetDisablesProgressEvenWithLogs() {
        // Given
        let calendar = TestDateFactory.utcCalendar
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [.init(timestamp: day, value: 1)],
            calendar: calendar
        )

        // When
        habit.goalType = .cumulative
        habit.targetValue = nil
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertFalse(habit.hasGoal)
        XCTAssertNil(progress)
    }
}
