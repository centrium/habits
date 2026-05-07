//
//  HabitHeatmap.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

enum ActivityStripStyle {
    case primary
    case subtle
}

struct HabitHeatmap: View {
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var uiStateStore: HabitUIStateStore
    @State private var cache = HeatmapMetricsCache()
    @State private var graphRefreshID = UUID()
    @State private var graphObserverID = UUID()
    @State private var identityRenderSnapshot: HeatmapIdentityRenderSnapshot = .noData
    @State private var identitySnapshotTask: Task<Void, Never>?
    @State private var identitySnapshotRequestSequence: UInt64 = 0
    @State private var identitySnapshotRequestKey: HeatmapIdentitySnapshotRequestKey?
    @State private var compactRenderSnapshot: CompactRenderSnapshot?

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
    let activityStripStyle: ActivityStripStyle

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
        showsIdentityStateSummary: Bool = true,
        activityStripStyle: ActivityStripStyle = .primary
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
        self.activityStripStyle = activityStripStyle
    }

    private var accent: Color {
        habit.curatedColorVariants.accent
    }

    private var projectionVersion: Int {
        Int(uiStateStore.projectionVersionByHabitID[habit.id] ?? 0)
    }

    private var effectiveProjectionVersion: Int {
        guard let dailyCountsOverride else { return projectionVersion }
        var hasher = Hasher()
        hasher.combine(dailyCountsOverride.count)
        for (day, count) in dailyCountsOverride.sorted(by: { $0.key < $1.key }) {
            hasher.combine(day.timeIntervalSince1970)
            hasher.combine(count)
        }
        return hasher.finalize()
    }

    private enum MomentumSemanticTone {
        case noData
        case strong
        case building
        case slipping
        case atRisk
    }

    private struct HeatmapIdentityRenderSnapshot {
        let identityState: HabitIdentityState?
        let tone: MomentumSemanticTone
        let label: String

        static let noData = HeatmapIdentityRenderSnapshot(
            identityState: nil,
            tone: .noData,
            label: ""
        )
    }

    private struct HeatmapIdentitySnapshotRequestKey: Equatable {
        let habitID: UUID
        let projectionVersion: Int
    }

    private struct CompactRenderDay: Equatable {
        let date: Date
        let count: Int
        let isToday: Bool
    }

    private struct CompactRenderSnapshot: Equatable {
        let id: Int
        let firstWeek: [CompactRenderDay]
        let secondWeek: [CompactRenderDay]
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
            GraphRecomputeCoordinator.shared.register(
                id: graphObserverID,
                habitID: habit.id
            ) {
                self.recomputeGraph()
            }
        }
        .onAppear {
            refreshCompactRenderSnapshot()
            scheduleIdentitySnapshotRefresh()
            seedProjectionFromCommittedIfNeeded()
        }
        .onDisappear {
            guard usesGraphRecomputeCoordinator else { return }
            GraphRecomputeCoordinator.shared.unregister(id: graphObserverID)
        }
        .onDisappear {
            identitySnapshotTask?.cancel()
            identitySnapshotTask = nil
        }
        .onReceive(uiStateStore.projectionPublisher(for: habit.id)) { newVersion in
            guard usesGraphRecomputeCoordinator else { return }
            GraphRecomputeCoordinator.shared.schedule(for: habit.id, version: Int(newVersion))
        }
        .onReceive(uiStateStore.projectionPublisher(for: habit.id)) { _ in
            refreshCompactRenderSnapshot()
            scheduleIdentitySnapshotRefresh()
        }
        .onChange(of: service.metricsRevision(for: habit.id)) { _, newVersion in
            refreshCompactRenderSnapshot()
            guard usesGraphRecomputeCoordinator else { return }
            GraphRecomputeCoordinator.shared.schedule(for: habit.id, version: newVersion)
        }
        .onChange(of: dailyCountsOverride) { _, _ in
            refreshCompactRenderSnapshot()
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
            habitVersion: effectiveProjectionVersion,
            calendarIdentifier: calendar.identifier,
            timeZoneIdentifier: calendar.timeZone.identifier,
            firstWeekday: calendar.firstWeekday,
            earliestVisibleDate: earliestVisibleDate
        )

        let entry = cache.entry(key: cacheKey) {
            let dayMetrics = service.dayMetrics(for: habit, on: fullGridDays)
            let projectedCounts = dailyCountsOverride == nil
                ? projectedCountMap(for: fullGridDays, calendar: calendar)
                : [:]
            let logCountMap = Dictionary(uniqueKeysWithValues: fullGridDays.map { day in
                if lockGate.isLocked(date: day) {
                    return (day, 0)
                }

                if let dailyCountsOverride {
                    return (day, dailyCountsOverride[day] ?? 0)
                }

                return (day, projectedCounts[day] ?? 0)
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
        LoggingPerformanceMonitor.markGraphUpdated(habitID: habit.id)
        graphRefreshID = UUID()
    }
    
    private func buildFullHeatmapDays(from weeks: [Week]) -> [Date] {
        weeks
            .flatMap(\.days)
            .compactMap { $0 }
            .map { calendarProvider.calendar.startOfDay(for: $0) }
    }

    private var compactHeatmap: some View {
        let snapshot = compactRenderSnapshot ?? makeCompactRenderSnapshot()

        return HStack(spacing: compactCellSpacing) {
            weekGrid(
                days: snapshot.firstWeek
            )
            .frame(maxWidth: .infinity)

            weekGrid(
                days: snapshot.secondWeek
            )
            .frame(maxWidth: .infinity)
        }
        .id(snapshot.id)
        .padding(.top, compactTopPadding)
        .padding(.bottom, compactBottomPadding)
        .frame(maxWidth: .infinity)
        .frame(height: compactHeight)
    }
    
    private func weekGrid(
        days: [CompactRenderDay]
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: compactCellSpacing), count: 7)

        return LazyVGrid(columns: columns, spacing: compactCellSpacing) {
            ForEach(days, id: \.date) { day in
                HeatmapCellView(
                    date: day.date,
                    isSelected: false,
                    logCount: day.count,
                    habitColor: habit.curatedColor,
                    selectionAccent: accent,
                    activityStripStyle: activityStripStyle
                )
                    .frame(height: activityStripStyle == .subtle ? 9 : 10)
                    .overlay {
                        if activityStripStyle == .primary, day.isToday {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(
                                    Color.primary.opacity(0.35),
                                    lineWidth: 1
                                )
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func refreshCompactRenderSnapshot() {
        guard isCompact else { return }
        compactRenderSnapshot = makeCompactRenderSnapshot()
    }

    private func makeCompactRenderSnapshot() -> CompactRenderSnapshot {
        let calendar = calendarProvider.calendar
        let today = calendar.startOfDay(for: Date())
        let dates: [Date] = (0..<14).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()

        let days = dates.map { day in
            let normalizedDay = calendar.startOfDay(for: day)
            let count: Int
            if let dailyCountsOverride {
                count = dailyCountsOverride[normalizedDay] ?? 0
            } else {
                count = projectedCount(for: normalizedDay, calendar: calendar)
            }
            return CompactRenderDay(
                date: normalizedDay,
                count: count,
                isToday: normalizedDay == today
            )
        }

        return CompactRenderSnapshot(
            id: service.metricsRevision(for: habit.id) ^ effectiveProjectionVersion,
            firstWeek: Array(days.prefix(7)),
            secondWeek: Array(days.suffix(7))
        )
    }

    private var compactCellSpacing: CGFloat {
        activityStripStyle == .subtle ? 3 : 2
    }

    private var compactHeight: CGFloat {
        activityStripStyle == .subtle ? 28 : 32
    }

    private var compactTopPadding: CGFloat {
        activityStripStyle == .subtle ? 4 : 6
    }

    private var compactBottomPadding: CGFloat {
        activityStripStyle == .subtle ? 3 : 4
    }
    
    private var identityStateBlock: some View {
        VStack(alignment: .leading, spacing: MomentumRowMetrics.verticalSpacing) {
            compactHeatmap

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                MomentumStatusRow(
                    text: identityRenderSnapshot.label,
                    dotColor: momentumDotColor(for: identityRenderSnapshot.tone),
                    rowSpacing: MomentumRowMetrics.rowSpacing,
                    dotBaselineOpticalCorrection: MomentumRowMetrics.dotBaselineOpticalCorrection,
                    staticDotOpacity: MomentumRowMetrics.staticDotOpacity,
                    breathingLowOpacity: MomentumRowMetrics.breathingLowOpacity,
                    breathingHighOpacity: MomentumRowMetrics.breathingHighOpacity,
                    breathingDuration: MomentumRowMetrics.breathingDuration,
                    isBreathingEnabled: identityRenderSnapshot.tone != .noData
                )
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func momentumDotColor(for tone: MomentumSemanticTone) -> Color {
        switch tone {
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

    private func scheduleIdentitySnapshotRefresh() {
        guard isCompact, showsIdentityStateSummary else { return }
        identitySnapshotTask?.cancel()

        let requestKey = HeatmapIdentitySnapshotRequestKey(
            habitID: habit.id,
            projectionVersion: projectionVersion
        )
        identitySnapshotRequestKey = requestKey
        let requestSequence = identitySnapshotRequestSequence + 1
        identitySnapshotRequestSequence = requestSequence

        let calendar = calendarProvider.calendar

        identitySnapshotTask = Task { @MainActor in
            let snapshot = computeIdentitySnapshot(calendar: calendar)
            guard !Task.isCancelled else { return }
            guard identitySnapshotRequestSequence == requestSequence else { return }
            guard identitySnapshotRequestKey == requestKey else { return }
            identityRenderSnapshot = snapshot
        }
    }

    private func computeIdentitySnapshot(
        calendar: Calendar
    ) -> HeatmapIdentityRenderSnapshot {
        let summary = projectionIdentitySnapshot(calendar: calendar)
        let tone = momentumSemanticTone(
            hasActivity: summary.activeDays > 0,
            state: summary.state
        )
        let label = HabitSecondaryMetricFormatter.text(
            habit: habit,
            service: service,
            asOf: Date(),
            weekStartPreference: userSettings.weekStartPreference
        )

        return HeatmapIdentityRenderSnapshot(
            identityState: summary.state,
            tone: tone,
            label: label
        )
    }

    private func projectionIdentitySnapshot(calendar: Calendar) -> HabitIdentityStateSnapshot {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        var activeDays = 0
        var totalLogs = 0
        var uniqueDays = 0
        var activeDaysLast14 = 0

        let projected = uiStateStore.projectedDayStates(for: habit.id)
        for (day, state) in projected {
            let normalizedDay = calendar.startOfDay(for: day)
            guard normalizedDay <= today else { continue }

            let dayIsActive = state.count > 0 || state.value > 0
            if dayIsActive {
                uniqueDays += 1
                totalLogs += max(0, state.count)
            }
            if normalizedDay >= start && normalizedDay <= today && dayIsActive {
                activeDays += 1
            }
            if let last14Start = calendar.date(byAdding: .day, value: -13, to: today),
               normalizedDay >= last14Start && normalizedDay <= today && dayIsActive {
                activeDaysLast14 += 1
            }
        }

        let completionRate = Double(activeDays) / 7.0
        let resolvedState = resolvedIdentityState(completionRate: completionRate, hasRecentData: activeDays > 0)

        return HabitIdentityStateSnapshot(
            state: resolvedState,
            completionRate: completionRate,
            activeDays: activeDays,
            windowDays: 7,
            hasRecentData: activeDays > 0,
            totalLogs: totalLogs,
            uniqueDays: uniqueDays,
            activeDaysLast14: activeDaysLast14
        )
    }

    private func momentumSemanticTone(
        hasActivity: Bool,
        state: HabitIdentityState
    ) -> MomentumSemanticTone {
        guard hasActivity else { return .noData }
        switch state {
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

    private func projectedCountMap(for days: [Date], calendar: Calendar) -> [Date: Int] {
        let projected = uiStateStore.projectedDayStates(for: habit.id)
        return Dictionary(uniqueKeysWithValues: days.map { day in
            let normalizedDay = calendar.startOfDay(for: day)
            let count = max(0, projected[normalizedDay]?.count ?? 0)
            return (normalizedDay, count)
        })
    }

    private func seedProjectionFromCommittedIfNeeded() {
        guard uiStateStore.projectedDayStates(for: habit.id).isEmpty else { return }
        _ = service.projectedHistoryDayStates(for: habit)
    }

    private func projectedCount(for day: Date, calendar: Calendar) -> Int {
        let normalizedDay = calendar.startOfDay(for: day)
        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )
        return max(0, projected?.count ?? 0)
    }

    private func resolvedIdentityState(completionRate: Double, hasRecentData: Bool) -> HabitIdentityState {
        guard hasRecentData else { return .gettingStarted }
        switch completionRate {
        case ..<0.2:
            return .rebuilding
        case ..<0.5:
            return .building
        case ..<0.75:
            return .steady
        default:
            return .strong
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
