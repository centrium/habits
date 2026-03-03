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
    @StateObject private var userSettings = UserSettings()

    var body: some Scene {
        WindowGroup {
            HabitsListView()
                .environmentObject(userSettings)
                .preferredColorScheme(.dark) // MVP: match the vibe
        }
        .modelContainer(for: [Habit.self, HabitLog.self])
    }
}
