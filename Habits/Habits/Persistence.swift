import Foundation
import SwiftData

enum Persistence {
    nonisolated static func makeAppContainer() throws -> ModelContainer {

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            fatalError("Tests must not use the production container")
        }

        return try ModelContainer(
            for: Habit.self,
            HabitReminder.self,
            HabitLog.self
        )
    }
    
    nonisolated static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: Habit.self,
            HabitReminder.self,
            HabitLog.self,
            configurations: config
        )
    }
}
