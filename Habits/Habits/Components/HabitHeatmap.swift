//
//  HabitHeatmap.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI


struct HabitHeatmap: View {
    let habit: Habit
    let service: HabitLogService
    let selectedDate: Date
    let onSelectDay: (Date) -> Void

    // 🔒 Locked design constants
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 4
    private let monthLabelHeight: CGFloat = 14

    private var accent: Color {
        Color(hex: habit.colorHex)
    }

    private var gridHeight: CGFloat {
        (cellSize * 7) + (cellSpacing * 6)
    }

    private var heatmapHeight: CGFloat {
        monthLabelHeight + gridHeight
    }

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let weekWidth = cellSize + cellSpacing
            let numberOfWeeks = min(20, Int(availableWidth / weekWidth))

            let weeks = HeatmapCalendar.makeWeeks(
                endingAt: Date(),
                numberOfWeeks: numberOfWeeks
            )

            GitHubHeatmapGrid(
                accent: accent,
                weeks: weeks,
                selectedDate: selectedDate,
                intensityFor: { day in
                    service.intensity(for: habit, on: day)
                },
                onTapDay: { day in
                    onSelectDay(day)
                    service.increment(for: habit, on: day)
                }
            )
        }
        .frame(height: heatmapHeight)
    }
}
