//
//  HeatCell.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct HeatCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    let date: Date
    let accent: Color
    let intensityLevel: Int
    let size: CGFloat
    let style: HeatmapStyleConfiguration
    let isSelected: Bool
    let isToday: Bool
    let isInteractive: Bool
    let isLocked: Bool
    let inactiveEmphasis: Double
    let onTap: () -> Void

    var body: some View {
        cellShape
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay(
                cellShape
                    .strokeBorder(borderColor, lineWidth: pixelLineWidth)
            )
            .overlay(selectionOverlay)
            .contentShape(cellShape)
            .allowsHitTesting(isInteractive)
            .highPriorityGesture(
                TapGesture().onEnded {
                    guard isInteractive else { return }
                    onTap()
                }
            )
            .accessibilityLabel(Text(formatted(date)))
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private var selectionOverlay: some View {
        let strokeColor: Color?
        let lineWidth: CGFloat

        if isSelected {
            strokeColor = accent.opacity(style.selectedStrokeOpacity)
            lineWidth = style.selectedStrokeWidth
        } else if isToday {
            strokeColor = Color.secondary.opacity(style.todayStrokeOpacity)
            lineWidth = style.todayStrokeWidth
        } else {
            strokeColor = nil
            lineWidth = 0
        }

        return cellShape
            .strokeBorder(strokeColor ?? .clear, lineWidth: lineWidth)
    }

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
    }

    private var intensityVisual: IntensityVisualStyle {
        IntensityColorEngine.style(forLevel: intensityLevel, colorScheme: colorScheme)
    }

    private var fillColor: Color {
        if isLocked {
            return Color.secondary.opacity(colorScheme == .dark ? 0.08 : 0.12)
        }

        guard intensityVisual.level > 0 else {
            return colorScheme == .dark
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.06)
        }

        return intensityVisual.fill
    }

    private var borderColor: Color {
        if isLocked {
            return Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.14)
        }

        guard intensityVisual.level > 0 else {
            let opacity = colorScheme == .light
                ? max(0.07, min(style.inactiveStrokeOpacity * inactiveEmphasis, 1))
                : min(style.inactiveStrokeOpacity * inactiveEmphasis, 1)
            return Color.secondary.opacity(opacity)
        }

        return intensityVisual.border
    }

    private var pixelLineWidth: CGFloat {
        1 / max(displayScale, 1)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
