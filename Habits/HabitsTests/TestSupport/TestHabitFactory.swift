import Foundation
@testable import Habits

enum TestHabitFactory {
    struct Entry {
        let timestamp: Date
        let value: Double
    }

    static func frequency(
        name: String = "Frequency Habit",
        period: GoalPeriod = .daily,
        target: Int = 1,
        hasGoal: Bool = true,
        triggerHabitID: UUID? = nil,
        createdAt: Date = TestDateFactory.referenceNow,
        entries: [Entry] = [],
        calendar: Calendar = TestDateFactory.utcCalendar
    ) -> Habit {
        let habit = Habit(
            name: name,
            colorHex: "#1F7A8C",
            hasStreakGoal: hasGoal,
            goalPeriod: period,
            goalType: .frequency,
            streakTarget: target,
            targetValue: nil,
            unit: nil,
            allowsDecimals: false,
            createdAt: createdAt,
            triggerHabitID: triggerHabitID
        )
        add(entries: entries, to: habit, calendar: calendar)
        return habit
    }

    static func cumulative(
        name: String = "Cumulative Habit",
        period: GoalPeriod = .daily,
        target: Double = 100,
        hasGoal: Bool = true,
        unit: String? = "units",
        allowsDecimals: Bool = true,
        createdAt: Date = TestDateFactory.referenceNow,
        entries: [Entry] = [],
        calendar: Calendar = TestDateFactory.utcCalendar
    ) -> Habit {
        let habit = Habit(
            name: name,
            colorHex: "#BF4342",
            hasStreakGoal: hasGoal,
            goalPeriod: period,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: target,
            unit: unit,
            allowsDecimals: allowsDecimals,
            createdAt: createdAt
        )
        add(entries: entries, to: habit, calendar: calendar)
        return habit
    }

    static func openEnded(
        name: String = "Open Habit",
        period: GoalPeriod = .daily,
        createdAt: Date = TestDateFactory.referenceNow,
        entries: [Entry] = [],
        calendar: Calendar = TestDateFactory.utcCalendar
    ) -> Habit {
        frequency(
            name: name,
            period: period,
            target: 1,
            hasGoal: false,
            createdAt: createdAt,
            entries: entries,
            calendar: calendar
        )
    }

    static func entry(
        on date: Date,
        value: Double = 1
    ) -> Entry {
        Entry(timestamp: date, value: value)
    }

    static func entryLog(
        on date: Date,
        value: Double = 1,
        createdAt: Date? = nil,
        calendar: Calendar = TestDateFactory.utcCalendar
    ) -> HabitLog {
        HabitLog(
            timestamp: date,
            value: value,
            createdAt: createdAt ?? date,
            calendar: calendar
        )
    }

    static func legacyLog(
        on day: Date,
        count: Int,
        createdAt: Date? = nil,
        calendar: Calendar = TestDateFactory.utcCalendar
    ) -> HabitLog {
        HabitLog(
            day: day,
            count: count,
            createdAt: createdAt ?? day,
            calendar: calendar
        )
    }

    static func add(
        entries: [Entry],
        to habit: Habit,
        calendar: Calendar = TestDateFactory.utcCalendar
    ) {
        for entry in entries {
            habit.logs.append(
                HabitLog(
                    timestamp: entry.timestamp,
                    value: entry.value,
                    calendar: calendar
                )
            )
        }
    }
}
