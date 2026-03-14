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
    @State private var timeline: HeatmapTimeline

    init(
        habit: Habit,
        service: HabitLogService,
        calendarProvider: CalendarProvider,
        selectedDate: Date,
        isInteractive: Bool,
        onSelectDay: @escaping (Date) -> Void
    ) {
        self.habit = habit
        self.service = service
        self.calendarProvider = calendarProvider
        self.selectedDate = selectedDate
        self.isInteractive = isInteractive
        self.onSelectDay = onSelectDay
        _timeline = State(
            initialValue: HeatmapTimelineBuilder.yearTimeline(calendar: calendarProvider.calendar)
        )
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
        GitHubHeatmapGrid(
            accent: accent,
            style: style,
            calendarProvider: calendarProvider,
            weeks: timeline.weeks,
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
        .frame(height: heatmapHeight)
        .onChange(of: calendarProvider.calendar.firstWeekday) { _, _ in
            timeline = HeatmapTimelineBuilder.yearTimeline(calendar: calendarProvider.calendar)
        }
        .onChange(of: calendarProvider.calendar.timeZone.identifier) { _, _ in
            timeline = HeatmapTimelineBuilder.yearTimeline(calendar: calendarProvider.calendar)
        }
    }
}
