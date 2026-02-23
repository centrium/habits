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

struct HeatmapCalendar {
    static let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday
        return cal
    }()

    // Map weekday to row index for Sunday-first weeks.
    // Sunday -> 0, Monday -> 1, ..., Saturday -> 6.
    static func weekdayRowIndex(for date: Date, calendar: Calendar = HeatmapCalendar.calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    static func makeWeeks(
        endingAt endDate: Date,
        numberOfWeeks: Int,
        calendar: Calendar = HeatmapCalendar.calendar
    ) -> [Week] {
        let end = calendar.startOfDay(for: endDate)

        // Find the Sunday of the last week
        let weekdayIndex = weekdayRowIndex(for: end, calendar: calendar)
        let lastSunday = calendar.date(byAdding: .day, value: -weekdayIndex, to: end)!

        var weeks: [Week] = []

        for weekOffset in (0..<numberOfWeeks).reversed() {
            let weekStart = calendar.date(byAdding: .day, value: -7 * weekOffset, to: lastSunday)!

            var days = Array<Date?>(repeating: nil, count: 7)
            for dayOffset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                let rowIndex = weekdayRowIndex(for: day, calendar: calendar)
                days[rowIndex] = day <= end ? day : nil
            }

            let month = calendar.component(.month, from: weekStart)
            weeks.append(Week(id: weekStart, days: days, month: month))
        }

#if DEBUG
        let todayIndex = weekdayRowIndex(for: Date(), calendar: calendar)
        let todayWeekday = calendar.component(.weekday, from: Date())
        assert(
            todayIndex == ((todayWeekday - calendar.firstWeekday + 7) % 7),
            "weekdayRowIndex mapping mismatch for today"
        )
#endif

        return weeks
    }
}
