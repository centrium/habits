//
//  Habit+.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {
    func currentStreak(
        referenceDate: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Int {
        guard hasGoal else { return 0 }

        var streak = 0
        var interval = periodRange(
            for: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        while true {
            if hasHitTarget(in: interval) {
                streak += 1
            } else {
                break
            }

            interval = previousPeriod(
                from: interval,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
        }

        return streak
    }

    func currentStreak(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Int {
        currentStreak(referenceDate: .now, calendar: calendar, weekStartPreference: weekStartPreference)
    }

    private func previousPeriod(
        from interval: DateInterval,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> DateInterval {
        let previousDate = goalPeriod.previousPeriodStart(
            before: interval.start,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        return periodRange(
            for: previousDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }
}
