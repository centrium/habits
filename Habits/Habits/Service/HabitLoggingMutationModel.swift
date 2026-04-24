import Foundation

struct HabitLogDayKey: Hashable, Codable, Sendable {
    let habitID: UUID
    let dayStart: Date

    init(habitID: UUID, dayStart: Date) {
        self.habitID = habitID
        self.dayStart = dayStart
    }

    static func make(
        habitID: UUID,
        day: Date,
        calendar: Calendar
    ) -> HabitLogDayKey {
        HabitLogDayKey(
            habitID: habitID,
            dayStart: calendar.startOfDay(for: day)
        )
    }
}

struct HabitLogMutationID: Hashable, Codable, Sendable, CustomStringConvertible {
    let habitID: UUID
    let dayStart: Date
    let sequence: UInt64
    let nonce: UUID

    init(habitID: UUID, dayStart: Date, sequence: UInt64, nonce: UUID = UUID()) {
        self.habitID = habitID
        self.dayStart = dayStart
        self.sequence = sequence
        self.nonce = nonce
    }

    var dayKey: HabitLogDayKey {
        HabitLogDayKey(habitID: habitID, dayStart: dayStart)
    }

    var description: String {
        "\(habitID.uuidString)-\(Int(dayStart.timeIntervalSince1970))-\(sequence)-\(nonce.uuidString)"
    }
}

enum HabitLogMutationStatus: String, Codable, Sendable {
    case queued
    case writing
    case committed
    case failed
    case droppedStale
}

struct HabitLogPendingMutation: Identifiable, Hashable, Codable, Sendable {
    let id: HabitLogMutationID
    let createdAt: Date
    let valueDelta: Double
    let countDelta: Int
    let expectedProgress: Double?
    let expectedCompletion: Bool?
    var status: HabitLogMutationStatus
    var lastErrorDescription: String?

    init(
        id: HabitLogMutationID,
        createdAt: Date = .now,
        valueDelta: Double,
        countDelta: Int,
        expectedProgress: Double?,
        expectedCompletion: Bool?,
        status: HabitLogMutationStatus = .queued,
        lastErrorDescription: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.valueDelta = valueDelta
        self.countDelta = countDelta
        self.expectedProgress = expectedProgress
        self.expectedCompletion = expectedCompletion
        self.status = status
        self.lastErrorDescription = lastErrorDescription
    }
}

struct HabitLogSequenceTracker: Codable, Sendable {
    private(set) var nextByDayKey: [HabitLogDayKey: UInt64] = [:]

    mutating func nextSequence(for dayKey: HabitLogDayKey) -> UInt64 {
        let next = (nextByDayKey[dayKey] ?? 0) + 1
        nextByDayKey[dayKey] = next
        return next
    }

    func sequence(for dayKey: HabitLogDayKey) -> UInt64 {
        nextByDayKey[dayKey] ?? 0
    }
}

struct HabitLogMutationLedger: Codable, Sendable {
    private(set) var pendingByDayKey: [HabitLogDayKey: [HabitLogPendingMutation]] = [:]
    private(set) var latestCommittedSequenceByDayKey: [HabitLogDayKey: UInt64] = [:]

    var hasPendingMutations: Bool {
        pendingByDayKey.values.contains { !$0.isEmpty }
    }

    func pendingMutations(for dayKey: HabitLogDayKey) -> [HabitLogPendingMutation] {
        pendingByDayKey[dayKey] ?? []
    }

    mutating func enqueue(_ mutation: HabitLogPendingMutation) {
        pendingByDayKey[mutation.id.dayKey, default: []].append(mutation)
    }

    mutating func updateStatus(
        for mutationID: HabitLogMutationID,
        status: HabitLogMutationStatus,
        errorDescription: String? = nil
    ) {
        let dayKey = mutationID.dayKey
        guard var list = pendingByDayKey[dayKey],
              let index = list.firstIndex(where: { $0.id == mutationID }) else {
            return
        }

        list[index].status = status
        list[index].lastErrorDescription = errorDescription
        pendingByDayKey[dayKey] = list
    }

    mutating func markCommitted(_ mutationID: HabitLogMutationID) {
        let dayKey = mutationID.dayKey
        latestCommittedSequenceByDayKey[dayKey] = max(
            latestCommittedSequenceByDayKey[dayKey] ?? 0,
            mutationID.sequence
        )
        remove(mutationID)
    }

    mutating func remove(_ mutationID: HabitLogMutationID) {
        let dayKey = mutationID.dayKey
        guard var list = pendingByDayKey[dayKey] else { return }
        list.removeAll(where: { $0.id == mutationID })
        if list.isEmpty {
            pendingByDayKey.removeValue(forKey: dayKey)
        } else {
            pendingByDayKey[dayKey] = list
        }
    }
}
