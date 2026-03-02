//
//  Habit+logcount.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {
    private func logs(in interval: DateInterval) -> [HabitLog] {
        logs.filter { log in
            log.day >= interval.start && log.day < interval.end
        }
    }

    private func aggregatedNumericValue(for logs: [HabitLog]) -> Double {
        logs.reduce(0) { $0 + $1.numericValue }
    }

    private func aggregatedFrequencyCount(for logs: [HabitLog]) -> Int {
        logs.reduce(0) { $0 + $1.frequencyContribution }
    }

    func totalCount(in interval: DateInterval) -> Int {
        aggregatedFrequencyCount(for: logs(in: interval))
    }

    func totalValue(in interval: DateInterval) -> Double {
        aggregatedNumericValue(for: logs(in: interval))
    }

    func dailyValueTotals(in interval: DateInterval) -> [Date: Double] {
        Dictionary(grouping: logs(in: interval), by: \.day)
            .mapValues { aggregatedNumericValue(for: $0) }
    }

    func hasHitTarget(in interval: DateInterval) -> Bool {
        guard hasGoal, let target = effectiveTargetValue else { return false }
        return progressTotal(in: interval) >= target
    }

    func log(on date: Date, amount: Int = 1, calendar: Calendar = .current) {
        guard amount > 0 else { return }
        logValue(on: date, value: Double(amount), calendar: calendar)
    }

    func logValue(on date: Date, value: Double, calendar: Calendar = .current) {
        guard value > 0 else { return }
        logs.append(HabitLog(timestamp: date, value: value, calendar: calendar))
    }

    func logs(on date: Date, calendar: Calendar = .current) -> [HabitLog] {
        let normalized = calendar.startOfDay(for: date)
        return logs
            .filter { $0.day == normalized }
            .sorted {
                if $0.effectiveTimestamp == $1.effectiveTimestamp {
                    return $0.createdAt < $1.createdAt
                }
                return $0.effectiveTimestamp < $1.effectiveTimestamp
            }
    }

    func count(on date: Date, calendar: Calendar = .current) -> Int {
        aggregatedFrequencyCount(for: logs(on: date, calendar: calendar))
    }

    func value(on date: Date, calendar: Calendar = .current) -> Double {
        aggregatedNumericValue(for: logs(on: date, calendar: calendar))
    }

    @discardableResult
    func normalizeCumulativeLogs(calendar: Calendar = .current) -> Bool {
        guard goalType == .cumulative else { return false }

        let legacyLogs = logs.filter { $0.kind == .legacyDailyTotal && $0.count > 0 }
        guard !legacyLogs.isEmpty else { return false }

        for legacyLog in legacyLogs {
            logs.removeAll { $0.id == legacyLog.id }
            let timestamp = legacyLog.effectiveTimestamp
            logs.append(
                HabitLog(
                    timestamp: timestamp,
                    value: Double(legacyLog.count),
                    createdAt: legacyLog.createdAt,
                    calendar: calendar
                )
            )
        }

        return true
    }
}
