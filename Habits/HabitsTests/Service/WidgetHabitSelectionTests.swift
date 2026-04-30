import XCTest
import SwiftData
@testable import Habits

@MainActor
final class WidgetHabitSelectionTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar
    private var referenceDate: Date { calendar.startOfDay(for: Date()) }

    func testSelectTopWidgetHabitsPrioritizesAttentionBuckets() {
        let completed = makeWidgetHabit(
            name: "Completed",
            goalType: .goal,
            isCompleteToday: true,
            streak: 10,
            progress: 1,
            hasActivityToday: true
        )
        let openEndedNoActivity = makeWidgetHabit(
            name: "Journal",
            goalType: .openEnded,
            streak: 2,
            hasActivityToday: false
        )
        let binaryIncomplete = makeWidgetHabit(
            name: "Walk",
            goalType: .binary,
            streak: 8,
            hasActivityToday: false
        )
        let partialGoal = makeWidgetHabit(
            name: "Read",
            goalType: .goal,
            streak: 3,
            progress: 0.6,
            hasActivityToday: true
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
        let highestProgress = makeWidgetHabit(
            name: "A",
            goalType: .goal,
            streak: 1,
            progress: 0.85,
            hasActivityToday: true
        )
        let mediumProgress = makeWidgetHabit(
            name: "B",
            goalType: .goal,
            streak: 5,
            progress: 0.5,
            hasActivityToday: true
        )
        let lowProgress = makeWidgetHabit(
            name: "C",
            goalType: .goal,
            streak: 10,
            progress: 0.2,
            hasActivityToday: true
        )

        let selected = selectTopWidgetHabits([
            mediumProgress,
            lowProgress,
            highestProgress,
        ])

        XCTAssertEqual(selected.map { $0.name }, ["A", "B", "C"])
    }

    func testSelectTopWidgetHabitsUsesCompletedHabitsOnlyWhenNeeded() {
        let incomplete = makeWidgetHabit(
            name: "Walk",
            goalType: .binary,
            streak: 4,
            hasActivityToday: false
        )
        let completedHighStreak = makeWidgetHabit(
            name: "Meditate",
            goalType: .goal,
            isCompleteToday: true,
            streak: 9,
            progress: 1,
            hasActivityToday: true
        )
        let completedLowStreak = makeWidgetHabit(
            name: "Stretch",
            goalType: .goal,
            isCompleteToday: true,
            streak: 2,
            progress: 1,
            hasActivityToday: true
        )

        let selected = selectTopWidgetHabits([
            completedLowStreak,
            incomplete,
            completedHighStreak,
        ])

        XCTAssertEqual(selected.map { $0.name }, ["Walk", "Meditate", "Stretch"])
    }

    func testGoalHabitInitializerNormalizesNilProgressToZero() async throws {
        let habit = try await makeHabit(name: "Read", goalType: .goal, progress: nil)

        XCTAssertEqual(habit.progress, 0)
        XCTAssertEqual(habit.goalProgress, 0)
    }

    func testSelectFocusWidgetHabitPrioritizesHighestStreakWithoutActivityToday() {
        let lowStreak = makeWidgetHabit(
            name: "Journal",
            goalType: .openEnded,
            streak: 2,
            hasActivityToday: false
        )
        let highStreak = makeWidgetHabit(
            name: "Read",
            goalType: .binary,
            streak: 8,
            hasActivityToday: false
        )
        let inProgress = makeWidgetHabit(
            name: "Hydrate",
            goalType: .goal,
            streak: 6,
            progress: 0.4,
            hasActivityToday: true
        )

        let selected = selectFocusWidgetHabit([lowStreak, inProgress, highStreak])

        XCTAssertEqual(selected?.name, "Read")
    }

    func testSelectFocusWidgetHabitFallsBackToFirstIncompleteHabit() async throws {
        let completed = try await makeHabit(name: "Stretch", goalType: .binary, isCompleteToday: true, hasActivityToday: true)
        let incompleteGoal = try await makeHabit(name: "Walk", goalType: .goal, progress: 0, hasActivityToday: false)
        let incompleteBinary = try await makeHabit(name: "Meditate", goalType: .binary, hasActivityToday: false)

        let selected = selectFocusWidgetHabit([completed, incompleteGoal, incompleteBinary])

        XCTAssertEqual(selected?.name, "Walk")
    }

    func testSelectFocusWidgetHabitReturnsNilWhenAllAreComplete() async throws {
        let firstCompleted = try await makeHabit(name: "Read", goalType: .goal, isCompleteToday: true, progress: 1, hasActivityToday: true)
        let secondCompleted = try await makeHabit(name: "Walk", goalType: .binary, isCompleteToday: true, hasActivityToday: true)

        let selected = selectFocusWidgetHabit([firstCompleted, secondCompleted])

        XCTAssertNil(selected)
    }

    func testResolveFocusWidgetStateReturnsNoHabitsForEmptyList() {
        let state = resolveFocusWidgetState([])

        guard case .noHabits = state else {
            return XCTFail("Expected no habits state")
        }
    }

    func testResolveFocusWidgetStateReturnsAllCompleteWhenAllHabitsHaveActivityToday() async throws {
        let completedGoal = try await makeHabit(name: "Read", goalType: .goal, isCompleteToday: false, progress: 0.5, hasActivityToday: true)
        let completedBinary = try await makeHabit(name: "Walk", goalType: .binary, isCompleteToday: true, hasActivityToday: true)

        let state = resolveFocusWidgetState([completedGoal, completedBinary])

        guard case .allComplete(let primaryHabit, let completedCount) = state else {
            return XCTFail("Expected all complete state")
        }

        XCTAssertEqual(primaryHabit.name, "Read")
        XCTAssertEqual(completedCount, 2)
        XCTAssertEqual(state.titleText, "All done")
        XCTAssertEqual(state.subtitleText, "2 done today")
    }

    func testResolveFocusWidgetStateReturnsNeedsAttentionForIncompleteHabit() async throws {
        let completed = try await makeHabit(name: "Walk", goalType: .binary, isCompleteToday: true, hasActivityToday: true)
        let incomplete = try await makeHabit(name: "Read", goalType: .goal, streak: 4, progress: 0, hasActivityToday: false)

        let state = resolveFocusWidgetState([completed, incomplete])

        guard case .needsAttention(let habit) = state else {
            return XCTFail("Expected needs attention state")
        }

        XCTAssertEqual(habit.name, "Read")
        XCTAssertEqual(state.titleText, "Read")
        XCTAssertEqual(state.subtitleText, "Keep 4-day streak")
    }

    func testResolveFocusWidgetStateUsesStartCopyForZeroStreakHabit() async throws {
        let incomplete = try await makeHabit(name: "Write", goalType: .binary, streak: 0, hasActivityToday: false)

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
    ) async throws -> WidgetHabit {
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
        let persistence = try TestPersistence()
        let habit: Habit = {
            switch goalType {
            case .binary:
                return TestHabitFactory.frequency(name: name, target: 1, calendar: calendar)
            case .goal:
                return TestHabitFactory.cumulative(name: name, target: 100, calendar: calendar)
            case .openEnded:
                return TestHabitFactory.openEnded(name: name, calendar: calendar)
            }
        }()
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        let targetStreak = max(streak, 0)
        let priorCompletionDays = max(targetStreak - (resolvedHasActivity ? 1 : 0), 0)
        for dayOffset in stride(from: priorCompletionDays, to: 0, by: -1) {
            let day = TestDateFactory.addingDays(-dayOffset, to: referenceDate, calendar: calendar)
            _ = service.addLog(for: habit, on: day, value: completedValue(for: goalType, isCompleteToday: true, progress: 1))
        }

        if resolvedHasActivity {
            let todayProgress: Double = {
                if let progress { return progress }
                return isCompleteToday ? 1 : (goalType == .goal ? 0.5 : 1)
            }()
            _ = service.addLog(
                for: habit,
                on: referenceDate,
                value: completedValue(for: goalType, isCompleteToday: isCompleteToday, progress: todayProgress)
            )
        }

        try await waitForReconciliation(uiStateStore: uiStateStore, habitID: habit.id)

        let descriptor = FetchDescriptor<Habit>()
        let readContext = ModelContext(persistence.container)
        let persistedHabits = try readContext.fetch(descriptor)
        guard let persistedHabit = persistedHabits.first(where: { $0.id == habit.id }) else {
            XCTFail("Expected persisted habit")
            return WidgetHabit(
                id: UUID(),
                name: name,
                isCompleteToday: false,
                streak: 0,
                goalType: goalType,
                progress: progress,
                hasActivityToday: resolvedHasActivity,
                iconName: nil,
                colorHex: nil
            )
        }

        let widgetHabit = mapToWidgetHabits(
            [persistedHabit],
            referenceDate: referenceDate,
            calendar: calendar,
            weekStartPreference: .monday
        ).first

        return try XCTUnwrap(widgetHabit)
    }

    private func makeWidgetHabit(
        name: String,
        goalType: WidgetGoalType,
        isCompleteToday: Bool = false,
        streak: Int = 0,
        progress: Double? = nil,
        hasActivityToday: Bool = false
    ) -> WidgetHabit {
        WidgetHabit(
            id: UUID(),
            name: name,
            isCompleteToday: isCompleteToday,
            streak: streak,
            goalType: goalType,
            progress: progress,
            hasActivityToday: hasActivityToday,
            iconName: nil,
            colorHex: nil
        )
    }

    private func completedValue(
        for goalType: WidgetGoalType,
        isCompleteToday: Bool,
        progress: Double
    ) -> Double {
        switch goalType {
        case .binary, .openEnded:
            return 1
        case .goal:
            if isCompleteToday {
                return 100
            }
            return max(0, min(progress, 1)) * 100
        }
    }

    private func waitForReconciliation(
        uiStateStore: HabitUIStateStore,
        habitID: UUID,
        timeout: TimeInterval = 4
    ) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if uiStateStore.pendingMutations(for: habitID).isEmpty {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for pending mutations to reconcile")
    }
}
