//
//  IconPickerSheet.swift
//  Habits
//
//  Created by Matt Adams on 26/02/2026.
//


import SwiftUI

struct IconPickerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let selectedIcon: String?
    let accentHex: String
    let onSelect: (String?) -> Void

    private var accent: Color { HabitColor.from(hex: accentHex).color }

    // Curated set — calm, neutral, habit-friendly
    private let icons: [String] = [
        "star.fill",
        "flame.fill",
        "bolt.fill",
        "heart.fill",
        "heart.text.square.fill",
        "brain.head.profile",
        "lungs.fill",
        "book.fill",
        "graduationcap.fill",
        "figure.walk",
        "figure.run",
        "figure.cooldown",
        "figure.strengthtraining.traditional",
        "dumbbell.fill",
        "bicycle",
        "drop.fill",
        "leaf.fill",
        "tree.fill",
        "moon.fill",
        "sun.max.fill",
        "bed.double.fill",
        "alarm.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "carrot.fill",
        "waterbottle.fill",
        "pills.fill",
        "cross.case.fill",
        "stethoscope",
        "bandage.fill",
        "calendar",
        "clock.fill",
        "hourglass",
        "target",
        "checkmark.seal.fill",
        "list.bullet.clipboard.fill",
        "checklist.checked",
        "chart.bar.fill",
        "chart.line.uptrend.xyaxis",
        "sparkles",
        "music.note",
        "guitars.fill",
        "paintbrush.fill",
        "camera.fill",
        "house.fill",
        "briefcase.fill",
        "gift.fill"
    ]

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 12),
        count: 5
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    // None option
                    iconCell(systemName: nil)

                    ForEach(icons, id: \.self) { icon in
                        iconCell(systemName: icon)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Choose Icon")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func iconCell(systemName: String?) -> some View {
        let isSelected = systemName == selectedIcon

        Button {
            onSelect(systemName)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(colorScheme == .light ? 0.06 : 0.08) : Color.appBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected
                                    ? accent.opacity(0.15)
                                    : (colorScheme == .light ? Color.primary.opacity(0.08) : Color.white.opacity(0.06)),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(colorScheme == .light ? (isSelected ? 0.045 : 0.03) : 0),
                        radius: colorScheme == .light ? (isSelected ? 8 : 6) : 0,
                        y: colorScheme == .light ? (isSelected ? 3 : 2) : 0
                    )

                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? accent : .primary)
                } else {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 58)
        }
        .buttonStyle(.plain)
    }
}
