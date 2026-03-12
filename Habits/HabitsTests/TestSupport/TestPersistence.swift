import SwiftData
@testable import Habits

struct TestPersistence {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Habit.self,
            HabitLog.self,
            configurations: configuration
        )
        context = ModelContext(container)
    }

    @discardableResult
    func insert(_ habit: Habit) -> Habit {
        context.insert(habit)
        return habit
    }

    func save() throws {
        try context.save()
    }
}
