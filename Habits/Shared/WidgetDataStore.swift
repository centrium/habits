//
//  WidgetDataStore.swift
//  Habits
//
//  Created by Matt Adams on 20/03/2026.
//


import Foundation
import WidgetKit

final class WidgetDataStore {
    static let shared = WidgetDataStore()

    private let suiteName = "group.ma.cadence.shared"
    private let key = "widget_habits"

    func save(_ habits: [WidgetHabit]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let validatedHabits = habits.map { habit in
            guard habit.goalType == .goal, habit.progress == nil else { return habit }

            WidgetHabitLogger.logValidationFailure(
                habitName: habit.name,
                reason: "Goal habit missing progress at encoding boundary"
            )

            return WidgetHabit(
                id: habit.id,
                name: habit.name,
                isCompleteToday: habit.isCompleteToday,
                streak: habit.streak,
                goalType: .goal,
                progress: 0,
                hasActivityToday: habit.hasActivityToday,
                iconName: habit.iconName,
                colorHex: habit.colorHex
            )
        }

        for habit in validatedHabits {
            WidgetHabitLogger.logCompactSummary(
                habitName: habit.name,
                goalType: habit.goalType,
                progress: habit.progress
            )
        }

        let data = try? JSONEncoder().encode(validatedHabits)
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
