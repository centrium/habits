import XCTest
@testable import Habits

final class InsightPerformanceSignalsTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testMomentumScoreImprovesWhenRecentActivityOutpacesHistory() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            offsets: [0, -1, -2, -4, -6, -8, -11, -14]
        )

        let score = PerformanceSignalsCalculator.momentumScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertGreaterThan(score, 0.15)
        XCTAssertEqual(
            PerformanceSignalsCalculator.momentumExplanation(for: score),
            "Your recent activity is improving and momentum is building."
        )
    }

    func testMomentumScoreDeclinesWhenRecentActivityDropsBelowHistory() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            offsets: [0, -8, -9, -10, -11, -12, -13, -14, -15, -16, -17, -18, -19, -20, -21, -22]
        )

        let score = PerformanceSignalsCalculator.momentumScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertLessThan(score, -0.15)
        XCTAssertEqual(
            PerformanceSignalsCalculator.momentumExplanation(for: score),
            "Your recent activity has dropped compared to your usual pattern."
        )
    }

    func testMomentumScoreIsStableWhenRecentActivityMatchesHistory() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            offsets: [0, -3, -8, -11, -14, -17, -20, -23]
        )

        let score = PerformanceSignalsCalculator.momentumScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(score, 0, accuracy: 0.0001)
        XCTAssertEqual(
            PerformanceSignalsCalculator.momentumExplanation(for: score),
            "Your habit activity is stable compared with recent weeks."
        )
    }

    func testHabitRiskIsLowWithRecentLogsAndHighCompletion() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            offsets: [0, -1, -2, -3, -4, -5]
        )

        let score = PerformanceSignalsCalculator.habitRiskScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertLessThan(score, 0.25)
        XCTAssertEqual(
            PerformanceSignalsCalculator.riskExplanation(for: score),
            "This habit is currently stable with very low drop-off risk."
        )
    }

    func testHabitRiskIsCriticalWhenThereAreNoRecentLogs() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            offsets: [-10, -12, -16, -19, -23]
        )

        let score = PerformanceSignalsCalculator.habitRiskScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertGreaterThan(score, 0.75)
        XCTAssertEqual(
            PerformanceSignalsCalculator.riskExplanation(for: score),
            "This habit is at risk of fading. A small action today can rebuild momentum."
        )
    }

    func testHabitStrengthIsWeakForNewHabitWithFewLogs() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -5,
            offsets: [0, -2]
        )

        let score = PerformanceSignalsCalculator.habitStrengthScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThan(score, 0.25)
        XCTAssertEqual(
            PerformanceSignalsCalculator.strengthExplanation(for: score),
            "This habit is still forming. Repeating the behaviour regularly will help establish the routine."
        )
    }

    func testHabitStrengthIsDevelopingWithModerateConsistency() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -20,
            offsets: [0, -2, -4, -6, -8, -10, -12, -14, -16, -18]
        )

        let score = PerformanceSignalsCalculator.habitStrengthScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertGreaterThanOrEqual(score, 0.25)
        XCTAssertLessThan(score, 0.5)
        XCTAssertEqual(
            PerformanceSignalsCalculator.strengthExplanation(for: score),
            "Your habit is developing and gaining consistency. Continued repetition will strengthen it."
        )
    }

    func testHabitStrengthIsStrongWithLongerStreakAndHighConsistency() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -30,
            offsets: Array(0...9).map { -$0 } + Array(12...19).map { -$0 }
        )

        let score = PerformanceSignalsCalculator.habitStrengthScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertGreaterThanOrEqual(score, 0.5)
        XCTAssertLessThan(score, 0.75)
        XCTAssertEqual(
            PerformanceSignalsCalculator.strengthExplanation(for: score),
            "This habit is becoming a stable part of your routine."
        )
    }

    func testHabitStrengthIsAutomaticForHighlyConsistentLongTermHabit() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -90,
            offsets: Array(0...75).map { -$0 }
        )

        let score = PerformanceSignalsCalculator.habitStrengthScore(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertGreaterThanOrEqual(score, 0.75)
        XCTAssertLessThanOrEqual(score, 1)
        XCTAssertEqual(
            PerformanceSignalsCalculator.strengthExplanation(for: score),
            "This habit is highly consistent and approaching automatic behaviour."
        )
    }

    func testInsightsViewModelIncludesPerformanceSignalsCard() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            offsets: [0, -1, -2, -4, -6, -8, -11, -14]
        )

        let viewModel = HabitInsightsEngine.insights(
            for: habit,
            calendar: calendar,
            weekStartPreference: .monday,
            greigModeEnabled: true,
            timezone: calendar.timeZone,
            now: now
        )

        let block = viewModel.cards.compactMap { card -> HabitInsightsPerformanceSignalsBlock? in
            guard case .performanceSignals(let block) = card else { return nil }
            return block
        }.first

        XCTAssertEqual(block?.heading, "Performance Signals")
        XCTAssertEqual(block?.signals.map(\.gauge.title), ["Momentum Score", "Habit Risk", "Habit Strength"])
    }

    private func makeHabit(
        now: Date,
        createdAtOffset: Int = -60,
        offsets: [Int]
    ) -> Habit {
        TestHabitFactory.frequency(
            createdAt: TestDateFactory.addingDays(createdAtOffset, to: now, calendar: calendar),
            entries: offsets.map { offset in
                TestHabitFactory.entry(
                    on: TestDateFactory.addingDays(offset, to: now, calendar: calendar)
                )
            },
            calendar: calendar
        )
    }
}
