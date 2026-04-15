import XCTest
@testable import Habits

final class ProgressCalculationTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testCumulativeGoalClampsProgressAtTarget() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: day, value: 20),
                .init(timestamp: day, value: 30),
                .init(timestamp: day, value: 80),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.progress(
            for: day,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 1, accuracy: 0.0001)
    }

    func testFrequencyProgressUsesEntryCountNotLoggedValueMagnitude() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [
                .init(timestamp: day, value: 1),
                .init(timestamp: day, value: 5),
                .init(timestamp: day, value: 20),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 1, accuracy: 0.0001)
    }

    func testProgressReturnsNilWhenHabitHasNoGoal() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: day, value: 1)],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertNil(progress)
    }

    func testWeeklyProgressRespectsWeekStartPreferenceAtBoundary() {
        // Given
        let sunday = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let monday = TestDateFactory.date(2026, 3, 2, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .weekly,
            target: 2,
            entries: [
                .init(timestamp: sunday, value: 1),
                .init(timestamp: monday, value: 1),
            ],
            calendar: calendar
        )

        // When
        let mondayStartTotal = habit.progressTotal(
            for: monday,
            calendar: calendar,
            weekStartPreference: .monday
        )
        let sundayStartTotal = habit.progressTotal(
            for: monday,
            calendar: calendar,
            weekStartPreference: .sunday
        )

        // Then
        XCTAssertEqual(mondayStartTotal, 1)
        XCTAssertEqual(sundayStartTotal, 2)
    }

    func testLargeCumulativeValuesClampToOne() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 10,
            entries: [.init(timestamp: day, value: 1_000_000)],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 1, accuracy: 0.0001)
    }

    func testFrequencyProgressIsZeroWhenNoLogsExist() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 0, accuracy: 0.0001)
    }

    func testCumulativeProgressIgnoresLogsOutsideActivePeriod() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let previousDay = TestDateFactory.addingDays(-1, to: day, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: previousDay, value: 90),
                .init(timestamp: day, value: 30),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 0.3, accuracy: 0.0001)
    }

    func testFrequencyProgressReturnsPartialFractionBeforeCompletion() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 4,
            entries: [
                .init(timestamp: day, value: 1),
                .init(timestamp: day, value: 1),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 0.5, accuracy: 0.0001)
    }

    func testNegativeLegacyCountsDoNotProduceNegativeProgress() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(target: 1, calendar: calendar)
        habit.logs = [
            TestHabitFactory.legacyLog(on: day, count: -5, calendar: calendar),
        ]

        // When
        let total = habit.progressTotal(for: day, calendar: calendar)
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(total, 0)
        XCTAssertEqual(try XCTUnwrap(progress), 0, accuracy: 0.0001)
    }

    func testCumulativeProgressIsZeroWhenNoLogsExist() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 50,
            entries: [],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 0, accuracy: 0.0001)
    }

    func testFrequencyProgressClampsAtOneWhenEntriesExceedTarget() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                .init(timestamp: day, value: 1),
                .init(timestamp: day, value: 1),
                .init(timestamp: day, value: 1),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 1, accuracy: 0.0001)
    }

    func testFrequencyProgressIgnoresLogsOutsideActivePeriod() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let previousDay = TestDateFactory.addingDays(-1, to: day, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [
                .init(timestamp: previousDay, value: 1),
                .init(timestamp: day, value: 1),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.progress(for: day, calendar: calendar)

        // Then
        XCTAssertEqual(try XCTUnwrap(progress), 1.0 / 3.0, accuracy: 0.0001)
    }

    func testFrequencyPeriodProgressIsAtRiskWhenBehindMidPeriod() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .weekly,
            target: 5,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected frequency period progress")
        }
        switch progress.state {
        case .atRisk:
            break
        case .onTrack, .offTrack:
            XCTFail("Expected at risk state")
        }
    }

    func testFrequencyPeriodProgressIsOnTrackNearEndOfPeriod() {
        // Given
        let now = TestDateFactory.date(2026, 3, 15, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .weekly,
            target: 5,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 11, hour: 9, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 12, hour: 9, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 13, hour: 9, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected frequency period progress")
        }
        switch progress.state {
        case .onTrack:
            break
        case .atRisk, .offTrack:
            XCTFail("Expected on track state")
        }
    }

    func testCumulativePeriodProgressIsAtRiskMidPeriod() {
        // Given
        let now = TestDateFactory.date(2026, 3, 12, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            period: .weekly,
            target: 100,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 30),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected cumulative period progress")
        }
        switch progress.state {
        case .atRisk:
            break
        case .onTrack, .offTrack:
            XCTFail("Expected at risk state")
        }
    }

    func testCumulativePeriodProgressIsOnTrackMidPeriod() {
        // Given
        let now = TestDateFactory.date(2026, 3, 12, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            period: .weekly,
            target: 100,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 80),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected cumulative period progress")
        }
        switch progress.state {
        case .onTrack:
            break
        case .atRisk, .offTrack:
            XCTFail("Expected on track state")
        }
    }

    func testCumulativePeriodProgressIsOffTrackLateInPeriod() {
        // Given
        let now = TestDateFactory.date(2026, 3, 15, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            period: .weekly,
            target: 100,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 10),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected cumulative period progress")
        }
        switch progress.state {
        case .offTrack:
            break
        case .onTrack, .atRisk:
            XCTFail("Expected off track state")
        }
    }

    func testPeriodProgressIsOnTrackWhenCompletedMeetsRequired() {
        // Given
        let now = TestDateFactory.date(2026, 3, 12, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            period: .weekly,
            target: 100,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 120),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected cumulative period progress")
        }
        switch progress.state {
        case .onTrack:
            break
        case .atRisk, .offTrack:
            XCTFail("Expected on track state")
        }
    }

    func testPeriodProgressWithZeroCompletedEarlyIsNotOffTrack() {
        // Given
        let now = TestDateFactory.date(2026, 3, 9, hour: 0, minute: 10, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            period: .weekly,
            target: 100,
            entries: [],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected cumulative period progress")
        }
        switch progress.state {
        case .onTrack, .atRisk:
            break
        case .offTrack:
            XCTFail("Expected on track or at risk early in period")
        }
    }

    func testPeriodProgressWithZeroCompletedLateIsOffTrack() {
        // Given
        let now = TestDateFactory.date(2026, 3, 15, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            period: .weekly,
            target: 100,
            entries: [],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        guard let progress else {
            return XCTFail("Expected cumulative period progress")
        }
        switch progress.state {
        case .offTrack:
            break
        case .onTrack, .atRisk:
            XCTFail("Expected off track late in period")
        }
    }

    func testPeriodProgressReturnsNilForOpenGoals() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            period: .weekly,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertNil(progress)
    }

    func testPeriodProgressReturnsNilWhenCumulativeRequiredIsZero() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            period: .weekly,
            target: 0,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 25),
            ],
            calendar: calendar
        )

        // When
        let progress = habit.periodProgress(
            now: now,
            calendar: calendar,
            weekStartPreference: .monday
        )

        // Then
        XCTAssertNil(progress)
    }

}
