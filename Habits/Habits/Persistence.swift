import Foundation
import SwiftData

enum Persistence {
    static func makeAppContainer() throws -> ModelContainer {

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            fatalError("Tests must not use the production container")
        }

        return try ModelContainer(
            for: Habit.self,
            HabitLog.self
        )
    }
    
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(for: Habit.self, HabitLog.self, configurations: config)
    }
}
