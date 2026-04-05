import Foundation
import SwiftUI
import SwiftData
import XCTest
@testable import Habits

final class HabitsListDeletionTests: XCTestCase {
    func testDeletingHabitRemovesItFromTheModel() throws {
        let persistence = try TestPersistence()
        let keepHabit = makeHabit(name: "Keep", orderIndex: 0)
        let deleteHabit = makeHabit(name: "Delete", orderIndex: 1)

        persistence.insert(keepHabit)
        persistence.insert(deleteHabit)
        try persistence.save()

        HabitDeletionAction.perform(
            habit: deleteHabit,
            modelContext: persistence.context
        )

        let remainingHabits = try fetchOrderedHabits(in: persistence.context)

        XCTAssertEqual(remainingHabits.count, 1)
        XCTAssertEqual(remainingHabits.first?.name, "Keep")
    }

    func testDeletingHabitDoesNotAffectRemainingHabits() throws {
        let persistence = try TestPersistence()
        let a = makeHabit(name: "A", colorHex: "#1F7A8C", orderIndex: 0)
        let b = makeHabit(name: "B", colorHex: "#BF4342", orderIndex: 1)
        let c = makeHabit(name: "C", colorHex: "#34D399", orderIndex: 2)

        persistence.insert(a)
        persistence.insert(b)
        persistence.insert(c)
        try persistence.save()

        HabitDeletionAction.perform(
            habit: b,
            modelContext: persistence.context
        )

        let remainingHabits = try fetchOrderedHabits(in: persistence.context)

        XCTAssertEqual(remainingHabits.map(\.name), ["A", "C"])
        XCTAssertEqual(remainingHabits.map(\.colorHex), ["#1F7A8C", "#34D399"])
        XCTAssertEqual(Set(remainingHabits.map(\.id)), Set([a.id, c.id]))
    }

    func testDeletingHabitNormalizesOrdering() throws {
        let persistence = try TestPersistence()
        let a = makeHabit(name: "A", orderIndex: 0)
        let b = makeHabit(name: "B", orderIndex: 1)
        let c = makeHabit(name: "C", orderIndex: 2)

        persistence.insert(a)
        persistence.insert(b)
        persistence.insert(c)
        try persistence.save()

        HabitDeletionAction.perform(
            habit: b,
            modelContext: persistence.context
        )

        let remainingHabits = try fetchOrderedHabits(in: persistence.context)

        XCTAssertEqual(remainingHabits.map(\.name), ["A", "C"])
        XCTAssertEqual(remainingHabits.map(\.orderIndex), [0, 1])
    }

    func testDeletingLastHabitLeavesNoHabitsForEmptyState() throws {
        let persistence = try TestPersistence()
        let onlyHabit = makeHabit(name: "Only", orderIndex: 0)

        persistence.insert(onlyHabit)
        try persistence.save()

        HabitDeletionAction.perform(
            habit: onlyHabit,
            modelContext: persistence.context
        )

        let remainingHabits = try fetchOrderedHabits(in: persistence.context)

        XCTAssertTrue(remainingHabits.isEmpty)
    }

    func testDeletingParentHabitUnlinksDirectChildrenOnly() throws {
        let persistence = try TestPersistence()
        let a = makeHabit(name: "A", orderIndex: 0)
        let b = makeHabit(name: "B", orderIndex: 1)
        let c = makeHabit(name: "C", orderIndex: 2)
        b.triggerHabitID = a.id
        c.triggerHabitID = b.id

        persistence.insert(a)
        persistence.insert(b)
        persistence.insert(c)
        try persistence.save()

        HabitDeletionAction.perform(
            habit: a,
            modelContext: persistence.context
        )

        let remainingHabits = try fetchOrderedHabits(in: persistence.context)
        XCTAssertEqual(remainingHabits.map(\.name), ["B", "C"])

        let bStored = try XCTUnwrap(remainingHabits.first(where: { $0.name == "B" }))
        let cStored = try XCTUnwrap(remainingHabits.first(where: { $0.name == "C" }))

        XCTAssertNil(bStored.triggerHabitID)
        XCTAssertEqual(cStored.triggerHabitID, bStored.id)
    }

    func testDeletingMiddleHabitDoesNotAutoRelinkChildren() throws {
        let persistence = try TestPersistence()
        let a = makeHabit(name: "A", orderIndex: 0)
        let b = makeHabit(name: "B", orderIndex: 1)
        let c = makeHabit(name: "C", orderIndex: 2)
        b.triggerHabitID = a.id
        c.triggerHabitID = b.id

        persistence.insert(a)
        persistence.insert(b)
        persistence.insert(c)
        try persistence.save()

        HabitDeletionAction.perform(
            habit: b,
            modelContext: persistence.context
        )

        let remainingHabits = try fetchOrderedHabits(in: persistence.context)
        XCTAssertEqual(remainingHabits.map(\.name), ["A", "C"])

        let cStored = try XCTUnwrap(remainingHabits.first(where: { $0.name == "C" }))
        XCTAssertNil(cStored.triggerHabitID)
    }

    func testCancelingDeletionDoesNotDeleteHabit() throws {
        let persistence = try TestPersistence()
        let habit = makeHabit(name: "Keep", orderIndex: 0)
        persistence.insert(habit)
        try persistence.save()

        var pendingHabit: Habit? = habit
        let isPresented = HabitDeletionConfirmationState.isPresentedBinding(
            for: Binding(
                get: { pendingHabit },
                set: { pendingHabit = $0 }
            )
        )

        isPresented.wrappedValue = false

        let remainingHabits = try fetchOrderedHabits(in: persistence.context)

        XCTAssertNil(pendingHabit)
        XCTAssertEqual(remainingHabits.map(\.name), ["Keep"])
    }

    func testDeleteConfirmationMessageUsesCorrectHabitName() {
        let habit = makeHabit(name: "Read 20 Pages", orderIndex: 0)

        let message = HabitDeletionConfirmationState.message(for: habit)

        XCTAssertEqual(
            message,
            "This will permanently delete \"Read 20 Pages\" and its history."
        )
    }

    private func makeHabit(
        name: String,
        colorHex: String = "#1F7A8C",
        orderIndex: Int
    ) -> Habit {
        Habit(
            name: name,
            colorHex: colorHex,
            orderIndex: orderIndex
        )
    }

    private func fetchOrderedHabits(in context: ModelContext) throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.orderIndex)])
        return try context.fetch(descriptor)
    }
}
