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

    private var accent: Color {
        habit.curatedColorVariants.accent
    }

    private var softAccent: Color {
        habit.curatedColorVariants.soft
    }

    private struct IdentityStateVisualStyle {
        let foreground: Color
        let background: Color
        let border: Color
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
        let calendar = calendarProvider.calendar
        let normalizedNow = calendar.startOfDay(for: now)
        let timeline = HeatmapTimelineBuilder.yearTimeline(
            endingAt: now,
            calendar: calendar,
        )

        let fullGridDays = buildFullHeatmapDays(from: timeline.weeks)

        let lockGate = PremiumHistoryGate.Context(
            calendar: calendar,
            premiumStatus: purchaseService.premiumStatus,
            now: normalizedNow
        )

        let cacheKey = HeatmapMetricsCacheKey(
            habitID: habit.id,
            revision: service.metricsRevision(for: habit.id),
            calendarIdentifier: calendar.identifier,
            timeZoneIdentifier: calendar.timeZone.identifier,
            firstWeekday: calendar.firstWeekday,
            earliestVisibleDate: earliestVisibleDate
        )

        let entry = cache.entry(key: cacheKey) {
            let dayMetrics = service.dayMetrics(for: habit, on: fullGridDays)

            let logCountMap = Dictionary(uniqueKeysWithValues: fullGridDays.map { day in
                (day, computeLogCount(for: day, dayMetrics: dayMetrics, lockGate: lockGate))
            })

            return HeatmapMetricsCache.Entry(
                dayMetrics: dayMetrics,
                logCountMap: logCountMap,
                days: fullGridDays
            )
        }

        let lockedDates = Set(entry.days.filter {
            lockGate.isLocked(date: $0)
        }.map {
            calendar.startOfDay(for: $0)
        })

        return GitHubHeatmapGrid(
            habitColor: habit.curatedColor,
            selectionAccent: accent,
            style: style,
            calendarProvider: calendarProvider,
            weeks: timeline.weeks,
            selectedDate: selectedDate,
            isInteractive: isInteractive,
            isDateLocked: { day in
                lockGate.isLocked(date: day)
            },
            logCountByDate: entry.logCountMap,
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

    private func computeLogCount(
        for day: Date,
        dayMetrics: [Date: HabitDayMetrics],
        lockGate: PremiumHistoryGate.Context
    ) -> Int {
        if lockGate.isLocked(date: day) {
            return 0
        }

        let metrics = dayMetrics[day] ?? .zero
        return metrics.count
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
                let metrics = dayMetrics[day] ?? .zero

                HeatmapCellView(
                    date: day,
                    isSelected: false,
                    logCount: metrics.count,
                    habitColor: habit.curatedColor,
                    selectionAccent: accent
                )
                    .frame(height: 14)
                    .overlay {
                        if calendar.isDateInToday(day) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    Color.primary.opacity(colorScheme == .dark ? 0.52 : 0.28),
                                    lineWidth: colorScheme == .dark ? 1.5 : 1.25
                                )
                        }
                    }
                    .animation(.easeOut(duration: 0.14), value: metrics.count)
            }
        }
    }
    
    private var identityStateBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            compactHeatmap

            HStack {
                Text(CadenceLanguage.shortLabel(for: identityStateSummary.state))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(identityStateVisualStyle.foreground)
                    .padding(.horizontal, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(identityStateVisualStyle.background)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(identityStateVisualStyle.border, lineWidth: 0.75)
                    }

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

    private var identityStateVisualStyle: IdentityStateVisualStyle {
        let state = identityStateSummary.state

        switch state {
        case .gettingStarted:
            return IdentityStateVisualStyle(
                foreground: Color.primary.opacity(colorScheme == .dark ? 0.83 : 0.8),
                background: Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09),
                border: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
            )
        case .building:
            return IdentityStateVisualStyle(
                foreground: Color.primary.opacity(colorScheme == .dark ? 0.9 : 0.84),
                background: softAccent.opacity(colorScheme == .dark ? 0.28 : 0.2),
                border: accent.opacity(colorScheme == .dark ? 0.2 : 0.14)
            )
        case .steady, .strong:
            return IdentityStateVisualStyle(
                foreground: Color.primary.opacity(colorScheme == .dark ? 0.9 : 0.84),
                background: softAccent.opacity(colorScheme == .dark ? 0.24 : 0.18),
                border: Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.1)
            )
        case .slipping, .rebuilding:
            return IdentityStateVisualStyle(
                foreground: Color.primary.opacity(colorScheme == .dark ? 0.84 : 0.8),
                background: softAccent.opacity(colorScheme == .dark ? 0.16 : 0.11),
                border: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
            )
        }
    }
}
