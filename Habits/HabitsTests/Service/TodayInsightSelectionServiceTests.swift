import XCTest
@testable import Habits

final class TodayInsightSelectionServiceTests: BaseTestCase {
    override func setUp() async throws {
        try await super.setUp()
        TodayInsightSelectionService.shared.reset()
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
