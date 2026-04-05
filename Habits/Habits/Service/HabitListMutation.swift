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
        let identitySnapshot = HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calendar,
            now: referenceDate,
            windowDays: 7
        )
        let resolvedIdentityState = widgetIdentityState(from: identitySnapshot.state)
        let identityOutput = CadenceLanguage.identityOutput(
            for: habit,
            date: referenceDate,
            calendar: calendar
        )
        let mappedProgress = habit.widgetProgressForWidget(
            referenceDate: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        var widgetHabit = WidgetHabit(
            id: habit.id,
            name: habit.name,
            identityTitle: identityOutput.title,
            identityLine1: identityOutput.line1,
            identityLine2: identityOutput.line2,
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
            colorHex: habit.colorHex,
            identityState: resolvedIdentityState,
            heatmapAggregationKind: habit.widgetHeatmapAggregationKind,
            recentActivity: habit.widgetRecentActivity(
                referenceDate: referenceDate,
                calendar: calendar
            )
        )

        if habit.isGoalBasedForWidget, (widgetHabit.goalType != .goal || widgetHabit.progress == nil) {
            WidgetHabitLogger.logValidationFailure(
                habitName: habit.name,
                reason: "Correcting invalid goal payload before save"
            )
            widgetHabit = WidgetHabit(
                id: widgetHabit.id,
                name: widgetHabit.name,
                identityTitle: widgetHabit.identityTitle,
                identityLine1: widgetHabit.identityLine1,
                identityLine2: widgetHabit.identityLine2,
                isCompleteToday: widgetHabit.isCompleteToday,
                streak: widgetHabit.streak,
                goalType: .goal,
                progress: mappedProgress ?? 0,
                hasActivityToday: hasActivityToday,
                iconName: widgetHabit.iconName,
                colorHex: widgetHabit.colorHex,
                identityState: widgetHabit.identityState,
                heatmapAggregationKind: widgetHabit.heatmapAggregationKind,
                recentActivity: widgetHabit.recentActivity
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

    var widgetHeatmapAggregationKind: WidgetHeatmapAggregationKind {
        guard hasStreakGoal else { return .completion }

        switch goalType {
        case .frequency:
            return streakTarget <= 1 ? .completion : .count
        case .cumulative:
            return .value
        }
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

    func widgetRecentActivity(
        referenceDate: Date,
        calendar: Calendar
    ) -> [WidgetActivitySample] {
        let today = calendar.startOfDay(for: referenceDate)

        return (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -13 + offset, to: today) else {
                return nil
            }

            return WidgetActivitySample(
                date: date,
                value: widgetActivityValue(on: date, calendar: calendar)
            )
        }
    }

    func widgetActivityValue(
        on date: Date,
        calendar: Calendar
    ) -> Double {
        let dayLogs = logs(on: date, calendar: calendar)

        switch widgetHeatmapAggregationKind {
        case .completion:
            return dayLogs.isEmpty ? 0 : 1
        case .count:
            return Double(dayLogs.reduce(0) { partialResult, log in
                partialResult + max(0, log.frequencyContribution)
            })
        case .value:
            return dayLogs.reduce(0) { partialResult, log in
                partialResult + max(0, log.numericValue)
            }
        }
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
            let widgetKinds = [
                WidgetDataStore.widgetKind,
                WidgetDataStore.identityStateWidgetKind,
                WidgetDataStore.focusWidgetKind,
                WidgetDataStore.consistencyWidgetKind,
            ]

            for kind in widgetKinds {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        } else {
            WidgetHabitLogger.logStorageFailure(
                context: "sync",
                reason: "Skipping widget reload because write failed"
            )
        }

        return didWrite
    }
}

private func widgetIdentityState(from state: HabitIdentityState) -> WidgetHabitIdentityState {
    switch state {
    case .starting:
        return .starting
    case .building:
        return .building
    case .holding:
        return .holding
    case .returning:
        return .returning
    }
}

extension ModelContext {
    @discardableResult
    func saveWithoutWidgetSync() -> Bool {
        do {
            try save()
            return true
        } catch {
            WidgetHabitLogger.logStorageFailure(
                context: "saveOnly",
                reason: "ModelContext save failed: \(error.localizedDescription)"
            )
            return false
        }
    }

    @discardableResult
    func saveAndSyncWidgetData() -> Bool {
        guard saveWithoutWidgetSync() else {
            return false
        }

        return WidgetDataSync.sync(in: self)
    }
}

enum HabitListMutation {
    @discardableResult
    static func applyOrderIndexesInMemory(to orderedHabits: [Habit]) -> Bool {
        var didChange = false

        for (index, habit) in orderedHabits.enumerated() where habit.orderIndex != index {
            habit.orderIndex = index
            didChange = true
        }

        return didChange
    }

    static func applyOrderIndexes(
        to orderedHabits: [Habit],
        in modelContext: ModelContext
    ) {
        _ = applyOrderIndexesInMemory(to: orderedHabits)
        _ = modelContext.saveAndSyncWidgetData()
    }

    @discardableResult
    static func persistOrderChanges(in modelContext: ModelContext) -> Bool {
        modelContext.saveAndSyncWidgetData()
    }

    static func normalizeOrderIndexes(in modelContext: ModelContext) {
        let sortDescriptors = [SortDescriptor(\Habit.orderIndex)]
        let descriptor = FetchDescriptor<Habit>(sortBy: sortDescriptors)
        let orderedHabits = (try? modelContext.fetch(descriptor)) ?? []
        applyOrderIndexes(to: orderedHabits, in: modelContext)
    }

    static func delete(_ habit: Habit, in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.orderIndex)])
        let allHabits = (try? modelContext.fetch(descriptor)) ?? []

        for child in allHabits where child.triggerHabitID == habit.id {
            child.triggerHabitID = nil
        }

        modelContext.delete(habit)
        _ = modelContext.saveAndSyncWidgetData()
        normalizeOrderIndexes(in: modelContext)
    }
}
