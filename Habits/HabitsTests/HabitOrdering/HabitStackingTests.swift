import XCTest
@testable import Habits

final class HabitStackingTests: BaseTestCase {
    func testCanAssignTriggerRejectsCycleAcrossMultipleLevels() {
        let a = TestHabitFactory.frequency(name: "A")
        let b = TestHabitFactory.frequency(name: "B", triggerHabitID: a.id)
        let c = TestHabitFactory.frequency(name: "C", triggerHabitID: b.id)
        let habits = [a, b, c]

        let canAssign = HabitStackingRules.canAssignTrigger(
            childID: a.id,
            childGoalType: .frequency,
            triggerID: c.id,
            habits: habits,
            parentOverrideByChildID: [a.id: c.id]
        )

        XCTAssertFalse(canAssign)
    }

    func testCanAssignTriggerAllowsAcyclicChain() {
        let a = TestHabitFactory.frequency(name: "A")
        let b = TestHabitFactory.frequency(name: "B", triggerHabitID: a.id)
        let c = TestHabitFactory.frequency(name: "C", triggerHabitID: b.id)
        let d = TestHabitFactory.frequency(name: "D")
        let habits = [a, b, c, d]

        let canAssign = HabitStackingRules.canAssignTrigger(
            childID: d.id,
            childGoalType: .frequency,
            triggerID: c.id,
            habits: habits,
            parentOverrideByChildID: [d.id: c.id]
        )

        XCTAssertTrue(canAssign)
    }

    func testOrderingDefersChildrenUntilParentThenCascadesChain() {
        let a = makeHabit(name: "A", orderIndex: 2)
        let b = makeHabit(name: "B", orderIndex: 0)
        let c = makeHabit(name: "C", orderIndex: 1)
        let d = makeHabit(name: "D", orderIndex: 3)

        b.triggerHabitID = a.id
        c.triggerHabitID = b.id
        d.triggerHabitID = c.id

        let base = [b, c, a, d].sorted { $0.orderIndex < $1.orderIndex }
        let snapshot = HabitStackingOrder.resolve(baseHabits: base)

        XCTAssertEqual(snapshot.displayHabits.map(\.name), ["A", "B", "C", "D"])
        XCTAssertEqual(snapshot.todayItems.count, 1)
        if case .stack(let stack) = snapshot.todayItems[0] {
            XCTAssertEqual(stack.orderedHabits.map(\.title), ["A", "B", "C", "D"])
        } else {
            XCTFail("Expected a stack item")
        }
    }

    func testOrderingGroupsNonAdjacentChainIntoSingleStackAndStandaloneItem() {
        let a = makeHabit(name: "A", orderIndex: 4)
        let b = makeHabit(name: "B", orderIndex: 0)
        let c = makeHabit(name: "C", orderIndex: 2)
        let d = makeHabit(name: "D", orderIndex: 1)
        let e = makeHabit(name: "E", orderIndex: 3)

        b.triggerHabitID = a.id
        c.triggerHabitID = b.id
        e.triggerHabitID = c.id

        let base = [b, d, c, e, a].sorted { $0.orderIndex < $1.orderIndex }
        let snapshot = HabitStackingOrder.resolve(baseHabits: base)

        XCTAssertEqual(snapshot.displayHabits.map(\.name), ["D", "A", "B", "C", "E"])
        XCTAssertEqual(snapshot.todayItems.count, 2)
        XCTAssertEqual(snapshot.stackColorHexByHabitID[e.id], a.colorHex)
    }

    private func makeHabit(name: String, orderIndex: Int) -> Habit {
        Habit(
            name: name,
            colorHex: "#1F7A8C",
            orderIndex: orderIndex
        )
    }
}
