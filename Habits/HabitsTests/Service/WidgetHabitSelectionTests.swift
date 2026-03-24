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
