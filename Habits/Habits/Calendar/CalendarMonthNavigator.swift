import Foundation

struct CalendarMonthNavigator {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func visibleMonth(for selectedDate: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        return calendar.date(from: components) ?? selectedDate
    }

    func adjacentMonth(from month: Date, offset: Int) -> Date {
        let normalizedMonth = visibleMonth(for: month)
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: normalizedMonth) else {
            return normalizedMonth
        }
        return visibleMonth(for: nextMonth)
    }

    func isCurrentMonth(_ month: Date, today: Date) -> Bool {
        calendar.isDate(visibleMonth(for: month), equalTo: today, toGranularity: .month)
    }
}
