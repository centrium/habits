import Foundation

@MainActor
final class GraphRecomputeCoordinator {
    static let shared = GraphRecomputeCoordinator()

    private var task: Task<Void, Never>?
    private var isRunning = false
    private var lastScheduledVersionByHabitID: [UUID: Int] = [:]
    private var lastExecutedVersionByHabitID: [UUID: Int] = [:]
    private var observers: [UUID: @MainActor () -> Void] = [:]

    private init() {}

    func register(id: UUID, observer: @escaping @MainActor () -> Void) {
        observers[id] = observer
    }

    func unregister(id: UUID) {
        observers.removeValue(forKey: id)
    }

    func schedule(for habitID: UUID, version: Int) {
        if version == lastScheduledVersionByHabitID[habitID] || version == lastExecutedVersionByHabitID[habitID] {
            return
        }

        lastScheduledVersionByHabitID[habitID] = version

        task?.cancel()
        print("GRAPH: scheduled at \(Date())")

        task = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            await execute(habitID: habitID, version: version)
        }
    }

    private func execute(habitID: UUID, version: Int) async {
        guard !isRunning else { return }
        isRunning = true
        print("GRAPH: executed at \(Date())")

        defer { isRunning = false }

        let callbacks = Array(observers.values)
        for callback in callbacks {
            await MainActor.run {
                callback()
            }
        }

        lastExecutedVersionByHabitID[habitID] = version
        print("GRAPH: recompute at \(Date())")
    }
}
