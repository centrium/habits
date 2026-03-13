import XCTest
import SwiftData
@testable import Habits

final class HabitOrderingTests: XCTestCase {
    func testHabitReorderingUpdatesIndexes() throws {
        let persistence = try TestPersistence()

        let a = makeHabit(name: "A", orderIndex: 0)
        let b = makeHabit(name: "B", orderIndex: 1)
        let c = makeHabit(name: "C", orderIndex: 2)

        persistence.insert(a)
        persistence.insert(b)
        persistence.insert(c)
        try persistence.save()

        let ordered = try fetchOrderedHabits(in: persistence.context)
        try moveHabits(in: persistence.context, habits: ordered, from: IndexSet(integer: 2), to: 0)

        let reordered = try fetchOrderedHabits(in: persistence.context)

        XCTAssertEqual(reordered.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(indexMap(for: reordered)["C"], 0)
        XCTAssertEqual(indexMap(for: reordered)["A"], 1)
        XCTAssertEqual(indexMap(for: reordered)["B"], 2)
    }

    func testDeletingHabitReindexesCorrectly() throws {
        let persistence = try TestPersistence()

        let a = makeHabit(name: "A", orderIndex: 0)
        let b = makeHabit(name: "B", orderIndex: 1)
        let c = makeHabit(name: "C", orderIndex: 2)

        persistence.insert(a)
        persistence.insert(b)
        persistence.insert(c)
        try persistence.save()

        persistence.context.delete(b)
        try persistence.save()

        try normalizeOrderIndexes(in: persistence.context)
        let reordered = try fetchOrderedHabits(in: persistence.context)

        XCTAssertEqual(reordered.map(\.name), ["A", "C"])
        XCTAssertEqual(indexMap(for: reordered)["A"], 0)
        XCTAssertEqual(indexMap(for: reordered)["C"], 1)
    }

    func testNewHabitAppendsToEnd() throws {
        let persistence = try TestPersistence()

        let a = makeHabit(name: "A", orderIndex: 0)
        let b = makeHabit(name: "B", orderIndex: 1)
        persistence.insert(a)
        persistence.insert(b)
        try persistence.save()

        let currentCount = try fetchOrderedHabits(in: persistence.context).count
        let c = makeHabit(name: "C", orderIndex: currentCount)
        persistence.insert(c)
        try persistence.save()

        let ordered = try fetchOrderedHabits(in: persistence.context)

        XCTAssertEqual(ordered.map(\.name), ["A", "B", "C"])
        XCTAssertEqual(indexMap(for: ordered)["A"], 0)
        XCTAssertEqual(indexMap(for: ordered)["B"], 1)
        XCTAssertEqual(indexMap(for: ordered)["C"], 2)
    }

    func testMultipleMovesRemainStable() throws {
        let persistence = try TestPersistence()

        let a = makeHabit(name: "A", orderIndex: 0)
        let b = makeHabit(name: "B", orderIndex: 1)
        let c = makeHabit(name: "C", orderIndex: 2)
        let d = makeHabit(name: "D", orderIndex: 3)

        persistence.insert(a)
        persistence.insert(b)
        persistence.insert(c)
        persistence.insert(d)
        try persistence.save()

        var ordered = try fetchOrderedHabits(in: persistence.context)
        try moveHabits(in: persistence.context, habits: ordered, from: IndexSet(integer: 3), to: 0)

        ordered = try fetchOrderedHabits(in: persistence.context)
        let bIndex = try XCTUnwrap(ordered.firstIndex(where: { $0.name == "B" }))
        try moveHabits(in: persistence.context, habits: ordered, from: IndexSet(integer: bIndex), to: ordered.count)

        let finalOrdered = try fetchOrderedHabits(in: persistence.context)

        XCTAssertEqual(finalOrdered.map(\.name), ["D", "A", "C", "B"])
        XCTAssertEqual(finalOrdered.map(\.orderIndex), Array(0..<finalOrdered.count))
    }

    private func makeHabit(name: String, orderIndex: Int) -> Habit {
        Habit(
            name: name,
            colorHex: "#1F7A8C",
            orderIndex: orderIndex
        )
    }

    private func fetchOrderedHabits(in context: ModelContext) throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.orderIndex)])
        return try context.fetch(descriptor)
    }

    private func moveHabits(
        in context: ModelContext,
        habits: [Habit],
        from source: IndexSet,
        to destination: Int
    ) throws {
        var reordered = habits
        let moving = source.sorted().map { reordered[$0] }
        for index in source.sorted(by: >) {
            reordered.remove(at: index)
        }

        var insertionIndex = destination
        for index in source where index < destination {
            insertionIndex -= 1
        }

        reordered.insert(contentsOf: moving, at: insertionIndex)

        for (index, habit) in reordered.enumerated() {
            habit.orderIndex = index
        }

        try context.save()
    }

    private func normalizeOrderIndexes(in context: ModelContext) throws {
        let ordered = try fetchOrderedHabits(in: context)
        for (index, habit) in ordered.enumerated() {
            habit.orderIndex = index
        }
        try context.save()
    }

    private func indexMap(for habits: [Habit]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: habits.map { ($0.name, $0.orderIndex) })
    }
}
