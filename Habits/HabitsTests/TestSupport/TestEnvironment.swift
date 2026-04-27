import Foundation
import SwiftData
@testable import Habits

@MainActor
final class TestEnvironment {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    let habitUIStateStore: HabitUIStateStore
    let habitLogService: HabitLogService
    let timeOfDayPerformanceService: TimeOfDayPerformanceService
    let graphRecomputeCoordinator: GraphRecomputeCoordinator
    let habitLogPersistenceCoordinator: HabitLogPersistenceCoordinator
    let habitLogSideEffectCoordinator: HabitLogSideEffectCoordinator

    private var trackedTasks: [Task<Void, Never>] = []

    init(calendar: Calendar = TestDateFactory.utcCalendar) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Habit.self,
            HabitReminder.self,
            HabitLog.self,
            configurations: configuration
        )
        modelContext = ModelContext(modelContainer)

        let uiStateStore = HabitUIStateStore()
        let timeService = TimeOfDayPerformanceService()
        let graphCoordinator = GraphRecomputeCoordinator()

        TestIsolationRegistry.timeOfDayPerformanceService = timeService
        TestIsolationRegistry.graphRecomputeCoordinator = graphCoordinator
        TestIsolationRegistry.todayInsightSelectionService = TodayInsightSelectionService()

        let service = HabitLogService(
            modelContext: modelContext,
            calendar: calendar,
            uiStateStore: uiStateStore
        )
        habitUIStateStore = uiStateStore
        timeOfDayPerformanceService = timeService
        graphRecomputeCoordinator = graphCoordinator
        habitLogService = service
        habitLogPersistenceCoordinator = service.persistenceCoordinatorForTesting
        habitLogSideEffectCoordinator = service.sideEffectCoordinatorForTesting
    }

    @discardableResult
    func track(_ task: Task<Void, Never>) -> Task<Void, Never> {
        trackedTasks.append(task)
        return task
    }

    func tearDown() async {
        for task in trackedTasks {
            task.cancel()
        }
        trackedTasks.removeAll()

        habitLogService.shutdownForTesting()
        await habitLogPersistenceCoordinator.cancelAllForTesting()
        await habitLogSideEffectCoordinator.cancelAllForTesting()
        await HabitLogService.shutdownAllForTesting()

        habitUIStateStore.resetForTesting()
        timeOfDayPerformanceService.resetForTesting()

        graphRecomputeCoordinator.resetForTesting()
        TodayInsightSelectionService.shared.reset()
        resetWidgetSyncSchedulerForTesting()
    }

    static func resetAll() async {
        await HabitLogService.shutdownAllForTesting()
        TimeOfDayPerformanceService.shared.resetForTesting()
        WidgetDataStore.shared.clearForTesting()
        GraphRecomputeCoordinator.shared.resetForTesting()
        TodayInsightSelectionService.shared.reset()
        resetWidgetSyncSchedulerForTesting()
        TestIsolationRegistry.reset()
    }
}
