//
//  HabitsApp.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI
import SwiftData

@main
struct HabitsApp: App {
    @StateObject var deepLinkManager = DeepLinkManager.shared
    let container: ModelContainer
    
    init() {
        container = try! ModelContainer(for: Habit.self)

        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationActionHandler.shared

        NotificationService.shared.registerNotificationCategories()

        NotificationActionHandler.shared.modelContainer = container
    }

    
    @StateObject private var userSettings = UserSettings()
    

    var body: some Scene {
        WindowGroup {
            HabitsListView()
                .environmentObject(userSettings)
                .environmentObject(deepLinkManager)
                .preferredColorScheme(.dark) // MVP: match the vibe
        }
        .modelContainer(for: [Habit.self, HabitLog.self])
    }
}
