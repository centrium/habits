import Combine
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

    func testComputedStatePopulatesAfterAddLogCommit() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Computed Add", target: 1, calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        _ = service.addLog(for: habit, on: day, value: 1)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? 0
            let computed = service.computedStateByHabitID[habit.id]
            return count == 1 && computed != nil
        }
    }

    func testComputedStatePopulatesAfterAllMutationCommitPaths() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let dayPlus1 = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let dayPlus2 = calendar.date(byAdding: .day, value: 2, to: day) ?? day
        let dayPlus3 = calendar.date(byAdding: .day, value: 3, to: day) ?? day
        let dayPlus4 = calendar.date(byAdding: .day, value: 4, to: day) ?? day

        let updateHabit = TestHabitFactory.cumulative(
            name: "Computed Update",
            target: 5,
            entries: [TestHabitFactory.entry(on: day.addingTimeInterval(8 * 3600), value: 1)],
            calendar: calendar
        )
        let deleteHabit = TestHabitFactory.cumulative(
            name: "Computed Delete",
            target: 5,
            entries: [TestHabitFactory.entry(on: dayPlus1.addingTimeInterval(8 * 3600), value: 1)],
            calendar: calendar
        )
        let clearHabit = TestHabitFactory.cumulative(
            name: "Computed Clear",
            target: 5,
            entries: [TestHabitFactory.entry(on: dayPlus2.addingTimeInterval(8 * 3600), value: 2)],
            calendar: calendar
        )
        let setCountHabit = TestHabitFactory.frequency(name: "Computed SetCount", target: 3, calendar: calendar)
        let addHabit = TestHabitFactory.frequency(name: "Computed Add", target: 2, calendar: calendar)

        persistence.insert(updateHabit)
        persistence.insert(deleteHabit)
        persistence.insert(clearHabit)
        persistence.insert(setCountHabit)
        persistence.insert(addHabit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        let updateEntry = try XCTUnwrap(updateHabit.logs.first)
        _ = service.updateEntry(updateEntry, for: updateHabit, on: day, value: 3)

        let deleteEntry = try XCTUnwrap(deleteHabit.logs.first)
        _ = service.deleteEntry(deleteEntry, for: deleteHabit, on: dayPlus1)

        _ = service.clearEntries(for: clearHabit, on: dayPlus2)
        _ = service.setCount(for: setCountHabit, on: dayPlus3, to: 2)
        _ = service.addLog(for: addHabit, on: dayPlus4, value: 1)

        let expectedIDs: Set<UUID> = [
            updateHabit.id,
            deleteHabit.id,
            clearHabit.id,
            setCountHabit.id,
            addHabit.id,
        ]

        try await waitUntil(timeout: 20) {
            let populatedIDs = Set(service.computedStateByHabitID.keys)
            return expectedIDs.isSubset(of: populatedIDs)
        }
    }

    func testResolvedComputedStateForDisplayReturnsNeutralEmptyStateForBrandNewHabit() throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let today = calendar.startOfDay(for: Date())
        let initialHabit = TestHabitFactory.frequency(name: "New Habit", target: 1, calendar: calendar)
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: HabitUIStateStore()
        )

        let resolved = service.resolvedComputedStateForDisplay(
            habit: initialHabit,
            referenceDate: today,
            weekStartPreference: .system
        )

        XCTAssertEqual(resolved.streakState.currentStreak, 0)
        XCTAssertEqual(resolved.streakState.status, .safe)
        XCTAssertFalse(resolved.streakState.isBroken)
        XCTAssertEqual(resolved.consistency.percentage, 0)
        XCTAssertEqual(resolved.consistency.daysCompleted, 0)
        XCTAssertEqual(resolved.consistency.daysAvailable, 1)
        XCTAssertEqual(resolved.consistency.windowDays, 7)
        XCTAssertNil(service.computedStateByHabitID[initialHabit.id])
    }

    func testResolvedComputedStateForDisplayDoesNotPublishComputedCacheChanges() throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let today = calendar.startOfDay(for: Date())
        let initialHabit = TestHabitFactory.frequency(name: "Pure Resolver", target: 1, calendar: calendar)
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: HabitUIStateStore()
        )

        var emissionCount = 0
        var cancellables = Set<AnyCancellable>()
        service.$computedStateByHabitID
            .sink { _ in emissionCount += 1 }
            .store(in: &cancellables)

        let baselineEmissions = emissionCount
        _ = service.resolvedComputedStateForDisplay(
            habit: initialHabit,
            referenceDate: today,
            weekStartPreference: .system
        )

        XCTAssertEqual(emissionCount, baselineEmissions)
        XCTAssertTrue(service.computedStateByHabitID.isEmpty)
    }

    func testComputedStateRefreshPolicyMatrix() throws {
        let persistence = try TestPersistence()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: TestDateFactory.utcCalendar,
            uiStateStore: HabitUIStateStore()
        )
        let day = TestDateFactory.utcCalendar.startOfDay(for: Date())

        XCTAssertTrue(service.shouldScheduleComputedStateRefresh(for: .committed(referenceDate: day)))
        XCTAssertFalse(service.shouldScheduleComputedStateRefresh(for: .failed(errorDescription: "x")))
        XCTAssertFalse(service.shouldScheduleComputedStateRefresh(for: .cancelled))
        XCTAssertFalse(service.shouldScheduleComputedStateRefresh(for: .stale))
    }

    func testFailedPersistenceDoesNotPopulateComputedState() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Missing", target: 1, calendar: calendar)

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        _ = service.addLog(for: habit, on: day, value: 1)

        try await waitUntil {
            let pending = uiStateStore.pendingMutations(for: habit.id)
            guard let first = pending.first else { return false }
            return first.status == .failed
        }
        XCTAssertNil(service.computedStateByHabitID[habit.id])
    }

    func testResolvedComputedStateUsesCachedSnapshotWhileMutationPending() throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Pending Computed", target: 1, calendar: calendar)

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        let baseline = service.resolvedComputedStateForDisplay(
            habit: habit,
            referenceDate: day,
            weekStartPreference: .system
        )
        XCTAssertEqual(baseline.streakState.currentStreak, 0)

        _ = service.addLog(for: habit, on: day, value: 1)

        let resolvedPending = service.resolvedComputedStateForDisplay(
            habit: habit,
            referenceDate: day,
            weekStartPreference: .system
        )

        XCTAssertEqual(resolvedPending.streakState.currentStreak, 0)
        XCTAssertEqual(service.computedStateByHabitID[habit.id]?.streakState.currentStreak, 0)
    }

    func testResolvedComputedStateRollsBackAfterFailedPersistence() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Rollback Computed", target: 1, calendar: calendar)

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        _ = service.resolvedComputedStateForDisplay(
            habit: habit,
            referenceDate: day,
            weekStartPreference: .system
        )
        _ = service.addLog(for: habit, on: day, value: 1)

        let optimistic = service.resolvedComputedStateForDisplay(
            habit: habit,
            referenceDate: day,
            weekStartPreference: .system
        )
        XCTAssertEqual(optimistic.streakState.currentStreak, 0)

        try await waitUntil {
            let pending = uiStateStore.pendingMutations(for: habit.id)
            guard let first = pending.first else { return false }
            return first.status == .failed
        }

        let rolledBack = service.resolvedComputedStateForDisplay(
            habit: habit,
            referenceDate: day,
            weekStartPreference: .system
        )
        XCTAssertEqual(rolledBack.streakState.currentStreak, 0)
    }

    private func persistedHabit(id: UUID, in container: ModelContainer) throws -> Habit? {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Habit>()).first(where: { $0.id == id })
    }

    private func waitUntil(
        timeout: TimeInterval = 12,
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
        case .cancelled, .stale:
            break
        case .writing:
            break
        }
    }
}
