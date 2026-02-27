//
//  Habit+logcount.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {
    
    private var logsByDay: [Date: HabitLog] {
        Dictionary(uniqueKeysWithValues: logs.map { ($0.day, $0) })
    }

    func totalCount(in interval: DateInterval) -> Int {
        logs.filter { interval.contains($0.day) }
            .reduce(0) { $0 + $1.count }
    }

    func hasHitTarget(in interval: DateInterval) -> Bool {
        guard hasStreakGoal else { return false }
        return totalCount(in: interval) >= streakTarget
    }
    
    func log(on date: Date = .now, amount: Int = 1, calendar: Calendar = .current) {
        guard amount > 0 else { return }

        let normalized = calendar.startOfDay(for: date)

        if let existing = logs.first(where: { $0.day == normalized }) {
            existing.count += amount
        } else {
            let newLog = HabitLog(day: normalized, count: amount)
            logs.append(newLog)
        }
    }
    
    func count(on date: Date, calendar: Calendar = .current) -> Int {
        let normalized = calendar.startOfDay(for: date)
        return logsByDay[normalized]?.count ?? 0
    }
}

