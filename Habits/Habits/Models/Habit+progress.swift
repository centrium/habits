//
//  Habit+progrss.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {
    var hasGoal: Bool {
        hasStreakGoal && streakTarget > 0
    }

    func progress(for date: Date, calendar: Calendar = .current) -> Double? {
        progressFraction(for: date, calendar: calendar)
    }

    func progressFraction(for date: Date, calendar: Calendar = .current) -> Double? {
        guard hasGoal else { return nil }

        let interval = periodRange(for: date, calendar: calendar)
        let total = totalCount(in: interval)
        let rawProgress = Double(total) / Double(streakTarget)

        return min(max(rawProgress, 0.0), 1.0)
    }

    func progressDetails(for date: Date, calendar: Calendar = .current) -> (current: Int, target: Int)? {
        guard hasGoal else { return nil }

        let interval = periodRange(for: date, calendar: calendar)
        let total = totalCount(in: interval)

        return (total, streakTarget)
    }
}
