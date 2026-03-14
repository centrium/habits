import Foundation
import SwiftData

enum HabitListMutation {
    static func applyOrderIndexes(
        to orderedHabits: [Habit],
        in modelContext: ModelContext
    ) {
        for (index, habit) in orderedHabits.enumerated() where habit.orderIndex != index {
            habit.orderIndex = index
        }

        try? modelContext.save()
    }

    static func normalizeOrderIndexes(in modelContext: ModelContext) {
        let sortDescriptors = [SortDescriptor(\Habit.orderIndex)]
        let descriptor = FetchDescriptor<Habit>(sortBy: sortDescriptors)
        let orderedHabits = (try? modelContext.fetch(descriptor)) ?? []
        applyOrderIndexes(to: orderedHabits, in: modelContext)
    }

    static func delete(_ habit: Habit, in modelContext: ModelContext) {
        modelContext.delete(habit)
        try? modelContext.save()
        normalizeOrderIndexes(in: modelContext)
    }
}
