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
        let candidate = makeCandidate(peakHour: 18)
        let now = dateAtHour(15)

        let insight = TodayInsightSelectionService.shared.selectInsight(
            from: [candidate],
            now: now,
            calendar: TestDateFactory.utcCalendar
        )

        XCTAssertEqual(insight?.message, "Best time to Reading: 6PM")
    }

    @MainActor
    func testMessageShowsTomorrowBestTimeWhenPeakHasPassed() {
        let candidate = makeCandidate(peakHour: 11)
        let now = dateAtHour(15)

        let insight = TodayInsightSelectionService.shared.selectInsight(
            from: [candidate],
            now: now,
            calendar: TestDateFactory.utcCalendar
        )

        XCTAssertEqual(insight?.message, "Best time tomorrow to Reading: 11AM")
    }

    private func makeCandidate(peakHour: Int) -> TodayInsightCandidate {
        let habit = TestHabitFactory.frequency(name: "Reading")
        let rhythm = HabitRhythm(
            peakHour: peakHour,
            dipStart: 14,
            dipEnd: 16,
            consistencyScore: 0.7,
            lastUpdated: TestDateFactory.referenceNow
        )

        return TodayInsightCandidate(
            habit: habit,
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
