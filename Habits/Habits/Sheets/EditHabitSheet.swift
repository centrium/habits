//
//  EditHabitSheet.swift
//  Habits
//
//  Created by Matt Adams on 26/02/2026.
//


import SwiftUI
import SwiftData

struct EditHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var habit: Habit

    @State private var name: String
    @State private var subtitle: String
    @State private var selectedHex: String
    @State private var iconName: String?
    @State private var hasStreakGoal: Bool
    @State private var streakGoalType: StreakGoalType
    @State private var streakTarget: Int

    private let palette: [(String, String)] = [
        ("Violet", "#7C3AED"),
        ("Blue",   "#3B82F6"),
        ("Mint",   "#34D399"),
        ("Amber",  "#F59E0B"),
        ("Pink",   "#EC4899"),
        ("Teal",   "#14B8A6")
    ]

    init(habit: Habit) {
        self.habit = habit

        _name = State(initialValue: habit.name)
        _subtitle = State(initialValue: habit.subtitle ?? "")
        _selectedHex = State(initialValue: habit.colorHex)
        _iconName = State(initialValue: habit.iconName)

        _hasStreakGoal = State(initialValue: habit.hasStreakGoal)
        _streakGoalType = State(initialValue: habit.streakGoalType)
        _streakTarget = State(initialValue: habit.streakTarget)
    }

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
                submitTitle: "Save"
            ) {
                saveChanges()
                dismiss()
            }
            .navigationTitle("Edit Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DismissButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(isUnchanged)
                }
            }
        }
    }

    private var isUnchanged: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedName == habit.name &&
               (trimmedSubtitle.isEmpty ? nil : trimmedSubtitle) == habit.subtitle &&
               selectedHex == habit.colorHex &&
               iconName == habit.iconName &&
               hasStreakGoal == habit.hasStreakGoal &&
               streakGoalType == habit.streakGoalType &&
               streakTarget == habit.streakTarget
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSubtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle

        let trimmedIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalIcon = trimmedIcon.isEmpty ? nil : trimmedIcon

        habit.name = trimmedName
        habit.subtitle = finalSubtitle
        habit.iconName = finalIcon
        habit.colorHex = selectedHex

        habit.hasStreakGoal = hasStreakGoal
        habit.streakGoalType = streakGoalType
        habit.streakTarget = streakTarget

        try? modelContext.save()
    }
}
