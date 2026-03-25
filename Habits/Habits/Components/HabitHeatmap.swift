//
//  HabitHeatmap.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI


struct HabitHeatmap: View {
    @EnvironmentObject private var purchaseService: PurchaseService

    let habit: Habit
    let calendarProvider: CalendarProvider
    let style: HeatmapStyleConfiguration = .premiumDefault
    let selectedDate: Date
    let isInteractive: Bool
    let onSelectDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    init(
        habit: Habit,
        calendarProvider: CalendarProvider,
        selectedDate: Date,
        isInteractive: Bool,
        onSelectDay: @escaping (Date) -> Void,
        onTapLockedDay: @escaping (Date) -> Void = { _ in }
    ) {
        self.habit = habit
        self.calendarProvider = calendarProvider
        self.selectedDate = selectedDate
        self.isInteractive = isInteractive
        self.onSelectDay = onSelectDay
        self.onTapLockedDay = onTapLockedDay
    }

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
        let now = Date()
        let timeline = HeatmapTimelineBuilder.yearTimeline(
            endingAt: now,
            calendar: calendarProvider.calendar,
        )
        let cells = HeatmapService(
            calendar: calendarProvider.calendar,
            premiumStatus: purchaseService.premiumStatus,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: timeline.dateRange(calendar: calendarProvider.calendar),
            goal: HabitGoal.from(habit: habit)
        )

        GitHubHeatmapGrid(
            accent: accent,
            style: style,
            calendarProvider: calendarProvider,
            weeks: timeline.weeks,
            selectedDate: selectedDate,
            isInteractive: isInteractive,
            cells: cells,
            onTapDay: { day in
                onSelectDay(day)
            },
            onTapLockedDay: { day in
                onTapLockedDay(day)
            }
        )
        .padding(.top, style.titleToGridSpacing)
        .frame(height: heatmapHeight)
    }
}
