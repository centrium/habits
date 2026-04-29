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

enum HabitLogMutationOperation: Hashable, Codable, Sendable {
    case addLog(value: Double, entryTimestamp: Date)
    case clearDay
    case setDayCount(Int)
    case deleteEntry(logID: UUID)
    case updateEntry(logID: UUID, value: Double)
}

enum HabitLogMutationIdentity {
    nonisolated static func deterministicLogID(baseNonce: UUID, index: Int) -> UUID {
        var bytes = baseNonce.uuid
        let encodedIndex = UInt64(max(0, index)).bigEndian
        withUnsafeMutableBytes(of: &bytes) { buffer in
            for byteOffset in 0..<8 {
                let shift = (7 - byteOffset) * 8
                buffer[8 + byteOffset] = UInt8((encodedIndex >> UInt64(shift)) & 0xFF)
            }
        }
        return UUID(uuid: bytes)
    }
}

struct HabitLogPendingMutation: Identifiable, Hashable, Codable, Sendable {
    let id: HabitLogMutationID
    let createdAt: Date
    let operation: HabitLogMutationOperation
    let valueDelta: Double
    let countDelta: Int
    let expectedCount: Int?
    let expectedValue: Double?
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
        self.operation = .addLog(value: valueDelta, entryTimestamp: createdAt)
        self.valueDelta = valueDelta
        self.countDelta = countDelta
        self.expectedCount = nil
        self.expectedValue = nil
        self.expectedProgress = expectedProgress
        self.expectedCompletion = expectedCompletion
        self.status = status
        self.lastErrorDescription = lastErrorDescription
    }

    init(
        id: HabitLogMutationID,
        createdAt: Date = .now,
        operation: HabitLogMutationOperation,
        valueDelta: Double = 0,
        countDelta: Int = 0,
        expectedCount: Int? = nil,
        expectedValue: Double? = nil,
        expectedProgress: Double?,
        expectedCompletion: Bool?,
        status: HabitLogMutationStatus = .queued,
        lastErrorDescription: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.operation = operation
        self.valueDelta = valueDelta
        self.countDelta = countDelta
        self.expectedCount = expectedCount
        self.expectedValue = expectedValue
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
