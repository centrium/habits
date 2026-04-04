//
//  HabitHeatmap.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

struct HabitHeatmap: View {
    @Environment(\.colorScheme) private var colorScheme
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
    let showsIdentityStateSummary: Bool

    init(
        habit: Habit,
        service: HabitLogService,
        calendarProvider: CalendarProvider,
        selectedDate: Date,
        earliestVisibleDate: Date? = nil,
        isInteractive: Bool,
        onSelectDay: @escaping (Date) -> Void,
        onTapLockedDay: @escaping (Date) -> Void = { _ in },
        isCompact: Bool = false,
        showsIdentityStateSummary: Bool = true
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
        self.showsIdentityStateSummary = showsIdentityStateSummary
    }

    private var baseAccent: Color {
        habit.curatedColorVariants.base
    }

    private var accent: Color {
        habit.curatedColorVariants.accent
    }

    private var softAccent: Color {
        habit.curatedColorVariants.soft
    }

    private var gridHeight: CGFloat {
        (style.cellSize * 7) + (style.verticalSpacing * 6)
    }

    private var heatmapTopPadding: CGFloat {
        max(12, style.titleToGridSpacing)
    }

    private var heatmapBottomPadding: CGFloat {
        10
    }

    private var heatmapContentHeight: CGFloat {
        style.monthLabelHeight + style.monthLabelToGridSpacing + gridHeight
    }

    private var heatmapHeight: CGFloat {
        heatmapTopPadding + heatmapContentHeight + heatmapBottomPadding
    }

    var body: some View {
        if isCompact {
            if showsIdentityStateSummary {
                identityStateBlock
            } else {
                compactHeatmap
            }
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
            accent: softAccent,
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
        .padding(.top, heatmapTopPadding)
        .padding(.bottom, heatmapBottomPadding)
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

        let dayMetrics = service.dayMetrics(for: habit, on: days)

        return HStack(spacing: 6) {
            weekGrid(
                days: Array(days.prefix(7)),
                dayMetrics: dayMetrics
            )

            weekGrid(
                days: Array(days.suffix(7)),
                dayMetrics: dayMetrics
            )
        }
        .id(revision)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(height: 40)
    }
    
    private func weekGrid(
        days: [Date],
        dayMetrics: [Date: HabitDayMetrics]
    ) -> some View {
        let calendar = calendarProvider.calendar
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2.5), count: 7)

        return LazyVGrid(columns: columns, spacing: 2.5) {
            ForEach(days, id: \.self) { day in
                let raw = clamp(dayMetrics[day]?.intensity ?? 0)

                RoundedRectangle(cornerRadius: 4)
                    .fill(cellColor(intensity: raw))
                    .frame(height: 14)
                    .overlay {
                        if calendar.isDateInToday(day) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(baseAccent.opacity(0.78), lineWidth: 1.5)
                        }
                    }
            }
        }
    }

    private func cellColor(intensity: Double) -> Color {
        let clamped = clamp(intensity)

        if clamped <= 0.001 {
            if colorScheme == .dark {
                return Color.white.opacity(0.10)
            }
            return Color(uiColor: .secondarySystemFill)
        }

        if clamped >= 0.999 {
            return softAccent.opacity(colorScheme == .dark ? 0.86 : 0.8)
        }

        return softAccent.opacity(colorScheme == .dark ? 0.68 : 0.58)
    }
    
    private var identityStateBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactHeatmap

            HStack {
                Text(CadenceLanguage.shortLabel(for: identityStateSummary.state))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(identityStateColor(for: identityStateSummary.state))

                Spacer()
            }
        }
    }

    private var identityStateSummary: HabitIdentityStateSnapshot {
        HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calendarProvider.calendar,
            now: Date(),
            windowDays: 7
        )
    }

    private func identityStateColor(for state: HabitIdentityState) -> Color {
        switch state {
        case .holding:
            return baseAccent.opacity(0.9)
        case .building:
            return CadenceTokens.Color.Text.secondary
        case .returning:
            return CadenceTokens.Color.Text.secondary.opacity(0.72)
        case .starting:
            return CadenceTokens.Color.Text.tertiary
        }
    }
}
