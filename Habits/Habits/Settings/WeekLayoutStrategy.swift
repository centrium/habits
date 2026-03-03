import Foundation

struct WeekLayoutStrategy {
    let baseCalendar: Calendar
    let weekStartPreference: WeekStartPreference

    init(
        baseCalendar: Calendar = .autoupdatingCurrent,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.baseCalendar = baseCalendar
        self.weekStartPreference = weekStartPreference
    }

    func calendarForCalculations() -> Calendar {
        configuredCalendar(firstWeekday: weekStartPreference.resolvedFirstWeekday(in: baseCalendar))
    }

    func calendarForCalendarView() -> Calendar {
        calendarForCalculations()
    }

    func calendarForHeatmap() -> Calendar {
        configuredCalendar(firstWeekday: WeekStartPreference.monday.resolvedFirstWeekday(in: baseCalendar))
    }

    func calendarProviderForCalculations() -> CalendarProvider {
        CalendarProvider(calendar: calendarForCalculations())
    }

    func calendarProviderForCalendarView() -> CalendarProvider {
        CalendarProvider(calendar: calendarForCalendarView())
    }

    func calendarProviderForHeatmap() -> CalendarProvider {
        CalendarProvider(calendar: calendarForHeatmap())
    }

    private func configuredCalendar(firstWeekday: Int) -> Calendar {
        var calendar = baseCalendar
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
