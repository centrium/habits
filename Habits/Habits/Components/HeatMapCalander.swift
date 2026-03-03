//
//  HeatMapCalander.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import Foundation

struct Week: Identifiable {
    let id: Date
    let days: [Date?]
    let month: Int
}

struct HeatmapLayoutService {
    let calendarProvider: CalendarProvider

    func makeWeeks(
        endingAt endDate: Date,
        numberOfWeeks: Int
    ) -> [Week] {
        let calendar = calendarProvider.calendar
        let end = calendar.startOfDay(for: endDate)
        let lastWeekStart = calendarProvider.startOfWeek(for: end)

        var weeks: [Week] = []

        for weekOffset in (0..<numberOfWeeks).reversed() {
            let weekStart = calendar.date(byAdding: .day, value: -7 * weekOffset, to: lastWeekStart)!

            var days = Array<Date?>(repeating: nil, count: 7)
            for dayOffset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                let rowIndex = calendarProvider.rowIndex(for: day)
                days[rowIndex] = day <= end ? day : nil
            }

            let month = calendar.component(.month, from: weekStart)
            weeks.append(Week(id: weekStart, days: days, month: month))
        }

#if DEBUG
        let todayIndex = calendarProvider.rowIndex(for: Date())
        let todayWeekday = calendar.component(.weekday, from: Date())
        assert(
            todayIndex == calendarProvider.rowIndex(forWeekdayNumber: todayWeekday),
            "weekdayRowIndex mapping mismatch for today"
        )
#endif

        return weeks
    }
}
