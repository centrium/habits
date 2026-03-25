import XCTest
@testable import Habits

final class WidgetHabitMomentumTests: XCTestCase {
    func testMomentumSummaryReturnsStartBuildingForZeroScore() {
        let habit = makeHabit(momentumScore: 0)

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.score, 0)
        XCTAssertEqual(summary.state, .startBuilding)
    }

    func testMomentumSummaryReturnsSlippingForLowNonZeroScore() {
        let habit = makeHabit(momentumScore: 28)

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.score, 28)
        XCTAssertEqual(summary.state, .slipping)
    }

    func testMomentumSummaryReturnsBuildingForMidRangeScore() {
        let habit = makeHabit(momentumScore: 61)

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.score, 61)
        XCTAssertEqual(summary.state, .building)
    }

    func testMomentumSummaryReturnsStrongForHighScore() {
        let habit = makeHabit(momentumScore: 88)

        let summary = habit.momentumSummary

        XCTAssertEqual(summary.score, 88)
        XCTAssertEqual(summary.state, .strong)
    }

    private func makeHabit(
        momentumScore: Int
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
            momentumScore: momentumScore
        )
    }
}
