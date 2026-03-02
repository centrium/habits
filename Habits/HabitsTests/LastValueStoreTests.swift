import SwiftData
import XCTest
@testable import Habits

final class LastValueStoreTests: XCTestCase {
    private func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Habit.self, HabitLog.self, configurations: config)
    }

    private func makeHabit() -> Habit {
        Habit(
            name: "Savings",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: 500,
            unit: "GBP",
            allowsDecimals: true
        )
    }

    func testReturnsMostRecentPersistedEntryValue() throws {
        let container = makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit()
        context.insert(habit)

        let earlier = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        habit.logs.append(HabitLog(timestamp: earlier, value: 12.5, createdAt: earlier))
        habit.logs.append(HabitLog(timestamp: later, value: 45.75, createdAt: later))
        try context.save()

        let store = LogDerivedLastValueStore()
        XCTAssertEqual(store.getLastValue(for: habit), Decimal(string: "45.75"))
    }

    func testLatestValueIsAvailableFromFreshContextBackedBySameContainer() throws {
        let container = makeContainer()
        let writeContext = ModelContext(container)
        let habit = makeHabit()
        writeContext.insert(habit)

        let timestamp = Date(timeIntervalSince1970: 300)
        habit.logs.append(HabitLog(timestamp: timestamp, value: 19.99, createdAt: timestamp))
        try writeContext.save()

        let readContext = ModelContext(container)
        let storedHabit = try XCTUnwrap(readContext.fetch(FetchDescriptor<Habit>()).first)

        let store = LogDerivedLastValueStore()
        XCTAssertEqual(store.getLastValue(for: storedHabit), Decimal(string: "19.99"))
    }

    func testDeletingLatestEntryFallsBackToPreviousEntry() {
        let container = makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit()
        context.insert(habit)

        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)
        habit.logs.append(HabitLog(timestamp: first, value: 10, createdAt: first))
        habit.logs.append(HabitLog(timestamp: second, value: 25, createdAt: second))
        habit.logs.removeAll { $0.createdAt == second }

        let store = LogDerivedLastValueStore()
        XCTAssertEqual(store.getLastValue(for: habit), Decimal(10))
    }
}
