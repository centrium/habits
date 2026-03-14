import XCTest
@testable import Habits

final class InsightEngineTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testCumulativeSnapshotClampsProgressAndTracksSurplus() {
        // Given
        let day = TestDateFactory.date(2026, 3, 11, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: day, value: 60),
                .init(timestamp: day, value: 50),
            ],
            calendar: calendar
        )

        // When
        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: day,
            calendar: calendar,
            weekStartPreference: .monday,
            now: day
        )

        // Then
        XCTAssertEqual(snapshot.currentPeriod.progress, 110, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentPeriod.progressClamped, 100, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.currentPeriod.target), 100, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentPeriod.surplus, 10, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.currentPeriod.completionRatio), 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentPeriod.isCompleted, true)
    }

    func testSnapshotStreakBreaksWhenIntermediatePeriodIsMissed() {
        // Given
        let day1 = TestDateFactory.date(2026, 3, 1, calendar: calendar)
        let day2 = TestDateFactory.date(2026, 3, 2, calendar: calendar)
        let day4 = TestDateFactory.date(2026, 3, 4, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: day1, value: 1),
                .init(timestamp: day2, value: 1),
                .init(timestamp: day4, value: 1),
            ],
            calendar: calendar
        )

        // When
        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: day4,
            calendar: calendar,
            weekStartPreference: .monday,
            now: day4
        )

        // Then
        XCTAssertEqual(snapshot.streak.current, 1)
        XCTAssertEqual(snapshot.streak.longest, 2)
    }

    func testOpenEndedSnapshotProvidesActivitySummaryWithoutPace() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            period: .weekly,
            entries: [
                .init(timestamp: now, value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )

        // When
        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard case .openEnded = foundation.mode else {
            return XCTFail("Expected open-ended insight mode")
        }
        XCTAssertNil(foundation.achievement.target)
        XCTAssertNil(foundation.pace)
        XCTAssertNotNil(foundation.activitySummary)
    }

    func testTrendIncludesSixMonthsAndFillsGapsWithZeros() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let olderLog = TestDateFactory.addingMonths(-4, to: now, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .monthly,
            target: 1,
            entries: [
                .init(timestamp: olderLog, value: 1),
                .init(timestamp: now, value: 1),
            ],
            calendar: calendar
        )

        // When
        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        XCTAssertEqual(foundation.trend.months.count, 6)
        let expectedFirstMonth = calendar.dateInterval(
            of: .month,
            for: TestDateFactory.addingMonths(-5, to: now, calendar: calendar)
        )?.start
        XCTAssertEqual(foundation.trend.months.first?.monthStart, expectedFirstMonth)
        XCTAssertTrue(foundation.trend.months.contains(where: { $0.total == 0 }))
    }

    func testPaceSignalsLikelyShortWithoutProgress() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [],
            calendar: calendar
        )

        // When
        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        XCTAssertEqual(foundation.pace?.status, .likelyShort)
    }

    func testPaceSignalsLikelyToHitTargetWhenProjectionReachesGoal() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let morning1 = TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar)
        let morning2 = TestDateFactory.date(2026, 3, 11, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 4,
            entries: [
                .init(timestamp: morning1, value: 1),
                .init(timestamp: morning2, value: 1),
            ],
            calendar: calendar
        )

        // When
        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        XCTAssertEqual(foundation.pace?.status, .likelyToHitTarget)
    }

    func testPaceSignalsCompletedWhenTargetAlreadyReached() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let first = TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar)
        let second = TestDateFactory.date(2026, 3, 11, hour: 9, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                .init(timestamp: first, value: 1),
                .init(timestamp: second, value: 1),
            ],
            calendar: calendar
        )

        // When
        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        XCTAssertEqual(foundation.pace?.status, .completed)
    }

    func testGoalSnapshotWithoutLogsStartsAtZeroAndNotCompleted() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 50,
            entries: [],
            calendar: calendar
        )

        // When
        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        XCTAssertEqual(snapshot.currentPeriod.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentPeriod.progressClamped, 0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.currentPeriod.target), 50, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.currentPeriod.completionRatio), 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentPeriod.isCompleted, false)
        XCTAssertEqual(snapshot.streak.current, 0)
        XCTAssertEqual(snapshot.streak.longest, 0)
    }

    func testWeeklySnapshotRespectsWeekStartPreferenceAtBoundary() {
        // Given
        let sunday = TestDateFactory.date(2026, 3, 1, hour: 10, calendar: calendar)
        let monday = TestDateFactory.date(2026, 3, 2, hour: 10, calendar: calendar)
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
        let mondayStartSnapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: monday,
            calendar: calendar,
            weekStartPreference: .monday,
            now: monday
        )
        let sundayStartSnapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: monday,
            calendar: calendar,
            weekStartPreference: .sunday,
            now: monday
        )

        // Then
        XCTAssertEqual(mondayStartSnapshot.currentPeriod.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(sundayStartSnapshot.currentPeriod.progress, 2, accuracy: 0.0001)
    }

    func testPatternSignalsRequireAtLeastFiveLogs() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: TestDateFactory.addingDays(-3, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: now, value: 1),
            ],
            calendar: calendar
        )

        // When
        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        XCTAssertNil(foundation.patternSignals)
    }

    func testPatternSignalsAreGeneratedWhenAtLeastFiveLogsExist() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: TestDateFactory.addingDays(-4, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-3, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: now, value: 1),
            ],
            calendar: calendar
        )

        // When
        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let patternSignals = foundation.patternSignals else {
            return XCTFail("Expected pattern signals for five or more logs")
        }
        XCTAssertFalse(patternSignals.patternItems.isEmpty)
    }

    func testInsightsForEmptyOpenEndedDataShowsNoEntriesMessage() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.openEnded(entries: [], calendar: calendar)

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let intent = intentBlock(from: viewModel) else {
            return XCTFail("Expected intent card for open-ended habit")
        }
        XCTAssertEqual(intent.primaryText, "No entries this week yet")
        XCTAssertEqual(intent.projectionText, "Average 0.0 entries per week")
    }

    func testInsightsForSparseLogsReflectSingleEntryThisWeek() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: now, value: 1)],
            calendar: calendar
        )

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let intent = intentBlock(from: viewModel) else {
            return XCTFail("Expected intent card for open-ended habit")
        }
        XCTAssertEqual(intent.primaryText, "1 entry this week")
    }

    func testInsightsForConsistentActivityReportsStableTrend() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let previousMonth = TestDateFactory.addingMonths(-1, to: now, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .monthly,
            target: 1,
            entries: [
                .init(timestamp: previousMonth, value: 1),
                .init(timestamp: now, value: 1),
            ],
            calendar: calendar
        )

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let trend = trendBlock(from: viewModel) else {
            return XCTFail("Expected trend card")
        }
        XCTAssertEqual(trend.insightText, "You've stayed consistent recently")
    }

    func testInsightsForDecliningActivityReportsTrendDip() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let previousMonth = TestDateFactory.addingMonths(-1, to: now, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            period: .monthly,
            target: 1,
            entries: [
                .init(timestamp: previousMonth, value: 1),
            ],
            calendar: calendar
        )

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let trend = trendBlock(from: viewModel) else {
            return XCTFail("Expected trend card")
        }
        XCTAssertEqual(trend.insightText, "Your activity dipped slightly this month")
    }

    func testInsightsForGoalHabitWithoutLogsShowsZeroAchievement() {
        // Given
        let now = TestDateFactory.date(2026, 3, 11, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [],
            calendar: calendar
        )

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let achievement = achievementBlock(from: viewModel) else {
            return XCTFail("Expected achievement card for goal-based habit")
        }
        XCTAssertEqual(achievement.progressText, "0 / 3")
        XCTAssertEqual(achievement.progressRatio, 0, accuracy: 0.0001)
    }

    func testBehaviourInsightsShowNeutralMessageWhenLogCountIsBelowMinimumThreshold() {
        // Given
        let now = TestDateFactory.date(2026, 3, 14, hour: 12, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: (0..<19).map { offset in
                .init(
                    timestamp: TestDateFactory.addingDays(-offset, to: now, calendar: calendar),
                    value: 1
                )
            },
            calendar: calendar
        )

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let behaviour = behaviourBlock(from: viewModel) else {
            return XCTFail("Expected behaviour insights card")
        }
        XCTAssertTrue(behaviour.observations.isEmpty)
        XCTAssertEqual(behaviour.suggestion, "We’ll start showing behaviour insights once we have a little more data.")
    }

    func testBehaviourInsightsShowNeutralMessageWhenCoverageIsBelowMinimumWeeksThreshold() {
        // Given
        let now = TestDateFactory.date(2026, 3, 14, hour: 12, calendar: calendar)
        let entries = (0..<20).map { offset in
            // Keep completion dates within two Monday-based weeks.
            let boundedOffset = offset % 13
            return TestHabitFactory.Entry(
                timestamp: TestDateFactory.addingDays(-boundedOffset, to: now, calendar: calendar),
                value: 1
            )
        }
        let habit = TestHabitFactory.openEnded(
            entries: entries,
            calendar: calendar
        )

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let behaviour = behaviourBlock(from: viewModel) else {
            return XCTFail("Expected behaviour insights card")
        }
        XCTAssertTrue(behaviour.observations.isEmpty)
        XCTAssertEqual(behaviour.suggestion, "We’ll start showing behaviour insights once we have a little more data.")
    }

    func testBehaviourInsightsUseCompletionDateWhenLogsAreBackfilled() {
        // Given
        let now = TestDateFactory.date(2026, 3, 14, hour: 12, calendar: calendar)
        let firstMonday = TestDateFactory.date(2026, 2, 9, calendar: calendar)
        let habit = TestHabitFactory.openEnded(entries: [], calendar: calendar)
        var logs: [HabitLog] = []

        for weekOffset in 0..<5 {
            for dayOffset in 0..<4 {
                let completionDay = TestDateFactory.addingDays((weekOffset * 7) + dayOffset, to: firstMonday, calendar: calendar)
                logs.append(
                    TestHabitFactory.legacyLog(
                        on: completionDay,
                        count: 1,
                        createdAt: now,
                        calendar: calendar
                    )
                )
            }
        }
        habit.logs = logs

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let behaviour = behaviourBlock(from: viewModel) else {
            return XCTFail("Expected behaviour insights card")
        }
        XCTAssertFalse(behaviour.observations.isEmpty)
        XCTAssertTrue(behaviour.observations.joined(separator: " ").contains("Mondays"))
        XCTAssertNotEqual(behaviour.suggestion, "We’ll start showing behaviour insights once we have a little more data.")
    }

    func testInsightsIncludeOverviewMetricsCard() {
        // Given
        let createdAt = TestDateFactory.date(2026, 3, 1, hour: 9, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 18, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            createdAt: createdAt,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 3, 1, hour: 8, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 4, hour: 10, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 7, hour: 10, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let expected = HabitInsightsService(calendar: calendar).snapshot(for: habit, now: now)

        // When
        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            now: now
        )

        // Then
        guard let overview = overviewBlock(from: viewModel) else {
            return XCTFail("Expected overview card")
        }
        XCTAssertEqual(overview.consistency, expected.consistency)
        XCTAssertEqual(overview.bestMonth, expected.bestMonth)
        XCTAssertEqual(overview.mostMissedDay, expected.mostMissedDay)
        XCTAssertEqual(overview.averageStreak, expected.averageStreak)
    }

    private func trendBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsTrendBlock? {
        for card in viewModel.cards {
            if case .trend(let block) = card {
                return block
            }
        }
        return nil
    }

    private func intentBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsIntentBlock? {
        for card in viewModel.cards {
            if case .intent(let block) = card {
                return block
            }
        }
        return nil
    }

    private func achievementBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsAchievementBlock? {
        for card in viewModel.cards {
            if case .achievement(let block) = card {
                return block
            }
        }
        return nil
    }

    private func behaviourBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsBehaviourBlock? {
        for card in viewModel.cards {
            if case .behaviourInsights(let block) = card {
                return block
            }
        }
        return nil
    }

    private func overviewBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsOverviewBlock? {
        for card in viewModel.cards {
            if case .overview(let block) = card {
                return block
            }
        }
        return nil
    }
}
