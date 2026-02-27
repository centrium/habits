//
//  CalendarGridHelper.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import Foundation

struct CalendarGridHelper {

    static func daysForMonth(_ month: Date, calendar: Calendar) -> [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        let totalCells = 42 // 6 rows x 7 columns for a stable calendar height.
        var days: [Date] = []
        var date = firstWeek.start

        while days.count < totalCells {
            days.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = next
        }

        return days
    }
}
