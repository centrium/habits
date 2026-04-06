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

    private struct IdentityStateVisualStyle {
        let foreground: Color
        let background: Color
        let border: Color
        let heatmapSaturation: Double
        let heatmapContrast: Double
        let heatmapBrightness: Double
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
            selectionAccent: accent,
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
        .saturation(identityStateVisualStyle.heatmapSaturation)
        .contrast(identityStateVisualStyle.heatmapContrast)
        .brightness(identityStateVisualStyle.heatmapBrightness)
        .frame(height: 40)
    }
    
    private func weekGrid(
        days: [Date],
        dayMetrics: [Date: HabitDayMetrics]
    ) -> some View {
        let calendar = calendarProvider.calendar
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2.5), count: 7)
        let glow = max(0, Double(CadenceTokens.Intensity.heatmapGlow))

        return LazyVGrid(columns: columns, spacing: 2.5) {
            ForEach(days, id: \.self) { day in
                let raw = clamp(dayMetrics[day]?.intensity ?? 0)

                RoundedRectangle(cornerRadius: 4)
                    .fill(cellColor(intensity: raw))
                    .frame(height: 14)
                    .opacity(raw > 0.001 ? 1 : 0.9)
                    .scaleEffect(calendar.isDateInToday(day) ? 1.04 : (raw > 0.001 ? 1 : 0.975))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                raw > 0.001
                                    ? softAccent.opacity(colorScheme == .dark ? 0.46 : 0.38)
                                    : Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: raw > 0.001
                            ? softAccent.opacity((colorScheme == .dark ? 0.1 : 0.12) * glow)
                            : .clear,
                        radius: raw > 0.001 ? 2 * glow : 0,
                        y: raw > 0.001 ? 0.8 * glow : 0
                    )
                    .overlay {
                        if calendar.isDateInToday(day) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    Color.primary.opacity(colorScheme == .dark ? 0.52 : 0.28),
                                    lineWidth: colorScheme == .dark ? 1.5 : 1.25
                                )
                        }
                    }
                    .animation(.easeOut(duration: 0.14), value: raw)
            }
        }
    }

    private func cellColor(intensity: Double) -> Color {
        let clamped = clamp(intensity)

        if clamped <= 0.001 {
            return Color.primary.opacity(colorScheme == .dark ? 0.065 : 0.045)
        }

        if clamped >= 0.999 {
            return softAccent.opacity(colorScheme == .dark ? 0.95 : 0.9)
        }

        return softAccent.opacity(colorScheme == .dark ? 0.85 : 0.8)
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
                border: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                heatmapSaturation: 1,
                heatmapContrast: 1,
                heatmapBrightness: 0
            )
        case .building:
            return IdentityStateVisualStyle(
                foreground: Color.primary.opacity(colorScheme == .dark ? 0.9 : 0.84),
                background: softAccent.opacity(colorScheme == .dark ? 0.28 : 0.2),
                border: accent.opacity(colorScheme == .dark ? 0.2 : 0.14),
                heatmapSaturation: 1.03,
                heatmapContrast: 1.02,
                heatmapBrightness: 0.01
            )
        case .steady, .strong:
            return IdentityStateVisualStyle(
                foreground: Color.primary.opacity(colorScheme == .dark ? 0.9 : 0.84),
                background: softAccent.opacity(colorScheme == .dark ? 0.24 : 0.18),
                border: Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.1),
                heatmapSaturation: 1,
                heatmapContrast: 1.04,
                heatmapBrightness: 0
            )
        case .slipping, .rebuilding:
            return IdentityStateVisualStyle(
                foreground: Color.primary.opacity(colorScheme == .dark ? 0.84 : 0.8),
                background: softAccent.opacity(colorScheme == .dark ? 0.16 : 0.11),
                border: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                heatmapSaturation: 0.92,
                heatmapContrast: 0.98,
                heatmapBrightness: 0
            )
        }
    }
}
