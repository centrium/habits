import Foundation
import SwiftData
import XCTest
@testable import Habits

@MainActor
final class HabitLoggingArchitectureTests: BaseTestCase {

    func testAlternatingRapidTapsAcrossHabitsPersistIndependently() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let a = TestHabitFactory.frequency(name: "A", calendar: calendar)
        let b = TestHabitFactory.frequency(name: "B", calendar: calendar)
        persistence.insert(a)
        persistence.insert(b)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        let today = calendar.startOfDay(for: Date())

        for index in 0..<20 {
            if index.isMultiple(of: 2) {
                _ = service.addLog(for: a, on: today, value: 1)
            } else {
                _ = service.addLog(for: b, on: today, value: 1)
            }
        }

        try await waitUntil {
            let persistedA = try self.persistedHabit(id: a.id, in: persistence.container)
            let persistedB = try self.persistedHabit(id: b.id, in: persistence.container)
            let countA = persistedA?.logs.filter { calendar.isDate($0.day, inSameDayAs: today) }.count ?? 0
            let countB = persistedB?.logs.filter { calendar.isDate($0.day, inSameDayAs: today) }.count ?? 0
            return countA == 10 && countB == 10
        }
    }


    func testClearEntriesProjectsZeroImmediatelyAndPersistsThroughMutationPipeline() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Clear",
            target: 10,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 3),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 4),
            ],
            calendar: calendar
        )
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        _ = service.projectedHistoryDayStates(for: habit)
        let versionBeforeClear = uiStateStore.projectionVersionByHabitID[habit.id] ?? 0

        _ = service.clearEntries(for: habit, on: day)

        let projectedNow = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projectedNow?.count, 0)
        XCTAssertEqual(projectedNow?.value, 0)
        XCTAssertEqual(projectedNow?.progress, 0)
        XCTAssertEqual(projectedNow?.isComplete, false)
        XCTAssertGreaterThan(uiStateStore.projectionVersionByHabitID[habit.id] ?? 0, versionBeforeClear)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return count == 0 && pending.isEmpty
        }

        let finalProjected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(finalProjected?.count, 0)
        XCTAssertEqual(finalProjected?.value, 0)
    }

    func testClearEntriesAfterRapidAddsKeepsProjectionZeroAndDrainsInOrder() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let habit = TestHabitFactory.frequency(name: "Rapid Clear", target: 1, calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        let day = calendar.startOfDay(for: Date())

        for _ in 0..<3 {
            _ = service.addLog(for: habit, on: day, value: 1)
        }
        _ = service.clearEntries(for: habit, on: day)

        let projectedNow = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projectedNow?.count, 0)
        XCTAssertEqual(projectedNow?.value, 0)
        XCTAssertEqual(projectedNow?.isComplete, false)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return count == 0 && pending.isEmpty
        }
    }

   

    func testDecrementClampsAtZero() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Decrement Clamp", target: 2, calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        XCTAssertEqual(service.decrement(for: habit, on: day), 0)
        let projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.count, 0)
        XCTAssertEqual(projected?.value, 0)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return count == 0 && pending.isEmpty
        }
    }

    func testDecrementTwiceContinuesDownToZero() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(
            name: "Decrement Twice",
            target: 3,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 1),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 1),
            ],
            calendar: calendar
        )
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        _ = service.projectedHistoryDayStates(for: habit)

        XCTAssertEqual(service.decrement(for: habit, on: day), 1)
        XCTAssertEqual(service.decrement(for: habit, on: day), 0)
        XCTAssertEqual(service.decrement(for: habit, on: day), 0)

        let projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.count, 0)
        XCTAssertEqual(projected?.value, 0)
    }

   
    func testDecrementOrderingLogLogThenDecrement() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Decrement LogLog", target: 3, calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        _ = service.addLog(for: habit, on: day, value: 1)
        _ = service.addLog(for: habit, on: day, value: 1)
        XCTAssertEqual(service.decrement(for: habit, on: day), 1)

        let projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.count, 1)
        XCTAssertEqual(projected?.value, 1)
    }

    func testDecrementMatchesSetCountCurrentMinusOne() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let decrementHabit = TestHabitFactory.frequency(
            name: "Dec Parity A",
            target: 4,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(8 * 3600), value: 1),
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 1),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 1),
            ],
            calendar: calendar
        )
        let setCountHabit = TestHabitFactory.frequency(
            name: "Dec Parity B",
            target: 4,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(8 * 3600), value: 1),
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 1),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 1),
            ],
            calendar: calendar
        )
        persistence.insert(decrementHabit)
        persistence.insert(setCountHabit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        _ = service.projectedHistoryDayStates(for: decrementHabit)
        _ = service.projectedHistoryDayStates(for: setCountHabit)

        XCTAssertEqual(service.decrement(for: decrementHabit, on: day), 2)
        XCTAssertEqual(service.setCount(for: setCountHabit, on: day, to: 2), 2)

        let projectedDecrement = uiStateStore.projectedDayState(
            habitID: decrementHabit.id,
            day: day,
            calendar: calendar
        )
        let projectedSetCount = uiStateStore.projectedDayState(
            habitID: setCountHabit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projectedDecrement?.count, projectedSetCount?.count)
        XCTAssertEqual(projectedDecrement?.value, projectedSetCount?.value)
        XCTAssertEqual(projectedDecrement?.progress, projectedSetCount?.progress)
        XCTAssertEqual(projectedDecrement?.isComplete, projectedSetCount?.isComplete)
    }

    private func persistedHabit(id: UUID, in container: ModelContainer) throws -> Habit? {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Habit>()).first(where: { $0.id == id })
    }

    private func waitUntil(
        timeout: TimeInterval = 6,
        pollIntervalNanoseconds: UInt64 = 50_000_000,
        condition: @escaping () async throws -> Bool
    ) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if try await condition() {
                return
            }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Timed out waiting for async condition")
    }
}

private actor TestEventStore {
    private(set) var committedCount: Int = 0
    private(set) var failedCount: Int = 0

    func append(_ event: HabitLogPersistenceEvent) {
        switch event {
        case .committed:
            committedCount += 1
        case .failed:
            failedCount += 1
        case .writing:
            break
        }
    }
}
