import Foundation

struct CalendarProvider {
    let calendar: Calendar

    init(calendar: Calendar) {
        var resolvedCalendar = calendar
        if resolvedCalendar.locale == nil {
            resolvedCalendar.locale = .autoupdatingCurrent
        }
        self.calendar = resolvedCalendar
    }

    var orderedVeryShortStandaloneWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }

        let startIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }

    func weekdayNumber(forRow row: Int) -> Int {
        ((calendar.firstWeekday - 1 + row) % 7) + 1
    }

    func rowIndex(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return rowIndex(forWeekdayNumber: weekday)
    }

    func rowIndex(forWeekdayNumber weekday: Int) -> Int {
        (weekday - calendar.firstWeekday + 7) % 7
    }

    func veryShortStandaloneWeekdaySymbol(forWeekdayNumber weekday: Int) -> String {
        calendar.veryShortStandaloneWeekdaySymbols[weekday - 1]
    }

    func heatmapRowLabel(forRow row: Int) -> String? {
        let weekday = weekdayNumber(forRow: row)

        switch weekday {
        case 2, 4, 6:
            return veryShortStandaloneWeekdaySymbol(forWeekdayNumber: weekday)
        default:
            return nil
        }
    }

    func startOfWeek(for date: Date) -> Date {
        WeekBoundaryCalculator.startOfWeek(
            for: date,
            calendar: calendar,
            weekStart: .system
        )
    }

    func weekInterval(containing date: Date) -> DateInterval {
        WeekBoundaryCalculator.weekInterval(
            containing: date,
            calendar: calendar,
            weekStart: .system
        )
    }
}
