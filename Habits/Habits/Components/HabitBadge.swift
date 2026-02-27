//
//  HabitBadge.swift
//  Habits
//
//  Created by Matt Adams on 26/02/2026.
//

import SwiftUI


struct HabitBadge: View {
    let iconName: String?
    let accent: Color
    let habitName: String
    var size: CGFloat = 26

    private var resolvedIcon: String? {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(systemName: resolvedIcon)
                    .font(.system(size: size * 0.85, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: size, height: size)
                    .accessibilityLabel("\(habitName) icon")
            } else {
                Circle()
                    .fill(accent.opacity(0.9))
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            }
        }
    }
}
