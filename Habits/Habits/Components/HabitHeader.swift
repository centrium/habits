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
    let calendar: Calendar
    let weekStartPreference: WeekStartPreference
    let showsQuickLogButton: Bool
    let showsInlineProgressText: Bool
    let secondaryTextOverride: String?
    let currentStreak: Int?
    let progressFractionOverride: Double?
    let isCompleteOverride: Bool?
    let onQuickLog: (Date) -> Void
    let onQuickLogLongPress: ((Date) -> Void)?

    init(
        habit: Habit,
        selectedDate: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        showsQuickLogButton: Bool,
        showsInlineProgressText: Bool,
        secondaryTextOverride: String?,
        currentStreak: Int? = nil,
        progressFractionOverride: Double? = nil,
        isCompleteOverride: Bool? = nil,
        onQuickLog: @escaping (Date) -> Void,
        onQuickLogLongPress: ((Date) -> Void)? = nil
    ) {
        self.habit = habit
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.weekStartPreference = weekStartPreference
        self.showsQuickLogButton = showsQuickLogButton
        self.showsInlineProgressText = showsInlineProgressText
        self.secondaryTextOverride = secondaryTextOverride
        self.currentStreak = currentStreak
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
        let progressText = showsInlineProgressText
            ? (habit.inlineProgressText(
                for: selectedDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            ) ?? "")
            : ""

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
        progressFractionOverride ?? habit.progressFraction(
            for: selectedDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ) ?? 0
    }

    private var isComplete: Bool {
        isCompleteOverride ?? habit.isComplete(
            for: selectedDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
    }

    private var quickLogAccessibilityLabel: String {
        let dateText = selectedDate.formatted(date: .abbreviated, time: .omitted)
        return "Log \(habit.name) for \(dateText)"
    }

    private var resolvedCurrentStreak: Int {
        max(0, currentStreak ?? 0)
    }

    var body: some View {
        HStack(spacing: 12) {
            HabitBadge(
                iconName: iconName,
                accent: accent,
                habitName: habit.name
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(.headline)
                        .lineLimit(1)

                    HabitHeaderStreakIndicator(streak: resolvedCurrentStreak)
                }

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

private struct HabitHeaderStreakIndicator: View {
    let streak: Int

    private var showsIndicator: Bool {
        StreakIndicatorPresentation.shouldShow(streak: streak)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text("888")
                    .font(.caption.weight(.regular))
            }
            .monospacedDigit()
            .opacity(0)

            if showsIndicator {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.82))

                    Text(StreakIndicatorPresentation.valueText(for: streak))
                        .font(.caption.weight(.regular))
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
            }
        }
        .frame(width: StreakIndicatorPresentation.reservedWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsIndicator ? "Streak \(streak)" : "")
        .accessibilityHidden(!showsIndicator)
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
