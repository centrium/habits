//
//  HeatmapGrid.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct HeatmapGrid: View {
    @Environment(\.colorScheme) private var colorScheme
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
                let visuals = IntensityColorEngine.style(
                    forLevel: IntensityColorEngine.level(for: intensity),
                    colorScheme: colorScheme
                )

                RoundedRectangle(cornerRadius: 2)
                    .fill(visuals.fill)
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(
                                visuals.level > 0
                                    ? visuals.border
                                    : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.07),
                                lineWidth: 1
                            )
                    )
                    .scaleEffect(visuals.peakScale)
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
