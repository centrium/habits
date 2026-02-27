//
//  Habit+.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {

    func currentStreak(referenceDate: Date, calendar: Calendar = .current) -> Int {
        guard hasStreakGoal else { return 0 }

        var streak = 0
        var date = referenceDate

        while true {
            let interval = periodRange(for: date, calendar: calendar)

            if hasHitTarget(in: interval) {
                streak += 1
            } else {
                break
            }

            // Step backwards one full period
            switch streakGoalType {
            case .daily:
                date = calendar.date(byAdding: .day, value: -1, to: interval.start)!
            case .monthly:
                date = calendar.date(byAdding: .month, value: -1, to: interval.start)!
            case .yearly:
                date = calendar.date(byAdding: .year, value: -1, to: interval.start)!
            }
        }

        return streak
    }

    func currentStreak(calendar: Calendar = .current) -> Int {
        currentStreak(referenceDate: .now, calendar: calendar)
    }
}
