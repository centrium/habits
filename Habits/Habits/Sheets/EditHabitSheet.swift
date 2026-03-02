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
    @State private var goalType: GoalType
    @State private var goalPeriod: GoalPeriod
    @State private var streakTarget: Int
    @State private var targetValue: Double
    @State private var unit: String
    @State private var allowsDecimals: Bool

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
        _goalType = State(initialValue: habit.goalType)
        _goalPeriod = State(initialValue: habit.goalPeriod)
        _streakTarget = State(initialValue: habit.streakTarget)
        _targetValue = State(initialValue: habit.targetValue ?? 1)
        _unit = State(initialValue: habit.unit ?? "")
        _allowsDecimals = State(initialValue: habit.allowsDecimals)
    }

    var body: some View {
        NavigationStack {
            HabitFormView(
                name: $name,
                subtitle: $subtitle,
                selectedHex: $selectedHex,
                iconName: $iconName,
                hasStreakGoal: $hasStreakGoal,
                goalType: $goalType,
                goalPeriod: $goalPeriod,
                streakTarget: $streakTarget,
                targetValue: $targetValue,
                unit: $unit,
                allowsDecimals: $allowsDecimals,
                palette: palette
            )
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
                    .disabled(isUnchanged || !canSave)
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
               goalType == habit.goalType &&
               goalPeriod == habit.goalPeriod &&
               streakTarget == habit.streakTarget &&
               targetValue == (habit.targetValue ?? 1) &&
               unit == (habit.unit ?? "") &&
               allowsDecimals == habit.allowsDecimals
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        guard hasStreakGoal else { return true }

        switch goalType {
        case .frequency:
            return streakTarget >= 1
        case .cumulative:
            return targetValue > 0 && !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSubtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle

        let trimmedIcon = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalIcon = trimmedIcon.isEmpty ? nil : trimmedIcon
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalUnit = trimmedUnit.isEmpty ? nil : trimmedUnit

        habit.name = trimmedName
        habit.subtitle = finalSubtitle
        habit.iconName = finalIcon
        habit.colorHex = selectedHex

        habit.hasStreakGoal = hasStreakGoal
        habit.goalType = goalType
        habit.goalPeriod = goalPeriod
        habit.streakTarget = streakTarget
        habit.targetValue = finalUnit == nil ? nil : targetValue
        habit.unit = finalUnit
        habit.allowsDecimals = allowsDecimals

        if habit.goalType == .cumulative {
            _ = habit.normalizeCumulativeLogs()
        }

        try? modelContext.save()
    }
}
