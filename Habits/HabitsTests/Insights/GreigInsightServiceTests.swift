import XCTest
@testable import Habits

final class GreigInsightServiceTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testCumulativeInsightReportsAheadWhenProjectionExceedsTarget() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 16, hour: 12, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 15, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 6, calendar: calendar), value: 15, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 15, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 15, calendar: calendar), value: 15, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .cumulative(target: 80),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: logs.reduce(0) { $0 + $1.numericValue },
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs,
            unit: "£",
            formatValue: { value in
                value.formatted(.number.precision(.fractionLength(0)))
            }
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .ahead)
        XCTAssertEqual(insight?.confidence, .medium)
        XCTAssertTrue(insight?.title.contains("£") ?? false)
        XCTAssertTrue(insight?.title.contains("this month") ?? false)
        XCTAssertTrue(insight?.body?.contains("£") ?? false)
    }

    func testCumulativeInsightReportsAtRiskWhenProjectedBelowTarget() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 14, hour: 12, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 3, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 10, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .cumulative(target: 250),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: logs.reduce(0) { $0 + $1.numericValue },
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs,
            unit: "£"
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .atRisk)
        XCTAssertEqual(insight?.confidence, .medium)
        XCTAssertTrue(insight?.body?.contains("£") ?? false)
        XCTAssertTrue(insight?.body?.contains("/day") ?? false)
    }

    func testCumulativeInsightUsesEarlyFallbackWhenDataPointsBelowThreshold() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 7, hour: 12, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 12, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 6, calendar: calendar), value: 10, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .cumulative(target: 80),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: logs.reduce(0) { $0 + $1.numericValue },
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs,
            unit: "£"
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.confidence, .low)
        XCTAssertEqual(insight?.status, .neutral)
        XCTAssertFalse(insight?.title.isEmpty ?? true)
        XCTAssertFalse(insight?.title.contains("£") ?? false)
        XCTAssertFalse(insight?.body?.contains("£") ?? false)
        XCTAssertFalse(containsDigit(in: insight?.title ?? ""))
        XCTAssertFalse(containsDigit(in: insight?.body ?? ""))
    }

    func testCumulativeInsightWithZeroDataUsesFallbackSafely() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 7, hour: 12, calendar: calendar)
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .cumulative(target: 80),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: 0,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: [],
            unit: "£"
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.confidence, .low)
        XCTAssertEqual(insight?.status, .neutral)
        XCTAssertFalse(insight?.title.isEmpty ?? true)
        XCTAssertFalse(insight?.title.contains("£") ?? false)
        XCTAssertFalse(insight?.body?.contains("£") ?? false)
        XCTAssertFalse(containsDigit(in: insight?.title ?? ""))
        XCTAssertFalse(containsDigit(in: insight?.body ?? ""))
    }

    func testFrequencyInsightReportsOnTrackWhenConsistencyMatchesTarget() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar) // Monday
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 12, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 7),
            period: .weekly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .onTrack)
        XCTAssertEqual(insight?.confidence, .medium)
        XCTAssertFalse(insight?.title.isEmpty ?? true)
        XCTAssertEqual(
            insight?.body,
            "3 more sessions will hit your target. One extra session could put you comfortably ahead."
        )
    }

    func testFrequencyInsightReportsAtRiskWhenShortOnPace() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar) // Monday
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 15, hour: 20, calendar: calendar) // Sunday
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 13, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 5),
            period: .weekly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .atRisk)
        XCTAssertEqual(insight?.body, "2 more check-ins would bring you back on track.")
    }

    func testFrequencyInsightUsesSmoothedPaceForSpikeData() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 10, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 12, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 20),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .atRisk)
    }

    func testFrequencyInsightUsesHighConfidenceWithSevenOrMoreDataPoints() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar) // Monday
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 15, hour: 20, calendar: calendar) // Sunday
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, hour: 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 13, hour: 8, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 5),
            period: .weekly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.confidence, .high)
    }

    func testConfidenceIsLowDuringFirstTwoDaysOfPeriod() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar) // Monday
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, hour: 7, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, hour: 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 7, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 10, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 5),
            period: .weekly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.confidence, .low)
    }

    func testLargeSpikeDayDoesNotAutoPromoteToHighConfidence() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 20, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 10, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 12, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 13, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 14, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 15, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 20),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertNotEqual(insight?.confidence, .high)
    }

    func testLongGapsReduceConfidenceToLow() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 28, hour: 18, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 1, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 16, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 8),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.confidence, .low)
    }

    func testOpenInsightUsesStreakWithoutProjection() {
        let periodStart = TestDateFactory.date(2026, 3, 10, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 7, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(kind: .open, period: .daily)
        let progress = GreigInsightProgress(
            currentTotal: 0,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .ahead)
        XCTAssertFalse(insight?.title.isEmpty ?? true)
        XCTAssertFalse(insight?.title.contains("on track to") ?? false)
    }

    func testOpenInsightWithNoDataIsAtRisk() {
        let periodStart = TestDateFactory.date(2026, 3, 10, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 11, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(kind: .open, period: .daily)
        let progress = GreigInsightProgress(
            currentTotal: 0,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: []
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .atRisk)
        XCTAssertEqual(insight?.confidence, .low)
        XCTAssertFalse(insight?.title.isEmpty ?? true)
        XCTAssertFalse(containsDigit(in: insight?.title ?? ""))
        XCTAssertFalse(containsDigit(in: insight?.body ?? ""))
    }

    func testFrequencyOverCompletionShowsCompletedVsPlannedMetric() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar) // Monday
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 14, hour: 20, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 13, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 14, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 14, hour: 9, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 3),
            period: .weekly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .ahead)
        XCTAssertTrue(insight?.body?.contains("of 3 planned sessions") ?? false)
    }

    func testFrequencyExactTargetHitAvoidsAtRiskAndShowsCompletionMetric() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar) // Monday
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 15, hour: 20, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 13, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 14, hour: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 15, hour: 8, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .frequency(target: 7),
            period: .weekly
        )
        let progress = GreigInsightProgress(
            currentTotal: Double(logs.reduce(0) { $0 + $1.frequencyContribution }),
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertNotEqual(insight?.status, .atRisk)
        XCTAssertEqual(
            insight?.body,
            "You've already hit your target. One extra session would put you comfortably ahead."
        )
    }

    func testCumulativeOnTrackShowsNudgeWhenSignalsAreStable() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 20, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 1, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 2, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 3, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 4, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 5, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 6, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 7, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 8, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 10, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 10, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .cumulative(target: 320),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: logs.reduce(0) { $0 + $1.numericValue },
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs,
            unit: "£"
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.status, .onTrack)
        XCTAssertTrue(insight?.body?.contains("could take this above your goal") ?? false)
    }

    func testCumulativeNudgeIsSuppressedWhenPatternIsNotStableEnough() {
        let periodStart = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 4, 1, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 20, hour: 20, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 1, calendar: calendar), value: 5, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 5, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 20, calendar: calendar), value: 5, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(
            kind: .cumulative(target: 24),
            period: .monthly
        )
        let progress = GreigInsightProgress(
            currentTotal: logs.reduce(0) { $0 + $1.numericValue },
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs,
            unit: "£"
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.confidence, .medium)
        XCTAssertFalse(insight?.body?.contains("could lift") ?? false)
        XCTAssertFalse(insight?.body?.contains("could take this above your goal") ?? false)
    }

    func testOpenAheadShowsBehaviourNudgeWhenConfidenceIsHigh() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 15, hour: 20, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 13, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 14, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 15, calendar: calendar), value: 1, calendar: calendar),
        ]
        let service = GreigInsightService(calendar: calendar)

        let goal = GreigInsightGoal(kind: .open, period: .weekly)
        let progress = GreigInsightProgress(
            currentTotal: 0,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )

        let insight = service.generateInsight(for: goal, progress: progress)

        XCTAssertEqual(insight?.confidence, .high)
        XCTAssertEqual(insight?.status, .ahead)
        XCTAssertEqual(insight?.body, "Showing up today could keep this momentum intact.")
    }

    private func containsDigit(in text: String) -> Bool {
        text.rangeOfCharacter(from: .decimalDigits) != nil
    }
}
