//
//  HabitHeader.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

struct HabitHeader: View {
    let habit: Habit
    let showsQuickLogButton: Bool
    let onQuickLog: () -> Void

    private var accent: Color { Color(hex: habit.colorHex) }

    private var subtitleText: String {
        let trimmed = habit.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Tap today to log" : trimmed
    }

    private var iconName: String? {
        let trimmed = habit.iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
                Button {
                    onQuickLog()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .padding(6)
                .buttonStyle(.plain)
                .accessibilityLabel("Log today for \(habit.name)")
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
