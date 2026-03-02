import Foundation
@testable import Habits

enum HabitDetailTestFixtures {
    static let locale = Locale(identifier: "en_US_POSIX")

    static func makeCalendar(
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current,
        firstWeekday: Int = 1
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    static func makeFrequencyHabit(
        goalPeriod: GoalPeriod = .monthly,
        target: Int = 1,
        calendar: Calendar
    ) -> Habit {
        Habit(
            name: "Frequency",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: goalPeriod,
            goalType: .frequency,
            streakTarget: target,
            createdAt: makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        )
    }

    static func makeCumulativeHabit(
        goalPeriod: GoalPeriod = .monthly,
        target: Double = 10,
        unit: String = "pages",
        calendar: Calendar
    ) -> Habit {
        Habit(
            name: "Cumulative",
            colorHex: "#FFFFFF",
            hasStreakGoal: true,
            goalPeriod: goalPeriod,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: target,
            unit: unit,
            createdAt: makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        )
    }
}
