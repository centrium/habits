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
        var interval = periodRange(for: referenceDate, calendar: calendar)

        while true {
            if hasHitTarget(in: interval) {
                streak += 1
            } else {
                break
            }

            interval = previousPeriod(from: interval, calendar: calendar)
        }

        return streak
    }

    func currentStreak(calendar: Calendar = .current) -> Int {
        currentStreak(referenceDate: .now, calendar: calendar)
    }

    private func previousPeriod(from interval: DateInterval, calendar: Calendar) -> DateInterval {
        let previousDate = goalPeriod.previousPeriodStart(before: interval.start, calendar: calendar)
        return periodRange(for: previousDate, calendar: calendar)
    }
}
