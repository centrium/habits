import Foundation
import SwiftData
@testable import Habits

enum TestHabitFactory {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Habit.self, HabitLog.self, configurations: configuration)
    }

    static func createHabit(
        name: String = "Test Habit",
        reminderEnabled: Bool = true,
        reminderHour: Int = 20,
        reminderMinute: Int = 0,
        createdAt: Date = .now
    ) -> Habit {
        Habit(
            name: name,
            colorHex: "#FFFFFF",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: createdAt,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }

    static func createCompletedHabit(
        name: String = "Completed Habit",
        calendar: Calendar = .current,
        completionDate: Date = .now,
        reminderHour: Int = 20,
        reminderMinute: Int = 0
    ) -> Habit {
        let habit = createHabit(
            name: name,
            reminderEnabled: true,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            createdAt: completionDate
        )

        habit.logs.append(HabitLog(timestamp: completionDate, value: 1, calendar: calendar))
        return habit
    }
}
