import XCTest
@testable import Habits

@MainActor
final class InsightEngineTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar

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

    private func weeklyRhythmBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsWeeklyRhythmBlock? {
        for card in viewModel.cards {
            if case .weeklyRhythm(let block) = card {
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

    private func greigBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsGreigModeBlock? {
        for card in viewModel.cards {
            if case .greigMode(let block) = card {
                return block
            }
        }
        return nil
    }

    private func performanceSignalsBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsPerformanceSignalsBlock? {
        for card in viewModel.cards {
            if case .performanceSignals(let block) = card {
                return block
            }
        }
        return nil
    }

    private func motivationBlock(from viewModel: HabitInsightsViewModel) -> MotivationCard? {
        for card in viewModel.cards {
            if case .motivation(let block) = card {
                return block
            }
        }
        return nil
    }

    private func identityStateBlock(from viewModel: HabitInsightsViewModel) -> HabitInsightsIdentityStateBlock? {
        for card in viewModel.cards {
            if case .identityState(let block) = card {
                return block
            }
        }
        return nil
    }

    private func expectedSignalLabel(for state: HabitIdentityState) -> String {
        switch state {
        case .gettingStarted:
            return "Start"
        case .building:
            return "Build"
        case .steady:
            return "Steady"
        case .strong:
            return "Strong"
        case .slipping:
            return "Slip"
        case .rebuilding:
            return "Rebuild"
        }
    }

    private func flattenedCardText(from viewModel: HabitInsightsViewModel) -> String {
        var values: [String] = []
        for card in viewModel.cards {
            switch card {
            case .motivation(let block):
                values.append(block.headline)
                values.append(block.supportingText)
            case .identityState(let block):
                values.append(block.line)
            case .greigMode(let block):
                values.append(block.headline)
                values.append(block.supportText)
            default:
                continue
            }
        }
        return values.joined(separator: " ")
    }

    private func dates(
        matchingWeekday targetWeekday: Int,
        count: Int,
        endingAt now: Date,
        minOffset: Int,
        maxOffset: Int
    ) -> [Date] {
        var result: [Date] = []
        for offset in minOffset...maxOffset {
            let candidate = TestDateFactory.addingDays(-offset, to: now, calendar: calendar)
            if calendar.component(.weekday, from: candidate) == targetWeekday {
                result.append(candidate)
                if result.count == count {
                    return result
                }
            }
        }
        return result
    }
}
