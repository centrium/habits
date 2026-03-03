//
//  Habit+.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {
    func periodRange(
        for date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> DateInterval {
        goalPeriod.periodRange(
            for: date,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }
}
