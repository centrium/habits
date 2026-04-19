import Foundation

@MainActor
final class GraphRecomputeCoordinator {
    static let shared = GraphRecomputeCoordinator()

    private var task: Task<Void, Never>?
    private var isRunning = false
    private var lastScheduledVersion: UUID?
    private var lastExecutedVersion: UUID?
    private var observers: [UUID: @MainActor () -> Void] = [:]

    private init() {}

    func register(id: UUID, observer: @escaping @MainActor () -> Void) {
        observers[id] = observer
    }

    func unregister(id: UUID) {
        observers.removeValue(forKey: id)
    }

    func schedule(for version: UUID) {
        if version == lastScheduledVersion || version == lastExecutedVersion {
            return
        }

        lastScheduledVersion = version

        task?.cancel()
        print("GRAPH: scheduled at \(Date())")

        task = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            await execute(version: version)
        }
    }

    private func execute(version: UUID) async {
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

        lastExecutedVersion = version
        print("GRAPH: recompute at \(Date())")
    }
}
