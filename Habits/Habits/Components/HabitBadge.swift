//
//  HabitBadge.swift
//  Habits
//
//  Created by Matt Adams on 26/02/2026.
//

import SwiftUI


struct HabitBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let iconName: String?
    let accent: Color
    let habitName: String
    var size: CGFloat = 26

    private var resolvedIcon: String? {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var visualSize: CGFloat {
        size * 0.87
    }

    private var iconTint: Color {
        accent.opacity(colorScheme == .dark ? 0.9 : 0.82)
    }

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(systemName: resolvedIcon)
                    .font(.system(size: visualSize * 0.8, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: visualSize, height: visualSize)
                    .accessibilityLabel("\(habitName) icon")
            } else {
                Circle()
                    .fill(accent.opacity(colorScheme == .dark ? 0.84 : 0.72))
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.2), lineWidth: 0.7)
                    }
                    .frame(width: visualSize, height: visualSize)
                    .accessibilityHidden(true)
            }
        }
    }
}
