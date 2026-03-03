//
//  CalendarGridHelper.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import Foundation

struct CalendarGridHelper {
    static func daysForMonth(_ month: Date, calendarProvider: CalendarProvider) -> [Date] {
        let calendar = calendarProvider.calendar
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month)
        else { return [] }

        let totalCells = 42 // 6 rows x 7 columns for a stable calendar height.
        var days: [Date] = []
        var date = calendarProvider.startOfWeek(for: monthInterval.start)

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
