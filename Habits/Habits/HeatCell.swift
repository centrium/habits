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
    let onTap: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(accent.opacity(intensity))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityLabel(Text(formatted(date)))
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}