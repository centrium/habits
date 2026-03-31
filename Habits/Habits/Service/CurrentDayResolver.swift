import Foundation

enum CurrentDayResolver {
    static func currentDay(calendar: Calendar, now: Date = Date()) -> Date {
        calendar.startOfDay(for: now)
    }
}
