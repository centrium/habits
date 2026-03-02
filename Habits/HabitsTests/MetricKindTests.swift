import XCTest
@testable import Habits

final class MetricKindTests: XCTestCase {
    private func makeHabit(goalType: GoalType, unit: String? = nil) -> Habit {
        Habit(
            name: "Test",
            colorHex: "#FFFFFF",
            hasStreakGoal: goalType == .cumulative,
            goalPeriod: .daily,
            goalType: goalType,
            streakTarget: 1,
            targetValue: goalType == .cumulative ? 10 : nil,
            unit: unit,
            allowsDecimals: true
        )
    }

    func testResolverReturnsCountForFrequencyHabit() {
        let habit = makeHabit(goalType: .frequency)

        XCTAssertEqual(MetricKindResolver.resolve(habit), .count)
    }

    func testResolverReturnsCurrencyForCurrencyUnit() {
        let habit = makeHabit(goalType: .cumulative, unit: "USD")

        XCTAssertEqual(MetricKindResolver.resolve(habit), .currency)
    }

    func testResolverReturnsGenericValueForNonCurrencyCumulativeHabit() {
        let habit = makeHabit(goalType: .cumulative, unit: "books")

        XCTAssertEqual(MetricKindResolver.resolve(habit), .genericValue)
    }
}
