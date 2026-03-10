//
//  HeatCell.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct HeatCell: View {
    @Environment(\.displayScale) private var displayScale

    let date: Date
    let accent: Color
    let intensity: Double
    let size: CGFloat
    let style: HeatmapStyleConfiguration
    let isSelected: Bool
    let isToday: Bool
    let isInteractive: Bool
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
            .onTapGesture {
                guard isInteractive else { return }
                onTap()
            }
            .accessibilityLabel(Text(formatted(date)))
            .animation(style.activationSpring, value: isActive)
            .animation(.easeInOut(duration: style.intensityFadeDuration), value: visualIntensity)
            .animation(style.animationStyle, value: isSelected)
            .animation(style.animationStyle, value: isToday)
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
        guard isActive else {
            return style.inactiveStrokeColor.opacity(style.inactiveFillOpacity)
        }

        return accent.opacity(visualIntensity)
    }

    private var borderColor: Color {
        guard isActive else {
            return style.inactiveStrokeColor.opacity(style.inactiveStrokeOpacity)
        }

        return accent.opacity(style.activeBorderOpacity(for: intensity))
    }

    private var pixelLineWidth: CGFloat {
        1 / max(displayScale, 1)
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
