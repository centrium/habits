//
//  HeatCell.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct HeatCell: View {
    let date: Date
    let accent: Color
    let intensity: Double
    let size: CGFloat
    let isSelected: Bool
    let isToday: Bool
    let isInteractive: Bool
    let onTap: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(accent.opacity(intensity * 0.6))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .overlay(selectionOverlay)
            .contentShape(Rectangle())
            .allowsHitTesting(isInteractive)
            .onTapGesture {
                guard isInteractive else { return }
                onTap()
            }
            .accessibilityLabel(Text(formatted(date)))
    }

    private var selectionOverlay: some View {
        let strokeColor: Color?
        let lineWidth: CGFloat

        if isSelected {
            strokeColor = Color.white.opacity(0.6)
            lineWidth = 2
        } else if isToday {
            strokeColor = Color.primary.opacity(0.35)
            lineWidth = 1
        } else {
            strokeColor = nil
            lineWidth = 0
        }

        return RoundedRectangle(cornerRadius: 2)
            .strokeBorder(strokeColor ?? .clear, lineWidth: lineWidth)
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
