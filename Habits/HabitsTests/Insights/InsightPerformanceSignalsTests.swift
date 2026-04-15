import XCTest
@testable import Habits

@MainActor
final class InsightPerformanceSignalsTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testIdentityStateIsStrongForLongTermStablePattern() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -45,
            offsets: Array(0...34).map { -$0 }
        )

        let state = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(state, .strong)
        XCTAssertEqual(CadenceLanguage.insightLine(for: state), "This habit has a strong rhythm")
    }

    func testIdentityStateIsRebuildingWhenPatternIsBroken() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -90,
            offsets: [-2, -20, -36, -50, -64, -79]
        )

        let state = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(state, .rebuilding)
        XCTAssertEqual(CadenceLanguage.insightLine(for: state), "This habit is getting back on track")
    }

    func testIdentityStateIsSteadyForModerateLongTermConsistency() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -45,
            offsets: Array(stride(from: 0, through: 28, by: 2)).map { -$0 }
        )

        let state = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(state, .steady)
        XCTAssertEqual(CadenceLanguage.insightLine(for: state), "This habit is staying consistent")
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
            "This habit is at risk of fading. A small action today can support a return."
        )
    }

    func testHabitRiskEarlyStageUsesInsufficientDataCopyAndHidesScore() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -2,
            offsets: [0, -1]
        )

        let signals = PerformanceSignalsCalculator.calculate(
            for: habit,
            calendar: calendar,
            now: now
        )
        guard let riskSignal = signals.first(where: { $0.gauge.title == "Habit Risk" }) else {
            return XCTFail("Expected Habit Risk signal")
        }

        XCTAssertEqual(riskSignal.gauge.explanation, CadenceLanguage.riskEarlyStage())
        XCTAssertEqual(riskSignal.displayValue, "")
    }

    func testHabitRiskHighWithoutDetectedDeclineUsesNonDeclineCopy() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -30,
            offsets: [-2, -4, -6]
        )

        let signals = PerformanceSignalsCalculator.calculate(
            for: habit,
            calendar: calendar,
            now: now
        )
        guard let riskSignal = signals.first(where: { $0.gauge.title == "Habit Risk" }) else {
            return XCTFail("Expected Habit Risk signal")
        }

        XCTAssertEqual(
            riskSignal.gauge.explanation,
            "Recent consistency is uneven. Logging today would help stabilise the routine."
        )
    }

    func testHabitRiskHighWithDetectedDeclineUsesDeclineCopy() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let recent = [-2]
        let previous = [-8, -9, -10, -11, -12, -13, -14]
        let habit = makeHabit(
            now: now,
            createdAtOffset: -45,
            offsets: recent + previous
        )

        let signals = PerformanceSignalsCalculator.calculate(
            for: habit,
            calendar: calendar,
            now: now
        )
        guard let riskSignal = signals.first(where: { $0.gauge.title == "Habit Risk" }) else {
            return XCTFail("Expected Habit Risk signal")
        }

        XCTAssertEqual(
            riskSignal.gauge.explanation,
            "Consistency has dropped recently. Logging today would help stabilise the routine."
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

        XCTAssertEqual(block?.heading, "Signals")
        XCTAssertEqual(block?.signals.map(\.gauge.title), ["Identity Signal", "Habit Risk", "Habit Strength"])
        XCTAssertEqual(block?.signals.first?.gauge.labels, ["Start", "Build", "Steady", "Strong", "Slip", "Rebuild"])
    }

    func testIdentityStateForNewHabitWithFirstLogTodayIsGettingStarted() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: 0,
            offsets: [0]
        )

        let state = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(state, .gettingStarted)
    }

    func testIdentityStateForOneOfLastSevenDaysStaysBelowStrongWithoutDegradationBand() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -45,
            offsets: [0, -9, -11, -13, -15, -17, -19]
        )

        let state = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(state, .building)
    }

    func testIdentityStateForRecentDeclineUsesSlipOnlyWhenGated() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -45,
            offsets: [-1] + Array(8...44).map { -$0 }
        )

        let state = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(state, .slipping)
    }

    func testIdentityStateForStrongConsistencyIsStrong() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -45,
            offsets: Array(0...32).map { -$0 }
        )

        let state = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(state, .strong)
    }

    func testIdentitySignalUsesAlignedBandForValueLabelAndExplanation() {
        let now = TestDateFactory.date(2026, 3, 28, hour: 12, calendar: calendar)
        let habit = makeHabit(
            now: now,
            createdAtOffset: -60,
            offsets: Array(0...42).map { -$0 }
        )

        let signals = PerformanceSignalsCalculator.calculate(
            for: habit,
            calendar: calendar,
            now: now
        )
        guard let identity = signals.first(where: { $0.gauge.title == "Identity Signal" }) else {
            return XCTFail("Expected identity signal")
        }

        let derivedState = PerformanceSignalsCalculator.identityState(
            for: habit,
            calendar: calendar,
            now: now
        )
        XCTAssertEqual(identity.displayValue, expectedScaleLabel(for: derivedState))
        XCTAssertEqual(identity.gauge.explanation, expectedBehaviourDescription(for: derivedState))
        XCTAssertEqual(identity.gauge.value, 0.7, accuracy: 0.1)
    }

    func testStrongLabelNeverUsesRebuildBandValue() {
        let value = PerformanceSignalsCalculator.identitySignalValue(for: .strong)
        XCTAssertLessThan(value, 0.8)
    }

    func testIdentityCalibrationKeepsMarkerInsideSteadyBandAndPullsOffDivider() {
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

    func testCalibrationBiasStrengthIncreasesNearDivider() {
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

    func testStrengthCalibrationPreservesOrderingWithinBand() {
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

    func testTerminalBandsBiasInwardFromOuterEdge() {
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
