import SwiftData
import XCTest
@testable import Habits

final class CurrencyIntegrationTests: XCTestCase {
    private func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Habit.self, HabitLog.self, configurations: config)
    }

    private func makeCurrencyHabit(unit: String = "GBP") -> Habit {
        Habit(
            name: "Savings",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: 500,
            unit: unit,
            allowsDecimals: true
        )
    }

    func testCurrencyHabitFormatsProgressWithoutAppendingRawUnit() {
        let habit = makeCurrencyHabit(unit: "GBP")
        let day = Date(timeIntervalSince1970: 100)
        habit.logValue(on: day, value: 12.5)

        let inline = habit.inlineProgressText(for: day)

        XCTAssertEqual(inline, "£12.50 / £500.00")
    }

    func testServiceFormatsCurrencyDayTotals() {
        let container = makeContainer()
        let context = ModelContext(container)
        let service = HabitLogService(modelContext: context)
        let habit = makeCurrencyHabit(unit: "£")
        context.insert(habit)

        let day = Date(timeIntervalSince1970: 200)
        _ = service.addLog(for: habit, on: day, value: 99.5)

        XCTAssertEqual(service.formattedValue(for: habit, on: day), "£99.50")
        XCTAssertEqual(service.displayUnitSuffix(for: habit), "")
    }

    func testChangingUnitToCurrencyUpdatesFormattingWithoutDataRewrite() {
        let habit = makeCurrencyHabit(unit: "books")
        let day = Date(timeIntervalSince1970: 300)
        habit.logValue(on: day, value: 20)

        XCTAssertEqual(habit.formatProgressValue(20), "20")

        habit.unit = "USD"

        XCTAssertEqual(habit.formatProgressValue(20), "$20.00")
    }
}
