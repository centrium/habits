import XCTest
@testable import Habits

final class GreigCopyProviderTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testScenarioSelectionUsesGoalTypeStatusAndConfidence() {
        let provider = GreigCopyProvider(calendar: calendar)

        XCTAssertEqual(
            provider.scenarioName(for: .cumulative, status: .ahead, confidence: .high),
            "aheadHigh"
        )
        XCTAssertEqual(
            provider.scenarioName(for: .cumulative, status: .ahead, confidence: .low),
            "aheadLow"
        )
        XCTAssertEqual(
            provider.scenarioName(for: .frequency, status: .onTrack, confidence: .medium),
            "onTrack"
        )
        XCTAssertEqual(
            provider.scenarioName(for: .frequency, status: .onTrack, confidence: .low),
            "onTrackLow"
        )
        XCTAssertEqual(
            provider.scenarioName(for: .frequency, status: .atRisk, confidence: .high),
            "atRisk"
        )
        XCTAssertEqual(
            provider.scenarioName(for: .frequency, status: .atRisk, confidence: .low),
            "atRiskLow"
        )
        XCTAssertEqual(
            provider.scenarioName(for: .open, status: .atRisk, confidence: .low),
            "atRiskLow"
        )
    }

    func testCopyIsStableWithinSameDay() {
        let provider = GreigCopyProvider(calendar: calendar)
        let day = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)

        let first = provider.copy(
            for: .frequency,
            status: .onTrack,
            confidence: .high,
            date: day
        )
        let second = provider.copy(
            for: .frequency,
            status: .onTrack,
            confidence: .high,
            date: TestDateFactory.date(2026, 3, 18, hour: 20, calendar: calendar)
        )

        XCTAssertEqual(first.title, second.title)
        XCTAssertEqual(first.body, second.body)
    }

    func testTitleChangesAcrossConsecutiveDays() {
        let provider = GreigCopyProvider(calendar: calendar)
        let dayOne = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let dayTwo = TestDateFactory.addingDays(1, to: dayOne, calendar: calendar)

        let first = provider.copy(
            for: .cumulative,
            status: .ahead,
            confidence: .high,
            date: dayOne
        )
        let second = provider.copy(
            for: .cumulative,
            status: .ahead,
            confidence: .high,
            date: dayTwo
        )

        XCTAssertNotEqual(first.title, second.title)
    }

    func testTitleDoesNotRepeatWithinThreeDayWindow() {
        let provider = GreigCopyProvider(calendar: calendar)
        let start = TestDateFactory.date(2026, 3, 1, hour: 8, calendar: calendar)
        var titles: [String] = []

        for offset in 0..<14 {
            let date = TestDateFactory.addingDays(offset, to: start, calendar: calendar)
            let copy = provider.copy(
                for: .frequency,
                status: .atRisk,
                confidence: .high,
                date: date
            )
            titles.append(copy.title)
        }

        for index in 0..<titles.count {
            let windowStart = max(0, index - 3)
            if windowStart == index { continue }
            for previous in windowStart..<index {
                XCTAssertNotEqual(
                    titles[index],
                    titles[previous],
                    "Title repeated within 3-day window at indices \(previous) and \(index)"
                )
            }
        }
    }

    func testCumulativeMediumConfidenceUsesProjectionAndDeltaMetrics() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            projectedValue: 312.4,
            deltaFromTarget: 62.1,
            unit: "£",
            targetValue: 250,
            periodLabel: "this month"
        )

        let copy = provider.copy(
            for: .cumulative,
            status: .ahead,
            confidence: .medium,
            date: date,
            context: context
        )

        XCTAssertTrue(copy.title.contains("£312"))
        XCTAssertTrue(copy.title.contains("this month"))
        XCTAssertTrue(copy.body?.contains("£62") ?? false)
    }

    func testCumulativeAtRiskUsesRoundedRequiredRateMetric() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            requiredRate: 12.48,
            unit: "£"
        )

        let copy = provider.copy(
            for: .cumulative,
            status: .atRisk,
            confidence: .high,
            date: date,
            context: context
        )

        XCTAssertEqual(copy.body, "Adding ~£12/day would bring you back on track.")
    }

    func testFrequencyOnTrackUsesRemainingActionMetric() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            targetValue: 5,
            currentValue: 3,
            remainingActions: 2
        )

        let copy = provider.copy(
            for: .frequency,
            status: .onTrack,
            confidence: .high,
            date: date,
            context: context
        )

        XCTAssertEqual(copy.body, "2 more sessions will hit your target.")
    }

    func testOpenAheadUsesStreakMetric() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(streakLength: 5)

        let copy = provider.copy(
            for: .open,
            status: .ahead,
            confidence: .high,
            date: date,
            context: context
        )

        XCTAssertEqual(copy.title, "You've built a 5-day streak")
    }

    func testOpenRecoveringUsesRecentCompletionMetric() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            recentCompletedDays: 3,
            recentWindowDays: 5
        )

        let copy = provider.copy(
            for: .open,
            status: .neutral,
            confidence: .medium,
            date: date,
            context: context
        )

        XCTAssertEqual(copy.title, "You've completed 3 of the last 5 days")
        XCTAssertEqual(copy.body, "Your rhythm is rebuilding.")
    }

    func testLowConfidenceDoesNotInjectNumericProjectionMetrics() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            projectedValue: 312,
            deltaFromTarget: 62,
            requiredRate: 12,
            unit: "£",
            periodLabel: "this month"
        )

        let copy = provider.copy(
            for: .cumulative,
            status: .neutral,
            confidence: .low,
            date: date,
            context: context
        )

        XCTAssertFalse(copy.title.contains("£"))
        XCTAssertFalse(copy.body?.contains("£") ?? false)
    }

    func testCumulativeAheadAddsNudgeWhenSuggestedIncrementIsPresent() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            projectedValue: 614,
            nudgedProjection: 650,
            deltaFromTarget: 364,
            suggestedIncrement: 10,
            unit: "£",
            periodLabel: "this week"
        )

        let copy = provider.copy(
            for: .cumulative,
            status: .ahead,
            confidence: .high,
            date: date,
            context: context
        )

        XCTAssertTrue(copy.body?.contains("~£10/day") ?? false)
        XCTAssertTrue(copy.body?.contains("£650") ?? false)
    }

    func testFrequencyOnTrackAddsNudgeWhenSuggestedIncrementIsPresent() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            suggestedIncrement: 1,
            targetValue: 5,
            currentValue: 3,
            remainingActions: 2
        )

        let copy = provider.copy(
            for: .frequency,
            status: .onTrack,
            confidence: .high,
            date: date,
            context: context
        )

        XCTAssertEqual(
            copy.body,
            "2 more sessions will hit your target. One extra session could put you comfortably ahead."
        )
    }

    func testOpenAheadAddsBehaviourNudgeWhenSuggestedIncrementIsPresent() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            suggestedIncrement: 1,
            streakLength: 4
        )

        let copy = provider.copy(
            for: .open,
            status: .ahead,
            confidence: .high,
            date: date,
            context: context
        )

        XCTAssertEqual(copy.title, "You've built a 4-day streak")
        XCTAssertEqual(copy.body, "Showing up today could keep this momentum intact.")
    }

    func testLowConfidenceSuppressesNudgeCopyEvenWhenSuggestedIncrementProvided() {
        let provider = GreigCopyProvider(calendar: calendar)
        let date = TestDateFactory.date(2026, 3, 18, hour: 9, calendar: calendar)
        let context = GreigContext(
            nudgedProjection: 650,
            suggestedIncrement: 10,
            unit: "£",
            periodLabel: "this week"
        )

        let copy = provider.copy(
            for: .cumulative,
            status: .ahead,
            confidence: .low,
            date: date,
            context: context
        )

        XCTAssertFalse(copy.body?.contains("could lift") ?? false)
        XCTAssertFalse(copy.body?.contains("~£10/day") ?? false)
    }
}
