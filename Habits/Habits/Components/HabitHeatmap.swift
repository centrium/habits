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
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let style: HeatmapStyleConfiguration = .premiumDefault
    let selectedDate: Date
    let isInteractive: Bool
    let onSelectDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void
    @State private var timeline: HeatmapTimeline

    init(
        habit: Habit,
        service: HabitLogService,
        calendarProvider: CalendarProvider,
        selectedDate: Date,
        isInteractive: Bool,
        onSelectDay: @escaping (Date) -> Void,
        onTapLockedDay: @escaping (Date) -> Void = { _ in }
    ) {
        self.habit = habit
        self.service = service
        self.calendarProvider = calendarProvider
        self.selectedDate = selectedDate
        self.isInteractive = isInteractive
        self.onSelectDay = onSelectDay
        self.onTapLockedDay = onTapLockedDay
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
        let now = Date()
        let heatmapDays = timeline.weeks.flatMap(\.days).compactMap { $0 }
        let dayMetrics = service.dayMetrics(for: habit, on: heatmapDays)
        let premiumHistoryGate = PremiumHistoryGate.Context(
            calendar: calendarProvider.calendar,
            premiumStatus: purchaseService.premiumStatus,
            now: now
        )

        GitHubHeatmapGrid(
            accent: accent,
            style: style,
            calendarProvider: calendarProvider,
            weeks: timeline.weeks,
            selectedDate: selectedDate,
            isInteractive: isInteractive,
            premiumHistoryGate: premiumHistoryGate,
            intensityFor: { day in
                let normalizedDay = service.calendar.startOfDay(for: day)
                return dayMetrics[normalizedDay]?.intensity ?? 0
            },
            onTapDay: { day in
                onSelectDay(day)
            },
            onTapLockedDay: { day in
                onTapLockedDay(day)
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
