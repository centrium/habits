import Foundation
import SwiftData
import XCTest
@testable import Habits

@MainActor
final class HabitLoggingArchitectureTests: XCTestCase {
    func testRapidTapsOnSameHabitConvergesAfterAsyncSettle() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let habit = TestHabitFactory.frequency(name: "Rapid", target: 1, calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        let today = calendar.startOfDay(for: Date())

        for _ in 0..<10 {
            _ = service.addLog(for: habit, on: today, value: 1)
        }

        let projectedNow = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: today,
            calendar: calendar
        )
        XCTAssertEqual(projectedNow?.count, 10)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: today) }.count ?? 0
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return count == 10 && pending.isEmpty
        }

        let persisted = try persistedHabit(id: habit.id, in: persistence.container)
        let persistedCount = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: today) }.count ?? 0
        XCTAssertEqual(persistedCount, 10)
        let finalProjected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: today,
            calendar: calendar
        )
        XCTAssertEqual(finalProjected?.count, 10)
    }

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

    func testGoalTypesFrequencyCumulativeAndOpenPersistCorrectly() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let frequency = TestHabitFactory.frequency(name: "F", target: 2, calendar: calendar)
        let cumulative = TestHabitFactory.cumulative(name: "C", target: 5, calendar: calendar)
        let open = TestHabitFactory.openEnded(name: "O", calendar: calendar)
        persistence.insert(frequency)
        persistence.insert(cumulative)
        persistence.insert(open)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        let today = calendar.startOfDay(for: Date())

        _ = service.addLog(for: frequency, on: today, value: 1)
        _ = service.addLog(for: frequency, on: today, value: 1)
        _ = service.addLog(for: cumulative, on: today, value: 2)
        _ = service.addLog(for: cumulative, on: today, value: 3)
        _ = service.addLog(for: open, on: today, value: 1)

        try await waitUntil {
            let pf = try self.persistedHabit(id: frequency.id, in: persistence.container)
            let pc = try self.persistedHabit(id: cumulative.id, in: persistence.container)
            let po = try self.persistedHabit(id: open.id, in: persistence.container)
            return (pf?.logs.count ?? 0) == 2 && (pc?.logs.count ?? 0) == 2 && (po?.logs.count ?? 0) == 1
        }

        let persistedFrequency = try XCTUnwrap(try persistedHabit(id: frequency.id, in: persistence.container))
        let persistedCumulative = try XCTUnwrap(try persistedHabit(id: cumulative.id, in: persistence.container))
        let persistedOpen = try XCTUnwrap(try persistedHabit(id: open.id, in: persistence.container))

        XCTAssertEqual(persistedFrequency.logs.count, 2)
        XCTAssertEqual(persistedCumulative.logs.reduce(0) { $0 + $1.numericValue }, 5, accuracy: 0.0001)
        XCTAssertEqual(persistedOpen.logs.count, 1)
    }

    func testTimeOfDayServiceDropsStaleResultAndKeepsLatest() async throws {
        let calendar = TestDateFactory.utcCalendar
        let service = TimeOfDayPerformanceService.shared
        service.clearCache()

        let base = Date()
        let oldHabit = TestHabitFactory.frequency(
            name: "Rhythm",
            entries: (0..<8).map { offset in
                TestHabitFactory.entry(
                    on: calendar.date(byAdding: .day, value: -offset, to: base)!
                        .addingTimeInterval(8 * 3600),
                    value: 1
                )
            },
            calendar: calendar
        )
        let newHabit = TestHabitFactory.frequency(
            name: "Rhythm",
            entries: (0..<8).map { offset in
                TestHabitFactory.entry(
                    on: calendar.date(byAdding: .day, value: -offset, to: base)!
                        .addingTimeInterval(20 * 3600),
                    value: 1
                )
            },
            calendar: calendar
        )
        newHabit.id = oldHabit.id

        async let first = service.hourlyValues(for: oldHabit, globalLogs: oldHabit.logs, days: 3, now: base, calendar: calendar)
        async let second = service.hourlyValues(for: newHabit, globalLogs: newHabit.logs, days: 3, now: base, calendar: calendar)
        _ = await (first, second)

        let latestPeak = service.cachedRhythm(for: newHabit, isPremium: false)?.peakHour
        XCTAssertEqual(latestPeak, 20)
    }

    func testPersistenceCoordinatorIsIdempotentForDuplicateMutationNonce() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let habit = TestHabitFactory.frequency(name: "Idempotent", calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let day = calendar.startOfDay(for: Date())
        let mutationID = HabitLogMutationID(
            habitID: habit.id,
            dayStart: day,
            sequence: 1,
            nonce: UUID()
        )
        let mutation = HabitLogPendingMutation(
            id: mutationID,
            valueDelta: 1,
            countDelta: 1,
            expectedProgress: 1,
            expectedCompletion: true
        )
        let payload = HabitLogWritePayload(
            mutation: mutation,
            entryTimestamp: Date(),
            referenceDate: day
        )

        let eventStore = TestEventStore()
        let coordinator = HabitLogPersistenceCoordinator(
            modelContainer: persistence.container,
            maxAttempts: 1
        ) { event in
            await eventStore.append(event)
        }

        await coordinator.enqueue(payload)
        await coordinator.enqueue(payload)

        try await waitUntil {
            let committed = await eventStore.committedCount
            return committed >= 2
        }

        let persisted = try persistedHabit(id: habit.id, in: persistence.container)
        XCTAssertEqual(persisted?.logs.count, 1, "Duplicate payloads must not produce duplicate logs")
    }

    func testPersistenceCoordinatorRecoversAfterFailedMutationForSameHabit() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let missingHabitID = UUID()
        let day = calendar.startOfDay(for: Date())

        let failedMutation = HabitLogPendingMutation(
            id: HabitLogMutationID(habitID: missingHabitID, dayStart: day, sequence: 1, nonce: UUID()),
            valueDelta: 1,
            countDelta: 1,
            expectedProgress: 1,
            expectedCompletion: true
        )
        let failedPayload = HabitLogWritePayload(
            mutation: failedMutation,
            entryTimestamp: Date(),
            referenceDate: day
        )

        let eventStore = TestEventStore()
        let coordinator = HabitLogPersistenceCoordinator(
            modelContainer: persistence.container,
            maxAttempts: 1
        ) { event in
            await eventStore.append(event)
        }

        await coordinator.enqueue(failedPayload)
        try await waitUntil {
            let failed = await eventStore.failedCount
            return failed == 1
        }

        let recoveredHabit = TestHabitFactory.frequency(name: "Recovered", calendar: calendar)
        recoveredHabit.id = missingHabitID
        persistence.insert(recoveredHabit)
        try persistence.save()

        let successfulMutation = HabitLogPendingMutation(
            id: HabitLogMutationID(habitID: missingHabitID, dayStart: day, sequence: 2, nonce: UUID()),
            valueDelta: 1,
            countDelta: 1,
            expectedProgress: 1,
            expectedCompletion: true
        )
        let successPayload = HabitLogWritePayload(
            mutation: successfulMutation,
            entryTimestamp: Date(),
            referenceDate: day
        )
        await coordinator.enqueue(successPayload)

        try await waitUntil {
            let committed = await eventStore.committedCount
            return committed >= 1
        }

        let persisted = try persistedHabit(id: missingHabitID, in: persistence.container)
        XCTAssertEqual(persisted?.logs.count, 1, "Queue must recover after a failure and commit subsequent writes")
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
