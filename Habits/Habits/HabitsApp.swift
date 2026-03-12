//
//  HabitsApp.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct HabitsApp: App {
    @StateObject var deepLinkManager = DeepLinkManager.shared
    let container: ModelContainer

    init() {
        self.init(container: nil)
    }

    init(container: ModelContainer?) {
        
        let isRunningTests =
               ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if let container {
            self.container = container
        } else if isRunningTests {
                self.container = try! Persistence.makeInMemoryContainer()
        } else if let appContainer = try? Persistence.makeAppContainer() {
            self.container = appContainer
        } else {
            // Fall back to in-memory storage so test hosts do not crash during app bootstrap.
            self.container = try! Persistence.makeInMemoryContainer()
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationActionHandler.shared

        NotificationService.shared.configureModelContextProvider { [container = self.container] in
            ModelContext(container)
        }

        NotificationService.shared.registerNotificationCategories()
        NotificationActionHandler.shared.configureModelContextProvider { [container = self.container] in
            ModelContext(container)
        }
    }

    
    @StateObject private var userSettings = UserSettings()
    

    var body: some Scene {
        WindowGroup {
            HabitsListView()
                .environmentObject(userSettings)
                .environmentObject(deepLinkManager)
                .preferredColorScheme(.dark) // MVP: match the vibe
        }
        .modelContainer(container)
    }
}
