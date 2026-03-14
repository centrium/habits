//
//  HabitsApp.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

enum RootDestination: Equatable {
    case onboarding
    case habitsList
}

enum RootViewRouter {
    static func destination(hasCompletedOnboarding: Bool) -> RootDestination {
        hasCompletedOnboarding ? .habitsList : .onboarding
    }
}

struct RootView: View {
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var userSettings: UserSettings

    var body: some View {
        switch RootViewRouter.destination(hasCompletedOnboarding: userSettings.hasCompletedOnboarding) {
        case .habitsList:
            HabitsListView()
                .environmentObject(userSettings)
                .environmentObject(deepLinkManager)
        case .onboarding:
            OnboardingView()
                .environmentObject(userSettings)
                .environmentObject(deepLinkManager)
        }
    }
}

@main
struct HabitsApp: App {
    @StateObject var deepLinkManager = DeepLinkManager.shared
    @StateObject private var userSettings = UserSettings()
    
    let container: ModelContainer

    init() {
        self.init(container: nil)
        KeyboardWarmup.warm()
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


    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(userSettings)
                .environmentObject(deepLinkManager)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
