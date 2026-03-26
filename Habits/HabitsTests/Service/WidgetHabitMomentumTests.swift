import XCTest
@testable import Habits

final class WidgetHabitMomentumTests: XCTestCase {
    func testMomentumSummaryReturnsSlippingForLowScore() {
        let habit = makeHabit(momentumScore: 22, recentActivity: [])

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.score, 22)
        XCTAssertEqual(summary.state, .slipping)
        XCTAssertEqual(summary.direction, .unavailable)
        XCTAssertEqual(summary.direction.summaryText, "Need 14 days")
    }

    func testMomentumSummaryReturnsSteadyForMidRangeScore() {
        let habit = makeHabit(momentumScore: 61, recentActivity: [])

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.score, 61)
        XCTAssertEqual(summary.state, .steady)
    }

    func testMomentumSummaryReturnsBuildingForHighScore() {
        let habit = makeHabit(momentumScore: 88, recentActivity: [])

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.score, 88)
        XCTAssertEqual(summary.state, .building)
    }

    func testMomentumSummaryDetectsImprovingDirectionFromRecentActivity() {
        let habit = makeHabit(
            momentumScore: 72,
            recentActivity: samples(values: [0.2, 0.3, 0.2, 0.4, 0.3, 0.4, 0.3, 0.3, 0.4, 0.4, 0.5, 0.4, 0.4, 0.4])
        )

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.direction, .improving(deltaPercent: 20))
        XCTAssertEqual(summary.direction.summaryText, "Up 20% vs prior 7d")
    }

    func testMomentumSummaryDetectsDecliningDirectionFromRecentActivity() {
        let habit = makeHabit(
            momentumScore: 28,
            recentActivity: samples(values: [0.8, 0.7, 0.8, 0.7, 0.6, 0.7, 0.6, 0.5, 0.4, 0.3, 0.3, 0.2, 0.1, 0.1])
        )

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.direction, .declining(deltaPercent: 54))
        XCTAssertEqual(summary.direction.summaryText, "Down 54% vs prior 7d")
    }

    func testMomentumSummaryReturnsStableDirectionForSmallWeeklyChange() {
        let habit = makeHabit(
            momentumScore: 52,
            recentActivity: samples(values: [0.5, 0.48, 0.5, 0.52, 0.49, 0.5, 0.51, 0.5, 0.49, 0.5, 0.51, 0.5, 0.5, 0.49])
        )

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.direction, .stable)
        XCTAssertEqual(summary.direction.summaryText, "Flat vs prior 7d")
    }

    private func makeHabit(
        momentumScore: Int,
        recentActivity: [WidgetActivitySample]
    ) -> WidgetHabit {
        WidgetHabit(
            id: UUID(),
            name: "Habit",
            isCompleteToday: false,
            streak: 0,
            goalType: .binary,
            progress: nil,
            hasActivityToday: false,
            iconName: nil,
            colorHex: nil,
            momentumScore: momentumScore,
            recentActivity: recentActivity
        )
    }

    private func samples(values: [Double]) -> [WidgetActivitySample] {
        let calendar = TestDateFactory.utcCalendar
        let referenceDate = TestDateFactory.referenceNow

        return values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .day, value: -13 + index, to: referenceDate) else {
                return nil
            }

            return WidgetActivitySample(date: date, value: value)
        }
    }
}
