//
//  HabitHeader.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

struct HabitHeader: View {
    let habit: Habit
    let selectedDate: Date
    let showsQuickLogButton: Bool
    let showsInlineProgressText: Bool
    let secondaryTextOverride: String?
    let progressFractionOverride: Double?
    let isCompleteOverride: Bool?
    let onQuickLog: (Date) -> Void
    let onQuickLogLongPress: ((Date) -> Void)?

    init(
        habit: Habit,
        selectedDate: Date,
        showsQuickLogButton: Bool,
        showsInlineProgressText: Bool,
        secondaryTextOverride: String?,
        progressFractionOverride: Double? = nil,
        isCompleteOverride: Bool? = nil,
        onQuickLog: @escaping (Date) -> Void,
        onQuickLogLongPress: ((Date) -> Void)? = nil
    ) {
        self.habit = habit
        self.selectedDate = selectedDate
        self.showsQuickLogButton = showsQuickLogButton
        self.showsInlineProgressText = showsInlineProgressText
        self.secondaryTextOverride = secondaryTextOverride
        self.progressFractionOverride = progressFractionOverride
        self.isCompleteOverride = isCompleteOverride
        self.onQuickLog = onQuickLog
        self.onQuickLogLongPress = onQuickLogLongPress
    }

    private var accent: Color { Color(hex: habit.colorHex) }

    private var subtitleText: String {
        if let secondaryTextOverride, !secondaryTextOverride.isEmpty {
            return secondaryTextOverride
        }

        let trimmed = habit.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let progressText = showsInlineProgressText ? (habit.inlineProgressText(for: selectedDate) ?? "") : ""

        if !progressText.isEmpty {
            return progressText
        }

        return trimmed.isEmpty ? "Tap to log" : trimmed
    }

    private var iconName: String? {
        let trimmed = habit.iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var goalProgressFraction: Double {
        progressFractionOverride ?? habit.progressFraction(for: selectedDate) ?? 0
    }

    private var isComplete: Bool {
        isCompleteOverride ?? habit.isComplete(for: selectedDate)
    }

    private var quickLogAccessibilityLabel: String {
        let dateText = selectedDate.formatted(date: .abbreviated, time: .omitted)
        return "Log \(habit.name) for \(dateText)"
    }

    var body: some View {
        HStack(spacing: 12) {
            HabitBadge(
                iconName: iconName,
                accent: accent,
                habitName: habit.name
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsQuickLogButton {
                GoalProgressButton(
                    accent: accent,
                    hasGoal: habit.hasGoal,
                    progressFraction: goalProgressFraction,
                    isComplete: isComplete,
                    accessibilityLabel: quickLogAccessibilityLabel,
                    action: {
                        onQuickLog(selectedDate)
                    },
                    longPressAction: onQuickLogLongPress.map { action in
                        { action(selectedDate) }
                    }
                )
            }
        }
    }
}

struct HabitHeaderPreview: View {
    let name: String
    let subtitle: String?
    let iconName: String?
    let colorHex: String

    private var accent: Color { Color(hex: colorHex) }

    private var displaySubtitle: String {
        let trimmed = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Optional subtitle" : trimmed
    }

    private var resolvedIcon: String? {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        HStack(spacing: 12) {
            HabitBadge(
                iconName: resolvedIcon,
                accent: accent,
                habitName: name.isEmpty ? "Habit name" : name
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Habit name" : name)
                    .font(.headline)

                Text(displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
