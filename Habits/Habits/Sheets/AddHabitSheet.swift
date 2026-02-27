//
//  AddHabitSheet.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI
import SwiftData

struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var selectedHex: String = "#7C3AED"
    @State private var iconName: String? = nil
    @State private var hasStreakGoal: Bool = false
    @State private var streakGoalType: StreakGoalType = .daily
    @State private var streakTarget: Int = 1

    private let palette: [(String, String)] = [
        ("Violet", "#7C3AED"),
        ("Blue",   "#3B82F6"),
        ("Mint",   "#34D399"),
        ("Amber",  "#F59E0B"),
        ("Pink",   "#EC4899"),
        ("Teal",   "#14B8A6")
    ]

    var body: some View {
        NavigationStack {
            HabitFormView(
                name: $name,
                subtitle: $subtitle,
                selectedHex: $selectedHex,
                iconName: $iconName,
                hasStreakGoal: $hasStreakGoal,
                streakGoalType: $streakGoalType,
                streakTarget: $streakTarget,
                palette: palette,
                submitTitle: "Add"
            ) {
                addHabit()
                dismiss()
            }
            .onChange(of: hasStreakGoal) { _, newValue in
                if !newValue {
                    streakGoalType = .daily
                    streakTarget = 1
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DismissButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addHabit()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSubtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle

        let trimmedIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalIcon = trimmedIcon.isEmpty ? nil : trimmedIcon

        let habit = Habit(
            name: trimmedName,
            colorHex: selectedHex,
            subtitle: finalSubtitle,
            iconName: finalIcon,
            hasStreakGoal: hasStreakGoal,
            streakGoalType: streakGoalType,
            streakTarget: streakTarget
        )

        modelContext.insert(habit)
        try? modelContext.save()
    }
}
