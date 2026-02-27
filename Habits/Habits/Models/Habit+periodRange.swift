//
//  Habit+.swift
//  Habits
//
//  Created by Matt Adams on 27/02/2026.
//

import SwiftUI

extension Habit {

    func periodRange(for date: Date, calendar: Calendar = .current) -> DateInterval {
        switch streakGoalType {
        case .daily:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return DateInterval(start: start, end: end)

        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)

        case .yearly:
            let components = calendar.dateComponents([.year], from: date)
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        }
    }
}
