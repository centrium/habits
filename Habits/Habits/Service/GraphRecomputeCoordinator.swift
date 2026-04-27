import Foundation

@MainActor
enum TestIsolationRegistry {
    static var timeOfDayPerformanceService: TimeOfDayPerformanceService?
    static var graphRecomputeCoordinator: GraphRecomputeCoordinator?
    static var todayInsightSelectionService: TodayInsightSelectionService?

    static func reset() {
        timeOfDayPerformanceService = nil
        graphRecomputeCoordinator = nil
        todayInsightSelectionService = nil
    }
}

@MainActor
final class GraphRecomputeCoordinator {
    private static let defaultShared = GraphRecomputeCoordinator()
    static var shared: GraphRecomputeCoordinator {
        TestIsolationRegistry.graphRecomputeCoordinator ?? defaultShared
    }

    private struct Observer {
        let habitID: UUID
        let callback: @MainActor () -> Void
    }

    private var taskByHabitID: [UUID: Task<Void, Never>] = [:]
    private var isRunningByHabitID: [UUID: Bool] = [:]
    private var lastScheduledVersionByHabitID: [UUID: Int] = [:]
    private var lastExecutedVersionByHabitID: [UUID: Int] = [:]
    private var observers: [UUID: Observer] = [:]
    private var traceEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["GRAPH_RECOMPUTE_DEBUG"]?.lowercased() == "1"
        #else
        false
        #endif
    }

    init() {}

    func register(
        id: UUID,
        habitID: UUID,
        observer: @escaping @MainActor () -> Void
    ) {
        observers[id] = Observer(habitID: habitID, callback: observer)
    }

    func unregister(id: UUID) {
        observers.removeValue(forKey: id)
    }

    func schedule(for habitID: UUID, version: Int) {
        if version == lastScheduledVersionByHabitID[habitID] || version == lastExecutedVersionByHabitID[habitID] {
            return
        }

        lastScheduledVersionByHabitID[habitID] = version

        taskByHabitID[habitID]?.cancel()
        if traceEnabled {
            print("GRAPH: scheduled at \(Date())")
        }

        let task = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            await execute(habitID: habitID, version: version)
        }
        taskByHabitID[habitID] = task
    }

    private func execute(habitID: UUID, version: Int) async {
        if isRunningByHabitID[habitID] == true { return }
        isRunningByHabitID[habitID] = true
        if traceEnabled {
            print("GRAPH: executed at \(Date())")
        }

        defer { isRunningByHabitID[habitID] = false }

        let callbacks = observers.values
            .filter { $0.habitID == habitID }
            .map(\.callback)
        for callback in callbacks {
            await MainActor.run {
                callback()
            }
        }

        lastExecutedVersionByHabitID[habitID] = version
        if traceEnabled {
            print("GRAPH: recompute at \(Date())")
        }
    }

    func resetForTesting() {
        for task in taskByHabitID.values {
            task.cancel()
        }
        taskByHabitID.removeAll()
        isRunningByHabitID.removeAll()
        lastScheduledVersionByHabitID.removeAll()
        lastExecutedVersionByHabitID.removeAll()
        observers.removeAll()
    }
}
