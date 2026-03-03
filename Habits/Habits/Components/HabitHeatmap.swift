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
    let calendarProvider: CalendarProvider
    let style: HeatmapStyleConfiguration = .premiumDefault
    let selectedDate: Date
    let isInteractive: Bool
    let onSelectDay: (Date) -> Void

    private var accent: Color {
        Color(hex: habit.colorHex)
    }

    private var gridHeight: CGFloat {
        (style.cellSize * 7) + (style.verticalSpacing * 6)
    }

    private var heatmapHeight: CGFloat {
        style.titleToGridSpacing + style.monthLabelHeight + style.monthLabelToGridSpacing + gridHeight
    }

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(
                0,
                geo.size.width - style.dayLabelWidth - style.rowLabelLeadingPadding - style.horizontalSpacing
            )
            let weekWidth = style.cellSize + style.horizontalSpacing
            let numberOfWeeks = max(1, min(20, Int((availableWidth + style.horizontalSpacing) / weekWidth)))
            let layoutService = HeatmapLayoutService(calendarProvider: calendarProvider)

            let weeks = layoutService.makeWeeks(
                endingAt: Date(),
                numberOfWeeks: numberOfWeeks
            )

            GitHubHeatmapGrid(
                accent: accent,
                style: style,
                calendarProvider: calendarProvider,
                weeks: weeks,
                selectedDate: selectedDate,
                isInteractive: isInteractive,
                intensityFor: { day in
                    service.intensity(for: habit, on: day)
                },
                onTapDay: { day in
                    onSelectDay(day)
                }
            )
            .padding(.top, style.titleToGridSpacing)
        }
        .frame(height: heatmapHeight)
    }
}
