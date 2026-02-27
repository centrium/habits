//
//  CalendarDayCell.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let intensity: Double
    let accent: Color
    let isInDisplayedMonth: Bool
    let isDisabled: Bool
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .foregroundStyle(!isInDisplayedMonth || isDisabled ? Color.secondary : Color.primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(backgroundOpacity))
                )
                .opacity(isInDisplayedMonth ? 1.0 : 0.45)
                .overlay(selectionOverlay)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var backgroundOpacity: Double {
        if !isInDisplayedMonth {
            return 0.06
        }
        if isDisabled {
            return min(intensity, 0.08)
        }
        return intensity
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

        return RoundedRectangle(cornerRadius: 8)
            .strokeBorder(strokeColor ?? .clear, lineWidth: lineWidth)
    }
}
