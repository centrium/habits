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
    let intensity: Double
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
            .scaleEffect(isActive ? 1 : 0.96)
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
            strokeColor = Color.primary.opacity(style.todayStrokeOpacity)
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

    private var visualIntensity: Double {
        style.visualIntensity(for: intensity)
    }

    private var isActive: Bool {
        visualIntensity > 0
    }

    private var fillColor: Color {
        if isLocked {
            return Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28)
        }

        guard isActive else {
            return style.inactiveStrokeColor.opacity(
                min(style.inactiveFillOpacity * inactiveEmphasis, 1)
            )
        }

        return accent.opacity(visualIntensity)
    }

    private var borderColor: Color {
        if isLocked {
            return Color.white.opacity(colorScheme == .dark ? 0.16 : 0.4)
        }

        guard isActive else {
            return style.inactiveStrokeColor.opacity(
                min(style.inactiveStrokeOpacity * inactiveEmphasis, 1)
            )
        }

        return accent.opacity(max(style.activeBorderOpacity(for: intensity), visualIntensity * 0.22))
    }

    private var pixelLineWidth: CGFloat {
        1 / max(displayScale, 1)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
