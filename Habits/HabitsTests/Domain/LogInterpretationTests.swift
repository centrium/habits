import XCTest
@testable import Habits

final class LogInterpretationTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testLegacyLogsUseCountForNumericValueAndFrequencyContribution() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let log = TestHabitFactory.legacyLog(on: day, count: 3, calendar: calendar)

        // When
        let numericValue = log.numericValue
        let frequencyContribution = log.frequencyContribution

        // Then
        XCTAssertEqual(numericValue, 3)
        XCTAssertEqual(frequencyContribution, 3)
    }

    func testEntryLogsContributeSingleFrequencyRegardlessOfValue() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let log = TestHabitFactory.entryLog(on: day, value: 20, calendar: calendar)

        // When
        let frequencyContribution = log.frequencyContribution
        let numericValue = log.numericValue

        // Then
        XCTAssertEqual(frequencyContribution, 1)
        XCTAssertEqual(numericValue, 20)
    }

    func testEntryLogsClampNegativeValuesToZero() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let log = TestHabitFactory.entryLog(on: day, value: -10, calendar: calendar)

        // When
        let numericValue = log.numericValue
        let frequencyContribution = log.frequencyContribution

        // Then
        XCTAssertEqual(numericValue, 0)
        XCTAssertEqual(frequencyContribution, 0)
    }

    func testLogsOnDateAreSortedByTimestampThenCreationDate() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, hour: 9, calendar: calendar)
        let earlierTimestamp = TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar)
        let createdLater = TestDateFactory.date(2026, 3, 11, hour: 10, calendar: calendar)
        let createdEarlier = TestDateFactory.date(2026, 3, 11, hour: 7, calendar: calendar)

        let habit = TestHabitFactory.openEnded(calendar: calendar)
        habit.logs = [
            TestHabitFactory.entryLog(on: day, value: 1, createdAt: day, calendar: calendar),
            TestHabitFactory.entryLog(on: earlierTimestamp, value: 1, createdAt: createdLater, calendar: calendar),
            TestHabitFactory.entryLog(on: earlierTimestamp, value: 1, createdAt: createdEarlier, calendar: calendar),
        ]

        // When
        let sorted = habit.logs(on: day, calendar: calendar)

        // Then
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].createdAt, createdEarlier)
        XCTAssertEqual(sorted[1].createdAt, createdLater)
        XCTAssertEqual(sorted[2].effectiveTimestamp, day)
    }

    func testNormalizeCumulativeLogsConvertsLegacyDailyTotalsToEntries() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, hour: 15, calendar: calendar)
        let habit = TestHabitFactory.cumulative(calendar: calendar)
        habit.logs = [
            TestHabitFactory.legacyLog(on: day, count: 4, calendar: calendar),
            TestHabitFactory.entryLog(on: day, value: 3, calendar: calendar),
        ]

        // When
        let didNormalize = habit.normalizeCumulativeLogs(calendar: calendar)

        // Then
        XCTAssertTrue(didNormalize)
        XCTAssertEqual(habit.logs.count, 2)
        XCTAssertTrue(habit.logs.allSatisfy { $0.kind == .entry })
        XCTAssertEqual(habit.value(on: day, calendar: calendar), 7)
    }

    func testNormalizeCumulativeLogsLeavesFrequencyHabitsUnchanged() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(calendar: calendar)
        let legacy = TestHabitFactory.legacyLog(on: day, count: 2, calendar: calendar)
        habit.logs = [legacy]

        // When
        let didNormalize = habit.normalizeCumulativeLogs(calendar: calendar)

        // Then
        XCTAssertFalse(didNormalize)
        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.kind, .legacyDailyTotal)
    }

    func testLegacyLogsClampNegativeCountToZero() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let log = TestHabitFactory.legacyLog(on: day, count: -3, calendar: calendar)

        // When
        let numericValue = log.numericValue
        let frequencyContribution = log.frequencyContribution

        // Then
        XCTAssertEqual(numericValue, 0)
        XCTAssertEqual(frequencyContribution, 0)
    }

    func testCountAndValueOnDateAggregateMixedLegacyAndEntryLogs() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, hour: 9, calendar: calendar)
        let habit = TestHabitFactory.cumulative(calendar: calendar)
        habit.logs = [
            TestHabitFactory.legacyLog(on: day, count: 2, calendar: calendar),
            TestHabitFactory.entryLog(on: day, value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: day, value: 0, calendar: calendar),
        ]

        // When
        let count = habit.count(on: day, calendar: calendar)
        let totalValue = habit.value(on: day, calendar: calendar)

        // Then
        XCTAssertEqual(count, 3)
        XCTAssertEqual(totalValue, 12, accuracy: 0.0001)
    }

    func testNormalizeCumulativeLogsReturnsFalseWhenAlreadyEntryOnly() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            entries: [.init(timestamp: day, value: 3)],
            calendar: calendar
        )

        // When
        let didNormalize = habit.normalizeCumulativeLogs(calendar: calendar)

        // Then
        XCTAssertFalse(didNormalize)
        XCTAssertTrue(habit.logs.allSatisfy { $0.kind == .entry })
    }

    func testNormalizeCumulativeLogsPreservesDayAndCreationDate() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, hour: 6, calendar: calendar)
        let createdAt = TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar)
        let habit = TestHabitFactory.cumulative(calendar: calendar)
        habit.logs = [
            TestHabitFactory.legacyLog(on: day, count: 4, createdAt: createdAt, calendar: calendar),
        ]

        // When
        _ = habit.normalizeCumulativeLogs(calendar: calendar)
        guard let normalized = habit.logs.first else {
            return XCTFail("Expected normalized log")
        }

        // Then
        XCTAssertEqual(normalized.kind, .entry)
        XCTAssertEqual(normalized.effectiveTimestamp, calendar.startOfDay(for: day))
        XCTAssertEqual(normalized.createdAt, createdAt)
        XCTAssertEqual(normalized.numericValue, 4, accuracy: 0.0001)
    }
}
