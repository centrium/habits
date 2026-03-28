//
//  HabitHeatmap.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

struct HabitHeatmap: View {
    @EnvironmentObject private var purchaseService: PurchaseService
    @State private var cache = HeatmapMetricsCache()

    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let style: HeatmapStyleConfiguration = .premiumDefault
    let selectedDate: Date
    let earliestVisibleDate: Date?
    let isInteractive: Bool
    let onSelectDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    init(
        habit: Habit,
        service: HabitLogService,
        calendarProvider: CalendarProvider,
        selectedDate: Date,
        earliestVisibleDate: Date? = nil,
        isInteractive: Bool,
        onSelectDay: @escaping (Date) -> Void,
        onTapLockedDay: @escaping (Date) -> Void = { _ in }
    ) {
        self.habit = habit
        self.service = service
        self.calendarProvider = calendarProvider
        self.selectedDate = selectedDate
        self.earliestVisibleDate = earliestVisibleDate
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
        let fullGridDays = buildFullHeatmapDays(from: timeline.weeks)
        let lockGate = PremiumHistoryGate.Context(
            calendar: calendarProvider.calendar,
            premiumStatus: purchaseService.premiumStatus,
            now: now
        )

        let cacheKey = HeatmapMetricsCacheKey(
            habitID: habit.id,
            revision: service.metricsRevision(for: habit.id),
            calendarIdentifier: calendarProvider.calendar.identifier,
            timeZoneIdentifier: calendarProvider.calendar.timeZone.identifier,
            firstWeekday: calendarProvider.calendar.firstWeekday,
            earliestVisibleDate: earliestVisibleDate
        )

        let entry = cache.entry(key: cacheKey) {
            let dayMetrics = service.dayMetrics(for: habit, on: fullGridDays)
            let intensityMap = Dictionary(uniqueKeysWithValues: fullGridDays.map { day in
                (day, computeIntensity(for: day, dayMetrics: dayMetrics, lockGate: lockGate))
            })

            return HeatmapMetricsCache.Entry(
                dayMetrics: dayMetrics,
                intensityMap: intensityMap,
                days: fullGridDays
            )
        }

        let lockedDates = Set(entry.days.filter { lockGate.isLocked(date: $0) })

        return GitHubHeatmapGrid(
            accent: accent,
            style: style,
            calendarProvider: calendarProvider,
            weeks: timeline.weeks,
            selectedDate: selectedDate,
            isInteractive: isInteractive,
            intensityByDate: entry.intensityMap,
            lockedDates: lockedDates,
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

    private func buildFullHeatmapDays(from weeks: [Week]) -> [Date] {
        weeks
            .flatMap(\.days)
            .compactMap { $0 }
            .map { calendarProvider.calendar.startOfDay(for: $0) }
    }

    private func computeIntensity(
        for day: Date,
        dayMetrics: [Date: HabitDayMetrics],
        lockGate: PremiumHistoryGate.Context
    ) -> Double {
        if lockGate.isLocked(date: day) {
            return 0
        }

        return clamp(dayMetrics[day]?.intensity ?? 0)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
