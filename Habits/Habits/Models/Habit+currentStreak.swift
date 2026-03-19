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
        StreakService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).currentStreak(
            for: self,
            referenceDate: referenceDate
        )
    }

    func currentStreak(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Int {
        currentStreak(referenceDate: .now, calendar: calendar, weekStartPreference: weekStartPreference)
    }

    func displayStreak(
        referenceDate: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Int {
        StreakService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).displayStreak(
            for: self,
            referenceDate: referenceDate
        )
    }

    func bestStreak(
        referenceDate: Date = .now,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Int {
        StreakService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).bestStreak(
            for: self,
            through: referenceDate
        )
    }

    var isOnStreak: Bool {
        currentStreak() >= 2
    }
}
