//
//  HeatmapGrid.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct HeatmapGrid: View {
    let accent: Color
    let days: [Date]
    let columnsCount: Int
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let intensityFor: (Date) -> Double
    let onTapDay: (Date) -> Void

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(cellSize), spacing: cellSpacing),
            count: columnsCount
        )

        LazyVGrid(columns: columns, spacing: cellSpacing) {
            ForEach(days, id: \.self) { day in
                let intensity = intensityFor(day)

                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.opacity(intensity))
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapDay(day)
                    }
                    .accessibilityLabel(Text(formatted(day)))
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}