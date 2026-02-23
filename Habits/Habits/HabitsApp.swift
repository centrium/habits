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
        var body: some Scene {
            WindowGroup {
                HabitsListView()
                    .preferredColorScheme(.dark) // MVP: match the vibe
            }
            .modelContainer(for: [Habit.self, HabitLog.self])
        }
    }

