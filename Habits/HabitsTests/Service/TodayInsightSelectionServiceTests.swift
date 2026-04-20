import XCTest
@testable import Habits

final class TodayInsightSelectionServiceTests: XCTestCase {
    @MainActor
    override func setUp() {
        super.setUp()
        TodayInsightSelectionService.shared.reset()
    }

    @MainActor
    func testMessageShowsTodayBestTimeWhenPeakIsAhead() {
        let now = dateAtHour(15)
        let candidate = makeCandidate(
            peakHour: 18,
            confidence: 0.9,
            uniqueEventCount: 24,
            now: now,
            uniqueCompletedDays: 6
        )

        let insight = TodayInsightSelectionService.shared.selectInsight(
            from: [candidate],
            now: now,
            calendar: TestDateFactory.utcCalendar
        )

        XCTAssertEqual(insight?.message, "Your strongest window is coming up for Reading")
    }

    @MainActor
    func testMessageShowsLaterInDayWhenPeakHasPassed() {
        let now = dateAtHour(15)
        let candidate = makeCandidate(
            peakHour: 11,
            confidence: 0.9,
            uniqueEventCount: 24,
            now: now,
            uniqueCompletedDays: 6
        )

        let insight = TodayInsightSelectionService.shared.selectInsight(
            from: [candidate],
            now: now,
            calendar: TestDateFactory.utcCalendar
        )

        XCTAssertEqual(insight?.message, "You usually do this later in the day for Reading")
    }

    @MainActor
    func testMessageUsesSoftWindowWhenConfidenceIsLow() {
        let now = dateAtHour(10)
        let candidate = makeCandidate(
            peakHour: 21,
            confidence: 0.2,
            uniqueEventCount: 8,
            now: now,
            uniqueCompletedDays: 6
        )

        let insight = TodayInsightSelectionService.shared.selectInsight(
            from: [candidate],
            now: now,
            calendar: TestDateFactory.utcCalendar
        )

        XCTAssertEqual(insight?.message, "Early signal around 9PM for Reading")
    }

    @MainActor
    func testMessageUsesMediumConfidenceLanguage() {
        let now = dateAtHour(10)
        let candidate = makeCandidate(
            peakHour: 21,
            confidence: 0.6,
            uniqueEventCount: 8,
            now: now,
            uniqueCompletedDays: 6
        )

        let insight = TodayInsightSelectionService.shared.selectInsight(
            from: [candidate],
            now: now,
            calendar: TestDateFactory.utcCalendar
        )

        XCTAssertEqual(insight?.message, "Often around 9PM for Reading")
    }

    @MainActor
    func testMessageForLowDataForcesTimingStillForming() {
        let now = dateAtHour(10)
        let candidate = makeCandidate(
            peakHour: 21,
            confidence: 0.9,
            uniqueEventCount: 24,
            now: now,
            uniqueCompletedDays: 2
        )

        let insight = TodayInsightSelectionService.shared.selectInsight(
            from: [candidate],
            now: now,
            calendar: TestDateFactory.utcCalendar
        )

        XCTAssertEqual(
            insight?.message,
            "Timing is still forming for Reading. Keep showing up to build a reliable timing signal."
        )
    }

    private func makeCandidate(
        peakHour: Int,
        confidence: Double,
        uniqueEventCount: Int,
        now: Date,
        uniqueCompletedDays: Int
    ) -> TodayInsightCandidate {
        let entries: [TestHabitFactory.Entry] = (0..<max(uniqueCompletedDays, 0)).map { offset in
            TestHabitFactory.entry(
                on: TestDateFactory.addingDays(-offset, to: now, calendar: TestDateFactory.utcCalendar)
            )
        }
        let habit = TestHabitFactory.frequency(
            name: "Reading",
            entries: entries,
            calendar: TestDateFactory.utcCalendar
        )
        let rhythm = HabitRhythm(
            peakHour: peakHour,
            dipStart: 14,
            dipEnd: 16,
            consistencyScore: 0.7,
            confidence: confidence,
            uniqueEventCount: uniqueEventCount,
            lastUpdated: TestDateFactory.referenceNow
        )

        return TodayInsightCandidate(
            habit: habit,
            computedState: HabitComputationEngine(
                calendar: TestDateFactory.utcCalendar,
                weekStartPreference: .system
            ).compute(
                habit: habit,
                logs: habit.logs,
                globalLogs: habit.logs,
                now: now
            ),
            rhythm: rhythm,
            isCompletedToday: false,
            lastCompletedDate: nil,
            streak: 3
        )
    }

    private func dateAtHour(_ hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 15
        components.hour = hour
        components.minute = 0
        components.second = 0
        return TestDateFactory.utcCalendar.date(from: components) ?? TestDateFactory.referenceNow
    }
}
