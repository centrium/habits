import Foundation

enum TestDateFactory {
    static let timeZone = TimeZone(secondsFromGMT: 0)!

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }

    static let referenceNow = date(2026, 3, 11, hour: 12, minute: 0, second: 0)

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0,
        calendar: Calendar = utcCalendar
    ) -> Date {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )

        guard let date = calendar.date(from: components) else {
            fatalError("Unable to construct deterministic test date")
        }
        return date
    }

    static func addingDays(
        _ days: Int,
        to date: Date,
        calendar: Calendar = utcCalendar
    ) -> Date {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: date) else {
            fatalError("Unable to add \(days) day(s) to deterministic test date")
        }
        return shifted
    }

    static func addingMonths(
        _ months: Int,
        to date: Date,
        calendar: Calendar = utcCalendar
    ) -> Date {
        guard let shifted = calendar.date(byAdding: .month, value: months, to: date) else {
            fatalError("Unable to add \(months) month(s) to deterministic test date")
        }
        return shifted
    }
}
