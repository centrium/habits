import XCTest
@testable import Habits

final class WidgetHabitSelectionTests: XCTestCase {
    func testSelectTopWidgetHabitsPrioritizesAttentionBuckets() {
        let completed = makeHabit(
            name: "Completed",
            goalType: .goal,
            isCompleteToday: true,
            streak: 10,
            progress: 1
        )
        let openEndedNoActivity = makeHabit(
            name: "Journal",
            goalType: .openEnded,
            streak: 2,
            hasActivityToday: false
        )
        let binaryIncomplete = makeHabit(
            name: "Walk",
            goalType: .binary,
            streak: 8
        )
        let partialGoal = makeHabit(
            name: "Read",
            goalType: .goal,
            streak: 3,
            progress: 0.6
        )

        let selected = selectTopWidgetHabits([
            completed,
            openEndedNoActivity,
            binaryIncomplete,
            partialGoal,
        ])

        XCTAssertEqual(selected.map { $0.name }, ["Read", "Walk", "Journal"])
    }

    func testSelectTopWidgetHabitsSortsPartialGoalHabitsByHighestProgressFirst() {
        let highestProgress = makeHabit(name: "A", goalType: .goal, streak: 1, progress: 0.85)
        let mediumProgress = makeHabit(name: "B", goalType: .goal, streak: 5, progress: 0.5)
        let lowProgress = makeHabit(name: "C", goalType: .goal, streak: 10, progress: 0.2)

        let selected = selectTopWidgetHabits([
            mediumProgress,
            lowProgress,
            highestProgress,
        ])

        XCTAssertEqual(selected.map { $0.name }, ["A", "B", "C"])
    }

    func testSelectTopWidgetHabitsUsesCompletedHabitsOnlyWhenNeeded() {
        let incomplete = makeHabit(name: "Walk", goalType: .binary, streak: 4)
        let completedHighStreak = makeHabit(
            name: "Meditate",
            goalType: .goal,
            isCompleteToday: true,
            streak: 9,
            progress: 1
        )
        let completedLowStreak = makeHabit(
            name: "Stretch",
            goalType: .goal,
            isCompleteToday: true,
            streak: 2,
            progress: 1
        )

        let selected = selectTopWidgetHabits([
            completedLowStreak,
            incomplete,
            completedHighStreak,
        ])

        XCTAssertEqual(selected.map { $0.name }, ["Walk", "Meditate", "Stretch"])
    }

    func testGoalHabitInitializerNormalizesNilProgressToZero() {
        let habit = makeHabit(name: "Read", goalType: .goal, progress: nil)

        XCTAssertEqual(habit.progress, 0)
        XCTAssertEqual(habit.goalProgress, 0)
    }

    func testSelectFocusWidgetHabitPrioritizesHighestStreakWithoutActivityToday() {
        let lowStreak = makeHabit(name: "Journal", goalType: .openEnded, streak: 2, hasActivityToday: false)
        let highStreak = makeHabit(name: "Read", goalType: .binary, streak: 8, hasActivityToday: false)
        let inProgress = makeHabit(name: "Hydrate", goalType: .goal, streak: 6, progress: 0.4, hasActivityToday: true)

        let selected = selectFocusWidgetHabit([lowStreak, inProgress, highStreak])

        XCTAssertEqual(selected?.name, "Read")
    }

    func testSelectFocusWidgetHabitFallsBackToFirstIncompleteHabit() {
        let completed = makeHabit(name: "Stretch", goalType: .binary, isCompleteToday: true, hasActivityToday: true)
        let incompleteGoal = makeHabit(name: "Walk", goalType: .goal, progress: 0, hasActivityToday: false)
        let incompleteBinary = makeHabit(name: "Meditate", goalType: .binary, hasActivityToday: false)

        let selected = selectFocusWidgetHabit([completed, incompleteGoal, incompleteBinary])

        XCTAssertEqual(selected?.name, "Walk")
    }

    func testSelectFocusWidgetHabitReturnsNilWhenAllAreComplete() {
        let firstCompleted = makeHabit(name: "Read", goalType: .goal, isCompleteToday: true, progress: 1, hasActivityToday: true)
        let secondCompleted = makeHabit(name: "Walk", goalType: .binary, isCompleteToday: true, hasActivityToday: true)

        let selected = selectFocusWidgetHabit([firstCompleted, secondCompleted])

        XCTAssertNil(selected)
    }

    func testResolveFocusWidgetStateReturnsNoHabitsForEmptyList() {
        let state = resolveFocusWidgetState([])

        guard case .noHabits = state else {
            return XCTFail("Expected no habits state")
        }
    }

    func testResolveFocusWidgetStateReturnsAllCompleteWhenAllHabitsHaveActivityToday() {
        let completedGoal = makeHabit(name: "Read", goalType: .goal, isCompleteToday: false, progress: 0.5, hasActivityToday: true)
        let completedBinary = makeHabit(name: "Walk", goalType: .binary, isCompleteToday: true, hasActivityToday: true)

        let state = resolveFocusWidgetState([completedGoal, completedBinary])

        guard case .allComplete(let primaryHabit, let completedCount) = state else {
            return XCTFail("Expected all complete state")
        }

        XCTAssertEqual(primaryHabit.name, "Read")
        XCTAssertEqual(completedCount, 2)
        XCTAssertEqual(state.titleText, "All done")
        XCTAssertEqual(state.subtitleText, "2 completed today")
    }

    func testResolveFocusWidgetStateReturnsNeedsAttentionForIncompleteHabit() {
        let completed = makeHabit(name: "Walk", goalType: .binary, isCompleteToday: true, hasActivityToday: true)
        let incomplete = makeHabit(name: "Read", goalType: .goal, streak: 4, progress: 0, hasActivityToday: false)

        let state = resolveFocusWidgetState([completed, incomplete])

        guard case .needsAttention(let habit) = state else {
            return XCTFail("Expected needs attention state")
        }

        XCTAssertEqual(habit.name, "Read")
        XCTAssertEqual(state.titleText, "Read")
        XCTAssertEqual(state.subtitleText, "Keep 4-day streak")
    }

    func testResolveFocusWidgetStateUsesStartCopyForZeroStreakHabit() {
        let incomplete = makeHabit(name: "Write", goalType: .binary, streak: 0, hasActivityToday: false)

        let state = resolveFocusWidgetState([incomplete])

        guard case .needsAttention(let habit) = state else {
            return XCTFail("Expected needs attention state")
        }

        XCTAssertEqual(habit.name, "Write")
        XCTAssertEqual(state.subtitleText, "Log today")
    }

    private func makeHabit(
        name: String,
        goalType: WidgetGoalType,
        isCompleteToday: Bool = false,
        streak: Int = 0,
        progress: Double? = nil,
        hasActivityToday: Bool? = nil
    ) -> WidgetHabit {
        let resolvedHasActivity: Bool = {
            if let hasActivityToday {
                return hasActivityToday
            }

            switch goalType {
            case .goal:
                return (progress ?? 0) > 0
            case .binary:
                return isCompleteToday
            case .openEnded:
                return false
            }
        }()

        return WidgetHabit(
            id: UUID(),
            name: name,
            isCompleteToday: isCompleteToday,
            streak: streak,
            goalType: goalType,
            progress: progress,
            hasActivityToday: resolvedHasActivity,
            iconName: nil,
            colorHex: nil
        )
    }
}
