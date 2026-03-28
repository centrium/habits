//
//  HabitLogService.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import Foundation
import QuartzCore
import SwiftData

final class HabitLogService {
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
    private weak var uiStateStore: HabitUIStateStore?
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldown: TimeInterval = 0.1
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var pendingSyncReferenceDate: Date?
    private let saveCoalescingDelay: TimeInterval = 0.12
    private var metricsRevisions: [UUID: Int] = [:]
    private var dayMetricsCache: [UUID: CachedDayMetrics] = [:]
    private var pendingDayMetricsByKey: [String: PendingDayMetrics] = [:]

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        lastValueStore: any LastValueStore = LogDerivedLastValueStore(),
        uiStateStore: HabitUIStateStore? = nil
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.lastValueStore = lastValueStore
        self.uiStateStore = uiStateStore
    }

    func updateCalendar(_ calendar: Calendar) {
        self.calendar = calendar
        dayMetricsCache.removeAll()
    }

    func setUIStateStore(_ uiStateStore: HabitUIStateStore?) {
        self.uiStateStore = uiStateStore
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

    private func saveAndPlayHaptic(for habit: Habit, referenceDate: Date, wasComplete: Bool) {
        schedulePersistAndReflectionSync(referenceDate: referenceDate)

        let isComplete = habit.isComplete(for: referenceDate, calendar: calendar)
        DispatchQueue.main.async {
            self.playHaptic(becameComplete: !wasComplete && isComplete)
        }
    }

    private func schedulePersistAndReflectionSync(referenceDate: Date) {
        pendingSyncReferenceDate = referenceDate
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [self] in
            let syncReferenceDate = pendingSyncReferenceDate ?? referenceDate
            pendingSyncReferenceDate = nil
            pendingSaveWorkItem = nil

            _ = modelContext.saveAndSyncWidgetData()

            Task { @MainActor in
                await NotificationService.shared.syncEveningReflectionFromStoredSettings(
                    referenceDate: syncReferenceDate
                )
            }
        }

        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + saveCoalescingDelay,
            execute: workItem
        )
    }

    private func logs(for habit: Habit, on date: Date) -> [HabitLog] {
        habit.logs(on: date, calendar: calendar)
    }

    private func removeLogs(for habit: Habit, on date: Date) {
        let day = calendar.startOfDay(for: date)
        habit.logs.removeAll { $0.day == day }
    }

    private func normalizeLogsIfNeeded(for habit: Habit) {
        guard habit.normalizeCumulativeLogs(calendar: calendar) else { return }
        invalidateMetricsCache(for: habit.id)
        _ = modelContext.saveAndSyncWidgetData()
    }

    private func invalidateMetricsCache(for habitID: UUID) {
        metricsRevisions[habitID, default: 0] += 1
        dayMetricsCache.removeValue(forKey: habitID)
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
        guard let uiStateStore else { return nil }
        return MainActor.assumeIsolated {
            uiStateStore.progress(habitId: habitID, date: day)
        }
    }

    private func optimisticCompletion(habitID: UUID, day: Date) -> Bool? {
        guard let uiStateStore else { return nil }
        return MainActor.assumeIsolated {
            uiStateStore.isComplete(habitId: habitID, date: day)
        }
    }

    private func setOptimisticState(
        habitID: UUID,
        day: Date,
        progress: Double,
        isComplete: Bool
    ) {
        guard let uiStateStore else { return }
        MainActor.assumeIsolated {
            uiStateStore.setProgress(
                habitId: habitID,
                date: day,
                progress: progress,
                isComplete: isComplete
            )
        }
    }
}

struct HabitDayMetrics {
    let count: Int
    let value: Double
    let intensity: Double

    static let zero = HabitDayMetrics(count: 0, value: 0, intensity: 0)
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

    func daysForMonth(_ month: Date) -> [Date] {
        CalendarGridHelper.daysForMonth(month, calendarProvider: calendarProvider)
    }

    func metricsRevision(for habitID: UUID) -> Int {
        metricsRevisions[habitID, default: 0]
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
    private func recentEntryLogs(for habit: Habit) -> [HabitLog] {
        habit.logs
            .filter { $0.kind == .entry }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func count(for habit: Habit, on date: Date) -> Int {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: date)
        if let pending = pendingDayMetrics(for: habit.id, day: normalizedDay) {
            return pending.count
        }
        return habit.count(on: date, calendar: calendar)
    }

    func value(for habit: Habit, on date: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: date)
        if let pending = pendingDayMetrics(for: habit.id, day: normalizedDay) {
            return pending.value
        }
        return habit.value(on: date, calendar: calendar)
    }

    func value(for habit: Habit, in interval: DateInterval) -> Double {
        normalizeLogsIfNeeded(for: habit)
        return habit.totalValue(in: interval)
    }

    func formattedValue(for habit: Habit, on date: Date) -> String? {
        let total = value(for: habit, on: date)
        guard total > 0 else { return nil }
        return formatValue(total, for: habit)
    }

    func formattedValue(for habit: Habit, in interval: DateInterval) -> String? {
        let total = value(for: habit, in: interval)
        guard total > 0 else { return nil }
        return formatValue(total, for: habit)
    }

    func entries(for habit: Habit, on date: Date) -> [HabitLog] {
        normalizeLogsIfNeeded(for: habit)
        return logs(for: habit, on: date)
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
}

private extension HabitLogService {
    func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
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
    @discardableResult
    func addLog(for habit: Habit, on day: Date, value: Double) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let amount = max(0, value)
        guard amount > 0 else { return 0 }

        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        let modelDayValue = habit.value(on: normalizedDay, calendar: calendar)
        let modelDayCount = habit.count(on: normalizedDay, calendar: calendar)
        let pendingMetrics = pendingDayMetrics(for: habit.id, day: normalizedDay)
        let currentDayValue = pendingMetrics?.value ?? modelDayValue
        let currentDayCount = pendingMetrics?.count ?? modelDayCount
        let newValue = currentDayValue + amount
        let newCount = currentDayCount + 1

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

        let intensity: Double = {
            guard habit.hasGoal, let target = habit.effectiveTargetValue, target > 0 else {
                return newValue > 0 ? 1 : 0
            }

            switch habit.goalType {
            case .frequency:
                return clamp(Double(newCount) / target)
            case .cumulative:
                return clamp(newValue / target)
            }
        }()

        setPendingDayMetrics(
            for: habit.id,
            day: normalizedDay,
            metrics: PendingDayMetrics(
                count: newCount,
                value: newValue,
                intensity: intensity
            )
        )

        let hasUIStateStore = uiStateStore != nil
        if hasUIStateStore {
            setOptimisticState(
                habitID: habit.id,
                day: normalizedDay,
                progress: newProgress,
                isComplete: willBeComplete
            )
            playHaptic(becameComplete: !wasComplete && willBeComplete)
        }

        guard hasUIStateStore else {
            habit.logs.append(HabitLog(timestamp: day, value: amount, calendar: self.calendar))
            invalidateMetricsCache(for: habit.id)
            saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
            clearPendingDayMetrics(for: habit.id, day: normalizedDay)
            return habit.value(on: normalizedDay, calendar: calendar)
        }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            await MainActor.run {
                habit.logs.append(HabitLog(timestamp: day, value: amount, calendar: self.calendar))
                self.invalidateMetricsCache(for: habit.id)
                self.schedulePersistAndReflectionSync(referenceDate: normalizedDay)
            }

            await MainActor.run {
                self.uiStateStore?.clear(habitId: habit.id, date: normalizedDay)
                self.clearPendingDayMetrics(for: habit.id, day: normalizedDay)
            }
        }

        return newValue
    }

    @discardableResult
    func updateEntry(_ entry: HabitLog, for habit: Habit, on day: Date, value: Double) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let amount = max(0, value)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)

        guard let logIndex = habit.logs.firstIndex(where: { $0.id == entry.id }) else {
            return habit.value(on: normalizedDay, calendar: calendar)
        }

        if amount == 0 {
            habit.logs.remove(at: logIndex)
        } else if habit.logs[logIndex].kind == .entry {
            habit.logs[logIndex].value = amount
            habit.logs[logIndex].createdAt = .now
        } else {
            let legacyLog = habit.logs.remove(at: logIndex)
            let timestamp = legacyLog.effectiveTimestamp
            habit.logs.append(HabitLog(timestamp: timestamp, value: amount, calendar: calendar))
        }

        invalidateMetricsCache(for: habit.id)
        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
        return habit.value(on: normalizedDay, calendar: calendar)
    }

    @discardableResult
    func deleteEntry(_ entry: HabitLog, for habit: Habit, on day: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)

        habit.logs.removeAll { $0.id == entry.id }

        invalidateMetricsCache(for: habit.id)
        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
        return habit.value(on: normalizedDay, calendar: calendar)
    }

    @discardableResult
    func clearEntries(for habit: Habit, on day: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        removeLogs(for: habit, on: normalizedDay)
        invalidateMetricsCache(for: habit.id)
        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
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
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        let dayLogs = logs(for: habit, on: normalizedDay)

        if let entryIndex = dayLogs.firstIndex(where: { $0.kind == .entry }),
           let logIndex = habit.logs.firstIndex(where: { $0.id == dayLogs[entryIndex].id }) {
            habit.logs.remove(at: logIndex)
        } else if let legacyIndex = habit.logs.firstIndex(where: { $0.day == normalizedDay && $0.kind == .legacyDailyTotal }) {
            let log = habit.logs[legacyIndex]
            log.count = max(0, log.count - 1)
            if log.count == 0 {
                habit.logs.remove(at: legacyIndex)
            }
        } else {
            return 0
        }

        invalidateMetricsCache(for: habit.id)
        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
        return count(for: habit, on: normalizedDay)
    }

    @discardableResult
    func setCount(for habit: Habit, on day: Date, to newValue: Int) -> Int {
        let normalizedDay = calendar.startOfDay(for: day)
        let value = max(0, newValue)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)

        removeLogs(for: habit, on: normalizedDay)

        if value > 0 {
            for offset in 0..<value {
                let timestamp = calendar.date(byAdding: .second, value: offset, to: normalizedDay) ?? normalizedDay
                habit.logs.append(HabitLog(timestamp: timestamp, value: 1, calendar: calendar))
            }
        }

        invalidateMetricsCache(for: habit.id)
        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
        return value
    }
}
