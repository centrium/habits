import Foundation
import XCTest
@testable import Habits

final class CurrentDayResolverTests: BaseTestCase {
    func testCurrentDayResolvesWithProvidedNow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt

        let nearMidnight = date(2026, 3, 31, hour: 0, minute: 2, calendar: calendar)
        let previousDay = date(2026, 3, 30, hour: 23, minute: 58, calendar: calendar)

        let resolved = CurrentDayResolver.currentDay(calendar: calendar, now: nearMidnight)

        XCTAssertEqual(resolved, calendar.startOfDay(for: nearMidnight))
        XCTAssertNotEqual(resolved, calendar.startOfDay(for: previousDay))
    }

    func testCurrentDayRespectsCalendarTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Kiritimati") ?? .gmt

        let now = date(2026, 3, 30, hour: 0, minute: 30, calendar: calendar)
        let resolved = CurrentDayResolver.currentDay(calendar: calendar, now: now)
        let components = calendar.dateComponents([.year, .month, .day], from: resolved)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 30)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
