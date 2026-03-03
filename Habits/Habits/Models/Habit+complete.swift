//
//  Habit+isCurrentPeriodComplete.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {
    func isCurrentPeriodComplete(
        for date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Bool {
        isComplete(for: date, calendar: calendar, weekStartPreference: weekStartPreference)
    }

    func isComplete(
        for date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Bool {
        progressFraction(for: date, calendar: calendar, weekStartPreference: weekStartPreference) == 1.0
    }
}
