import Foundation

struct TimelineContext {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func isViewingPast(selectedDate: Date, today: Date) -> Bool {
        calendar.startOfDay(for: selectedDate) < calendar.startOfDay(for: today)
    }

    func asOfExclusiveUpperBound(for selectedDate: Date, today: Date) -> Date {
        let normalizedSelectedDate = calendar.startOfDay(for: selectedDate)
        let normalizedToday = calendar.startOfDay(for: today)

        if normalizedSelectedDate < normalizedToday {
            return calendar.date(byAdding: .day, value: 1, to: normalizedSelectedDate) ?? normalizedSelectedDate
        }

        return today
    }

    func periodContextLabel(for goalPeriod: GoalPeriod, selectedDate: Date, today: Date) -> String {
        if isViewingPast(selectedDate: selectedDate, today: today) {
            return goalPeriod.displayLabel(for: selectedDate, calendar: calendar)
        }

        return goalPeriod.relativeLabel
    }
}
