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

    private var accent: Color { Color(hex: accentHex) }

    // Curated set — calm, neutral, habit-friendly
    private let icons: [String] = [
        "star.fill",
        "flame.fill",
        "bolt.fill",
        "heart.fill",
        "brain.head.profile",
        "book.fill",
        "figure.walk",
        "figure.run",
        "dumbbell.fill",
        "drop.fill",
        "leaf.fill",
        "moon.fill",
        "sun.max.fill",
        "bed.double.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "pills.fill",
        "cross.case.fill",
        "calendar",
        "clock.fill",
        "target",
        "checkmark.seal.fill",
        "sparkles",
        "music.note",
        "paintbrush.fill",
        "camera.fill"
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 56), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    // None option
                    iconCell(systemName: nil)

                    ForEach(icons, id: \.self) { icon in
                        iconCell(systemName: icon)
                    }
                }
                .padding(20)
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
            .frame(height: 56)
        }
        .buttonStyle(.plain)
    }
}
