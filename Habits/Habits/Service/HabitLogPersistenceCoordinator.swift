import Foundation
import SwiftData

struct HabitLogWritePayload: Sendable {
    let mutation: HabitLogPendingMutation
    let entryTimestamp: Date
    let referenceDate: Date
}

enum HabitLogPersistenceEvent: Sendable {
    case writing(HabitLogPendingMutation)
    case committed(HabitLogPendingMutation, Date)
    case failed(HabitLogPendingMutation, String)
}

actor HabitLogPersistenceCoordinator {
    typealias Completion = @Sendable (HabitLogPersistenceEvent) async -> Void

    private let modelContainer: ModelContainer
    private let completion: Completion
    private let maxAttempts: Int
    private var queueByHabitID: [UUID: [HabitLogWritePayload]] = [:]
    private var workerByHabitID: [UUID: Task<Void, Never>] = [:]

    init(
        modelContainer: ModelContainer,
        maxAttempts: Int = 3,
        completion: @escaping Completion
    ) {
        self.modelContainer = modelContainer
        self.maxAttempts = maxAttempts
        self.completion = completion
    }

    func enqueue(_ payload: HabitLogWritePayload) {
        let habitID = payload.mutation.id.habitID
        queueByHabitID[habitID, default: []].append(payload)
        guard workerByHabitID[habitID] == nil else { return }
        startWorker(for: habitID)
    }

    private func startWorker(for habitID: UUID) {
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runWorker(for: habitID)
        }
        workerByHabitID[habitID] = task
    }

    private func runWorker(for habitID: UUID) async {
        defer { workerByHabitID.removeValue(forKey: habitID) }

        while !Task.isCancelled {
            guard var queue = queueByHabitID[habitID], let payload = queue.first else {
                queueByHabitID.removeValue(forKey: habitID)
                return
            }

            await completion(.writing(payload.mutation))
            let outcome = await persist(payload)
            switch outcome {
            case .committed:
                queue.removeFirst()
                queueByHabitID[habitID] = queue
                await completion(.committed(payload.mutation, payload.referenceDate))
            case .failed:
                queue.removeFirst()
                queueByHabitID[habitID] = queue
                await completion(.failed(payload.mutation, outcome.errorDescription))
            }
        }
    }

    private func persist(_ payload: HabitLogWritePayload) async -> PersistOutcome {
        var lastError = "Unknown persistence error"

        for attempt in 1...maxAttempts {
            do {
                let didCommit = try writePayload(payload)
                if didCommit {
                    return .committed
                }
                return .failed("Habit not found during persistence")
            } catch {
                lastError = error.localizedDescription
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }
        }

        return .failed(lastError)
    }

    private func writePayload(_ payload: HabitLogWritePayload) throws -> Bool {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Habit>()
        guard let habit = try context.fetch(descriptor).first(where: { $0.id == payload.mutation.id.habitID }) else {
            return false
        }

        switch payload.mutation.operation {
        case .addLog:
            if !habit.logs.contains(where: { $0.id == payload.mutation.id.nonce }) {
                let log = HabitLog(
                    timestamp: payload.entryTimestamp,
                    value: payload.mutation.valueDelta,
                    createdAt: payload.mutation.createdAt
                )
                log.id = payload.mutation.id.nonce
                log.day = payload.mutation.id.dayStart
                habit.logs.append(log)
            }
        case .clearDay:
            habit.logs.removeAll { $0.day == payload.mutation.id.dayStart }
        case let .setDayCount(newCount):
            habit.logs.removeAll { $0.day == payload.mutation.id.dayStart }
            for offset in 0..<max(0, newCount) {
                let timestamp = payload.mutation.id.dayStart.addingTimeInterval(TimeInterval(offset))
                let logID = HabitLogMutationIdentity.deterministicLogID(
                    baseNonce: payload.mutation.id.nonce,
                    index: offset
                )
                guard !habit.logs.contains(where: { $0.id == logID }) else { continue }
                let log = HabitLog(
                    timestamp: timestamp,
                    value: 1,
                    createdAt: payload.mutation.createdAt
                )
                log.id = logID
                log.day = payload.mutation.id.dayStart
                habit.logs.append(log)
            }
        case let .deleteEntry(logID):
            habit.logs.removeAll { $0.id == logID }
        case let .updateEntry(logID, value):
            let amount = max(0, value)
            guard let logIndex = habit.logs.firstIndex(where: { $0.id == logID }) else {
                break
            }

            if amount == 0 {
                habit.logs.remove(at: logIndex)
            } else if habit.logs[logIndex].kind == .entry {
                habit.logs[logIndex].value = amount
                habit.logs[logIndex].createdAt = payload.mutation.createdAt
            } else {
                let legacyLog = habit.logs.remove(at: logIndex)
                let timestamp = legacyLog.effectiveTimestamp
                habit.logs.append(
                    HabitLog(
                        timestamp: timestamp,
                        value: amount,
                        createdAt: payload.mutation.createdAt
                    )
                )
            }
        }

        try context.save()
        return true
    }

    func cancelAllForTesting() {
        for worker in workerByHabitID.values {
            worker.cancel()
        }
        workerByHabitID.removeAll()
        queueByHabitID.removeAll()
    }
}

private enum PersistOutcome: Sendable {
    case committed
    case failed(String)

    var errorDescription: String {
        switch self {
        case .committed:
            return ""
        case let .failed(message):
            return message
        }
    }
}
