import Foundation

enum WeekBoundaryCalculator {
    static func startOfWeek(
        for date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        weekStart: WeekStartPreference = .system
    ) -> Date {
        let resolvedCalendar = WeekLayoutStrategy(
            baseCalendar: calendar,
            weekStartPreference: weekStart
        ).calendarForCalculations()
        let normalizedDate = resolvedCalendar.startOfDay(for: date)
        let weekday = resolvedCalendar.component(.weekday, from: normalizedDate)
        let delta = (weekday - resolvedCalendar.firstWeekday + 7) % 7
        return resolvedCalendar.date(byAdding: .day, value: -delta, to: normalizedDate) ?? normalizedDate
    }

    static func weekInterval(
        containing date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        weekStart: WeekStartPreference = .system
    ) -> DateInterval {
        let resolvedCalendar = WeekLayoutStrategy(
            baseCalendar: calendar,
            weekStartPreference: weekStart
        ).calendarForCalculations()
        let start = startOfWeek(for: date, calendar: resolvedCalendar, weekStart: .system)
        let end = resolvedCalendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    static func endOfWeek(
        for date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        weekStart: WeekStartPreference = .system
    ) -> Date {
        weekInterval(containing: date, calendar: calendar, weekStart: weekStart).end
    }
}
