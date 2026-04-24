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

    func testSetCountProjectsReplacementAndPersistsExactCount() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(
            name: "Set Count",
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

        XCTAssertEqual(service.setCount(for: habit, on: day, to: 1), 1)
        let projectedOne = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projectedOne?.count, 1)
        XCTAssertEqual(projectedOne?.value, 1)
        XCTAssertEqual(projectedOne?.isComplete, false)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            return count == 1 && uiStateStore.pendingMutations(for: habit.id).isEmpty
        }

        XCTAssertEqual(service.setCount(for: habit, on: day, to: 3), 3)
        let projectedThree = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projectedThree?.count, 3)
        XCTAssertEqual(projectedThree?.value, 3)
        XCTAssertEqual(projectedThree?.isComplete, true)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            return count == 3 && uiStateStore.pendingMutations(for: habit.id).isEmpty
        }

        XCTAssertEqual(service.setCount(for: habit, on: day, to: 0), 0)
        let projectedZero = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projectedZero?.count, 0)
        XCTAssertEqual(projectedZero?.value, 0)
        XCTAssertEqual(projectedZero?.progress, 0)
        XCTAssertEqual(projectedZero?.isComplete, false)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            return count == 0 && uiStateStore.pendingMutations(for: habit.id).isEmpty
        }
    }

    func testSetCountOrderingWithPendingAddsAndSubsequentLog() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Set Ordering", target: 2, calendar: calendar)
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
        _ = service.setCount(for: habit, on: day, to: 1)

        var projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.count, 1)
        XCTAssertEqual(projected?.value, 1)

        _ = service.addLog(for: habit, on: day, value: 1)
        projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.count, 2)
        XCTAssertEqual(projected?.value, 2)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            return count == 2 && uiStateStore.pendingMutations(for: habit.id).isEmpty
        }
    }

    func testSetCountOpenGoalKeepsCompletionFalse() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.openEnded(name: "Open Set", calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        _ = service.setCount(for: habit, on: day, to: 3)

        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projected?.count, 3)
        XCTAssertEqual(projected?.value, 3)
        XCTAssertEqual(projected?.progress, 0)
        XCTAssertEqual(projected?.isComplete, false)
    }

    func testDeleteEntryProjectsImmediatelyAndPersistsRemoval() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Delete Immediate",
            target: 10,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 3),
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
        let entryToDelete = try XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.deleteEntry(entryToDelete, for: habit, on: day)

        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projected?.count, 1)
        XCTAssertEqual(projected?.value, 3)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let dayLogs = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) } ?? []
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return dayLogs.count == 1 && pending.isEmpty
        }
    }

    func testDeleteEntrySequentiallyKeepsStateConsistent() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Delete Sequential",
            target: 10,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(8 * 3600), value: 1),
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 3),
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

        let first = try XCTUnwrap(service.entries(for: habit, on: day).first)
        _ = service.deleteEntry(first, for: habit, on: day)
        let second = try XCTUnwrap(service.entries(for: habit, on: day).dropFirst().first)
        _ = service.deleteEntry(second, for: habit, on: day)

        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projected?.count, 1)
        XCTAssertEqual(projected?.value, 3)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let dayLogs = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) } ?? []
            let total = dayLogs.reduce(0.0) { $0 + $1.numericValue }
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return dayLogs.count == 1 && abs(total - 3) < 0.0001 && pending.isEmpty
        }
    }

    func testDeleteEntryOrderingWithPendingLogMutations() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Delete Ordering",
            target: 10,
            entries: [TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2)],
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
        let original = try XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.addLog(for: habit, on: day, value: 4)
        _ = service.deleteEntry(original, for: habit, on: day)
        var projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.value, 4)

        _ = service.addLog(for: habit, on: day, value: 1)
        projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.value, 5)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let dayLogs = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) } ?? []
            let total = dayLogs.reduce(0.0) { $0 + $1.numericValue }
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return abs(total - 5) < 0.0001 && pending.isEmpty
        }
    }

    func testEntriesUseProjectedStateDuringPendingDelete() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Projected Entries",
            target: 10,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 3),
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
        let entryToDelete = try XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.deleteEntry(entryToDelete, for: habit, on: day)

        let pending = uiStateStore.pendingMutations(for: habit.id)
        XCTAssertFalse(pending.isEmpty)
        let projectedEntries = service.entries(for: habit, on: day)
        XCTAssertEqual(projectedEntries.count, 1)
        XCTAssertFalse(projectedEntries.contains { $0.id == entryToDelete.id })
    }

    func testPendingDeleteEntryIDsTracksQueuedDeleteForDay() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Pending Delete IDs",
            target: 10,
            entries: [TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2)],
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
        let entry = try XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.deleteEntry(entry, for: habit, on: day)

        let pendingDeleteIDs = service.pendingDeleteEntryIDs(for: habit, on: day)
        XCTAssertTrue(pendingDeleteIDs.contains(entry.id))
        let projectedAfterDelete = service.entries(for: habit, on: day)
        XCTAssertFalse(projectedAfterDelete.contains { $0.id == entry.id })
    }

    func testProjectedEntriesKeepStableUniqueIdentityAcrossMutations() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Projected Identity",
            target: 10,
            entries: [TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2)],
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

        let baseline = try XCTUnwrap(service.entries(for: habit, on: day).first)
        _ = service.addLog(for: habit, on: day, value: 4)
        let withPendingAdd = service.entries(for: habit, on: day)
        XCTAssertEqual(Set(withPendingAdd.map(\.id)).count, withPendingAdd.count)
        let pendingAdd = try XCTUnwrap(withPendingAdd.first { $0.id != baseline.id })

        _ = service.deleteEntry(baseline, for: habit, on: day)
        var afterDelete = service.entries(for: habit, on: day)
        XCTAssertFalse(afterDelete.contains { $0.id == baseline.id })
        XCTAssertTrue(afterDelete.contains { $0.id == pendingAdd.id })
        XCTAssertEqual(Set(afterDelete.map(\.id)).count, afterDelete.count)

        _ = service.deleteEntry(pendingAdd, for: habit, on: day)
        afterDelete = service.entries(for: habit, on: day)
        XCTAssertFalse(afterDelete.contains { $0.id == pendingAdd.id })
        XCTAssertEqual(Set(afterDelete.map(\.id)).count, afterDelete.count)
    }

    func testUpdateEntryProjectsImmediatelyAndPersistsUpdatedValue() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Update Immediate",
            target: 10,
            entries: [
                TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2),
                TestHabitFactory.entry(on: day.addingTimeInterval(10 * 3600), value: 3),
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
        let entryToUpdate = try XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.updateEntry(entryToUpdate, for: habit, on: day, value: 10)

        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projected?.count, 2)
        XCTAssertEqual(projected?.value, 13)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let dayLogs = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) } ?? []
            let total = dayLogs.reduce(0.0) { $0 + $1.numericValue }
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return dayLogs.count == 2 && abs(total - 13) < 0.0001 && pending.isEmpty
        }
    }

    func testUpdateEntryOrderingWithPendingLogMutations() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Update Ordering",
            target: 20,
            entries: [TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 2)],
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
        let original = try XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.addLog(for: habit, on: day, value: 4)
        _ = service.updateEntry(original, for: habit, on: day, value: 10)
        var projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.value, 14)

        _ = service.addLog(for: habit, on: day, value: 1)
        projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.value, 15)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let dayLogs = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) } ?? []
            let total = dayLogs.reduce(0.0) { $0 + $1.numericValue }
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return abs(total - 15) < 0.0001 && pending.isEmpty
        }
    }

    func testUpdateEntryToZeroThenDeleteStaysConsistent() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.cumulative(
            name: "Update Delete Ordering",
            target: 10,
            entries: [TestHabitFactory.entry(on: day.addingTimeInterval(9 * 3600), value: 5)],
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
        let entry = try XCTUnwrap(service.entries(for: habit, on: day).first)

        _ = service.updateEntry(entry, for: habit, on: day, value: 0)
        _ = service.deleteEntry(entry, for: habit, on: day)

        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(projected?.count, 0)
        XCTAssertEqual(projected?.value, 0)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let dayLogs = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) } ?? []
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return dayLogs.isEmpty && pending.isEmpty
        }
    }

    func testDecrementReducesCountByOne() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(
            name: "Decrement Core",
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
        let projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.count, 1)
        XCTAssertEqual(projected?.value, 1)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return count == 1 && pending.isEmpty
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

    func testDecrementOrderingLogThenDecrementAndBackToLog() async throws {
        let persistence = try TestPersistence()
        let calendar = TestDateFactory.utcCalendar
        let day = calendar.startOfDay(for: Date())
        let habit = TestHabitFactory.frequency(name: "Decrement Ordering", target: 2, calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        _ = service.addLog(for: habit, on: day, value: 1)
        XCTAssertEqual(service.decrement(for: habit, on: day), 0)
        _ = service.addLog(for: habit, on: day, value: 1)

        let projected = uiStateStore.projectedDayState(habitID: habit.id, day: day, calendar: calendar)
        XCTAssertEqual(projected?.count, 1)
        XCTAssertEqual(projected?.value, 1)

        try await waitUntil {
            let persisted = try self.persistedHabit(id: habit.id, in: persistence.container)
            let count = persisted?.logs.filter { calendar.isDate($0.day, inSameDayAs: day) }.count ?? -1
            let pending = uiStateStore.pendingMutations(for: habit.id)
            return count == 1 && pending.isEmpty
        }
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
