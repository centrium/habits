import XCTest
@testable import Habits

@MainActor
final class InsightPerformanceSignalsTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar

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
            "This habit is at risk of fading. A small action today can support a return."
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
            "This habit is becoming a reliable part of your routine."
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


    func testStrongLabelNeverUsesRebuildBandValue() {
        let value = PerformanceSignalsCalculator.identitySignalValue(for: HabitState.strong)
        XCTAssertLessThan(value, 0.8)
    }

    func testIdentityCalibrationKeepsMarkerInsideSteadyBandAndPullsOffDivider() throws {
        let result = try XCTUnwrap(
            SignalMarkerCalibration.calibrate(
                rawPosition: 0.595,
                labels: ["Start", "Build", "Steady", "Strong", "Slip", "Rebuild"],
                activeBandLabel: "Steady",
                safeInset: 0.03,
                profile: .identity
            )
        )

        XCTAssertEqual(result.activeBand.label, "Steady")
        XCTAssertLessThan(result.adjustedPosition, 0.60)
        XCTAssertLessThanOrEqual(result.visibleMax, result.activeBand.upper)
        XCTAssertGreaterThanOrEqual(result.visibleMin, result.activeBand.lower)
    }

    func testCalibrationBiasStrengthIncreasesNearDivider() throws {
        let labels = ["Low", "Moderate", "High", "Critical"]
        let center = try XCTUnwrap(
            SignalMarkerCalibration.calibrate(
                rawPosition: 0.375,
                labels: labels,
                activeBandLabel: nil,
                safeInset: 0.025,
                profile: .risk
            )
        )
        let edge = try XCTUnwrap(
            SignalMarkerCalibration.calibrate(
                rawPosition: 0.26,
                labels: labels,
                activeBandLabel: nil,
                safeInset: 0.025,
                profile: .risk
            )
        )

        XCTAssertGreaterThan(edge.biasStrength, center.biasStrength)
        XCTAssertGreaterThan(edge.adjustedPosition - edge.rawPosition, 0)
        XCTAssertLessThan(center.adjustedPosition - center.rawPosition, edge.adjustedPosition - edge.rawPosition)
    }

    func testStrengthCalibrationPreservesOrderingWithinBand() throws {
        let labels = ["Weak", "Developing", "Strong", "Automatic"]
        let lower = try XCTUnwrap(
            SignalMarkerCalibration.calibrate(
                rawPosition: 0.52,
                labels: labels,
                activeBandLabel: nil,
                safeInset: 0.025,
                profile: .strength
            )
        )
        let upper = try XCTUnwrap(
            SignalMarkerCalibration.calibrate(
                rawPosition: 0.70,
                labels: labels,
                activeBandLabel: nil,
                safeInset: 0.025,
                profile: .strength
            )
        )

        XCTAssertEqual(lower.activeBand.label, "Strong")
        XCTAssertEqual(upper.activeBand.label, "Strong")
        XCTAssertLessThan(lower.adjustedPosition, upper.adjustedPosition)
        XCTAssertLessThanOrEqual(lower.visibleMax, lower.activeBand.upper)
        XCTAssertLessThanOrEqual(upper.visibleMax, upper.activeBand.upper)
    }

    func testTerminalBandsBiasInwardFromOuterEdge() throws {
        let labels = ["Weak", "Developing", "Strong", "Automatic"]
        let weak = try XCTUnwrap(
            SignalMarkerCalibration.calibrate(
                rawPosition: 0.02,
                labels: labels,
                activeBandLabel: nil,
                safeInset: 0.025,
                profile: .strength
            )
        )
        let automatic = try XCTUnwrap(
            SignalMarkerCalibration.calibrate(
                rawPosition: 0.98,
                labels: labels,
                activeBandLabel: nil,
                safeInset: 0.025,
                profile: .strength
            )
        )

        XCTAssertGreaterThan(weak.adjustedPosition, weak.rawPosition)
        XCTAssertLessThan(automatic.adjustedPosition, automatic.rawPosition)
        XCTAssertGreaterThanOrEqual(weak.visibleMin, weak.activeBand.lower)
        XCTAssertLessThanOrEqual(automatic.visibleMax, automatic.activeBand.upper)
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

    private func expectedScaleLabel(for state: HabitIdentityState) -> String {
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

    private func expectedBehaviourDescription(for state: HabitIdentityState) -> String {
        switch state {
        case .gettingStarted:
            return "You are beginning to establish this habit."
        case .building:
            return "This habit is taking shape."
        case .steady:
            return "You have built a reliable pattern."
        case .strong:
            return "You are showing up consistently."
        case .slipping:
            return "Recent consistency has softened."
        case .rebuilding:
            return "Recent follow-through has been interrupted."
        }
    }
}
