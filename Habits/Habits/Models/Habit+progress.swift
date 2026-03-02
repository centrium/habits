//
//  Habit+progrss.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import Foundation

struct HabitProgressDetails {
    let current: Double
    let target: Double
    let currentText: String
    let targetText: String
    let unitText: String?
    let goalType: GoalType
}

extension Habit {
    var hasGoal: Bool {
        guard hasStreakGoal else { return false }
        return effectiveTargetValue.map { $0 > 0 } ?? false
    }

    var effectiveTargetValue: Double? {
        guard hasStreakGoal else { return nil }

        switch goalType {
        case .frequency:
            return Double(max(1, streakTarget))
        case .cumulative:
            guard let targetValue, targetValue > 0 else { return nil }
            return targetValue
        }
    }

    var trimmedUnit: String? {
        let trimmed = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func progress(for date: Date, calendar: Calendar = .current) -> Double? {
        progressFraction(for: date, calendar: calendar)
    }

    func progressTotal(in interval: DateInterval) -> Double {
        switch goalType {
        case .frequency:
            return Double(totalCount(in: interval))
        case .cumulative:
            return totalValue(in: interval)
        }
    }

    func progressTotal(for date: Date, calendar: Calendar = .current) -> Double {
        progressTotal(in: periodRange(for: date, calendar: calendar))
    }

    func progressFraction(for date: Date, calendar: Calendar = .current) -> Double? {
        guard let target = effectiveTargetValue, target > 0 else { return nil }

        let interval = periodRange(for: date, calendar: calendar)
        let rawProgress = progressTotal(in: interval) / target

        return min(max(rawProgress, 0.0), 1.0)
    }

    func progressDetails(for date: Date, calendar: Calendar = .current) -> HabitProgressDetails? {
        guard let target = effectiveTargetValue else { return nil }

        let interval = periodRange(for: date, calendar: calendar)
        let current = progressTotal(in: interval)
        let metricKind = MetricKindResolver.resolve(self)

        return HabitProgressDetails(
            current: current,
            target: target,
            currentText: formatProgressValue(current),
            targetText: formatProgressValue(target),
            unitText: metricKind == .genericValue ? trimmedUnit : nil,
            goalType: goalType
        )
    }

    func formatProgressValue(_ value: Double) -> String {
        HabitValueFormatter.string(
            for: value,
            context: ValueFormattingContext(habit: self)
        )
    }

    func inlineProgressText(for date: Date, calendar: Calendar = .current) -> String? {
        guard let details = progressDetails(for: date, calendar: calendar) else { return nil }

        switch goalType {
        case .frequency:
            return "\(details.currentText) / \(details.targetText)"
        case .cumulative:
            let unitSuffix = details.unitText.map { " \($0)" } ?? ""
            return "\(details.currentText) / \(details.targetText)\(unitSuffix)"
        }
    }

    func detailProgressText(for date: Date, calendar: Calendar = .current) -> String? {
        guard let details = progressDetails(for: date, calendar: calendar) else { return nil }

        switch goalType {
        case .frequency:
            return "\(details.currentText) of \(details.targetText)"
        case .cumulative:
            let unitSuffix = details.unitText.map { " \($0)" } ?? ""
            return "\(details.currentText) of \(details.targetText)\(unitSuffix)"
        }
    }

    func activePeriodText(for date: Date, calendar: Calendar = .current) -> String {
        goalPeriod.relativeLabel
    }
}
