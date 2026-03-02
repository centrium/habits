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
    private let modelContext: ModelContext
    private let calendar: Calendar
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldown: TimeInterval = 0.1

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        var cal = Calendar.current
        cal.firstWeekday = 1
        self.calendar = cal
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

    private func cumulativeIntensityWindow(for endDate: Date) -> DateInterval {
        let end = calendar.startOfDay(for: endDate)
        let start = calendar.date(byAdding: .day, value: -89, to: end) ?? end
        let intervalEnd = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        return DateInterval(start: start, end: intervalEnd)
    }

    private func normalizeLogsIfNeeded(for habit: Habit) {
        guard habit.normalizeCumulativeLogs(calendar: calendar) else { return }
        try? modelContext.save()
    }

    private func cumulativeScaleReference(for habit: Habit, endingAt date: Date) -> Double {
        let grouped = habit.dailyValueTotals(in: cumulativeIntensityWindow(for: date))
        let totals = grouped.values
            .map { max(0, $0) }
            .filter { $0 > 0 }
            .sorted()

        guard !totals.isEmpty else {
            return 1
        }

        let percentileIndex = min(totals.count - 1, Int(Double(totals.count - 1) * 0.85))
        return max(1, totals[percentileIndex])
    }

    private func cumulativeTierIntensity(for value: Double, upperBound: Double) -> Double {
        let normalized = min(max(value, 0) / max(upperBound, 1), 1)

        switch normalized {
        case ..<0.0001:
            return 0
        case ..<0.20:
            return 0.24
        case ..<0.45:
            return 0.40
        case ..<0.70:
            return 0.56
        case ..<1.00:
            return 0.72
        default:
            return 0.86
        }
    }
}

extension HabitLogService {
    func prepare(_ habit: Habit) {
        normalizeLogsIfNeeded(for: habit)
    }

    func daysForMonth(_ month: Date) -> [Date] {
        CalendarGridHelper.daysForMonth(month, calendar: calendar)
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
        return habit.formatProgressValue(total)
    }

    func formattedValue(for habit: Habit, in interval: DateInterval) -> String? {
        let total = value(for: habit, in: interval)
        guard total > 0 else { return nil }
        return habit.formatProgressValue(total)
    }

    func entries(for habit: Habit, on date: Date) -> [HabitLog] {
        normalizeLogsIfNeeded(for: habit)
        return logs(for: habit, on: date)
    }

    func suggestedQuickEntryValue(for habit: Habit) -> Double? {
        normalizeLogsIfNeeded(for: habit)

        guard habit.goalType == .cumulative else { return 1 }

        let lastValue = recentEntryLogs(for: habit)
            .first?
            .numericValue

        guard let lastValue else { return nil }

        let suggestedValue = max(lastValue, 1)
        return habit.allowsDecimals ? suggestedValue : Double(Int(suggestedValue.rounded()))
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
        switch habit.goalType {
        case .frequency:
            let dayCount = count(for: habit, on: date)

            if dayCount == 0 {
                return 0.10
            }

            if habit.hasGoal, let target = habit.effectiveTargetValue, target > 0 {
                let dailyContribution = Double(dayCount) / target
                let intensity = min(dailyContribution, 1.0)
                return 0.20 + (0.80 * intensity)
            }

            let scaled = min(Double(dayCount) / 10.0, 1.0)
            return 0.20 + (0.80 * scaled)

        case .cumulative:
            let dayValue = value(for: habit, on: date)

            if dayValue == 0 {
                return 0
            }

            let reference = cumulativeScaleReference(for: habit, endingAt: Date())
            return cumulativeTierIntensity(for: dayValue, upperBound: reference)
        }
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
