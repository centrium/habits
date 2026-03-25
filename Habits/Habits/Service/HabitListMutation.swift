import Foundation
import SwiftData
import WidgetKit

func mapToWidgetHabits(
    _ habits: [Habit],
    referenceDate: Date = .now,
    calendar: Calendar = .current,
    weekStartPreference: WeekStartPreference = .system
) -> [WidgetHabit] {
    habits.map { habit in
        let widgetGoalType = habit.widgetGoalTypeForWidget
        let hasActivityToday = !habit.logs(on: referenceDate, calendar: calendar).isEmpty
        let mappedProgress = habit.widgetProgressForWidget(
            referenceDate: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        var widgetHabit = WidgetHabit(
            id: habit.id,
            name: habit.name,
            isCompleteToday: habit.isComplete(
                for: referenceDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            ),
            streak: habit.currentStreak(
                referenceDate: referenceDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            ),
            goalType: widgetGoalType,
            progress: mappedProgress,
            hasActivityToday: hasActivityToday,
            iconName: habit.iconName,
            colorHex: habit.colorHex
        )

        if habit.isGoalBasedForWidget, (widgetHabit.goalType != .goal || widgetHabit.progress == nil) {
            WidgetHabitLogger.logValidationFailure(
                habitName: habit.name,
                reason: "Correcting invalid goal payload before save"
            )
            widgetHabit = WidgetHabit(
                id: widgetHabit.id,
                name: widgetHabit.name,
                isCompleteToday: widgetHabit.isCompleteToday,
                streak: widgetHabit.streak,
                goalType: .goal,
                progress: mappedProgress ?? 0,
                hasActivityToday: hasActivityToday,
                iconName: widgetHabit.iconName,
                colorHex: widgetHabit.colorHex
            )
        }

        WidgetHabitLogger.log(
            context: "mapped",
            habitName: widgetHabit.name,
            goalType: widgetHabit.goalType,
            progress: widgetHabit.progress
        )

        return widgetHabit
    }
}

private extension Habit {
    var widgetGoalTypeForWidget: WidgetGoalType {
        guard hasStreakGoal else { return .openEnded }

        switch goalType {
        case .frequency:
            return streakTarget <= 1 ? .binary : .goal
        case .cumulative:
            return .goal
        }
    }

    var isGoalBasedForWidget: Bool {
        widgetGoalTypeForWidget == .goal
    }

    func widgetProgressForWidget(
        referenceDate: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> Double? {
        guard isGoalBasedForWidget else { return nil }
        let rawProgress = progressFraction(
            for: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ) ?? 0
        let clamped = min(max(rawProgress, 0), 1)
        return clamped.isFinite ? clamped : 0
    }
}

enum WidgetDataSync {
    @discardableResult
    static func sync(in modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.orderIndex)])
        let habits = (try? modelContext.fetch(descriptor)) ?? []
        let widgetHabits = mapToWidgetHabits(habits)
        let didWrite = WidgetDataStore.shared.save(widgetHabits)

        if didWrite {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetDataStore.widgetKind)
        } else {
            WidgetHabitLogger.logStorageFailure(
                context: "sync",
                reason: "Skipping widget reload because write failed"
            )
        }

        return didWrite
    }
}

extension ModelContext {
    @discardableResult
    func saveAndSyncWidgetData() -> Bool {
        do {
            try save()
        } catch {
            WidgetHabitLogger.logStorageFailure(
                context: "saveAndSync",
                reason: "ModelContext save failed: \(error.localizedDescription)"
            )
            return false
        }

        return WidgetDataSync.sync(in: self)
    }
}

enum HabitListMutation {
    static func applyOrderIndexes(
        to orderedHabits: [Habit],
        in modelContext: ModelContext
    ) {
        for (index, habit) in orderedHabits.enumerated() where habit.orderIndex != index {
            habit.orderIndex = index
        }

        _ = modelContext.saveAndSyncWidgetData()
    }

    static func normalizeOrderIndexes(in modelContext: ModelContext) {
        let sortDescriptors = [SortDescriptor(\Habit.orderIndex)]
        let descriptor = FetchDescriptor<Habit>(sortBy: sortDescriptors)
        let orderedHabits = (try? modelContext.fetch(descriptor)) ?? []
        applyOrderIndexes(to: orderedHabits, in: modelContext)
    }

    static func delete(_ habit: Habit, in modelContext: ModelContext) {
        modelContext.delete(habit)
        _ = modelContext.saveAndSyncWidgetData()
        normalizeOrderIndexes(in: modelContext)
    }
}
