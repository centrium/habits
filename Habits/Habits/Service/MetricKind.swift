//
//  MetricKind.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import Foundation

enum MetricKind: Equatable {
    case count
    case currency
    case genericValue
}

enum MetricKindResolver {
    static func resolve(_ habit: Habit) -> MetricKind {
        resolve(goalType: habit.goalType, unit: habit.trimmedUnit)
    }

    static func resolve(goalType: GoalType, unit: String?) -> MetricKind {
        switch goalType {
        case .frequency:
            return .count
        case .cumulative:
            return CurrencyDetection.detect(unit: unit).isCurrency ? .currency : .genericValue
        }
    }
}
