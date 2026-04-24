import Foundation

enum LoggingPerformanceMonitor {
    private static var tapStartByTraceID: [UUID: Date] = [:]
    private static let lock = NSLock()

    static func markTapStart(traceID: UUID, habitID: UUID) {
        #if DEBUG
        lock.lock()
        tapStartByTraceID[traceID] = Date()
        lock.unlock()
        print("PERF: tap-start trace=\(traceID.uuidString) habit=\(habitID.uuidString)")
        #endif
    }

    static func markOptimisticApplied(traceID: UUID, habitID: UUID) {
        #if DEBUG
        let elapsedMs = consumeElapsedMilliseconds(for: traceID)
        if let elapsedMs {
            print(String(format: "PERF: optimistic-applied trace=%@ habit=%@ in %.1fms",
                         traceID.uuidString,
                         habitID.uuidString,
                         elapsedMs))
        } else {
            print("PERF: optimistic-applied trace=\(traceID.uuidString) habit=\(habitID.uuidString)")
        }
        #endif
    }

    static func markPersistCommitted(habitID: UUID, referenceDate: Date) {
        #if DEBUG
        print("PERF: persist-committed habit=\(habitID.uuidString) day=\(referenceDate.timeIntervalSince1970)")
        #endif
    }

    static func markGraphUpdated(habitID: UUID) {
        #if DEBUG
        print("PERF: graph-updated habit=\(habitID.uuidString)")
        #endif
    }

    static func assertHeavyPathOffMainThread(_ path: StaticString) {
        #if DEBUG
        guard Thread.isMainThread else { return }
        let message = "Heavy path running on main thread: \(path)"
        if ProcessInfo.processInfo.environment["STRICT_HEAVY_PATH_ASSERTS"] == "1" {
            assertionFailure(message)
        } else {
            print("PERF WARNING: \(message)")
            print(Thread.callStackSymbols.joined(separator: "\n"))
        }
        #endif
    }

    private static func consumeElapsedMilliseconds(for traceID: UUID) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard let startedAt = tapStartByTraceID.removeValue(forKey: traceID) else { return nil }
        return Date().timeIntervalSince(startedAt) * 1000
    }
}
