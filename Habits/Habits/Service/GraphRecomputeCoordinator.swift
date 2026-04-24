import Foundation

@MainActor
final class GraphRecomputeCoordinator {
    static let shared = GraphRecomputeCoordinator()

    private struct Observer {
        let habitID: UUID
        let callback: @MainActor () -> Void
    }

    private var taskByHabitID: [UUID: Task<Void, Never>] = [:]
    private var isRunningByHabitID: [UUID: Bool] = [:]
    private var lastScheduledVersionByHabitID: [UUID: Int] = [:]
    private var lastExecutedVersionByHabitID: [UUID: Int] = [:]
    private var observers: [UUID: Observer] = [:]

    private init() {}

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
        print("GRAPH: scheduled at \(Date())")

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
        print("GRAPH: executed at \(Date())")

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
        print("GRAPH: recompute at \(Date())")
    }
}
