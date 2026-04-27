import Foundation
import Combine

struct HabitCommittedDayState: Equatable, Sendable {
    let count: Int
    let value: Double
    let progress: Double
    let isComplete: Bool
    let committedSequence: UInt64
}

struct HabitProjectedDayState: Equatable, Sendable {
    let count: Int
    let value: Double
    let progress: Double
    let isComplete: Bool
    let headSequence: UInt64
}

@MainActor
final class HabitUIStateStore: ObservableObject {
    @Published var progressByHabitAndDate: [String: Double] = [:]
    @Published var completionByHabitAndDate: [String: Bool] = [:]
    @Published private(set) var projectionVersionByHabitID: [UUID: UInt64] = [:]

    private var committedDayStateByKey: [HabitLogDayKey: HabitCommittedDayState] = [:]
    private var pendingMutationsByHabitID: [UUID: [HabitLogPendingMutation]] = [:]
    private var projectedDayStateByKey: [HabitLogDayKey: HabitProjectedDayState] = [:]
    private var projectionSubjectsByHabitID: [UUID: CurrentValueSubject<UInt64, Never>] = [:]

    func key(habitId: UUID, date: Date, calendar: Calendar = .current) -> String {
        "\(habitId.uuidString)-\(calendar.startOfDay(for: date).timeIntervalSince1970)"
    }

    func setProgress(habitId: UUID, date: Date, progress: Double, isComplete: Bool, calendar: Calendar = .current) {
        let key = key(habitId: habitId, date: date, calendar: calendar)
        progressByHabitAndDate[key] = progress
        completionByHabitAndDate[key] = isComplete
    }

    func reconcileProgress(habitId: UUID, date: Date, progress: Double, isComplete: Bool, calendar: Calendar = .current) {
        let key = key(habitId: habitId, date: date, calendar: calendar)
        let existingProgress = progressByHabitAndDate[key]
        let existingComplete = completionByHabitAndDate[key]
        guard existingProgress != progress || existingComplete != isComplete else { return }
        progressByHabitAndDate[key] = progress
        completionByHabitAndDate[key] = isComplete
    }

    func progress(habitId: UUID, date: Date, calendar: Calendar = .current) -> Double? {
        let dayKey = HabitLogDayKey(
            habitID: habitId,
            dayStart: calendar.startOfDay(for: date)
        )
        if let projected = projectedDayStateByKey[dayKey] {
            return projected.progress
        }
        return progressByHabitAndDate[key(habitId: habitId, date: date, calendar: calendar)]
    }

    func isComplete(habitId: UUID, date: Date, calendar: Calendar = .current) -> Bool? {
        let dayKey = HabitLogDayKey(
            habitID: habitId,
            dayStart: calendar.startOfDay(for: date)
        )
        if let projected = projectedDayStateByKey[dayKey] {
            return projected.isComplete
        }
        return completionByHabitAndDate[key(habitId: habitId, date: date, calendar: calendar)]
    }

    func clear(habitId: UUID, date: Date, calendar: Calendar = .current) {
        let key = key(habitId: habitId, date: date, calendar: calendar)
        progressByHabitAndDate.removeValue(forKey: key)
        completionByHabitAndDate.removeValue(forKey: key)
    }

    func clearIfPresent(habitId: UUID, date: Date, calendar: Calendar = .current) {
        let key = key(habitId: habitId, date: date, calendar: calendar)
        let hasProgress = progressByHabitAndDate[key] != nil
        let hasCompletion = completionByHabitAndDate[key] != nil
        guard hasProgress || hasCompletion else { return }
        progressByHabitAndDate.removeValue(forKey: key)
        completionByHabitAndDate.removeValue(forKey: key)
    }

    func committedDayState(
        habitID: UUID,
        day: Date,
        calendar: Calendar
    ) -> HabitCommittedDayState? {
        committedDayStateByKey[HabitLogDayKey.make(habitID: habitID, day: day, calendar: calendar)]
    }

    func projectedDayState(
        habitID: UUID,
        day: Date,
        calendar: Calendar
    ) -> HabitProjectedDayState? {
        projectedDayStateByKey[HabitLogDayKey.make(habitID: habitID, day: day, calendar: calendar)]
    }

    func projectedDayStates(for habitID: UUID) -> [Date: HabitProjectedDayState] {
        projectedDayStateByKey.reduce(into: [Date: HabitProjectedDayState]()) { result, entry in
            guard entry.key.habitID == habitID else { return }
            result[entry.key.dayStart] = entry.value
        }
    }

    func pendingMutations(for habitID: UUID) -> [HabitLogPendingMutation] {
        pendingMutationsByHabitID[habitID] ?? []
    }

    func setCommittedDayState(
        habitID: UUID,
        day: Date,
        calendar: Calendar,
        state: HabitCommittedDayState
    ) {
        let dayKey = HabitLogDayKey.make(habitID: habitID, day: day, calendar: calendar)
        committedDayStateByKey[dayKey] = state
        rebuildProjectedDayState(for: dayKey)
        publishProjectionUpdate(for: habitID)
    }

    func setCommittedDayStates(
        habitID: UUID,
        calendar: Calendar,
        statesByDay: [Date: HabitCommittedDayState]
    ) {
        guard !statesByDay.isEmpty else { return }

        var didChange = false
        for (day, state) in statesByDay {
            let dayKey = HabitLogDayKey.make(habitID: habitID, day: day, calendar: calendar)
            guard committedDayStateByKey[dayKey] != state else { continue }
            committedDayStateByKey[dayKey] = state
            rebuildProjectedDayState(for: dayKey)
            didChange = true
        }

        guard didChange else { return }
        publishProjectionUpdate(for: habitID)
    }

    func replacePendingMutations(
        for habitID: UUID,
        mutations: [HabitLogPendingMutation]
    ) {
        pendingMutationsByHabitID[habitID] = mutations
        rebuildProjectedDayStates(for: habitID)
        publishProjectionUpdate(for: habitID)
    }

    func appendPendingMutation(_ mutation: HabitLogPendingMutation) {
        pendingMutationsByHabitID[mutation.id.habitID, default: []].append(mutation)
        rebuildProjectedDayState(for: mutation.id.dayKey)
        publishProjectionUpdate(for: mutation.id.habitID)
    }

    func seedCommittedAndAppendPending(
        habitID: UUID,
        day: Date,
        calendar: Calendar,
        committedState: HabitCommittedDayState,
        mutation: HabitLogPendingMutation
    ) {
        let dayKey = HabitLogDayKey.make(habitID: habitID, day: day, calendar: calendar)
        committedDayStateByKey[dayKey] = committedState
        pendingMutationsByHabitID[habitID, default: []].append(mutation)
        rebuildProjectedDayState(for: dayKey)
        publishProjectionUpdate(for: habitID)
    }

    func updatePendingMutationStatus(
        mutationID: HabitLogMutationID,
        status: HabitLogMutationStatus,
        errorDescription: String? = nil
    ) {
        let habitID = mutationID.habitID
        guard var pending = pendingMutationsByHabitID[habitID],
              let index = pending.firstIndex(where: { $0.id == mutationID }) else {
            return
        }

        var updated = pending[index]
        updated.status = status
        updated.lastErrorDescription = errorDescription
        pending[index] = updated
        pendingMutationsByHabitID[habitID] = pending
        rebuildProjectedDayState(for: mutationID.dayKey)
        publishProjectionUpdate(for: habitID)
    }

    func removePendingMutation(_ mutationID: HabitLogMutationID) {
        let habitID = mutationID.habitID
        guard var pending = pendingMutationsByHabitID[habitID] else { return }
        let originalCount = pending.count
        pending.removeAll(where: { $0.id == mutationID })

        guard pending.count != originalCount else { return }
        pendingMutationsByHabitID[habitID] = pending
        rebuildProjectedDayState(for: mutationID.dayKey)
        publishProjectionUpdate(for: habitID)
    }

    func applyCommittedMutation(_ mutation: HabitLogPendingMutation) {
        let dayKey = mutation.id.dayKey
        let currentCommitted = committedDayStateByKey[dayKey]
        let nextCommitted = committedState(
            byApplying: mutation,
            to: currentCommitted
        )
        committedDayStateByKey[dayKey] = nextCommitted

        guard var pending = pendingMutationsByHabitID[mutation.id.habitID] else {
            rebuildProjectedDayState(for: dayKey)
            publishProjectionUpdate(for: mutation.id.habitID)
            return
        }

        pending.removeAll(where: { $0.id == mutation.id })
        pendingMutationsByHabitID[mutation.id.habitID] = pending
        rebuildProjectedDayState(for: dayKey)
        publishProjectionUpdate(for: mutation.id.habitID)
    }

    func projectionPublisher(for habitID: UUID) -> AnyPublisher<UInt64, Never> {
        subject(for: habitID).eraseToAnyPublisher()
    }

    private func rebuildProjectedDayStates(for habitID: UUID) {
        var dayKeys = Set(committedDayStateByKey.keys.filter { $0.habitID == habitID })
        let pendingDayKeys = (pendingMutationsByHabitID[habitID] ?? []).map(\.id.dayKey)
        dayKeys.formUnion(pendingDayKeys)

        for dayKey in dayKeys {
            rebuildProjectedDayState(for: dayKey)
        }
    }

    private func rebuildProjectedDayState(for dayKey: HabitLogDayKey) {
        let committed = committedDayStateByKey[dayKey]
        let pendingForDay = (pendingMutationsByHabitID[dayKey.habitID] ?? [])
            .filter { $0.id.dayKey == dayKey }

        guard committed != nil || !pendingForDay.isEmpty else {
            projectedDayStateByKey.removeValue(forKey: dayKey)
            return
        }

        var count = committed?.count ?? 0
        var value = committed?.value ?? 0
        var progress = committed?.progress ?? 0
        var isComplete = committed?.isComplete ?? false
        var headSequence = committed?.committedSequence ?? 0

        for mutation in pendingForDay where mutation.status != .failed {
            switch mutation.operation {
            case .addLog:
                count = max(0, count + mutation.countDelta)
                value = max(0, value + mutation.valueDelta)
                progress = mutation.expectedProgress ?? progress
                isComplete = mutation.expectedCompletion ?? isComplete
            case .clearDay:
                count = 0
                value = 0
                progress = mutation.expectedProgress ?? 0
                isComplete = mutation.expectedCompletion ?? false
            case let .setDayCount(newCount):
                count = max(0, newCount)
                value = max(0, mutation.expectedValue ?? Double(max(0, newCount)))
                progress = mutation.expectedProgress ?? progress
                isComplete = mutation.expectedCompletion ?? isComplete
            case .deleteEntry, .updateEntry:
                count = max(0, mutation.expectedCount ?? (count + mutation.countDelta))
                value = max(0, mutation.expectedValue ?? (value + mutation.valueDelta))
                progress = mutation.expectedProgress ?? progress
                isComplete = mutation.expectedCompletion ?? isComplete
            }
            headSequence = max(headSequence, mutation.id.sequence)
        }

        projectedDayStateByKey[dayKey] = HabitProjectedDayState(
            count: count,
            value: value,
            progress: progress,
            isComplete: isComplete,
            headSequence: headSequence
        )
    }

    private func committedState(
        byApplying mutation: HabitLogPendingMutation,
        to currentCommitted: HabitCommittedDayState?
    ) -> HabitCommittedDayState {
        let committedSequence = max(currentCommitted?.committedSequence ?? 0, mutation.id.sequence)

        switch mutation.operation {
        case .addLog:
            return HabitCommittedDayState(
                count: max(0, (currentCommitted?.count ?? 0) + mutation.countDelta),
                value: max(0, (currentCommitted?.value ?? 0) + mutation.valueDelta),
                progress: mutation.expectedProgress ?? currentCommitted?.progress ?? 0,
                isComplete: mutation.expectedCompletion ?? currentCommitted?.isComplete ?? false,
                committedSequence: committedSequence
            )
        case .clearDay:
            return HabitCommittedDayState(
                count: 0,
                value: 0,
                progress: mutation.expectedProgress ?? 0,
                isComplete: mutation.expectedCompletion ?? false,
                committedSequence: committedSequence
            )
        case let .setDayCount(newCount):
            let count = max(0, newCount)
            return HabitCommittedDayState(
                count: count,
                value: max(0, mutation.expectedValue ?? Double(count)),
                progress: mutation.expectedProgress ?? currentCommitted?.progress ?? 0,
                isComplete: mutation.expectedCompletion ?? currentCommitted?.isComplete ?? false,
                committedSequence: committedSequence
            )
        case .deleteEntry, .updateEntry:
            return HabitCommittedDayState(
                count: max(0, mutation.expectedCount ?? ((currentCommitted?.count ?? 0) + mutation.countDelta)),
                value: max(0, mutation.expectedValue ?? ((currentCommitted?.value ?? 0) + mutation.valueDelta)),
                progress: mutation.expectedProgress ?? currentCommitted?.progress ?? 0,
                isComplete: mutation.expectedCompletion ?? currentCommitted?.isComplete ?? false,
                committedSequence: committedSequence
            )
        }
    }

    private func publishProjectionUpdate(for habitID: UUID) {
        let nextVersion = (projectionVersionByHabitID[habitID] ?? 0) + 1
        projectionVersionByHabitID[habitID] = nextVersion
        subject(for: habitID).send(nextVersion)
    }

    private func subject(for habitID: UUID) -> CurrentValueSubject<UInt64, Never> {
        if let existing = projectionSubjectsByHabitID[habitID] {
            return existing
        }

        let subject = CurrentValueSubject<UInt64, Never>(projectionVersionByHabitID[habitID] ?? 0)
        projectionSubjectsByHabitID[habitID] = subject
        return subject
    }

    func resetForTesting() {
        progressByHabitAndDate.removeAll()
        completionByHabitAndDate.removeAll()
        projectionVersionByHabitID.removeAll()
        committedDayStateByKey.removeAll()
        pendingMutationsByHabitID.removeAll()
        projectedDayStateByKey.removeAll()
        projectionSubjectsByHabitID.removeAll()
    }
}
