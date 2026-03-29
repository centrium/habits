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
    let isCompact: Bool

    init(
        habit: Habit,
        service: HabitLogService,
        calendarProvider: CalendarProvider,
        selectedDate: Date,
        earliestVisibleDate: Date? = nil,
        isInteractive: Bool,
        onSelectDay: @escaping (Date) -> Void,
        onTapLockedDay: @escaping (Date) -> Void = { _ in },
        isCompact: Bool = false
    ) {
        self.habit = habit
        self.service = service
        self.calendarProvider = calendarProvider
        self.selectedDate = selectedDate
        self.earliestVisibleDate = earliestVisibleDate
        self.isInteractive = isInteractive
        self.onSelectDay = onSelectDay
        self.onTapLockedDay = onTapLockedDay
        self.isCompact = isCompact
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
        if isCompact {
            cadenceMomentumBlock
           } else {
               fullHeatmap
           }
    }

    
    private var fullHeatmap: some View {
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
    
    private var compactHeatmap: some View {
        let revision = service.metricsRevision(for: habit.id)
        let calendar = calendarProvider.calendar
        let today = calendar.startOfDay(for: Date())

        let days: [Date] = (0..<14).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()

        return HStack(spacing: 6) {
            weekGrid(days: Array(days.prefix(7)), isRecent: false)
            weekGrid(days: Array(days.suffix(7)), isRecent: true)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(height: 40)
        .id(revision)
    }
    
    private func weekGrid(days: [Date], isRecent: Bool) -> some View {
        let calendar = calendarProvider.calendar
        let dayMetrics = service.dayMetrics(for: habit, on: days)

        let columns = Array(repeating: GridItem(.flexible(), spacing: 2.5), count: 7)

        return LazyVGrid(columns: columns, spacing: 2.5) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                let raw = clamp(dayMetrics[day]?.intensity ?? 0)
                let adjusted = pow(raw, 0.7)
                let boosted = isRecent ? min(adjusted * 1.1, 1.0) : adjusted

                RoundedRectangle(cornerRadius: 4)
                    .fill(cellColor(intensity: boosted, isRecent: isRecent))
                    .opacity(isRecent ? 1.0 : 0.25)
                    .scaleEffect(isRecent ? 1.0 : 0.90)
                    .offset(y: isRecent ? 0 : 1.5)
                    .frame(height: 14)
                

                    .overlay {
                        if calendar.isDateInToday(day) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(accent, lineWidth: 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(accent.opacity(0.15))
                                )
                        }
                    }
            }
        }
    }
    
    private func cellColor(intensity: Double, isRecent: Bool) -> Color {
        if intensity == 0 {
            return Color.primary.opacity(0.06)
        }

        let base = accent.opacity(0.25 + (0.75 * intensity))

        return isRecent
            ? base
            : base.opacity(0.7)
    }
    
    private var cadenceMomentumBlock: some View {
        VStack(alignment: .leading, spacing: 10) {

            compactHeatmap

            VStack(alignment: .leading, spacing: 2) {

                HStack {
                    Text(momentumLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(momentumColor)

                    Spacer()
                }

                Text(momentumInsight)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var momentumLabel: String {
        let last7 = recentCompletionCount(days: 7)

        switch last7 {
        case 6...7: return "Locked in"
        case 4...5: return "On track"
        case 2...3: return "Picking up"
        default: return "Falling off"
        }
    }
    
    private var momentumInsight: String {
        let last7 = recentCompletionCount(days: 7)
        return "\(last7) of last 7 days"
    }
    
    private func recentCompletionCount(days: Int) -> Int {
        let calendar = calendarProvider.calendar
        let today = calendar.startOfDay(for: Date())

        let range: [Date] = (0..<days).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }

        let metrics = service.dayMetrics(for: habit, on: range)

        return range.reduce(0) { count, day in
            let intensity = metrics[day]?.intensity ?? 0
            return count + (intensity > 0 ? 1 : 0)
        }
    }
    
    private var momentumColor: Color {
        let last7 = recentCompletionCount(days: 7)

        switch last7 {
        case 6...7: return .green
        case 4...5: return accent
        case 2...3: return .orange
        default: return .red
        }
    }
}
