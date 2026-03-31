import Foundation
import XCTest
@testable import Habits

@MainActor
final class HabitLogServiceDateSelectionTests: XCTestCase {
    func testAddLogStoresEntryOnSelectedDay() throws {
        let calendar = makeCalendar(timeZoneID: "Europe/London")
        let selectedDate = date(2026, 3, 30, hour: 14, minute: 20, calendar: calendar)
        let habit = TestHabitFactory.frequency(calendar: calendar)
        habit.logValue(on: selectedDate, value: 1, calendar: calendar)

        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.day, calendar.startOfDay(for: selectedDate))
    }

    func testAddLogNearMidnightDoesNotDriftToPreviousDay() throws {
        let calendar = makeCalendar(timeZoneID: "America/Los_Angeles")
        let selectedDate = date(2026, 4, 1, hour: 0, minute: 5, calendar: calendar)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let habit = TestHabitFactory.frequency(calendar: calendar)
        habit.logValue(on: selectedDate, value: 1, calendar: calendar)

        let storedDay = try XCTUnwrap(habit.logs.first?.day)
        XCTAssertEqual(storedDay, calendar.startOfDay(for: selectedDate))
        XCTAssertNotEqual(storedDay, calendar.startOfDay(for: previousDay))
    }

    func testAddLogUsesCalendarTimeZoneForDayBucketing() throws {
        let calendar = makeCalendar(timeZoneID: "Pacific/Kiritimati")
        let selectedDate = date(2026, 3, 30, hour: 0, minute: 30, calendar: calendar)
        let habit = TestHabitFactory.frequency(calendar: calendar)
        habit.logValue(on: selectedDate, value: 1, calendar: calendar)

        let storedDay = try XCTUnwrap(habit.logs.first?.day)
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: storedDay)
        XCTAssertEqual(dayComponents.year, 2026)
        XCTAssertEqual(dayComponents.month, 3)
        XCTAssertEqual(dayComponents.day, 30)
    }

    private func makeCalendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
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
        guard let resolved = calendar.date(from: components) else {
            fatalError("Unable to create deterministic test date")
        }
        return resolved
    }
}
