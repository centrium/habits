//
//  LastValueStore.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import Foundation

protocol LastValueStore {
    func getLastValue(for habit: Habit) -> Decimal?
}

struct LogDerivedLastValueStore: LastValueStore {
    func getLastValue(for habit: Habit) -> Decimal? {
        habit.logs
            .filter { $0.kind == .entry }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.effectiveTimestamp > rhs.effectiveTimestamp
                }
                return lhs.createdAt > rhs.createdAt
            }
            .first
            .map { NSDecimalNumber(value: $0.numericValue).decimalValue }
    }
}
