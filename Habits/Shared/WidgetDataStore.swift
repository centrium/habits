//
//  WidgetDataStore.swift
//  Habits
//
//  Created by Matt Adams on 20/03/2026.
//


import Foundation

final class WidgetDataStore {
    static let shared = WidgetDataStore()
    static let suiteName = "group.ma.cadence.shared"
    static let key = "widget_habits"
    static let widgetKind = "HabitsWidget"
    static let momentumWidgetKind = "HabitMomentumWidget"
    static let focusWidgetKind = "HabitFocusWidget"
    static let consistencyWidgetKind = "HabitConsistencyWidget"

    func load() -> [WidgetHabit] {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            assertionFailure("Shared UserDefaults suite unavailable: \(Self.suiteName)")
            WidgetHabitLogger.logStorageFailure(
                context: "load",
                reason: "Failed to resolve shared UserDefaults suite"
            )
            return []
        }

        guard let data = defaults.data(forKey: Self.key) else {
            WidgetHabitLogger.logWidgetRead(count: 0)
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([WidgetHabit].self, from: data)
            WidgetHabitLogger.logWidgetRead(count: decoded.count)
            return decoded
        } catch {
            WidgetHabitLogger.logStorageFailure(
                context: "load",
                reason: "Failed to decode widget habits. Raw data size: \(data.count) bytes. Error: \(error.localizedDescription)"
            )
            return []
        }
    }

    @discardableResult
    func save(_ habits: [WidgetHabit]) -> Bool {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            assertionFailure("Shared UserDefaults suite unavailable: \(Self.suiteName)")
            WidgetHabitLogger.logStorageFailure(
                context: "save",
                reason: "Failed to resolve shared UserDefaults suite"
            )
            return false
        }

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
                colorHex: habit.colorHex,
                momentumScore: habit.momentumScore,
                heatmapAggregationKind: habit.heatmapAggregationKind,
                recentActivity: habit.recentActivity
            )
        }

        do {
            let data = try JSONEncoder().encode(validatedHabits)
            defaults.set(data, forKey: Self.key)

            for habit in validatedHabits {
                WidgetHabitLogger.logCompactSummary(
                    habitName: habit.name,
                    goalType: habit.goalType,
                    progress: habit.progress
                )
            }

            WidgetHabitLogger.logWidgetWrite(count: validatedHabits.count)
            return true
        } catch {
            WidgetHabitLogger.logStorageFailure(
                context: "save",
                reason: "Failed to encode widget habits: \(error.localizedDescription)"
            )
            return false
        }
    }
}
