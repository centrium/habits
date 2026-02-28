//
//  Habit+isCurrentPeriodComplete.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {

    func isCurrentPeriodComplete(for date: Date, calendar: Calendar = .current) -> Bool {
        isComplete(for: date, calendar: calendar)
    }

    func isComplete(for date: Date, calendar: Calendar = .current) -> Bool {
        progressFraction(for: date, calendar: calendar) == 1.0
    }
}
