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
    private enum HeatmapConstants {
        static let visibleWindowDays = 140
    }

    private let modelContext: ModelContext
    private(set) var calendar: Calendar
    private let lastValueStore: any LastValueStore
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldown: TimeInterval = 0.1

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        lastValueStore: any LastValueStore = LogDerivedLastValueStore()
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.lastValueStore = lastValueStore
    }

    func updateCalendar(_ calendar: Calendar) {
        self.calendar = calendar
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
        try? modelContext.save()

        Task { @MainActor in
            await NotificationService.shared.syncEveningReflectionFromStoredSettings(
                referenceDate: referenceDate
            )
        }

        let isComplete = habit.isComplete(for: referenceDate, calendar: calendar)
        DispatchQueue.main.async {
            self.playHaptic(becameComplete: !wasComplete && isComplete)
        }
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
        try? modelContext.save()
    }

    private func heatmapWindow(for endDate: Date) -> DateInterval {
        let end = calendar.startOfDay(for: endDate)
        let start = calendar.date(byAdding: .day, value: -(HeatmapConstants.visibleWindowDays - 1), to: end) ?? end
        let intervalEnd = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        return DateInterval(start: start, end: intervalEnd)
    }

    private func heatmapReferenceDate(for habit: Habit, requested date: Date) -> Date {
        let normalizedRequestedDate = calendar.startOfDay(for: date)
        let normalizedToday = calendar.startOfDay(for: Date())
        let latestLoggedDay = habit.logs.map(\.day).max() ?? normalizedRequestedDate
        return max(normalizedToday, max(normalizedRequestedDate, latestLoggedDay))
    }

    private func maxDailyCumulativeValueInHeatmapWindow(for habit: Habit, endingAt endDate: Date) -> Double {
        guard habit.goalType == .cumulative else { return 0 }

        let interval = heatmapWindow(for: endDate)
        var dailyTotals: [Date: Double] = [:]

        for log in habit.logs where log.day >= interval.start && log.day < interval.end {
            let value = log.numericValue
            guard value > 0 else { continue }
            dailyTotals[log.day, default: 0] += value
        }

        return dailyTotals.values.max() ?? 0
    }
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
}

extension HabitLogService {
    private func recentEntryLogs(for habit: Habit) -> [HabitLog] {
        habit.logs
            .filter { $0.kind == .entry }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func count(for habit: Habit, on date: Date) -> Int {
        normalizeLogsIfNeeded(for: habit)
        return habit.count(on: date, calendar: calendar)
    }

    func value(for habit: Habit, on date: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
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

extension HabitLogService {
    func intensity(for habit: Habit, on date: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let dailyLogCount = max(0, habit.count(on: date, calendar: calendar))
        let dailyLogValue = max(0, habit.value(on: date, calendar: calendar))
        guard dailyLogCount > 0 || dailyLogValue > 0 else { return HeatmapNormalizer.intensity(forTier: 0) }

        let referenceDate = heatmapReferenceDate(for: habit, requested: date)
        let maxDailyValueInWindow = maxDailyCumulativeValueInHeatmapWindow(for: habit, endingAt: referenceDate)

        let tier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: habit.goalType,
                hasGoal: habit.hasGoal,
                targetValue: habit.effectiveTargetValue,
                dailyLogCount: dailyLogCount,
                dailyLogValue: dailyLogValue,
                maxDailyValueInWindow: maxDailyValueInWindow
            )
        )
        return HeatmapNormalizer.intensity(forTier: tier)
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
        habit.logs.append(HabitLog(timestamp: day, value: amount, calendar: calendar))
        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)

        return habit.value(on: normalizedDay, calendar: calendar)
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

        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
        return habit.value(on: normalizedDay, calendar: calendar)
    }

    @discardableResult
    func deleteEntry(_ entry: HabitLog, for habit: Habit, on day: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)

        habit.logs.removeAll { $0.id == entry.id }

        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
        return habit.value(on: normalizedDay, calendar: calendar)
    }

    @discardableResult
    func clearEntries(for habit: Habit, on day: Date) -> Double {
        normalizeLogsIfNeeded(for: habit)
        let normalizedDay = calendar.startOfDay(for: day)
        let wasComplete = habit.isComplete(for: normalizedDay, calendar: calendar)
        removeLogs(for: habit, on: normalizedDay)
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

        saveAndPlayHaptic(for: habit, referenceDate: normalizedDay, wasComplete: wasComplete)
        return value
    }
}
