//
//  HabitHeatmap.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

struct HabitHeatmap: View {
    private static let snapshotStableVersion = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @EnvironmentObject private var purchaseService: PurchaseService
    @State private var cache = HeatmapMetricsCache()
    @State private var graphRefreshID = UUID()
    @State private var graphObserverID = UUID()

    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let style: HeatmapStyleConfiguration = .premiumDefault
    let selectedDate: Date
    let earliestVisibleDate: Date?
    let dailyCountsOverride: [Date: Int]?
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
        dailyCountsOverride: [Date: Int]? = nil,
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
        self.dailyCountsOverride = dailyCountsOverride
        self.isInteractive = isInteractive
        self.onSelectDay = onSelectDay
        self.onTapLockedDay = onTapLockedDay
        self.isCompact = isCompact
        self.showsIdentityStateSummary = showsIdentityStateSummary
    }

    private var accent: Color {
        habit.curatedColorVariants.accent
    }

    private enum MomentumSemanticTone {
        case noData
        case strong
        case building
        case slipping
        case atRisk
    }

    private enum MomentumRowMetrics {
        static let rowSpacing: CGFloat = 6
        static let verticalSpacing: CGFloat = 6
        static let dotBaselineOpticalCorrection: CGFloat = 1
        static let staticDotOpacity: Double = 0.9
        static let breathingLowOpacity: Double = 0.75
        static let breathingHighOpacity: Double = 1.0
        static let breathingDuration: Double = 3.0
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

    private var usesGraphRecomputeCoordinator: Bool {
        // Snapshot-driven history views should update from data injection, not global recompute fan-out.
        dailyCountsOverride == nil && isInteractive
    }

    var body: some View {
        Group {
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
        .id(graphRefreshID)
        .onAppear {
            guard usesGraphRecomputeCoordinator else { return }
            GraphRecomputeCoordinator.shared.register(id: graphObserverID) {
                self.recomputeGraph()
            }
        }
        .onDisappear {
            guard usesGraphRecomputeCoordinator else { return }
            GraphRecomputeCoordinator.shared.unregister(id: graphObserverID)
        }
        .onChange(of: service.logsVersion) { _, _ in
            guard usesGraphRecomputeCoordinator else { return }
            GraphRecomputeCoordinator.shared.schedule(for: service.logsVersion)
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
            logsVersion: dailyCountsOverride == nil ? service.logsVersion : Self.snapshotStableVersion,
            calendarIdentifier: calendar.identifier,
            timeZoneIdentifier: calendar.timeZone.identifier,
            firstWeekday: calendar.firstWeekday,
            earliestVisibleDate: earliestVisibleDate
        )

        let entry = cache.entry(key: cacheKey) {
            let dayMetrics = service.dayMetrics(for: habit, on: fullGridDays)
            let logsByDay = dailyCountsOverride == nil
                ? Dictionary(grouping: habit.logs) { log in
                    calendar.startOfDay(for: log.day)
                }
                : [:]
            let logCountMap = Dictionary(uniqueKeysWithValues: fullGridDays.map { day in
                if lockGate.isLocked(date: day) {
                    return (day, 0)
                }

                if let dailyCountsOverride {
                    return (day, dailyCountsOverride[day] ?? 0)
                }

                return (day, logsByDay[day]?.count ?? 0)
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

    private func recomputeGraph() {
        cache.invalidateAll()
        graphRefreshID = UUID()
    }
    
    private func buildFullHeatmapDays(from weeks: [Week]) -> [Date] {
        weeks
            .flatMap(\.days)
            .compactMap { $0 }
            .map { calendarProvider.calendar.startOfDay(for: $0) }
    }

    private var compactHeatmap: some View {
        let revision = service.metricsRevision(for: habit.id)

        let calendar = calendarProvider.calendar
        let today = calendar.startOfDay(for: Date())

        let days: [Date] = (0..<14).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()

        let dayCountMap = Dictionary(uniqueKeysWithValues: days.map { day in
            let count: Int
            if let dailyCountsOverride {
                count = dailyCountsOverride[day] ?? 0
            } else {
                count = habit.logs(on: day, calendar: calendar).count
            }
            return (day, count)
        })

        return HStack(spacing: 2) {
            weekGrid(
                days: Array(days.prefix(7)),
                dayCountMap: dayCountMap
            )

            weekGrid(
                days: Array(days.suffix(7)),
                dayCountMap: dayCountMap
            )
        }
        .id(revision)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(height: 32)
    }
    
    private func weekGrid(
        days: [Date],
        dayCountMap: [Date: Int]
    ) -> some View {
        let calendar = calendarProvider.calendar
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let count = dayCountMap[day] ?? 0

                HeatmapCellView(
                    date: day,
                    isSelected: false,
                    logCount: count,
                    habitColor: habit.curatedColor,
                    selectionAccent: accent
                )
                    .frame(height: 10)
                    .overlay {
                        if calendar.isDateInToday(day) {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(
                                    Color.primary.opacity(0.35),
                                    lineWidth: 1
                                )
                        }
                    }
            }
        }
    }
    
    private var identityStateBlock: some View {
        VStack(alignment: .leading, spacing: MomentumRowMetrics.verticalSpacing) {
            compactHeatmap

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                MomentumStatusRow(
                    text: momentumLabelText,
                    dotColor: momentumDotColor,
                    rowSpacing: MomentumRowMetrics.rowSpacing,
                    dotBaselineOpticalCorrection: MomentumRowMetrics.dotBaselineOpticalCorrection,
                    staticDotOpacity: MomentumRowMetrics.staticDotOpacity,
                    breathingLowOpacity: MomentumRowMetrics.breathingLowOpacity,
                    breathingHighOpacity: MomentumRowMetrics.breathingHighOpacity,
                    breathingDuration: MomentumRowMetrics.breathingDuration,
                    isBreathingEnabled: momentumSemanticTone != .noData
                )
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

    private var momentumLabelText: String {
        switch momentumSemanticTone {
        case .noData:
            return "No activity yet"
        case .strong, .building, .slipping, .atRisk:
            return CadenceLanguage.shortLabel(for: identityStateSummary.state)
        }
    }

    private var momentumDotColor: Color {
        switch momentumSemanticTone {
        case .noData:
            return Color(uiColor: .systemGray3)
        case .strong:
            return HabitColor.fern.variants.soft
        case .building:
            return HabitColor.teal.variants.soft
        case .slipping:
            return HabitColor.amber.variants.soft
        case .atRisk:
            return HabitColor.coral.variants.soft
        }
    }

    private var momentumSemanticTone: MomentumSemanticTone {
        if habit.logs.isEmpty {
            return .noData
        }
        switch identityStateSummary.state {
        case .strong:
            return .strong
        case .building, .steady, .gettingStarted:
            return .building
        case .slipping:
            return .slipping
        case .rebuilding:
            return .atRisk
        }
    }
}

private struct MomentumStatusRow: View {
    let text: String
    let dotColor: Color
    let rowSpacing: CGFloat
    let dotBaselineOpticalCorrection: CGFloat
    let staticDotOpacity: Double
    let breathingLowOpacity: Double
    let breathingHighOpacity: Double
    let breathingDuration: Double
    let isBreathingEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: rowSpacing) {
            Text("•")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(dotColor)
                .opacity(dotOpacity)
                .baselineOffset(dotBaselineOpticalCorrection)

            Text(text)
                .font(.caption)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
        }
        .onAppear {
            restartBreathingAnimation()
        }
        .onChange(of: isBreathingEnabled) { _, _ in
            restartBreathingAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            restartBreathingAnimation()
        }
    }

    private var dotOpacity: Double {
        guard isBreathingEnabled, !reduceMotion else {
            return staticDotOpacity
        }
        return isBreathing ? breathingHighOpacity : breathingLowOpacity
    }

    private func restartBreathingAnimation() {
        guard isBreathingEnabled, !reduceMotion else {
            isBreathing = false
            return
        }
        isBreathing = false
        withAnimation(.easeInOut(duration: breathingDuration).repeatForever(autoreverses: true)) {
            isBreathing = true
        }
    }
}
