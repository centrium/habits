//
//  HabitLogService.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import Combine
import Foundation
import QuartzCore
import SwiftData

struct CueInsight: Equatable, Sendable {
    let sourceHabitId: UUID
    let confidence: Double
    let occurrenceCount: Int
}

final class CueInsightService {
    private struct SourceEvent: Sendable {
        let habitID: UUID
        let timestamp: Date
    }

    private struct CueComputationSnapshot: Sendable {
        let targetTimestamps: [Date]
        let sourceEvents: [SourceEvent]
    }

    private let modelContext: ModelContext
    private let minimumInterval: TimeInterval = 0
    private let maximumInterval: TimeInterval = 30 * 60
    private let minimumOccurrenceCount: Int = 3
    private let minimumDominantRatio: Double = 0.6
    private var cacheByHabitID: [UUID: CueInsight?] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func detectCue(for habitId: UUID) async -> CueInsight? {
        if let cached = cacheByHabitID[habitId] {
            return cached
        }

        guard let snapshot = buildSnapshot(for: habitId) else {
            cacheByHabitID[habitId] = nil
            return nil
        }

        let minimumInterval = self.minimumInterval
        let maximumInterval = self.maximumInterval
        let minimumOccurrenceCount = self.minimumOccurrenceCount
        let minimumDominantRatio = self.minimumDominantRatio

        let insight = await Task.detached(priority: .utility) {
            await Self.computeCue(
                from: snapshot,
                minimumInterval: minimumInterval,
                maximumInterval: maximumInterval,
                minimumOccurrenceCount: minimumOccurrenceCount,
                minimumDominantRatio: minimumDominantRatio
            )
        }.value

        cacheByHabitID[habitId] = insight
        return insight
    }

    func resetCache() {
        cacheByHabitID.removeAll()
    }

    private func buildSnapshot(for habitId: UUID) -> CueComputationSnapshot? {
        let descriptor = FetchDescriptor<Habit>()
        guard let habits = try? modelContext.fetch(descriptor),
              let targetHabit = habits.first(where: { $0.id == habitId }) else {
            return nil
        }

        let targetTimestamps = relevantTimestamps(from: targetHabit.logs)
        guard targetTimestamps.count >= minimumOccurrenceCount else { return nil }

        let sourceEvents: [SourceEvent] = habits
            .filter { $0.id != habitId }
            .flatMap { habit in
                relevantTimestamps(from: habit.logs).map {
                    SourceEvent(habitID: habit.id, timestamp: $0)
                }
            }
            .sorted { $0.timestamp < $1.timestamp }

        guard !sourceEvents.isEmpty else { return nil }

        return CueComputationSnapshot(
            targetTimestamps: targetTimestamps,
            sourceEvents: sourceEvents
        )
    }

    private static func computeCue(
        from snapshot: CueComputationSnapshot,
        minimumInterval: TimeInterval,
        maximumInterval: TimeInterval,
        minimumOccurrenceCount: Int,
        minimumDominantRatio: Double
    ) -> CueInsight? {
        var occurrenceBySourceHabitID: [UUID: Int] = [:]
        occurrenceBySourceHabitID.reserveCapacity(8)

        for targetTimestamp in snapshot.targetTimestamps {
            guard let match = nearestPriorSourceEvent(
                before: targetTimestamp,
                events: snapshot.sourceEvents,
                minimumInterval: minimumInterval,
                maximumInterval: maximumInterval
            ) else {
                continue
            }

            occurrenceBySourceHabitID[match, default: 0] += 1
        }

        guard let dominant = occurrenceBySourceHabitID.max(by: { lhs, rhs in
            lhs.value < rhs.value
        }) else {
            return nil
        }

        let totalMatches = occurrenceBySourceHabitID.values.reduce(0, +)
        guard totalMatches > 0 else { return nil }

        let dominantCount = dominant.value
        let dominantRatio = Double(dominantCount) / Double(totalMatches)

        guard dominantCount >= minimumOccurrenceCount,
              dominantRatio >= minimumDominantRatio else {
            return nil
        }

        return CueInsight(
            sourceHabitId: dominant.key,
            confidence: dominantRatio,
            occurrenceCount: dominantCount
        )
    }

    private func relevantTimestamps(from logs: [HabitLog]) -> [Date] {
        logs
            .filter { $0.kind == .entry && $0.numericValue > 0 }
            .map(\.effectiveTimestamp)
            .sorted()
    }

    private static func nearestPriorSourceEvent(
        before targetTimestamp: Date,
        events: [SourceEvent],
        minimumInterval: TimeInterval,
        maximumInterval: TimeInterval
    ) -> UUID? {
        var low = 0
        var high = events.count
        let targetInterval = targetTimestamp.timeIntervalSinceReferenceDate

        while low < high {
            let mid = (low + high) / 2
            if events[mid].timestamp.timeIntervalSinceReferenceDate < targetInterval {
                low = mid + 1
            } else {
                high = mid
            }
        }

        var index = low - 1
        while index >= 0 {
            let event = events[index]
            let interval = targetTimestamp.timeIntervalSince(event.timestamp)

            guard interval > 0 else {
                index -= 1
                continue
            }

            if interval > maximumInterval {
                break
            }

            if interval >= minimumInterval {
                return event.habitID
            }

            index -= 1
        }

        return nil
    }
}

final class HabitLogService: ObservableObject {
    private enum ComputedStateRefreshTrigger {
        case optimisticUser
        case committedSingle
        case committedBatch
    }

    enum MutationTerminalOutcome: Sendable {
        case committed(referenceDate: Date)
        case failed(errorDescription: String)
        case cancelled
        case stale
    }

    private static var trackedServicesForTesting: [HabitLogService] = []
    private static let isRunningTests: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private static let computedStateTraceEnabled: Bool = {
#if DEBUG
        ProcessInfo.processInfo.environment["COMPUTED_STATE_DEBUG"]?.lowercased() == "1"
#else
        false
#endif
    }()
    private struct CachedDayMetrics {
        let revision: Int
        let timeZoneIdentifier: String
        let hasStreakGoal: Bool
        let goalType: GoalType
        let target: Double
        let metricsByDay: [Date: HabitDayMetrics]
    }

    private struct PendingDayMetrics {
        let count: Int
        let value: Double
        let intensity: Double
    }

    private let modelContext: ModelContext
    private(set) var calendar: Calendar
    private let lastValueStore: any LastValueStore
    private let uiStateStore: HabitUIStateStore
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldown: TimeInterval = 0.1
    private var pendingComputedStateRefreshTasks: [UUID: Task<Void, Never>] = [:]
    private var computedStateRequestSequenceByHabitID: [UUID: UInt64] = [:]
    private let computedStateImmediateRefreshDelayNanoseconds: UInt64 = 0
    private let computedStateBatchRefreshDelayNanoseconds: UInt64 = 40_000_000
    private var metricsRevisions: [UUID: Int] = [:]
    private var dayMetricsCache: [UUID: CachedDayMetrics] = [:]
    private var pendingDayMetricsByKey: [String: PendingDayMetrics] = [:]
    private var mutationSequenceTracker = HabitLogSequenceTracker()
    private var mutationLedger = HabitLogMutationLedger()
    private lazy var sideEffectCoordinator = HabitLogSideEffectCoordinator(
        modelContainer: modelContext.container
    )
    private lazy var persistenceCoordinator: HabitLogPersistenceCoordinator = HabitLogPersistenceCoordinator(
        modelContainer: modelContext.container
    ) { [weak self] event in
        guard let self else { return }
        await MainActor.run {
            self.handlePersistenceEvent(event)
        }
    }
    private let cueInsightService: CueInsightService
    let habitVersionStore: HabitVersionStore
    @Published private(set) var computedStateByHabitID: [UUID: HabitComputedState] = [:]
    @Published private(set) var lastKnownComputedStateByHabitID: [UUID: HabitComputedState] = [:]
    @Published private(set) var lastLogUserActionAt: Date?

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        lastValueStore: any LastValueStore = LogDerivedLastValueStore(),
        uiStateStore: HabitUIStateStore,
        habitVersionStore: HabitVersionStore = HabitVersionStore()
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.lastValueStore = lastValueStore
        self.uiStateStore = uiStateStore
        self.habitVersionStore = habitVersionStore
        self.cueInsightService = CueInsightService(modelContext: modelContext)
#if DEBUG
        if Self.isRunningTests {
            Self.trackedServicesForTesting.append(self)
        }
#endif
    }

    func updateCalendar(_ calendar: Calendar) {
        self.calendar = calendar
        dayMetricsCache.removeAll()
        cueInsightService.resetCache()
    }

    private func playHaptic(becameComplete: Bool) {
        let now = CACurrentMediaTime()
        guard now - lastHapticTime > hapticCooldown else {
            return
        }

        lastHapticTime = now

        if becameComplete {
            Haptics.success()
        } else {
            Haptics.impactLight()
        }
    }

    private func logs(for habit: Habit, on date: Date) -> [HabitLog] {
        habit.logs(on: date, calendar: calendar)
    }

    private func enqueueMutationPersistence(
        mutation: HabitLogPendingMutation,
        entryTimestamp: Date,
        referenceDate: Date
    ) {
        Task {
            await persistenceCoordinator.enqueue(
                HabitLogWritePayload(
                    mutation: mutation,
                    entryTimestamp: entryTimestamp,
                    referenceDate: referenceDate
                )
            )
        }
    }

    @MainActor
    private func handlePersistenceEvent(_ event: HabitLogPersistenceEvent) {
        switch event {
        case let .writing(mutation):
            mutationLedger.updateStatus(for: mutation.id, status: .writing)
            uiStateStore.updatePendingMutationStatus(
                mutationID: mutation.id,
                status: .writing
            )
        case let .committed(mutation, referenceDate):
            finalizeMutation(
                mutation,
                outcome: .committed(referenceDate: referenceDate)
            )
        case let .failed(mutation, errorDescription):
            finalizeMutation(
                mutation,
                outcome: .failed(errorDescription: errorDescription)
            )
        case let .cancelled(mutation):
            finalizeMutation(mutation, outcome: .cancelled)
        case let .stale(mutation):
            finalizeMutation(mutation, outcome: .stale)
        }
    }

    @MainActor
    private func finalizeMutation(
        _ mutation: HabitLogPendingMutation,
        outcome: MutationTerminalOutcome
    ) {
        switch outcome {
        case let .committed(referenceDate):
            mutationLedger.updateStatus(for: mutation.id, status: .committed)
            mutationLedger.markCommitted(mutation.id)
            if case .clearDay = mutation.operation {
                invalidateMetricsCache(for: mutation.id.habitID)
            } else if case .setDayCount = mutation.operation {
                invalidateMetricsCache(for: mutation.id.habitID)
            } else if case .deleteEntry = mutation.operation {
                invalidateMetricsCache(for: mutation.id.habitID)
            } else if case .updateEntry = mutation.operation {
                invalidateMetricsCache(for: mutation.id.habitID)
            }
            uiStateStore.applyCommittedMutation(mutation)
            clearPendingDayMetrics(for: mutation.id.habitID, day: mutation.id.dayStart)
            if shouldScheduleComputedStateRefresh(for: .committed(referenceDate: referenceDate)) {
                let hasActivePending = !activePendingMutations(for: mutation.id.habitID).isEmpty
                scheduleHabitComputedStateRefresh(
                    for: mutation.id.habitID,
                    referenceDate: referenceDate,
                    trigger: hasActivePending ? .committedBatch : .committedSingle
                )
            }
            LoggingPerformanceMonitor.markPersistCommitted(
                habitID: mutation.id.habitID,
                referenceDate: referenceDate
            )
            Task {
                await sideEffectCoordinator.enqueue(
                    habitID: mutation.id.habitID,
                    referenceDate: referenceDate
                )
            }
        case let .failed(errorDescription):
            mutationLedger.updateStatus(
                for: mutation.id,
                status: .failed,
                errorDescription: errorDescription
            )
            uiStateStore.updatePendingMutationStatus(
                mutationID: mutation.id,
                status: .failed,
                errorDescription: errorDescription
            )
            clearPendingDayMetrics(for: mutation.id.habitID, day: mutation.id.dayStart)
        case .cancelled:
            mutationLedger.updateStatus(
                for: mutation.id,
                status: .droppedStale,
                errorDescription: "Cancelled before commit"
            )
            uiStateStore.updatePendingMutationStatus(
                mutationID: mutation.id,
                status: .droppedStale,
                errorDescription: "Cancelled before commit"
            )
            clearPendingDayMetrics(for: mutation.id.habitID, day: mutation.id.dayStart)
        case .stale:
            mutationLedger.updateStatus(
                for: mutation.id,
                status: .droppedStale,
                errorDescription: "Superseded before commit"
            )
            uiStateStore.updatePendingMutationStatus(
                mutationID: mutation.id,
                status: .droppedStale,
                errorDescription: "Superseded before commit"
            )
            clearPendingDayMetrics(for: mutation.id.habitID, day: mutation.id.dayStart)
        }
    }

    func shouldScheduleComputedStateRefresh(for outcome: MutationTerminalOutcome) -> Bool {
        switch outcome {
        case .committed:
            return true
        case .failed, .cancelled, .stale:
            return false
        }
    }

    private func normalizeLogsIfNeeded(for habit: Habit) {
        guard habit.normalizeCumulativeLogs(calendar: calendar) else { return }
        invalidateMetricsCache(for: habit.id)
        _ = modelContext.saveAndSyncWidgetData()
    }

    private func invalidateMetricsCache(
        for habitID: UUID,
        bumpRevision: Bool = true
    ) {
        if bumpRevision {
            metricsRevisions[habitID, default: 0] += 1
        }
        dayMetricsCache.removeValue(forKey: habitID)
        cueInsightService.resetCache()
        // Drop stale cached computed state so UI falls back to optimistic/live state immediately.
        computedStateByHabitID.removeValue(forKey: habitID)
    }

    private func dayKey(habitID: UUID, day: Date) -> String {
        "\(habitID.uuidString)-\(calendar.startOfDay(for: day).timeIntervalSince1970)"
    }

    private func pendingDayMetrics(for habitID: UUID, day: Date) -> PendingDayMetrics? {
        pendingDayMetricsByKey[dayKey(habitID: habitID, day: day)]
    }

    private func setPendingDayMetrics(
        for habitID: UUID,
        day: Date,
        metrics: PendingDayMetrics
    ) {
        pendingDayMetricsByKey[dayKey(habitID: habitID, day: day)] = metrics
    }

    private func clearPendingDayMetrics(for habitID: UUID, day: Date) {
        pendingDayMetricsByKey.removeValue(forKey: dayKey(habitID: habitID, day: day))
    }

    private func optimisticProgress(habitID: UUID, day: Date) -> Double? {
        return MainActor.assumeIsolated {
            uiStateStore.progress(habitId: habitID, date: day, calendar: calendar)
        }
    }

    private func optimisticCompletion(habitID: UUID, day: Date) -> Bool? {
        return MainActor.assumeIsolated {
            uiStateStore.isComplete(habitId: habitID, date: day, calendar: calendar)
        }
    }

    private func clearOptimisticStateIfPresent(habitID: UUID, day: Date) {
        MainActor.assumeIsolated {
            uiStateStore.clearIfPresent(habitId: habitID, date: day, calendar: calendar)
        }
    }

    private func refreshDelayNanoseconds(for trigger: ComputedStateRefreshTrigger) -> UInt64 {
        switch trigger {
        case .optimisticUser, .committedSingle:
            return computedStateImmediateRefreshDelayNanoseconds
        case .committedBatch:
            return computedStateBatchRefreshDelayNanoseconds
        }
    }

    private func scheduleHabitComputedStateRefresh(
        for habitID: UUID,
        referenceDate: Date,
        trigger: ComputedStateRefreshTrigger,
        projectedPendingMutations: [HabitLogPendingMutation]? = nil
    ) {
        pendingComputedStateRefreshTasks[habitID]?.cancel()
        let sequence = (computedStateRequestSequenceByHabitID[habitID] ?? 0) + 1
        computedStateRequestSequenceByHabitID[habitID] = sequence
        let delayNanoseconds = refreshDelayNanoseconds(for: trigger)
        logComputedStateDebug(
            "schedule habit=\(habitID.uuidString) seq=\(sequence) trigger=\(String(describing: trigger)) delayNs=\(delayNanoseconds) day=\(referenceDate.timeIntervalSince1970)"
        )

        let task = Task { [weak self] in
            guard let self else { return }
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else {
                self.logComputedStateDebug(
                    "cancel-before-compute habit=\(habitID.uuidString) seq=\(sequence)"
                )
                return
            }

            let state = await self.computeComputedStateOffMain(
                habitID: habitID,
                referenceDate: referenceDate,
                projectedPendingMutations: projectedPendingMutations
            )
            guard !Task.isCancelled else {
                self.logComputedStateDebug(
                    "cancel-after-compute habit=\(habitID.uuidString) seq=\(sequence)"
                )
                return
            }
            guard let state else {
                self.logComputedStateDebug(
                    "compute-missing habit=\(habitID.uuidString) seq=\(sequence)"
                )
                return
            }

            await MainActor.run {
                guard self.computedStateRequestSequenceByHabitID[habitID] == sequence else {
                    self.logComputedStateDebug(
                        "drop-stale habit=\(habitID.uuidString) seq=\(sequence)"
                    )
                    return
                }
                self.computedStateByHabitID[habitID] = state
                self.lastKnownComputedStateByHabitID[habitID] = state
                self.pendingComputedStateRefreshTasks.removeValue(forKey: habitID)
                self.logComputedStateDebug(
                    "publish habit=\(habitID.uuidString) seq=\(sequence) cacheSize=\(self.computedStateByHabitID.count)"
                )
            }
        }

        pendingComputedStateRefreshTasks[habitID] = task
    }

    private func computeComputedStateOffMain(
        habitID: UUID,
        referenceDate: Date,
        projectedPendingMutations: [HabitLogPendingMutation]? = nil
    ) async -> HabitComputedState? {
        await withCheckedContinuation { continuation in
            let modelContainer = modelContext.container
            let calendar = self.calendar
            let pendingMutations = projectedPendingMutations ?? []
            DispatchQueue.global(qos: .utility).async {
                Self.logComputedStateDebug(
                    "compute-start habit=\(habitID.uuidString) day=\(referenceDate.timeIntervalSince1970)"
                )
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<Habit>()
                guard let habit = try? context.fetch(descriptor).first(where: { $0.id == habitID }) else {
                    Self.logComputedStateDebug(
                        "compute-end-missing-habit habit=\(habitID.uuidString)"
                    )
                    continuation.resume(returning: nil)
                    return
                }

                let baseSnapshots = habit.logs.map { log in
                    HabitComputationLog(
                        id: log.id,
                        day: log.day,
                        effectiveTimestamp: log.effectiveTimestamp,
                        createdAt: log.createdAt,
                        kind: log.kind,
                        numericValue: log.numericValue,
                        frequencyContribution: log.frequencyContribution,
                        rawTimestamp: log.timestamp
                    )
                }
                let resolvedSnapshots = Self.projectedLogSnapshots(
                    baseSnapshots: baseSnapshots,
                    habitID: habit.id,
                    activePendingMutations: pendingMutations,
                    calendar: calendar
                )
                let computed = HabitComputationEngine(
                    calendar: calendar,
                    weekStartPreference: .system
                ).compute(
                    habit: habit,
                    logSnapshots: resolvedSnapshots,
                    timingLogSnapshots: resolvedSnapshots,
                    timingGlobalLogSnapshots: resolvedSnapshots,
                    now: referenceDate
                )
                Self.logComputedStateDebug(
                    "compute-end habit=\(habitID.uuidString) streak=\(computed.streakState.currentStreak)"
                )
                continuation.resume(returning: computed)
            }
        }
    }

    private static func logComputedStateDebug(_ message: String) {
#if DEBUG
        guard computedStateTraceEnabled else { return }
        print("COMPUTED_STATE: \(message)")
#endif
    }

    private func logComputedStateDebug(_ message: String) {
        Self.logComputedStateDebug(message)
    }
}

struct HabitDayMetrics {
    let count: Int
    let value: Double
    let intensity: Double

    static let zero = HabitDayMetrics(count: 0, value: 0, intensity: 0)
}

struct MonthlyBehaviourComparison {
    let currentAverageUnitsPerActiveDay: Double
    let previousAverageUnitsPerActiveDay: Double
    let percentChange: Double
    let insightText: String
}

extension HabitLogService {
    var calendarProvider: CalendarProvider {
        CalendarProvider(calendar: calendar)
    }

    func metricKind(for habit: Habit) -> MetricKind {
        MetricKindResolver.resolve(habit)
    }

    func currencyDetection(for habit: Habit) -> CurrencyDetectionResult {
        CurrencyDetection.detect(unit: habit.trimmedUnit)
    }

    func valueFormattingContext(for habit: Habit, locale: Locale = .current) -> ValueFormattingContext {
        ValueFormattingContext(habit: habit, locale: locale)
    }

    func valueInputContext(for habit: Habit, locale: Locale = .current) -> ValueInputContext {
        ValueInputContext(habit: habit, locale: locale)
    }

    func formatValue(_ value: Double, for habit: Habit, locale: Locale = .current) -> String {
        HabitValueFormatter.string(
            for: value,
            context: valueFormattingContext(for: habit, locale: locale)
        )
    }

    func displayUnitSuffix(for habit: Habit) -> String {
        let context = valueFormattingContext(for: habit)
        guard context.showsUnitSuffix, let unit = habit.trimmedUnit else { return "" }
        return " \(unit)"
    }

    func prepare(_ habit: Habit) {
        normalizeLogsIfNeeded(for: habit)
    }

    func resolvedComputedStateForDisplay(
        habit: Habit,
        referenceDate: Date,
        weekStartPreference: WeekStartPreference
    ) -> HabitComputedState {
        _ = referenceDate
        _ = weekStartPreference
        logComputedStateDebug("resolve-enter habit=\(habit.id.uuidString)")
        let activePending = activePendingMutations(for: habit.id)
        if !activePending.isEmpty {
            logComputedStateDebug("resolve-pending habit=\(habit.id.uuidString) pending=\(activePending.count)")
            return computedStateByHabitID[habit.id]
                ?? lastKnownComputedStateByHabitID[habit.id]
                ?? emptyComputedState()
        }

        if let cached = computedStateByHabitID[habit.id] {
            return cached
        }
        return lastKnownComputedStateByHabitID[habit.id] ?? emptyComputedState()
    }

    func resolvedComputedStateForInsights(
        habit: Habit,
        referenceDate: Date,
        weekStartPreference: WeekStartPreference
    ) async -> HabitComputedState {
        _ = await ensureComputedState(for: habit.id, referenceDate: referenceDate)
        return resolvedComputedStateForDisplay(
            habit: habit,
            referenceDate: referenceDate,
            weekStartPreference: weekStartPreference
        )
    }

    private func resolveComputedState(
        habit: Habit,
        logs: [HabitLog],
        referenceDate: Date,
        weekStartPreference: WeekStartPreference
    ) -> HabitComputedState {
        if logs.isEmpty {
            return emptyComputedState()
        }
        return HabitComputationEngine(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).compute(
            habit: habit,
            logs: logs,
            globalLogs: logs,
            now: referenceDate
        )
    }

    private func resolveComputedState(
        habit: Habit,
        projectedLogSnapshots: [HabitComputationLog],
        referenceDate: Date,
        weekStartPreference: WeekStartPreference
    ) -> HabitComputedState {
        if projectedLogSnapshots.isEmpty {
            return emptyComputedState()
        }
        return HabitComputationEngine(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).compute(
            habit: habit,
            logSnapshots: projectedLogSnapshots,
            timingLogSnapshots: projectedLogSnapshots,
            timingGlobalLogSnapshots: projectedLogSnapshots,
            now: referenceDate
        )
    }

    private func isActivePendingStatus(_ status: HabitLogMutationStatus) -> Bool {
        switch status {
        case .queued, .writing:
            return true
        case .committed, .failed, .droppedStale:
            return false
        }
    }

    private func activePendingMutations(for habitID: UUID) -> [HabitLogPendingMutation] {
        MainActor.assumeIsolated {
            uiStateStore.pendingMutations(for: habitID).filter {
                isActivePendingStatus($0.status)
            }
        }
    }

    private func projectedLogSnapshotsForDisplay(
        habit: Habit,
        activePendingMutations: [HabitLogPendingMutation]
    ) -> [HabitComputationLog] {
        let baseSnapshots = habit.logs.map(computationSnapshot(from:))
        return Self.projectedLogSnapshots(
            baseSnapshots: baseSnapshots,
            habitID: habit.id,
            activePendingMutations: activePendingMutations,
            calendar: calendar
        )
    }

    private func computationSnapshot(from log: HabitLog) -> HabitComputationLog {
        HabitComputationLog(
            id: log.id,
            day: log.day,
            effectiveTimestamp: log.effectiveTimestamp,
            createdAt: log.createdAt,
            kind: log.kind,
            numericValue: log.numericValue,
            frequencyContribution: log.frequencyContribution,
            rawTimestamp: log.timestamp
        )
    }

    private static func projectedLogSnapshots(
        baseSnapshots: [HabitComputationLog],
        habitID: UUID,
        activePendingMutations: [HabitLogPendingMutation],
        calendar: Calendar
    ) -> [HabitComputationLog] {
        guard !activePendingMutations.isEmpty else {
            return baseSnapshots.sorted { lhs, rhs in
                if lhs.effectiveTimestamp == rhs.effectiveTimestamp {
                    if lhs.createdAt == rhs.createdAt {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.effectiveTimestamp < rhs.effectiveTimestamp
            }
        }

        var projectedByLogID = Dictionary(
            uniqueKeysWithValues: baseSnapshots.map { ($0.id, $0) }
        )
        let pendingDays = Set(
            activePendingMutations.map { calendar.startOfDay(for: $0.id.dayStart) }
        )

        for day in pendingDays {
            let dayKey = HabitLogDayKey.make(habitID: habitID, day: day, calendar: calendar)
            let dayMutations = activePendingMutations
                .filter { $0.id.dayKey == dayKey }
                .sorted { lhs, rhs in
                    if lhs.id.sequence == rhs.id.sequence {
                        return lhs.createdAt < rhs.createdAt
                    }
                    return lhs.id.sequence < rhs.id.sequence
                }

            projectedByLogID = projectedByLogID.filter { _, snapshot in
                calendar.startOfDay(for: snapshot.day) != dayKey.dayStart
            }

            for mutation in dayMutations {
                switch mutation.operation {
                case let .addLog(value, entryTimestamp):
                    projectedByLogID.removeValue(forKey: mutation.id.nonce)
                    projectedByLogID[mutation.id.nonce] = HabitComputationLog(
                        id: mutation.id.nonce,
                        day: dayKey.dayStart,
                        effectiveTimestamp: entryTimestamp,
                        createdAt: mutation.createdAt,
                        kind: .entry,
                        numericValue: max(0, value),
                        frequencyContribution: max(0, value) > 0 ? 1 : 0,
                        rawTimestamp: entryTimestamp
                    )
                case let .deleteEntry(logID):
                    projectedByLogID.removeValue(forKey: logID)
                case let .updateEntry(logID, value):
                    guard var existing = projectedByLogID[logID] else { continue }
                    let amount = max(0, value)
                    if amount == 0 {
                        projectedByLogID.removeValue(forKey: logID)
                    } else {
                        existing = HabitComputationLog(
                            id: existing.id,
                            day: existing.day,
                            effectiveTimestamp: existing.effectiveTimestamp,
                            createdAt: mutation.createdAt,
                            kind: existing.kind,
                            numericValue: amount,
                            frequencyContribution: amount > 0 ? 1 : 0,
                            rawTimestamp: existing.rawTimestamp
                        )
                        projectedByLogID[logID] = existing
                    }
                case .clearDay:
                    projectedByLogID = projectedByLogID.filter { _, snapshot in
                        calendar.startOfDay(for: snapshot.day) != dayKey.dayStart
                    }
                case let .setDayCount(newCount):
                    projectedByLogID = projectedByLogID.filter { _, snapshot in
                        calendar.startOfDay(for: snapshot.day) != dayKey.dayStart
                    }
                    for offset in 0..<max(0, newCount) {
                        let timestamp = dayKey.dayStart.addingTimeInterval(TimeInterval(offset))
                        let logID = HabitLogMutationIdentity.deterministicLogID(
                            baseNonce: mutation.id.nonce,
                            index: offset
                        )
                        projectedByLogID[logID] = HabitComputationLog(
                            id: logID,
                            day: dayKey.dayStart,
                            effectiveTimestamp: timestamp,
                            createdAt: mutation.createdAt,
                            kind: .entry,
                            numericValue: 1,
                            frequencyContribution: 1,
                            rawTimestamp: timestamp
                        )
                    }
                }
            }
        }

        return projectedByLogID.values.sorted { lhs, rhs in
            if lhs.effectiveTimestamp == rhs.effectiveTimestamp {
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.effectiveTimestamp < rhs.effectiveTimestamp
        }
    }

    private func scheduleOptimisticComputedStateRefresh(
        habitID: UUID,
        referenceDate: Date
    ) {
        let activePending = activePendingMutations(for: habitID)
        guard !activePending.isEmpty else { return }
        scheduleHabitComputedStateRefresh(
            for: habitID,
            referenceDate: referenceDate,
            trigger: .optimisticUser,
            projectedPendingMutations: activePending
        )
    }

    func ensureComputedState(
        for habitID: UUID,
        referenceDate: Date
    ) async -> HabitComputedState? {
        if let existing = computedStateByHabitID[habitID] {
            return existing
        }
        guard let computed = await computeComputedStateOffMain(
            habitID: habitID,
            referenceDate: referenceDate
        ) else {
            return nil
        }
        await MainActor.run {
            computedStateByHabitID[habitID] = computed
            lastKnownComputedStateByHabitID[habitID] = computed
            logComputedStateDebug(
                "warmup-publish habit=\(habitID.uuidString) cacheSize=\(computedStateByHabitID.count)"
            )
        }
        return computed
    }

    func ensureComputedStates(
        for habitIDs: [UUID],
        referenceDate: Date
    ) async {
        let missingHabitIDs = habitIDs.filter { computedStateByHabitID[$0] == nil }
        guard !missingHabitIDs.isEmpty else { return }
        await withTaskGroup(of: (UUID, HabitComputedState?).self) { group in
            for habitID in missingHabitIDs {
                group.addTask { [weak self] in
                    guard let self else { return (habitID, nil) }
                    let state = await self.computeComputedStateOffMain(
                        habitID: habitID,
                        referenceDate: referenceDate
                    )
                    return (habitID, state)
                }
            }

            var statesToPublish: [(UUID, HabitComputedState)] = []
            for await (habitID, state) in group {
                guard let state else { continue }
                statesToPublish.append((habitID, state))
            }

            await MainActor.run {
                for (habitID, state) in statesToPublish {
                    computedStateByHabitID[habitID] = state
                    lastKnownComputedStateByHabitID[habitID] = state
                }
                if !statesToPublish.isEmpty {
                    logComputedStateDebug(
                        "warmup-batch-publish count=\(statesToPublish.count) cacheSize=\(computedStateByHabitID.count)"
                    )
                }
            }
        }
    }

    private func emptyComputedState() -> HabitComputedState {
        HabitComputedState(
            identityState: .gettingStarted,
            streakState: StreakState(
                currentStreak: 0,
                longestStreak: 0,
                hasMetRequirementToday: false,
                isRequiredToday: true,
                isAtRisk: false,
                isBroken: false,
                status: .safe
            ),
            consistency: HabitComputedConsistency(
                percentage: 0,
                daysCompleted: 0,
                daysAvailable: 1,
                windowDays: 7
            ),
            rhythmState: RhythmState(
                rhythm: nil,
                isForming: true,
                visualConfidence: 0
            ),
            timingInsight: nil,
            completionStats: CompletionStats(
                totalLogs: 0,
                uniqueCompletedDays: 0,
                recentActiveDays: 0,
                validTimingSamples: 0
            ),
            weeklyPattern: WeeklyPattern(
                recentTopDay: nil,
                historicalTopDay: nil,
                weekdayDistribution: [:],
                weekdayActiveDayCounts: [:],
                sampleSize: 0
            )
        )
    }

    func daysForMonth(_ month: Date) -> [Date] {
        CalendarGridHelper.daysForMonth(month, calendarProvider: calendarProvider)
    }

    func metricsRevision(for habitID: UUID) -> Int {
        metricsRevisions[habitID, default: 0]
    }

    func habitVersion(for habitID: UUID) -> Int {
        habitVersionStore.version(for: habitID)
    }

    func dayMetrics(for habit: Habit, on days: [Date]) -> [Date: HabitDayMetrics] {
        normalizeLogsIfNeeded(for: habit)

        let normalizedDays = Set(days.map { calendar.startOfDay(for: $0) })
        guard !normalizedDays.isEmpty else { return [:] }

        let target = max(0, habit.effectiveTargetValue ?? 0)
        let revision = metricsRevisions[habit.id, default: 0]
        let resolvedMetricsByDay: [Date: HabitDayMetrics]

        if let cached = dayMetricsCache[habit.id],
           cached.revision == revision,
           cached.timeZoneIdentifier == calendar.timeZone.identifier,
           cached.hasStreakGoal == habit.hasStreakGoal,
           cached.goalType == habit.goalType,
           cached.target == target {
            resolvedMetricsByDay = cached.metricsByDay
        } else {
            var countsByDay: [Date: Int] = [:]
            var valuesByDay: [Date: Double] = [:]
            var frequencyIntensityByDay: [Date: Double] = [:]
            var cumulativeIntensityByDay: [Date: Double] = [:]
            var hasCompletionByDay: Set<Date> = []

            for log in habit.logs {
                let countDay = log.day
                countsByDay[countDay, default: 0] += log.frequencyContribution
                valuesByDay[countDay, default: 0] += log.numericValue

                let intensityDay = calendar.startOfDay(for: log.effectiveTimestamp)
                if log.frequencyContribution > 0 || log.numericValue > 0 {
                    hasCompletionByDay.insert(intensityDay)
                }

                frequencyIntensityByDay[intensityDay, default: 0] += Double(max(0, log.frequencyContribution))
                cumulativeIntensityByDay[intensityDay, default: 0] += max(0, log.numericValue)
            }

            var allKnownDays = Set(countsByDay.keys)
            allKnownDays.formUnion(valuesByDay.keys)
            allKnownDays.formUnion(frequencyIntensityByDay.keys)
            allKnownDays.formUnion(cumulativeIntensityByDay.keys)
            allKnownDays.formUnion(hasCompletionByDay)

            var rebuiltMetricsByDay: [Date: HabitDayMetrics] = [:]
            rebuiltMetricsByDay.reserveCapacity(allKnownDays.count)

            for day in allKnownDays {
                let count = countsByDay[day, default: 0]
                let value = valuesByDay[day, default: 0]

                let intensity: Double
                if !habit.hasStreakGoal {
                    intensity = hasCompletionByDay.contains(day) ? 1 : 0
                } else if target > 0 {
                    switch habit.goalType {
                    case .frequency:
                        intensity = clamp(
                            frequencyIntensityByDay[day, default: 0] / target
                        )
                    case .cumulative:
                        intensity = clamp(
                            cumulativeIntensityByDay[day, default: 0] / target
                        )
                    }
                } else {
                    intensity = 0
                }

                rebuiltMetricsByDay[day] = HabitDayMetrics(
                    count: count,
                    value: value,
                    intensity: intensity
                )
            }

            dayMetricsCache[habit.id] = CachedDayMetrics(
                revision: revision,
                timeZoneIdentifier: calendar.timeZone.identifier,
                hasStreakGoal: habit.hasStreakGoal,
                goalType: habit.goalType,
                target: target,
                metricsByDay: rebuiltMetricsByDay
            )
            resolvedMetricsByDay = rebuiltMetricsByDay
        }

        var requestedMetrics: [Date: HabitDayMetrics] = [:]
        requestedMetrics.reserveCapacity(normalizedDays.count)

        for day in normalizedDays {
            if let pending = pendingDayMetrics(for: habit.id, day: day) {
                requestedMetrics[day] = HabitDayMetrics(
                    count: pending.count,
                    value: pending.value,
                    intensity: pending.intensity
                )
                continue
            }

            var metrics = resolvedMetricsByDay[day] ?? .zero
            if let optimisticProgress = optimisticProgress(habitID: habit.id, day: day) {
                metrics = HabitDayMetrics(
                    count: metrics.count,
                    value: metrics.value,
                    intensity: clamp(optimisticProgress)
                )
            }
            if let optimisticCompletion = optimisticCompletion(habitID: habit.id, day: day),
               optimisticCompletion,
               metrics.intensity <= 0 {
                metrics = HabitDayMetrics(
                    count: max(metrics.count, 1),
                    value: max(metrics.value, 1),
                    intensity: 1
                )
            }

            requestedMetrics[day] = metrics
        }

        return requestedMetrics
    }
}

extension HabitLogService {
    private func seedProjectedDayStateBySeeding(
        for habit: Habit,
        on date: Date
    ) -> HabitProjectedDayState? {
        let normalizedDay = calendar.startOfDay(for: date)

        if let projected = MainActor.assumeIsolated({
            uiStateStore.projectedDayState(
                habitID: habit.id,
                day: normalizedDay,
                calendar: calendar
            )
        }) {
            return projected
        }

        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        let committedSequence = mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
        let committedState = HabitCommittedDayState(
            count: max(0, habit.count(on: normalizedDay, calendar: calendar)),
            value: max(0, habit.value(on: normalizedDay, calendar: calendar)),
            progress: habit.progressFraction(for: normalizedDay, calendar: calendar) ?? 0,
            isComplete: habit.isComplete(for: normalizedDay, calendar: calendar),
            committedSequence: committedSequence
        )

        MainActor.assumeIsolated {
            uiStateStore.setCommittedDayState(
                habitID: habit.id,
                day: normalizedDay,
                calendar: calendar,
                state: committedState
            )
        }

        return MainActor.assumeIsolated {
            uiStateStore.projectedDayState(
                habitID: habit.id,
                day: normalizedDay,
                calendar: calendar
            )
        }
    }

    @discardableResult
    func seedProjectedDayStateIfNeeded(
        for habit: Habit,
        on date: Date
    ) -> HabitProjectedDayState? {
        normalizeLogsIfNeeded(for: habit)
        return seedProjectedDayStateBySeeding(for: habit, on: date)
    }

    func dayStateIfAvailable(
        for habit: Habit,
        on date: Date
    ) -> HabitProjectedDayState? {
        let normalizedDay = calendar.startOfDay(for: date)

        if let projected = MainActor.assumeIsolated({
            uiStateStore.projectedDayState(
                habitID: habit.id,
                day: normalizedDay,
                calendar: calendar
            )
        }) {
            return projected
        }

        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        return HabitProjectedDayState(
            count: max(0, habit.count(on: normalizedDay, calendar: calendar)),
            value: max(0, habit.value(on: normalizedDay, calendar: calendar)),
            progress: habit.progressFraction(for: normalizedDay, calendar: calendar) ?? 0,
            isComplete: habit.isComplete(for: normalizedDay, calendar: calendar),
            headSequence: mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
        )
    }

    func projectedValueIfAvailable(for habit: Habit, on date: Date) -> Double? {
        let normalizedDay = calendar.startOfDay(for: date)
        if let pending = pendingDayMetrics(for: habit.id, day: normalizedDay) {
            return pending.value
        }
        return dayStateIfAvailable(for: habit, on: normalizedDay)?.value
    }

    func projectedValueIfAvailable(for habit: Habit, in interval: DateInterval) -> Double? {
        let days = days(in: interval)
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { partialResult, day in
            partialResult + (projectedValueIfAvailable(for: habit, on: day) ?? 0)
        }
    }

    func formattedProjectedValueIfAvailable(for habit: Habit, on date: Date) -> String? {
        guard let total = projectedValueIfAvailable(for: habit, on: date), total > 0 else {
            return nil
        }
        return formatValue(total, for: habit)
    }

    func formattedProjectedValueIfAvailable(for habit: Habit, in interval: DateInterval) -> String? {
        guard let total = projectedValueIfAvailable(for: habit, in: interval), total > 0 else {
            return nil
        }
        return formatValue(total, for: habit)
    }

    func projectedHistoryDayStates(for habit: Habit) -> [Date: HabitProjectedDayState] {
        normalizeLogsIfNeeded(for: habit)

        var countsByDay: [Date: Int] = [:]
        var valuesByDay: [Date: Double] = [:]

        for log in habit.logs {
            let day = calendar.startOfDay(for: log.day)
            countsByDay[day, default: 0] += max(0, log.frequencyContribution)
            valuesByDay[day, default: 0] += max(0, log.numericValue)
        }

        let pendingMutations = MainActor.assumeIsolated {
            uiStateStore.pendingMutations(for: habit.id)
        }
        let pendingDays = pendingMutations.map { calendar.startOfDay(for: $0.id.dayStart) }

        var allDays = Set(countsByDay.keys)
        allDays.formUnion(valuesByDay.keys)
        allDays.formUnion(pendingDays)

        guard !allDays.isEmpty else { return [:] }

        let committedStatesByDay: [Date: HabitCommittedDayState] = allDays.reduce(into: [:]) { result, day in
            let dayKey = HabitLogDayKey.make(habitID: habit.id, day: day, calendar: calendar)
            let committedState = HabitCommittedDayState(
                count: max(0, countsByDay[day, default: 0]),
                value: max(0, valuesByDay[day, default: 0]),
                progress: habit.progressFraction(for: day, calendar: calendar) ?? 0,
                isComplete: habit.isComplete(for: day, calendar: calendar),
                committedSequence: mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
            )
            result[day] = committedState
        }

        MainActor.assumeIsolated {
            uiStateStore.setCommittedDayStates(
                habitID: habit.id,
                calendar: calendar,
                statesByDay: committedStatesByDay
            )
        }

        return MainActor.assumeIsolated {
            allDays.reduce(into: [Date: HabitProjectedDayState]()) { result, day in
                guard let projected = uiStateStore.projectedDayState(
                    habitID: habit.id,
                    day: day,
                    calendar: calendar
                ) else {
                    return
                }
                result[day] = projected
            }
        }
    }

    private func recentEntryLogs(for habit: Habit) -> [HabitLog] {
        habit.logs
            .filter { $0.kind == .entry }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func count(for habit: Habit, on date: Date) -> Int {
        let normalizedDay = calendar.startOfDay(for: date)
        if let pending = pendingDayMetrics(for: habit.id, day: normalizedDay) {
            return pending.count
        }
        return dayStateIfAvailable(for: habit, on: normalizedDay)?.count ?? 0
    }

    func value(for habit: Habit, on date: Date) -> Double {
        projectedValueIfAvailable(for: habit, on: date) ?? 0
    }

    func value(for habit: Habit, in interval: DateInterval) -> Double {
        projectedValueIfAvailable(for: habit, in: interval) ?? 0
    }

    func formattedValue(for habit: Habit, on date: Date) -> String? {
        formattedProjectedValueIfAvailable(for: habit, on: date)
    }

    func formattedValue(for habit: Habit, in interval: DateInterval) -> String? {
        formattedProjectedValueIfAvailable(for: habit, in: interval)
    }

    func entries(for habit: Habit, on date: Date) -> [HabitLog] {
        return projectedEntries(for: habit, on: date)
    }

    func pendingDeleteEntryIDs(for habit: Habit, on date: Date) -> Set<UUID> {
        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: date,
            calendar: calendar
        )
        let pending = MainActor.assumeIsolated {
            uiStateStore.pendingMutations(for: habit.id)
        }
        return Set(
            pending.compactMap { mutation in
                guard mutation.id.dayKey == dayKey else { return nil }
                guard mutation.status != .failed,
                      mutation.status != .droppedStale,
                      mutation.status != .committed else {
                    return nil
                }
                guard case let .deleteEntry(logID) = mutation.operation else { return nil }
                return logID
            }
        )
    }

    func suggestedQuickEntryValue(for habit: Habit) -> Double? {
        normalizeLogsIfNeeded(for: habit)

        guard habit.goalType == .cumulative else { return 1 }

        let resolvedValue = lastValueStore.getLastValue(for: habit) ?? Decimal(1)
        let suggestedValue = ValueInputParser.sanitizeForStorage(
            resolvedValue,
            context: valueInputContext(for: habit)
        )
        return max(suggestedValue, 1)
    }

    func hasSuggestedQuickEntryValue(for habit: Habit) -> Bool {
        suggestedQuickEntryValue(for: habit) != nil
    }

    func detailAutoAddValue(for habit: Habit) -> Double? {
        suggestedQuickEntryValue(for: habit)
    }

    func quickLogAmount(for habit: Habit) -> Double {
        1
    }

    func detectCue(for habitId: UUID) async -> CueInsight? {
        await cueInsightService.detectCue(for: habitId)
    }

    func monthlyBehaviourComparison(
        for habit: Habit,
        selectedMonth: Date,
        asOf now: Date,
        threshold: Double = 0.05
    ) -> MonthlyBehaviourComparison? {
        guard let windows = matchedMonthlyWindows(selectedMonth: selectedMonth, asOf: now) else {
            return nil
        }

        let currentStats = averageSuccessfulUnitsPerActiveDay(
            for: habit,
            in: windows.current
        )
        let previousStats = averageSuccessfulUnitsPerActiveDay(
            for: habit,
            in: windows.previous
        )

        guard previousStats.activeDays > 0, previousStats.average > 0 else {
            return nil
        }

        let percentChange = (currentStats.average - previousStats.average) / previousStats.average

        let insightText: String = {
            if percentChange > threshold {
                return "Your activity increased this month"
            }
            if percentChange < -threshold {
                return "Your activity dipped this month"
            }
            return "Your activity is steady this month"
        }()

        return MonthlyBehaviourComparison(
            currentAverageUnitsPerActiveDay: currentStats.average,
            previousAverageUnitsPerActiveDay: previousStats.average,
            percentChange: percentChange,
            insightText: insightText
        )
    }
}

private extension HabitLogService {
    func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    struct ActiveDayAverageStats {
        let average: Double
        let activeDays: Int
    }

    struct MatchedMonthlyWindows {
        let current: DateInterval
        let previous: DateInterval
    }

    func matchedMonthlyWindows(
        selectedMonth: Date,
        asOf now: Date
    ) -> MatchedMonthlyWindows? {
        guard
            let currentMonth = calendar.dateInterval(of: .month, for: selectedMonth),
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonth.start),
            let previousMonth = calendar.dateInterval(of: .month, for: previousMonthStart)
        else {
            return nil
        }

        let today = calendar.startOfDay(for: now)
        let currentMonthLastDay = calendar.date(byAdding: .day, value: -1, to: currentMonth.end) ?? currentMonth.start
        let currentEndDay = min(today, currentMonthLastDay)
        guard currentEndDay >= currentMonth.start else {
            return nil
        }

        let elapsedDayCount = (calendar.dateComponents([.day], from: currentMonth.start, to: currentEndDay).day ?? 0) + 1
        guard elapsedDayCount > 0 else {
            return nil
        }

        guard let previousEndExclusive = calendar.date(byAdding: .day, value: elapsedDayCount, to: previousMonth.start) else {
            return nil
        }
        guard previousEndExclusive <= previousMonth.end else {
            return nil
        }

        guard
            let currentEndExclusive = calendar.date(byAdding: .day, value: 1, to: currentEndDay),
            currentMonth.start < currentEndExclusive
        else {
            return nil
        }

        return MatchedMonthlyWindows(
            current: DateInterval(start: currentMonth.start, end: currentEndExclusive),
            previous: DateInterval(start: previousMonth.start, end: previousEndExclusive)
        )
    }

    func averageSuccessfulUnitsPerActiveDay(
        for habit: Habit,
        in interval: DateInterval
    ) -> ActiveDayAverageStats {
        let days = days(in: interval)
        guard !days.isEmpty else {
            return ActiveDayAverageStats(average: 0, activeDays: 0)
        }
        let metricsByDay = dayMetrics(for: habit, on: days)

        var totalUnits: Double = 0
        var activeDays = 0

        for day in days {
            let metrics = metricsByDay[day] ?? .zero
            let units = successfulUnits(for: habit, metrics: metrics)
            if units > 0 {
                activeDays += 1
                totalUnits += units
            }
        }

        guard activeDays > 0 else {
            return ActiveDayAverageStats(average: 0, activeDays: 0)
        }

        return ActiveDayAverageStats(
            average: totalUnits / Double(activeDays),
            activeDays: activeDays
        )
    }

    func successfulUnits(
        for habit: Habit,
        metrics: HabitDayMetrics
    ) -> Double {
        if !habit.hasGoal {
            return Double(max(0, metrics.count))
        }
        switch habit.goalType {
        case .frequency:
            return Double(max(0, metrics.count))
        case .cumulative:
            return max(0, metrics.value)
        }
    }

    func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        while cursor < end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return result
    }
}

extension HabitLogService {
    func intensity(for habit: Habit, on date: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
        return HeatmapIntensityCalculator.intensity(
            for: date,
            habit: habit,
            logs: habit.logs,
            calendar: calendar
        )
    }
}

extension HabitLogService {
    private func resolvedEntryTimestamp(for _: Date) -> Date {
        // Always use real log time for timing insights and behaviour modeling.
        Date()
    }

    @discardableResult
    func addLog(for habit: Habit, on day: Date, value: Double) -> Double {
        logComputedStateDebug("add-enter habit=\(habit.id.uuidString)")
        let traceID = UUID()
        LoggingPerformanceMonitor.markTapStart(traceID: traceID, habitID: habit.id)
        lastLogUserActionAt = Date()
        let normalizedDay = calendar.startOfDay(for: day)
        let entryTimestamp = resolvedEntryTimestamp(for: day)
        let amount = max(0, value)
        guard amount > 0 else { return 0 }

        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        let currentDayCount = habit.count(on: normalizedDay, calendar: calendar)
        let currentDayValue = habit.value(on: normalizedDay, calendar: calendar)
        let newValue = currentDayValue + amount

        let newProgress = habit.progressFractionAfterAdding(
            value: newValue,
            date: normalizedDay,
            calendar: calendar
        )
        let willBeComplete = habit.willBeCompleteAfterAdding(
            value: newValue,
            date: normalizedDay,
            calendar: calendar
        )

        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        let sequence = mutationSequenceTracker.nextSequence(for: dayKey)
        let mutationID = HabitLogMutationID(
            habitID: habit.id,
            dayStart: dayKey.dayStart,
            sequence: sequence
        )

        clearOptimisticStateIfPresent(habitID: habit.id, day: normalizedDay)
        let committedState = HabitCommittedDayState(
            count: currentDayCount,
            value: currentDayValue,
            progress: habit.progressFraction(for: normalizedDay, calendar: calendar) ?? 0,
            isComplete: wasComplete,
            committedSequence: mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
        )
        let pendingMutation = HabitLogPendingMutation(
            id: mutationID,
            operation: .addLog(value: amount, entryTimestamp: entryTimestamp),
            valueDelta: amount,
            countDelta: 1,
            expectedProgress: newProgress,
            expectedCompletion: willBeComplete
        )
        mutationLedger.enqueue(pendingMutation)
        logComputedStateDebug("add-enqueued habit=\(habit.id.uuidString) seq=\(sequence)")
        uiStateStore.seedCommittedAndAppendPending(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar,
            committedState: committedState,
            mutation: pendingMutation
        )
        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        setPendingDayMetrics(
            for: habit.id,
            day: normalizedDay,
            metrics: PendingDayMetrics(
                count: projected?.count ?? (currentDayCount + 1),
                value: projected?.value ?? newValue,
                intensity: clamp(projected?.progress ?? newProgress)
            )
        )
        scheduleOptimisticComputedStateRefresh(
            habitID: habit.id,
            referenceDate: normalizedDay
        )
        LoggingPerformanceMonitor.markOptimisticApplied(traceID: traceID, habitID: habit.id)
        playHaptic(becameComplete: !wasComplete && willBeComplete)
        enqueueMutationPersistence(
            mutation: pendingMutation,
            entryTimestamp: entryTimestamp,
            referenceDate: normalizedDay
        )
        logComputedStateDebug("add-persist-enqueued habit=\(habit.id.uuidString)")

        return newValue
    }

    @discardableResult
    func updateEntry(_ entry: HabitLog, for habit: Habit, on day: Date, value: Double) -> Double {
        lastLogUserActionAt = Date()
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let amount = max(0, value)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        let currentDayCount = habit.count(on: normalizedDay, calendar: calendar)
        let currentDayValue = habit.value(on: normalizedDay, calendar: calendar)
        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        let sequence = mutationSequenceTracker.nextSequence(for: dayKey)
        let mutationID = HabitLogMutationID(
            habitID: habit.id,
            dayStart: dayKey.dayStart,
            sequence: sequence
        )
        clearOptimisticStateIfPresent(habitID: habit.id, day: normalizedDay)
        let committedState = HabitCommittedDayState(
            count: currentDayCount,
            value: currentDayValue,
            progress: habit.progressFraction(for: normalizedDay, calendar: calendar) ?? 0,
            isComplete: wasComplete,
            committedSequence: mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
        )
        let currentProjected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        ) ?? HabitProjectedDayState(
            count: currentDayCount,
            value: currentDayValue,
            progress: committedState.progress,
            isComplete: committedState.isComplete,
            headSequence: committedState.committedSequence
        )
        let expected = expectedStateAfterUpdatingEntry(
            entry: entry,
            newValue: amount,
            habit: habit,
            day: normalizedDay,
            currentProjected: currentProjected
        )
        let pendingMutation = HabitLogPendingMutation(
            id: mutationID,
            operation: .updateEntry(logID: entry.id, value: amount),
            expectedCount: expected.count,
            expectedValue: expected.value,
            expectedProgress: expected.progress,
            expectedCompletion: expected.isComplete
        )
        mutationLedger.enqueue(pendingMutation)
        uiStateStore.seedCommittedAndAppendPending(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar,
            committedState: committedState,
            mutation: pendingMutation
        )
        setPendingDayMetrics(
            for: habit.id,
            day: normalizedDay,
            metrics: PendingDayMetrics(
                count: expected.count,
                value: expected.value,
                intensity: clamp(expected.progress)
            )
        )
        scheduleOptimisticComputedStateRefresh(
            habitID: habit.id,
            referenceDate: normalizedDay
        )
        playHaptic(becameComplete: !wasComplete && expected.isComplete)
        enqueueMutationPersistence(
            mutation: pendingMutation,
            entryTimestamp: normalizedDay,
            referenceDate: normalizedDay
        )
        return expected.value
    }

    @discardableResult
    func deleteEntry(_ entry: HabitLog, for habit: Habit, on day: Date) -> Double {
        lastLogUserActionAt = Date()
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        let currentDayCount = habit.count(on: normalizedDay, calendar: calendar)
        let currentDayValue = habit.value(on: normalizedDay, calendar: calendar)
        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        let sequence = mutationSequenceTracker.nextSequence(for: dayKey)
        let mutationID = HabitLogMutationID(
            habitID: habit.id,
            dayStart: dayKey.dayStart,
            sequence: sequence
        )
        clearOptimisticStateIfPresent(habitID: habit.id, day: normalizedDay)
        let committedState = HabitCommittedDayState(
            count: currentDayCount,
            value: currentDayValue,
            progress: habit.progressFraction(for: normalizedDay, calendar: calendar) ?? 0,
            isComplete: wasComplete,
            committedSequence: mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
        )
        let currentProjected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        ) ?? HabitProjectedDayState(
            count: currentDayCount,
            value: currentDayValue,
            progress: committedState.progress,
            isComplete: committedState.isComplete,
            headSequence: committedState.committedSequence
        )
        let expected = expectedStateAfterDeletingEntry(
            entry: entry,
            habit: habit,
            day: normalizedDay,
            currentProjected: currentProjected
        )
        let pendingMutation = HabitLogPendingMutation(
            id: mutationID,
            operation: .deleteEntry(logID: entry.id),
            expectedCount: expected.count,
            expectedValue: expected.value,
            expectedProgress: expected.progress,
            expectedCompletion: expected.isComplete
        )
        mutationLedger.enqueue(pendingMutation)
        uiStateStore.seedCommittedAndAppendPending(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar,
            committedState: committedState,
            mutation: pendingMutation
        )
        setPendingDayMetrics(
            for: habit.id,
            day: normalizedDay,
            metrics: PendingDayMetrics(
                count: expected.count,
                value: expected.value,
                intensity: clamp(expected.progress)
            )
        )
        scheduleOptimisticComputedStateRefresh(
            habitID: habit.id,
            referenceDate: normalizedDay
        )
        playHaptic(becameComplete: !wasComplete && expected.isComplete)
        enqueueMutationPersistence(
            mutation: pendingMutation,
            entryTimestamp: normalizedDay,
            referenceDate: normalizedDay
        )
        return expected.value
    }

    @discardableResult
    func clearEntries(for habit: Habit, on day: Date) -> Double {
        lastLogUserActionAt = Date()
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)

        let currentDayCount = habit.count(on: normalizedDay, calendar: calendar)
        let currentDayValue = habit.value(on: normalizedDay, calendar: calendar)
        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        let sequence = mutationSequenceTracker.nextSequence(for: dayKey)
        let mutationID = HabitLogMutationID(
            habitID: habit.id,
            dayStart: dayKey.dayStart,
            sequence: sequence
        )

        clearOptimisticStateIfPresent(habitID: habit.id, day: normalizedDay)
        let committedState = HabitCommittedDayState(
            count: currentDayCount,
            value: currentDayValue,
            progress: habit.progressFraction(for: normalizedDay, calendar: calendar) ?? 0,
            isComplete: wasComplete,
            committedSequence: mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
        )
        let pendingMutation = HabitLogPendingMutation(
            id: mutationID,
            operation: .clearDay,
            expectedCount: 0,
            expectedValue: 0,
            expectedProgress: 0,
            expectedCompletion: false
        )
        mutationLedger.enqueue(pendingMutation)
        uiStateStore.seedCommittedAndAppendPending(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar,
            committedState: committedState,
            mutation: pendingMutation
        )
        setPendingDayMetrics(
            for: habit.id,
            day: normalizedDay,
            metrics: PendingDayMetrics(count: 0, value: 0, intensity: 0)
        )
        scheduleOptimisticComputedStateRefresh(
            habitID: habit.id,
            referenceDate: normalizedDay
        )
        playHaptic(becameComplete: false)
        enqueueMutationPersistence(
            mutation: pendingMutation,
            entryTimestamp: normalizedDay,
            referenceDate: normalizedDay
        )
        return 0
    }

    @discardableResult
    func quickLog(for habit: Habit, on day: Date) -> Double {
        addLog(for: habit, on: day, value: quickLogAmount(for: habit))
    }

    @discardableResult
    func increment(for habit: Habit, on day: Date) -> Int {
        _ = addLog(for: habit, on: day, value: 1)
        return count(for: habit, on: day)
    }

    @discardableResult
    func decrement(for habit: Habit, on day: Date) -> Int {
        let normalizedDay = calendar.startOfDay(for: day)
        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        let currentCount = max(0, projected?.count ?? 0)
        let nextCount = max(0, currentCount - 1)
        return setCount(for: habit, on: normalizedDay, to: nextCount)
    }

    @discardableResult
    func setCount(for habit: Habit, on day: Date, to newValue: Int) -> Int {
        lastLogUserActionAt = Date()
        let normalizedDay = calendar.startOfDay(for: day)
        let value = max(0, newValue)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        let currentDayCount = habit.count(on: normalizedDay, calendar: calendar)
        let currentDayValue = habit.value(on: normalizedDay, calendar: calendar)

        let dayKey = HabitLogDayKey.make(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        let sequence = mutationSequenceTracker.nextSequence(for: dayKey)
        let mutationID = HabitLogMutationID(
            habitID: habit.id,
            dayStart: dayKey.dayStart,
            sequence: sequence
        )
        let expectedProgress: Double
        let expectedCompletion: Bool
        if value == 0 {
            expectedProgress = 0
            expectedCompletion = false
        } else {
            let state = projectedFrequencyStateAfterSettingCount(
                habit: habit,
                day: normalizedDay,
                replacementCount: value
            )
            expectedProgress = state.progress
            expectedCompletion = state.isComplete
        }

        clearOptimisticStateIfPresent(habitID: habit.id, day: normalizedDay)
        let committedState = HabitCommittedDayState(
            count: currentDayCount,
            value: currentDayValue,
            progress: habit.progressFraction(for: normalizedDay, calendar: calendar) ?? 0,
            isComplete: wasComplete,
            committedSequence: mutationLedger.latestCommittedSequenceByDayKey[dayKey] ?? 0
        )
        let pendingMutation = HabitLogPendingMutation(
            id: mutationID,
            operation: .setDayCount(value),
            expectedCount: value,
            expectedValue: Double(value),
            expectedProgress: expectedProgress,
            expectedCompletion: expectedCompletion
        )
        mutationLedger.enqueue(pendingMutation)
        uiStateStore.seedCommittedAndAppendPending(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar,
            committedState: committedState,
            mutation: pendingMutation
        )
        setPendingDayMetrics(
            for: habit.id,
            day: normalizedDay,
            metrics: PendingDayMetrics(
                count: value,
                value: Double(value),
                intensity: clamp(expectedProgress)
            )
        )
        scheduleOptimisticComputedStateRefresh(
            habitID: habit.id,
            referenceDate: normalizedDay
        )
        playHaptic(becameComplete: !wasComplete && expectedCompletion)
        enqueueMutationPersistence(
            mutation: pendingMutation,
            entryTimestamp: normalizedDay,
            referenceDate: normalizedDay
        )
        return value
    }
}

private extension HabitLogService {
    func expectedStateAfterUpdatingEntry(
        entry: HabitLog,
        newValue: Double,
        habit: Habit,
        day: Date,
        currentProjected: HabitProjectedDayState
    ) -> (count: Int, value: Double, progress: Double, isComplete: Bool) {
        let dayKey = HabitLogDayKey.make(habitID: habit.id, day: day, calendar: calendar)
        let pendingForDay = uiStateStore.pendingMutations(for: habit.id).filter {
            $0.id.dayKey == dayKey && $0.status != .failed
        }
        let hasReplacementPending = pendingForDay.contains { mutation in
            switch mutation.operation {
            case .clearDay, .setDayCount:
                return true
            case .addLog, .deleteEntry, .updateEntry:
                return false
            }
        }
        let hasPendingDeleteForEntry = pendingForDay.contains { mutation in
            guard case let .deleteEntry(logID) = mutation.operation else { return false }
            return logID == entry.id
        }

        let nextCount: Int
        let nextValue: Double
        if hasReplacementPending || hasPendingDeleteForEntry {
            nextCount = currentProjected.count
            nextValue = currentProjected.value
        } else {
            let oldCountContribution = max(0, entry.frequencyContribution)
            let oldValueContribution = max(0, entry.numericValue)
            let nextCountContribution = newValue > 0 ? 1 : 0
            nextCount = max(0, currentProjected.count - oldCountContribution + nextCountContribution)
            nextValue = max(0, currentProjected.value - oldValueContribution + newValue)
        }

        let replacementState = projectedStateAfterReplacingDayTotals(
            habit: habit,
            day: day,
            currentProjectedCount: currentProjected.count,
            currentProjectedValue: currentProjected.value,
            replacementCount: nextCount,
            replacementValue: nextValue
        )
        return (
            count: nextCount,
            value: nextValue,
            progress: replacementState.progress,
            isComplete: replacementState.isComplete
        )
    }

    func expectedStateAfterDeletingEntry(
        entry: HabitLog,
        habit: Habit,
        day: Date,
        currentProjected: HabitProjectedDayState
    ) -> (count: Int, value: Double, progress: Double, isComplete: Bool) {
        let pendingForDay = uiStateStore.pendingMutations(for: habit.id).filter {
            $0.id.dayKey == HabitLogDayKey.make(habitID: habit.id, day: day, calendar: calendar) && $0.status != .failed
        }
        let hasReplacementPending = pendingForDay.contains { mutation in
            switch mutation.operation {
            case .clearDay, .setDayCount:
                return true
            case .addLog, .deleteEntry, .updateEntry:
                return false
            }
        }

        let nextCount: Int
        let nextValue: Double
        if hasReplacementPending {
            nextCount = currentProjected.count
            nextValue = currentProjected.value
        } else {
            nextCount = max(0, currentProjected.count - max(0, entry.frequencyContribution))
            nextValue = max(0, currentProjected.value - max(0, entry.numericValue))
        }

        let replacementState = projectedStateAfterReplacingDayTotals(
            habit: habit,
            day: day,
            currentProjectedCount: currentProjected.count,
            currentProjectedValue: currentProjected.value,
            replacementCount: nextCount,
            replacementValue: nextValue
        )
        return (
            count: nextCount,
            value: nextValue,
            progress: replacementState.progress,
            isComplete: replacementState.isComplete
        )
    }

    func projectedFrequencyStateAfterSettingCount(
        habit: Habit,
        day: Date,
        replacementCount: Int
    ) -> (progress: Double, isComplete: Bool) {
        projectedStateAfterReplacingDayTotals(
            habit: habit,
            day: day,
            currentProjectedCount: habit.count(on: day, calendar: calendar),
            currentProjectedValue: habit.value(on: day, calendar: calendar),
            replacementCount: replacementCount,
            replacementValue: Double(replacementCount)
        )
    }

    func projectedStateAfterReplacingDayTotals(
        habit: Habit,
        day: Date,
        currentProjectedCount: Int,
        currentProjectedValue: Double,
        replacementCount: Int,
        replacementValue: Double
    ) -> (progress: Double, isComplete: Bool) {
        guard let target = habit.effectiveTargetValue, target > 0 else {
            return (0, false)
        }

        let interval = habit.periodRange(for: day, calendar: calendar)
        let currentPeriodTotal = habit.progressTotal(in: interval)
        switch habit.goalType {
        case .frequency:
            let committedDayCount = Double(habit.count(on: day, calendar: calendar))
            let projectedPeriodTotal = max(
                0,
                currentPeriodTotal - committedDayCount + Double(currentProjectedCount)
            )
            let updatedPeriodTotal = max(
                0,
                projectedPeriodTotal - Double(currentProjectedCount) + Double(replacementCount)
            )
            let progress = GoalProgress(actual: Int(updatedPeriodTotal), goal: Int(target)).fraction
            return (progress, progress >= 1)
        case .cumulative:
            let committedDayValue = habit.value(on: day, calendar: calendar)
            let projectedPeriodTotal = max(
                0,
                currentPeriodTotal - committedDayValue + currentProjectedValue
            )
            let updatedPeriodTotal = max(
                0,
                projectedPeriodTotal - currentProjectedValue + replacementValue
            )
            let progress = min(max(updatedPeriodTotal / target, 0), 1)
            return (progress, progress >= 1)
        }
    }

    func projectedEntries(for habit: Habit, on date: Date) -> [HabitLog] {
        let normalizedDay = calendar.startOfDay(for: date)
        var projected = logs(for: habit, on: normalizedDay).map { detachedEntryCopy(from: $0) }
        let dayKey = HabitLogDayKey.make(habitID: habit.id, day: normalizedDay, calendar: calendar)
        let pendingForDay = activePendingMutations(for: habit.id)
            .filter { mutation in
                mutation.id.dayKey == dayKey
            }
            .sorted { lhs, rhs in
                if lhs.id.sequence == rhs.id.sequence {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.sequence < rhs.id.sequence
            }

        guard !pendingForDay.isEmpty else { return projected }

        for mutation in pendingForDay {
            switch mutation.operation {
            case let .addLog(value, entryTimestamp):
                projected.removeAll(where: { $0.id == mutation.id.nonce })
                let log = HabitLog(
                    timestamp: entryTimestamp,
                    value: max(0, value),
                    createdAt: mutation.createdAt,
                    calendar: calendar
                )
                log.id = mutation.id.nonce
                log.day = dayKey.dayStart
                projected.append(log)
            case let .deleteEntry(logID):
                projected.removeAll(where: { $0.id == logID })
            case let .updateEntry(logID, value):
                guard let index = projected.firstIndex(where: { $0.id == logID }) else {
                    continue
                }
                let amount = max(0, value)
                if amount == 0 {
                    projected.remove(at: index)
                } else {
                    projected[index].value = amount
                    projected[index].createdAt = mutation.createdAt
                }
            case .clearDay:
                projected.removeAll()
            case let .setDayCount(newCount):
                projected.removeAll()
                for offset in 0..<max(0, newCount) {
                    let timestamp = dayKey.dayStart.addingTimeInterval(TimeInterval(offset))
                    let log = HabitLog(
                        timestamp: timestamp,
                        value: 1,
                        createdAt: mutation.createdAt,
                        calendar: calendar
                    )
                    log.id = HabitLogMutationIdentity.deterministicLogID(
                        baseNonce: mutation.id.nonce,
                        index: offset
                    )
                    log.day = dayKey.dayStart
                    projected.append(log)
                }
            }
        }

        return projected.sorted { lhs, rhs in
            if lhs.effectiveTimestamp == rhs.effectiveTimestamp {
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.effectiveTimestamp < rhs.effectiveTimestamp
        }
    }

    func detachedEntryCopy(from log: HabitLog) -> HabitLog {
        let copy: HabitLog
        switch log.kind {
        case .entry:
            copy = HabitLog(
                timestamp: log.effectiveTimestamp,
                value: log.numericValue,
                createdAt: log.createdAt,
                calendar: calendar
            )
        case .legacyDailyTotal:
            copy = HabitLog(
                day: log.day,
                count: log.count,
                createdAt: log.createdAt,
                calendar: calendar
            )
        }
        copy.id = log.id
        copy.day = log.day
        copy.count = log.count
        copy.timestamp = log.timestamp
        copy.value = log.value
        copy.logKindRaw = log.logKindRaw
        copy.createdAt = log.createdAt
        return copy
    }

}

extension HabitLogService {
    func shutdownForTesting() {
        for task in pendingComputedStateRefreshTasks.values {
            task.cancel()
        }
        pendingComputedStateRefreshTasks.removeAll()
        computedStateRequestSequenceByHabitID.removeAll()
        dayMetricsCache.removeAll()
        pendingDayMetricsByKey.removeAll()
        metricsRevisions.removeAll()
        mutationLedger = HabitLogMutationLedger()
        mutationSequenceTracker = HabitLogSequenceTracker()
        computedStateByHabitID.removeAll()
        lastKnownComputedStateByHabitID.removeAll()
        cueInsightService.resetCache()
    }

    var persistenceCoordinatorForTesting: HabitLogPersistenceCoordinator {
        persistenceCoordinator
    }

    var sideEffectCoordinatorForTesting: HabitLogSideEffectCoordinator {
        sideEffectCoordinator
    }

    static func shutdownAllForTesting() async {
        let services = trackedServicesForTesting
        for service in services {
            service.shutdownForTesting()
            await service.persistenceCoordinator.cancelAllForTesting()
            await service.sideEffectCoordinator.cancelAllForTesting()
        }
        trackedServicesForTesting.removeAll()
    }
}
