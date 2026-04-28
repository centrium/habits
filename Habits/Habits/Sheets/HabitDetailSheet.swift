import SwiftUI
import SwiftData
import Combine

private enum SectionLoadState<Value> {
    case loading
    case loaded(Value)
    case empty

    var value: Value? {
        guard case .loaded(let value) = self else { return nil }
        return value
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

private enum ActiveSheet: Identifiable {
    case edit
    case insights
    case valueEntry
    case aiCoachDetail
    case paywall(PremiumFeature)

    var id: String {
        switch self {
        case .edit:
            return "edit"
        case .insights:
            return "insights"
        case .valueEntry:
            return "valueEntry"
        case .aiCoachDetail:
            return "aiCoachDetail"
        case .paywall(let feature):
            return "paywall-\(String(describing: feature))"
        }
    }
}

private struct IdentityReinforcement {
    let line: String
}

private struct TodayGoalProgressPresentation {
    let summaryText: String
    let readinessText: String?
    let fraction: Double
    let isComplete: Bool
}

private struct HistorySnapshot: Equatable {
    let dailyCounts: [Date: Int]
    let dailyValues: [Date: Double]
    let activeDays: Int
    let totalEntries: Int
    let longestRun: Int

    static let empty = HistorySnapshot(
        dailyCounts: [:],
        dailyValues: [:],
        activeDays: 0,
        totalEntries: 0,
        longestRun: 0
    )
}

private struct DetailDeferredRefreshQueue {
    var progressSnapshot = false
    var cueInsight = false
    var rhythmData = false
    var historyProjectionSnapshot = false
    var historyProjectionSeedFromCommitted = false
    var aiCoachRequestKey: String?

    var isEmpty: Bool {
        !progressSnapshot &&
        !cueInsight &&
        !rhythmData &&
        !historyProjectionSnapshot &&
        aiCoachRequestKey == nil
    }
}

private struct DetailScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CoachingContext {
    let input: CoachingInput
    let depth: CoachingDepth
    let selectedSignals: SelectedCoachingSignals
    let coreMeaningFingerprint: String
    let aiFingerprint: String
}

private struct PendingAICandidate {
    let text: String
    let usedSignals: Set<CoachingSignalID>
    let aiFingerprint: String
}

private enum CoachPresentationState: Equatable {
    case loadingAI
    case ai(String)
    case fallbackGuidance(String)
}

@MainActor
private final class HabitDetailViewModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var historySnapshot: HistorySnapshot = .empty

    private var historySnapshotTask: Task<Void, Never>?

    func activate() {
        isActive = true
    }

    func deactivate() {
        isActive = false
    }

    func refreshHistorySnapshot(
        projectedDayStates: [Date: HabitProjectedDayState],
        calendar: Calendar
    ) {
        historySnapshotTask?.cancel()

        historySnapshotTask = Task { @MainActor in
            let snapshot = await Task.detached(priority: .utility) {
                var countsByOrdinal: [Int: Int] = [:]
                var dayByOrdinal: [Int: Date] = [:]
                var dailyValues: [Date: Double] = [:]
                countsByOrdinal.reserveCapacity(projectedDayStates.count)
                dayByOrdinal.reserveCapacity(projectedDayStates.count)
                dailyValues.reserveCapacity(projectedDayStates.count)

                for (day, state) in projectedDayStates {
                    guard let ordinality = calendar.ordinality(of: .day, in: .era, for: day) else {
                        continue
                    }
                    countsByOrdinal[ordinality] = max(0, state.count)
                    dayByOrdinal[ordinality] = day
                    dailyValues[day] = max(0, state.value)
                }

                let activeOrdinals = countsByOrdinal
                    .filter { $0.value > 0 }
                    .map(\.key)
                    .sorted()

                var longestRun = 0
                var currentRun = 0
                var previousOrdinal: Int?

                for ordinality in activeOrdinals {
                    if let previousOrdinal, ordinality == previousOrdinal + 1 {
                        currentRun += 1
                    } else {
                        currentRun = 1
                    }
                    longestRun = max(longestRun, currentRun)
                    previousOrdinal = ordinality
                }

                let dailyCounts = Dictionary(
                    uniqueKeysWithValues: dayByOrdinal.map { ordinality, day in
                        (day, countsByOrdinal[ordinality] ?? 0)
                    }
                )

                return HistorySnapshot(
                    dailyCounts: dailyCounts,
                    dailyValues: dailyValues,
                    activeDays: activeOrdinals.count,
                    totalEntries: dailyCounts.values.reduce(0, +),
                    longestRun: longestRun
                )
            }.value

            guard !Task.isCancelled else { return }
            self.historySnapshot = snapshot
        }
    }
}

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var uiStateStore: HabitUIStateStore
    @EnvironmentObject private var habitLogService: HabitLogService
    private let aiCoach = AICoachService.shared
    @StateObject private var appTime = AppTime.shared
    @StateObject private var selectionState: HabitSelectionState
    @State private var activeSheet: ActiveSheet?
    @State private var manualLogValue: Double? = nil
    @State private var insightsDetent: PresentationDetent = .large
    @State private var cachedProgressSnapshot: ProgressAsOfSnapshot?
    @State private var snapshotRefreshTask: Task<Void, Never>?
    @State private var selectedDate: Date
    @State private var isHistoryPresented = false
    @State private var cueInsight: CueInsight?
    @State private var rhythmSectionState: SectionLoadState<[HourValue]> = .loading
    @State private var aiCoachSectionState: SectionLoadState<GuidanceOutput> = .loading
    @State private var metadataSectionState: SectionLoadState<Void> = .loading
    @State private var prefersIdentityFocusOnEdit = false
    @State private var coachPresentationState: CoachPresentationState = .fallbackGuidance(SafeMinimalCoaching.line)
    @State private var coachingContext: CoachingContext?
    @State private var guidanceCoachText: String = SafeMinimalCoaching.line
    @State private var guidanceUsedSignals: Set<CoachingSignalID> = []
    @State private var aiUsedSignals: Set<CoachingSignalID> = []
    @State private var coachRenderLockedUntil: Date = .distantPast
    @State private var pendingAICandidate: PendingAICandidate?
    @State private var coachRenderUnlockTask: Task<Void, Never>?
    @State private var frozenGuidanceOutput: GuidanceOutput?
    @State private var frozenStateModel: HabitStateModel?
    @State private var lastReconcileProbeKey: String?
    @State private var shouldAnimateGoalProgress = false
    @State private var goalProgressAnimationResetTask: Task<Void, Never>?
    @State private var cueRefreshTask: Task<Void, Never>?
    @State private var historyProjectedDayStates: [Date: HabitProjectedDayState] = [:]
    @State private var cueRequestSequence: UInt64 = 0
    @State private var currentRhythmRequestID: UUID?
    @State private var detailAppearStartedAt: Date?
    @State private var cachedIdentitySnapshot = HabitIdentityStateSnapshot(
        state: .gettingStarted,
        completionRate: 0,
        activeDays: 0,
        windowDays: 7,
        hasRecentData: false,
        totalLogs: 0,
        uniqueDays: 0,
        activeDaysLast14: 0
    )
    @State private var cachedTodayGoalProgress: TodayGoalProgressPresentation?
    @State private var isDetailScrollActive = false
    @State private var lastObservedDetailScrollOffset: CGFloat?
    @State private var detailScrollIdleTask: Task<Void, Never>?
    @State private var deferredRefreshQueue = DetailDeferredRefreshQueue()
    @StateObject private var viewModel = HabitDetailViewModel()
    private let onDeleted: (() -> Void)?
    private let detailScrollCoordinateSpace = "habit-detail-scroll-space"

    let habit: Habit

    init(
        habit: Habit,
        initialCalendar: Calendar = .autoupdatingCurrent,
        onDeleted: (() -> Void)? = nil
    ) {
        self.habit = habit
        self.onDeleted = onDeleted
        _selectionState = StateObject(wrappedValue: HabitSelectionState(calendar: initialCalendar))
        _selectedDate = State(initialValue: initialCalendar.startOfDay(for: Date()))
    }

    var body: some View {
        let progressSnapshot = cachedProgressSnapshot
        let now = Date()
        let calendar = habitLogService.calendar
        let progressRevision = habitLogService.metricsRevision(for: habit.id)
        let habitVersion = Int(uiStateStore.projectionVersionByHabitID[habit.id] ?? 0)
        let streakState = currentStreakState(now: now)
        let premiumHistoryGate = PremiumHistoryGate.Context(
            calendar: calendar,
            premiumStatus: purchaseService.premiumStatus,
            now: now
        )
        let earliestCalendarDate: Date? = {
            switch purchaseService.premiumStatus {
            case .free:
                return premiumHistoryGate.earliestVisibleDate
            case .unknown, .premium:
                return nil
            }
        }()
        let calendarMonthSummaryText: String? = {
            guard !premiumHistoryGate.isLocked(date: selectionState.visibleMonth) else {
                return nil
            }

            return progressSnapshot?.visibleMonthText
        }()

        ZStack(alignment: .top) {
            backgroundColor
                .ignoresSafeArea()

            TopAmbientGradient()
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea()

            detailContent(
                progressSnapshot: progressSnapshot,
                streakState: streakState,
                progressRevision: progressRevision,
                earliestCalendarDate: earliestCalendarDate
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {

                Button {
                    switch purchaseService.premiumStatus {
                    case .unknown:
                        return
                    case .premium:
                        activeSheet = .insights
                    case .free:
                        showPaywall(feature: .advancedInsights)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                            .foregroundStyle(CadenceTokens.Color.accent(from: HabitColor.default.hex).primary)

                        if purchaseService.premiumStatus == .free {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        }
                    }
                    .frame(height: 34)
                    .padding(.horizontal, 10)
                    .cadenceControlChrome()
                }
                .buttonStyle(TactileButtonStyle())

                Button {
                    prefersIdentityFocusOnEdit = false
                    activeSheet = .edit
                } label: {
                    Image(systemName: "pencil")
                        .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        .frame(width: 34, height: 34)
                        .padding(.horizontal, 4)
                        .cadenceControlChrome()
                }
                .buttonStyle(TactileButtonStyle())

            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit:
                EditHabitSheet(
                    habit: habit,
                    focusIdentityOnAppear: prefersIdentityFocusOnEdit
                ) {
                    activeSheet = nil
                    dismiss()
                    onDeleted?()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)

            case .insights:
                NavigationStack {
                    HabitInsightsView(
                        habit: habit,
                        logAnchorDate: selectedDate
                    )
                }
                .presentationDetents([.medium, .large], selection: $insightsDetent)
                .presentationBackground(CadenceTokens.Color.Background.primary)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)

            case .valueEntry:
                CumulativeQuickEntrySheet(
                    goalName: habit.name,
                    unitLabel: habit.trimmedUnit,
                    initialValue: manualLogValue,
                    todayTotal: habitLogService.value(for: habit, on: selectedDate),
                    targetValue: habit.effectiveTargetValue,
                    formattingContext: habitLogService.valueFormattingContext(for: habit),
                    inputContext: habitLogService.valueInputContext(for: habit)
                ) { newValue in
                    let resolvedDay = calculationCalendar.startOfDay(for: selectedDate)
                    _ = habitLogService.addLog(for: habit, on: resolvedDay, value: max(0, newValue))
                    manualLogValue = newValue
                } onClearDay: {
                    let resolvedDay = calculationCalendar.startOfDay(for: selectedDate)
                    _ = habitLogService.clearEntries(for: habit, on: resolvedDay)
                    manualLogValue = nil
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)

            case .aiCoachDetail:
                AICoachDetailSheet(
                    title: coachCardLabel,
                    message: aiCoachDetailMessage,
                    isLoading: isAICoachThinking,
                    loadingText: aiCoach.loadingText
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(CadenceTokens.Color.Background.primary)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)

            case .paywall(let feature):
                PaywallView(feature: feature)

            }

        }
        .onAppear {
            viewModel.activate()
            detailAppearStartedAt = Date()
            rhythmSectionState = .loading
            aiCoachSectionState = .loading
            metadataSectionState = .loading
            frozenStateModel = nil
            frozenGuidanceOutput = nil
            Task { @MainActor in
                await bootstrapDetailSections(now: now)
            }

            guard purchaseService.premiumStatus == .free else { return }

            let minimumVisibleMonth = calendarViewProvider.calendar.dateInterval(
                of: .month,
                for: premiumHistoryGate.earliestVisibleDate
            )?.start
            if let minimumVisibleMonth,
               calendarViewProvider.calendar.compare(
                selectionState.visibleMonth,
                to: minimumVisibleMonth,
                toGranularity: .month
               ) == .orderedAscending {
                selectionState.selectCalendarMonth(minimumVisibleMonth, today: now)
            }
        }
        .onDisappear {
            viewModel.deactivate()
            snapshotRefreshTask?.cancel()
            goalProgressAnimationResetTask?.cancel()
            cueRefreshTask?.cancel()
            detailScrollIdleTask?.cancel()
            deferredRefreshQueue = DetailDeferredRefreshQueue()
            freezeDetailState()
        }
        .onChange(of: userSettings.weekStartPreference) { _, _ in
            habitLogService.updateCalendar(calculationCalendar)
            requestHistoryProjectionSnapshotRefresh(seedFromCommitted: false)
            guard viewModel.isActive, !isHistoryPresented else { return }
            requestProgressSnapshotRefresh()
        }
        .onChange(of: selectedDate) { _, _ in
            guard viewModel.isActive, !isHistoryPresented else { return }
            requestProgressSnapshotRefresh()
        }
        .onChange(of: selectionState.visibleMonth) { _, _ in
            guard viewModel.isActive, !isHistoryPresented else { return }
            requestProgressSnapshotRefresh()
        }
        .onChange(of: appTime.now) { oldValue, newValue in
            guard viewModel.isActive, !isHistoryPresented else { return }
            let previousDay = calculationCalendar.startOfDay(for: oldValue)
            let currentDay = calculationCalendar.startOfDay(for: newValue)
            guard previousDay != currentDay else { return }
            requestHistoryProjectionSnapshotRefresh(seedFromCommitted: false)
            requestProgressSnapshotRefresh(now: newValue)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            guard viewModel.isActive, !isHistoryPresented else { return }
            requestAICoachRegeneration(
                requestKey: "scene-active-\(habit.id.uuidString)-\(Date().timeIntervalSince1970)"
            )
        }
        .onChange(of: progressRevision) { _, _ in
            requestHistoryProjectionSnapshotRefresh(seedFromCommitted: false)
            guard viewModel.isActive, !isHistoryPresented else { return }
            requestProgressSnapshotRefresh()
            requestCueInsightRefresh()
        }
        .onReceive(uiStateStore.projectionPublisher(for: habit.id)) { _ in
            requestHistoryProjectionSnapshotRefresh()
            guard viewModel.isActive, !isHistoryPresented else { return }
            recordUIReconcileProbe(stage: "projection")
            requestProgressSnapshotRefresh()
            triggerGoalProgressAnimation()
            requestCueInsightRefresh()
        }
        .onChange(of: isHistoryPresented) { _, presented in
            if presented {
                viewModel.deactivate()
                freezeDetailState(resetCueInsight: false)
                return
            }

            viewModel.activate()
            frozenStateModel = nil
            frozenGuidanceOutput = nil
            requestHistoryProjectionSnapshotRefresh(seedFromCommitted: false)
            metadataSectionState = .loaded(())
            requestProgressSnapshotRefresh()
            requestCueInsightRefresh()
            aiCoachSectionState = .loading
            refreshCoachingContextAndGuidance(now: Date())
            aiCoachSectionState = {
                if let output = frozenGuidanceOutput {
                    return .loaded(output)
                }
                return .empty
            }()
            coachPresentationState = aiCoach.isAppleIntelligenceAvailable()
                ? .loadingAI
                : .fallbackGuidance(guidanceCoachText)
            requestAICoachRegeneration(
                requestKey: "history-return-\(habit.id.uuidString)-\(Date().timeIntervalSince1970)"
            )
        }
        .task(id: habit.id) {
            if let startedAt = detailAppearStartedAt {
                detailPerfLog("first-paint-ms=\(detailElapsedMs(since: startedAt))")
                detailAppearStartedAt = nil
            }
            guard viewModel.isActive, !isHistoryPresented else { return }
            requestCueInsightRefresh()
        }
        .task(id: rhythmTaskKey) {
            rhythmDebugLog("task-trigger key=\(rhythmTaskKey)")
            await requestRhythmRefresh()
        }
        .navigationDestination(isPresented: $isHistoryPresented) {
            let liveHistorySnapshot = viewModel.historySnapshot
            let historyDailyCounts = Dictionary(
                uniqueKeysWithValues: historyProjectedDayStates.map { ($0.key, $0.value.count) }
            )
            ZStack(alignment: .top) {
                backgroundColor
                    .ignoresSafeArea()

                TopAmbientGradient()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea()

                historyTabContent(
                    progressRevision: progressRevision,
                    habitVersion: habitVersion,
                    snapshot: liveHistorySnapshot,
                    historyProjectedDayStates: historyProjectedDayStates,
                    historyDailyCounts: historyDailyCounts,
                    calendarMonthSummaryText: calendarMonthSummaryText,
                    earliestCalendarDate: earliestCalendarDate,
                    premiumHistoryGate: premiumHistoryGate,
                    calendar: calendar
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        openInsightsOrPaywall()
                    } label: {
                        Image(systemName: "sparkles")
                            .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                            .foregroundStyle(CadenceTokens.Color.accent(from: HabitColor.default.hex).primary)
                            .frame(width: 34, height: 34)
                            .padding(.horizontal, 4)
                            .cadenceControlChrome()
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel("Insights")

                    Button {
                        quickLogFromCalendarDay(selectedDate)
                    } label: {
                        Image(systemName: "plus")
                            .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .padding(.horizontal, 4)
                            .cadenceControlChrome()
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel("Quick log")

                   
                }
            }
        }
    }

    @ViewBuilder
    private func detailContent(
        progressSnapshot: ProgressAsOfSnapshot?,
        streakState: StreakState,
        progressRevision: Int,
        earliestCalendarDate: Date?
    ) -> some View {
        let sectionPadding = CadenceTokens.Space.lg
        let accent = CadenceTokens.Color.accent(for: habit)
        let stateModel = frozenStateModel
        let identityState = cachedIdentitySnapshot
        let heroStatus = CadenceLanguage.shortLabel(for: identityState.state)
        let logCount = viewModel.historySnapshot.totalEntries
        let isLowDataActivityState = logCount == 0
        let isCumulativeGoal = habit.goalType == .cumulative
        let showsInsightsSection = hasInsightsInlineAction
        let metaLines = MetaDisplayFormatter.format(
            habit: habit,
            streakState: streakState,
            weeklyActiveDays: identityState.activeDays,
            isGoalMet: isCompleteForSelectedDate
        )
        let primaryMetaLine = metaLines.first?.text ?? "Getting started this week"
        let secondaryMetaLine = metaLines.dropFirst().first?.text
        let identityText = userDefinedIdentityText
        let identityStatText = identityText == nil
            ? nil
            : CadenceLanguage.identityStat(days: identityState.activeDays, window: identityState.windowDays)
        let guidanceOutput = aiCoachSectionState.value
        let identityReflectionText = pairedIdentityReflection(for: guidanceOutput)
        let isMetadataLoading = metadataSectionState.isLoading

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHeaderIdentity(
                    habitName: habit.name,
                    iconName: habit.iconName,
                    accent: accent.primary
                )
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md)

                VStack(alignment: .leading, spacing: 5) {
                    Text(heroStatus)
                        .font(CadenceTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(CadenceTokens.Color.Text.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.92)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let userCueText = userDefinedCueText {
                        Text(userCueText)
                            .font(CadenceTokens.Typography.body)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let detectedCueText {
                        Text(detectedCueText)
                            .font(CadenceTokens.Typography.body)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        openHistoryFromDetail(earliestCalendarDate: earliestCalendarDate)
                    } label: {
                        Text(primaryMetaLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if let secondaryMetaLine {
                        Text(secondaryMetaLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.sm)
                .redacted(reason: isMetadataLoading ? .placeholder : [])

                VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                    if logCount == 0 {
                        Text("Your progress starts here")
                            .font(CadenceTokens.Typography.supporting)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .lineLimit(1)
                    }

                    Text(goalDescriptorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let goalProgress = todayGoalProgressPresentation {
                        todayGoalProgressRow(goalProgress)
                    }

                    KeyActionsSection(
                        isCumulativeGoal: isCumulativeGoal,
                        isCompleteToday: isCompleteForSelectedDate,
                        accentHex: habit.colorHex,
                        onQuickLog: {
                            quickLogFromCalendarDay(selectedDate)
                        },
                        onManualEntry: {
                            presentManualEntry(for: selectedDate)
                        }
                    )
                }
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md)
                .redacted(reason: isMetadataLoading ? .placeholder : [])

                Button {
                    openHistoryFromDetail(earliestCalendarDate: earliestCalendarDate)
                } label: {
                    HabitHeatmap(
                        habit: habit,
                        service: habitLogService,
                        calendarProvider: heatmapCalendarProvider,
                        selectedDate: selectedDate,
                        earliestVisibleDate: earliestCalendarDate,
                        isInteractive: false,
                        onSelectDay: { _ in },
                        onTapLockedDay: { _ in },
                        isCompact: true,
                        showsIdentityStateSummary: false,
                        activityStripStyle: .subtle
                    )
                    .opacity(isLowDataActivityState ? 0.7 : 1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md + 2)

                Group {
                    let output = aiCoachSectionState.value ?? frozenGuidanceOutput ?? placeholderGuidanceOutput
                    GuidanceCard(
                        output: output,
                        accent: accent,
                        variant: GuidanceEngine.visualVariant(for: output),
                        label: coachCardLabel,
                        guidanceText: resolvedCoachMessage(for: output),
                        isLoading: isAICoachThinking,
                        loadingText: aiCoach.loadingText
                    )
                }
                .contentShape(Rectangle())
                .allowsHitTesting(!isAICoachThinking)
                .onTapGesture {
                    guard !isAICoachThinking else { return }
                    activeSheet = .aiCoachDetail
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: aiCoachSectionPhase)
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.lg + 4)

                Group {
                    switch rhythmSectionState {
                    case .loading:
                        RhythmCardView(
                            isPremium: purchaseService.premiumStatus == .premium,
                            data: rhythmPlaceholderData,
                            rhythm: nil,
                            computedState: nil,
                            stateModel: stateModel,
                            identitySnapshot: identityState,
                            habit: habit,
                            onUnlock: {
                                showPaywall(feature: .advancedInsights)
                            }
                        )
                        .redacted(reason: .placeholder)
                        .allowsHitTesting(false)
                    case .loaded(let values):
                        RhythmCardView(
                            isPremium: purchaseService.premiumStatus == .premium,
                            data: values,
                            rhythm: TimeOfDayPerformanceService.shared.cachedRhythm(
                                for: habit,
                                isPremium: purchaseService.premiumStatus == .premium
                            ),
                            computedState: nil,
                            stateModel: stateModel,
                            identitySnapshot: identityState,
                            habit: habit,
                            onUnlock: {
                                showPaywall(feature: .advancedInsights)
                            }
                        )
                    case .empty:
                        RhythmCardView(
                            isPremium: purchaseService.premiumStatus == .premium,
                            data: rhythmZeroData,
                            rhythm: nil,
                            computedState: nil,
                            stateModel: stateModel,
                            identitySnapshot: identityState,
                            habit: habit,
                            onUnlock: {
                                showPaywall(feature: .advancedInsights)
                            }
                        )
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: rhythmSectionPhase)
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md + 2)

                HabitIdentityCard(
                    identityText: identityText,
                    statText: identityStatText,
                    reflectionText: identityReflectionText,
                    accent: CadenceTokens.Color.accent(for: habit)
                ) {
                    prefersIdentityFocusOnEdit = true
                    activeSheet = .edit
                }
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md + 2)

                if showsInsightsSection {
                    InsightsInlineNudgeRow(
                        text: insightsInlineNudgeText,
                        action: openInsightsOrPaywall
                    )
                    .padding(.horizontal, sectionPadding)
                    .padding(.top, CadenceTokens.Space.lg + 6)
                }

                Color.clear
                    .frame(height: CadenceTokens.Space.lg + 2)
                    .allowsHitTesting(false)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DetailScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named(detailScrollCoordinateSpace)).minY
                    )
                }
            )
            .padding(.bottom, CadenceTokens.Space.md)
        }
        .coordinateSpace(name: detailScrollCoordinateSpace)
        .onPreferenceChange(DetailScrollOffsetPreferenceKey.self) { offset in
            handleDetailScrollOffsetChange(offset)
        }
        .scrollContentBackground(.hidden)
    }

    private var backgroundColor: Color {
        colorScheme == .light
            ? Color(white: 0.96)
            : Color(white: 0.04)
    }

    @ViewBuilder
    private func historyTabContent(
        progressRevision: Int,
        habitVersion: Int,
        snapshot: HistorySnapshot,
        historyProjectedDayStates: [Date: HabitProjectedDayState],
        historyDailyCounts: [Date: Int],
        calendarMonthSummaryText: String?,
        earliestCalendarDate: Date?,
        premiumHistoryGate: PremiumHistoryGate.Context,
        calendar: Calendar
    ) -> some View {
        let now = Date()
        let historyInsight = historyInsightSummary(
            snapshot: snapshot,
            visibleMonth: selectionState.visibleMonth,
            now: now,
            calendar: calendar
        )
        let selectedDayContext = selectedDayContextSummary(
            snapshot: snapshot,
            selectedDate: selectedDate,
            calendar: calendar
        )

        ScrollView {
            VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
                VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                    Text("History")
                        .font(CadenceTokens.Typography.roleTitle.weight(.semibold))
                        .foregroundStyle(CadenceTokens.Color.Text.primary)

                    fadingHistorySecondaryText(
                        historyMonthLabel(for: selectionState.visibleMonth),
                        id: "history-month-label-\(historyMonthKey(for: selectionState.visibleMonth, calendar: calendar))"
                    )
                }
                .padding(.horizontal, CadenceTokens.Space.lg)
                .padding(.top, CadenceTokens.Space.sm)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Your activity over time")
                        .font(CadenceTokens.Typography.roleLabel.weight(.regular))
                        .foregroundStyle(
                            CadenceTokens.Color.Text.secondary.opacity(CadenceTokens.Typography.roleLabelOpacity)
                        )
                        .padding(.horizontal, CadenceTokens.Space.sm)
                        .padding(.top, CadenceTokens.Space.sm)

                    ZStack {
                        EquatableView(
                            content: HeatmapSection(
                                habitID: habit.id,
                                selectedDate: selectedDate,
                                metricsRevision: progressRevision,
                                habitVersion: habitVersion,
                                earliestVisibleDate: earliestCalendarDate,
                                historyDailyCounts: historyDailyCounts,
                                habit: habit,
                                service: habitLogService,
                                calendarProvider: heatmapCalendarProvider,
                                onSelectDay: { day in
                                    let normalized = calendar.startOfDay(for: day)
                                    withAnimation(.easeInOut(duration: 0.27)) {
                                        selectedDate = normalized
                                    }

                                    if !calendar.isDate(normalized, equalTo: selectionState.visibleMonth, toGranularity: .month) {
                                        withAnimation(.easeInOut(duration: 0.27)) {
                                            selectionState.selectCalendarMonth(normalized)
                                        }
                                    }
                                    quickLogFromCalendarDay(normalized)
                                },
                                onTapLockedDay: { _ in
                                    showPaywall(feature: .fullHeatmapHistory)
                                }
                            )
                        )
                        .id("history-heatmap-\(historyMonthKey(for: selectionState.visibleMonth, calendar: calendar))")
                        .transition(.opacity)
                    }
                    .animation(.easeInOut(duration: 0.22), value: historyMonthKey(for: selectionState.visibleMonth, calendar: calendar))
                    .padding(.top, CadenceTokens.Space.md + 2)
                    .padding(.bottom, CadenceTokens.Space.md + 2)

                    Divider().opacity(0.08)

                    HistoryInsightSummarySection(summary: historyInsight)
                        .padding(.top, CadenceTokens.Space.md)

                    Divider().opacity(0.08)

                    SelectedDayContextSection(context: selectedDayContext)
                        .padding(.top, CadenceTokens.Space.md)

                    EquatableView(
                        content: CalendarSection(
                            habitID: habit.id,
                            selectedDate: selectedDate,
                            visibleMonth: selectionState.visibleMonth,
                            metricsRevision: progressRevision,
                            habitVersion: habitVersion,
                            monthSummaryText: calendarMonthSummaryText,
                            earliestVisibleDate: earliestCalendarDate,
                            historyProjectedDayStates: historyProjectedDayStates,
                            isTapToLogEnabled: userSettings.tapToLogEnabled,
                            month: Binding(
                                get: { selectionState.visibleMonth },
                                set: { newValue in
                                    withAnimation(.easeInOut(duration: 0.27)) {
                                        selectionState.selectCalendarMonth(newValue)
                                    }
                                }
                            ),
                            habit: habit,
                            service: habitLogService,
                            calendarProvider: calendarViewProvider,
                            premiumHistoryGate: premiumHistoryGate,
                            onSelectDay: { day in
                                selectedDate = calendar.startOfDay(for: day)
                            },
                            onTapDay: { day in
                                quickLogFromCalendarDay(day)
                            },
                            onTapLockedDay: { _ in
                                showPaywall(feature: .fullHeatmapHistory)
                            }
                        )
                    )
                    .padding(.top, CadenceTokens.Space.sm + 2)
                }
                .padding(CadenceTokens.Space.md)
                .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
                .padding(.horizontal, CadenceTokens.Space.lg)
                .padding(.top, CadenceTokens.Space.sm + 2)

                Color.clear
                    .frame(height: 72)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, CadenceTokens.Space.lg)
        }
        .scrollContentBackground(.hidden)
    }

    private var loggingContextText: String {
        let shortDate = selectedDate.formatted(
            Date.FormatStyle()
                .day()
                .month(.abbreviated)
        )
        return "Logging for \(shortDate)"
    }

    private func identityStateSummary() -> HabitIdentityStateSnapshot {
        cachedIdentitySnapshot
    }

    private func streakCardConfiguration(streakState: StreakState) -> StreakCardConfiguration? {
        StreakCardConfiguration(streakState: streakState)
    }

    private func guidanceOutput(
        streakState: StreakState,
        identityState: HabitIdentityStateSnapshot
    ) -> GuidanceOutput {
        GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: Date(),
                isCompletedToday: hasActivityToday(),
                streakState: streakState,
                completionHistory: [],
                globalHistory: [],
                pattern: guidancePattern(),
                goalType: habit.goalType
            ),
            calendar: calculationCalendar,
            identitySnapshot: identityState
        )
    }

    private func hasActivityToday() -> Bool {
        let today = CurrentDayResolver.currentDay(calendar: calculationCalendar)
        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: today,
            calendar: calculationCalendar
        )
        return (projected?.progress ?? 0) > 0
            || (projected?.count ?? 0) > 0
            || (projected?.value ?? 0) > 0
    }

    private func currentStreakState(now: Date) -> StreakState {
        if let cached = habitLogService.computedStateByHabitID[habit.id]?.streakState {
            return cached
        }

        let today = calculationCalendar.startOfDay(for: now)
        let projected = uiStateStore.projectedDayState(
            habitID: habit.id,
            day: today,
            calendar: calculationCalendar
        )
        let isCompleteToday = projected?.isComplete ?? false
        return StreakState(
            currentStreak: 0,
            longestStreak: 0,
            hasMetRequirementToday: isCompleteToday,
            isRequiredToday: !isCompleteToday,
            isAtRisk: false,
            isBroken: !isCompleteToday,
            status: isCompleteToday ? .safe : .broken
        )
    }

    private func reinforcement(for guidanceType: GuidanceType?) -> IdentityReinforcement {
        switch guidanceType {
        case .momentum:
            return IdentityReinforcement(line: "This is becoming part of who you are")
        case .atRisk:
            return IdentityReinforcement(line: "Even small actions like this matter")
        case .recovery:
            return IdentityReinforcement(line: "This is how consistency builds")
        case .identity:
            return IdentityReinforcement(line: "This is starting to feel natural")
        case nil:
            return IdentityReinforcement(line: "This is taking shape")
        }
    }

    private func pairedIdentityReflection(for guidanceOutput: GuidanceOutput?) -> String {
        let candidate = reinforcement(for: guidanceOutput?.type).line
        guard let guidanceOutput else { return candidate }
        let guidanceVerbs = guidanceActionVerbs(from: guidanceOutput.action)
        guard guidanceVerbs.allSatisfy({ !candidate.localizedCaseInsensitiveContains($0) }) else {
            return "This is becoming part of who you are"
        }
        return candidate
    }

    private func guidanceActionVerbs(from action: String) -> Set<String> {
        let actionWords = action.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        let trackedVerbs: Set<String> = [
            "save",
            "walk",
            "read",
            "learn",
            "study",
            "practice",
            "log"
        ]
        return Set(actionWords.filter { trackedVerbs.contains($0) })
    }

    private func debugPrintRecentHabitLogTimestamps() {
#if DEBUG
        guard isDetailPerfDebugEnabled else { return }
        TimeInsightEngine.debugDumpAllLogs(
            for: habit,
            now: Date(),
            calendar: calculationCalendar
        )
#endif
    }

    private func presentManualEntry(for date: Date) {
        let resolvedDay = calculationCalendar.startOfDay(for: date)
        selectedDate = resolvedDay
        selectionState.select(date: resolvedDay)
        manualLogValue = habitLogService.suggestedQuickEntryValue(for: habit)
        activeSheet = .valueEntry
    }

    private func showPaywall(feature: PremiumFeature) {
        guard purchaseService.premiumStatus != .unknown else { return }
        activeSheet = .paywall(feature)
    }

    private func quickLogFromCalendarDay(_ day: Date) {
        let resolvedDay = calculationCalendar.startOfDay(for: day)
        selectedDate = resolvedDay
        selectionState.select(date: resolvedDay)

        if habit.goalType == .cumulative {
            presentManualEntry(for: resolvedDay)
            return
        }

        _ = habitLogService.quickLog(for: habit, on: resolvedDay)
    }

    private func refreshHistoryProjectionState(seedFromCommitted: Bool = false) {
        if seedFromCommitted {
            _ = habitLogService.projectedHistoryDayStates(for: habit)
        }
        let updatedStates = uiStateStore.projectedDayStates(for: habit.id)
        guard updatedStates != historyProjectedDayStates else { return }
        historyProjectedDayStates = updatedStates
        refreshIdentitySnapshotCache()
        refreshTodayGoalProgressPresentation()
    }

    private func refreshIdentitySnapshotCache() {
        let normalizedWindow = 7
        let today = calculationCalendar.startOfDay(for: Date())
        let earliest = calculationCalendar.date(byAdding: .day, value: -(normalizedWindow - 1), to: today) ?? today
        let last14Start = calculationCalendar.date(byAdding: .day, value: -13, to: today) ?? today

        var uniqueDays = 0
        var activeDays = 0
        var activeDaysLast14 = 0
        var totalLogs = 0

        for (day, state) in historyProjectedDayStates {
            let normalizedDay = calculationCalendar.startOfDay(for: day)
            guard normalizedDay <= today else { continue }
            let hasActivity = state.count > 0 || state.value > 0
            guard hasActivity else { continue }

            uniqueDays += 1
            totalLogs += max(0, state.count)

            if normalizedDay >= earliest && normalizedDay <= today {
                activeDays += 1
            }
            if normalizedDay >= last14Start && normalizedDay <= today {
                activeDaysLast14 += 1
            }
        }

        let completionRate = Double(activeDays) / Double(normalizedWindow)
        let state: HabitIdentityState
        switch completionRate {
        case ..<0.2:
            state = activeDays > 0 ? .rebuilding : .gettingStarted
        case ..<0.5:
            state = .building
        case ..<0.75:
            state = .steady
        default:
            state = .strong
        }

        cachedIdentitySnapshot = HabitIdentityStateSnapshot(
            state: state,
            completionRate: completionRate,
            activeDays: activeDays,
            windowDays: normalizedWindow,
            hasRecentData: activeDays > 0,
            totalLogs: totalLogs,
            uniqueDays: uniqueDays,
            activeDaysLast14: activeDaysLast14
        )
    }

    private func refreshTodayGoalProgressPresentation() {
        guard habit.hasGoal,
              let targetValue = habit.effectiveTargetValue,
              targetValue > 0 else {
            cachedTodayGoalProgress = nil
            return
        }

        let today = CurrentDayResolver.currentDay(calendar: calculationCalendar)
        let currentValue: Double
        switch habit.goalType {
        case .frequency:
            currentValue = Double(habitLogService.count(for: habit, on: today))
        case .cumulative:
            currentValue = habitLogService.value(for: habit, on: today)
        }

        let clampedProgress = min(max(currentValue / targetValue, 0), 1)
        let isComplete = clampedProgress >= 1
        let displayCurrent = isComplete ? targetValue : max(0, currentValue)
        let summaryText = "\(formattedTodayGoalValue(displayCurrent)) of \(formattedTodayGoalValue(targetValue)) today"

        if clampedProgress == 0 {
            cachedTodayGoalProgress = TodayGoalProgressPresentation(
                summaryText: summaryText,
                readinessText: "Start when ready",
                fraction: clampedProgress,
                isComplete: false
            )
            return
        }

        if isComplete {
            cachedTodayGoalProgress = TodayGoalProgressPresentation(
                summaryText: summaryText,
                readinessText: nil,
                fraction: clampedProgress,
                isComplete: true
            )
            return
        }

        let remainingValue = max(0, targetValue - currentValue)
        let summaryWithRemaining: String
        switch habit.goalType {
        case .frequency:
            let remainingCount = max(0, Int(remainingValue.rounded(.up)))
            summaryWithRemaining = "\(summaryText) • \(remainingCount) more to hit today"
        case .cumulative:
            summaryWithRemaining = "\(summaryText) • \(formattedTodayGoalValue(remainingValue)) to go"
        }

        cachedTodayGoalProgress = TodayGoalProgressPresentation(
            summaryText: summaryWithRemaining,
            readinessText: nil,
            fraction: clampedProgress,
            isComplete: false
        )
    }

    private func applyHistoryProjectionSnapshotRefresh(seedFromCommitted: Bool = false) {
        refreshHistoryProjectionState(seedFromCommitted: seedFromCommitted)
        viewModel.refreshHistorySnapshot(
            projectedDayStates: historyProjectedDayStates,
            calendar: calculationCalendar
        )
    }

    private func requestHistoryProjectionSnapshotRefresh(seedFromCommitted: Bool = false) {
        guard viewModel.isActive, !isHistoryPresented else {
            applyHistoryProjectionSnapshotRefresh(seedFromCommitted: seedFromCommitted)
            return
        }

        guard isDetailScrollActive else {
            applyHistoryProjectionSnapshotRefresh(seedFromCommitted: seedFromCommitted)
            return
        }

        deferredRefreshQueue.historyProjectionSnapshot = true
        deferredRefreshQueue.historyProjectionSeedFromCommitted = deferredRefreshQueue.historyProjectionSeedFromCommitted || seedFromCommitted
        detailPerfLog("scroll-defer history-projection")
    }

    private func requestProgressSnapshotRefresh(now: Date = Date()) {
        guard viewModel.isActive, !isHistoryPresented else { return }
        guard !isDetailScrollActive else {
            deferredRefreshQueue.progressSnapshot = true
            detailPerfLog("scroll-defer progress-snapshot")
            return
        }
        scheduleProgressSnapshotRefresh(now: now)
    }

    private func startCueInsightRefreshTask() {
        cueRefreshTask?.cancel()
        cueRefreshTask = Task { await refreshCueInsight() }
    }

    private func requestCueInsightRefresh() {
        guard viewModel.isActive, !isHistoryPresented else { return }
        guard !isDetailScrollActive else {
            deferredRefreshQueue.cueInsight = true
            detailPerfLog("scroll-defer cue-refresh")
            return
        }
        startCueInsightRefreshTask()
    }

    private func requestAICoachRegeneration(requestKey: String) {
        guard viewModel.isActive else { return }
        guard !isDetailScrollActive else {
            deferredRefreshQueue.aiCoachRequestKey = requestKey
            detailPerfLog("scroll-defer ai-coach")
            return
        }
        regenerateAICoach(requestKey: requestKey)
    }

    private func requestRhythmRefresh() async {
        guard viewModel.isActive, !isHistoryPresented else { return }
        guard !isDetailScrollActive else {
            deferredRefreshQueue.rhythmData = true
            detailPerfLog("scroll-defer rhythm-refresh")
            return
        }
        await refreshRhythmData()
    }

    private func flushDeferredRefreshQueueIfNeeded() {
        guard !deferredRefreshQueue.isEmpty else { return }
        let queued = deferredRefreshQueue
        deferredRefreshQueue = DetailDeferredRefreshQueue()

        if queued.historyProjectionSnapshot {
            applyHistoryProjectionSnapshotRefresh(seedFromCommitted: queued.historyProjectionSeedFromCommitted)
        }
        if queued.progressSnapshot {
            scheduleProgressSnapshotRefresh()
        }
        if queued.cueInsight {
            startCueInsightRefreshTask()
        }
        if queued.rhythmData {
            Task { await refreshRhythmData() }
        }
        if let requestKey = queued.aiCoachRequestKey {
            regenerateAICoach(requestKey: requestKey)
        }
        detailPerfLog("scroll-flush completed")
    }

    private func handleDetailScrollOffsetChange(_ offset: CGFloat) {
        guard viewModel.isActive, !isHistoryPresented else { return }
        defer { lastObservedDetailScrollOffset = offset }

        guard let previous = lastObservedDetailScrollOffset else { return }
        guard abs(previous - offset) > 0.5 else { return }

        if !isDetailScrollActive {
            isDetailScrollActive = true
            detailPerfLog("scroll-start")
        }

        detailScrollIdleTask?.cancel()
        detailScrollIdleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            isDetailScrollActive = false
            detailPerfLog("scroll-stop")
            flushDeferredRefreshQueueIfNeeded()
        }
    }

    private func recordUIReconcileProbe(stage: String) {
        guard let startedAt = habitLogService.lastLogUserActionAt else { return }
        let deltaMs = Date().timeIntervalSince(startedAt) * 1000

        #if DEBUG
        let traceEnabled = ProcessInfo.processInfo.environment["UI_RECONCILE_DEBUG"]?.lowercased() == "1"
        guard traceEnabled else { return }
        #else
        return
        #endif

        // Ignore stale probes from older actions and prevent duplicate noise per stage.
        guard deltaMs >= 0, deltaMs < 3_000 else { return }
        let probeKey = "\(startedAt.timeIntervalSince1970)-\(stage)"
        if lastReconcileProbeKey == probeKey {
            return
        }

        print(String(format: "PERF: %@ reconcile in %.1fms", stage, deltaMs))
        lastReconcileProbeKey = probeKey
    }

    private func historyMonthLabel(for visibleMonth: Date) -> String {
        visibleMonth.formatted(
            Date.FormatStyle()
                .month(.wide)
                .year()
        )
    }

    private func historyMonthKey(for visibleMonth: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: visibleMonth)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return "\(year)-\(month)"
    }

    private func historyInsightSummary(
        snapshot: HistorySnapshot,
        visibleMonth: Date,
        now: Date,
        calendar: Calendar
    ) -> HistoryInsightSummary {
        let monthTitle = visibleMonth.formatted(
            Date.FormatStyle()
                .month(.wide)
        )
        let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth)
        let monthCounts = snapshot.dailyCounts.filter { day, _ in
            guard let monthInterval else { return false }
            return monthInterval.contains(day)
        }
        let activeDays = monthCounts.values.filter { $0 > 0 }.count
        let entries = monthCounts.values.reduce(0, +)
        let bestStreak = historyBestStreak(
            snapshot: snapshot,
            visibleMonth: visibleMonth,
            now: now,
            calendar: calendar
        )

        return HistoryInsightSummary(
            monthTitle: monthTitle,
            activeDays: activeDays,
            entries: entries,
            bestStreak: bestStreak
        )
    }

    private func historyBestStreak(
        snapshot: HistorySnapshot,
        visibleMonth: Date,
        now: Date,
        calendar: Calendar
    ) -> Int {
        let streakCalendar = calendar
        guard let monthInterval = streakCalendar.dateInterval(of: .month, for: visibleMonth) else {
            return 0
        }

        let periodEndDayExclusive = streakCalendar.startOfDay(for: monthInterval.end)
        let periodLastDay = streakCalendar.date(byAdding: .day, value: -1, to: periodEndDayExclusive) ?? monthInterval.start
        let asOf = min(streakCalendar.startOfDay(for: now), periodLastDay)

        var best = 0
        var current = 0
        var day = streakCalendar.startOfDay(for: monthInterval.start)

        while day <= asOf {
            if (snapshot.dailyCounts[day] ?? 0) > 0 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
            guard let next = streakCalendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = next
        }

        return best
    }

    private func selectedDayContextSummary(
        snapshot: HistorySnapshot,
        selectedDate: Date,
        calendar: Calendar
    ) -> SelectedDayContextSummary {
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        let dayLabel = normalizedDate.formatted(
            Date.FormatStyle()
                .day()
                .month(.abbreviated)
        )

        let loggedText: String
        switch habit.goalType {
        case .frequency:
            let count = snapshot.dailyCounts[normalizedDate] ?? 0
            loggedText = "\(count) \(count == 1 ? "entry" : "entries")"
        case .cumulative:
            let total = snapshot.dailyValues[normalizedDate] ?? 0
            let valueText = habitLogService.formatValue(total, for: habit)
            loggedText = "\(valueText)\(habitLogService.displayUnitSuffix(for: habit))"
        }

        return SelectedDayContextSummary(
            dayLabel: dayLabel,
            loggedText: loggedText
        )
    }

    private func fadingHistorySecondaryText(_ text: String, id: String) -> some View {
        ZStack {
            Text(text)
                .id(id)
                .font(CadenceTokens.Typography.roleSectionHeader.weight(.medium))
                .foregroundStyle(CadenceTokens.Color.Text.primary)
                .lineLimit(1)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: id)
    }

    private func scheduleProgressSnapshotRefresh(now: Date = Date()) {
        snapshotRefreshTask?.cancel()

        snapshotRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))

            guard !Task.isCancelled else { return }

            refreshProgressSnapshot(now: now)
        }
    }

    private func refreshProgressSnapshot(now: Date = Date()) {
        let progressService = ProgressAsOfService(
            calendar: habitLogService.calendar,
            weekStartPreference: userSettings.weekStartPreference,
            now: { now }
        )

        let metricDays = progressService.metricDays(
            for: habit,
            visibleMonth: selectionState.visibleMonth,
            selectedDate: selectedDate
        )

        let dayMetrics = habitLogService.dayMetrics(for: habit, on: metricDays)

        cachedProgressSnapshot = progressService.snapshot(
            for: habit,
            visibleMonth: selectionState.visibleMonth,
            selectedDate: selectedDate,
            dayMetrics: dayMetrics
        )
        refreshTodayGoalProgressPresentation()
        metadataSectionState = .loaded(())
    }

    private var weekLayoutStrategy: WeekLayoutStrategy {
        userSettings.weekLayoutStrategy(base: habitLogService.calendar)
    }

    private var calculationCalendar: Calendar {
        weekLayoutStrategy.calendarForCalculations()
    }

    private var calendarViewProvider: CalendarProvider {
        weekLayoutStrategy.calendarProviderForCalendarView()
    }

    private var heatmapCalendarProvider: CalendarProvider {
        weekLayoutStrategy.calendarProviderForHeatmap()
    }

    private var hasInsightsInlineAction: Bool {
        guard viewModel.historySnapshot.totalEntries >= 3 else { return false }
        return purchaseService.premiumStatus != .unknown
    }

    private var insightsInlineNudgeText: String {
        "See your patterns"
    }

    private func openInsightsOrPaywall() {
        switch purchaseService.premiumStatus {
        case .unknown:
            return
        case .premium:
            activeSheet = .insights
        case .free:
            showPaywall(feature: .advancedInsights)
        }
    }

    private var isCompleteForSelectedDate: Bool {
        uiStateStore.projectedDayState(
            habitID: habit.id,
            day: selectedDate,
            calendar: calculationCalendar
        )?.isComplete ?? false
    }

    private var userDefinedCueText: String? {
        let trimmed = habit.cueText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private var userDefinedIdentityText: String? {
        let trimmed = habit.identity?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private var goalDescriptorText: String {
        guard habit.hasGoal,
              let targetValue = habit.effectiveTargetValue,
              targetValue > 0 else {
            return "Flexible habit"
        }

        let periodText = "per \(habit.goalPeriod.unit)"

        switch habit.goalType {
        case .frequency:
            let targetCount = max(1, Int(targetValue.rounded()))
            return "\(targetCount)× \(periodText) target"
        case .cumulative:
            let targetText = habit.formatProgressValue(targetValue)
            let unitSuffix: String = {
                guard MetricKindResolver.resolve(habit) == .genericValue,
                      let normalizedUnit = normalizedGoalDescriptorUnit else {
                    return ""
                }
                return " \(normalizedUnit)"
            }()
            return "\(targetText)\(unitSuffix) \(periodText) target"
        }
    }

    @ViewBuilder
    private func todayGoalProgressRow(_ progress: TodayGoalProgressPresentation) -> some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: CadenceTokens.Space.xs) {
                Text(progress.summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if progress.isComplete {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let readinessText = progress.readinessText {
                Text(readinessText)
                    .font(.footnote)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GeometryReader { proxy in
                let clampedProgress = min(max(progress.fraction, 0), 1)
                let fillWidth = clampedProgress * proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CadenceTokens.Color.accent(for: habit).primary.opacity(0.12))
                    Capsule()
                        .fill(CadenceTokens.Color.accent(for: habit).primary.opacity(0.7))
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 5)
            .animation(
                shouldAnimateGoalProgress ? .easeOut(duration: 0.24) : nil,
                value: progress.fraction
            )
        }
    }

    private var todayGoalProgressPresentation: TodayGoalProgressPresentation? {
        cachedTodayGoalProgress
    }

    private func formattedTodayGoalValue(_ value: Double) -> String {
        switch habit.goalType {
        case .frequency:
            return "\(max(0, Int(value.rounded(.down))))"
        case .cumulative:
            let baseText = habit.formatProgressValue(max(0, value))
            guard MetricKindResolver.resolve(habit) == .genericValue,
                  let normalizedUnit = normalizedGoalDescriptorUnit else {
                return baseText
            }
            return "\(baseText) \(normalizedUnit)"
        }
    }

    private var normalizedGoalDescriptorUnit: String? {
        guard let unit = habit.trimmedUnit else { return nil }
        switch unit.lowercased() {
        case "minute", "minutes", "min", "mins":
            return "mins"
        default:
            return unit
        }
    }

    private func cueSourceHabitName(for insight: CueInsight) -> String? {
        allHabitsSnapshot().first(where: { $0.id == insight.sourceHabitId })?.name
    }

    private func guidancePattern() -> HabitPattern? {
        let habits = allHabitsSnapshot()
        if let triggerHabitID = habit.triggerHabitID,
           let triggerHabit = habits.first(where: { $0.id == triggerHabitID }) {
            return HabitPattern(
                description: "after \(triggerHabit.name.lowercased())",
                anchor: triggerHabit.name
            )
        }

        if let cueInsight,
           let sourceHabitName = cueSourceHabitName(for: cueInsight) {
            return HabitPattern(
                description: "after \(sourceHabitName.lowercased())",
                anchor: sourceHabitName
            )
        }

        return nil
    }

    private func refreshCueInsight() async {
        guard viewModel.isActive else { return }
        let requestSequence = cueRequestSequence + 1
        cueRequestSequence = requestSequence
        let insight = await habitLogService.detectCue(for: habit.id)
        guard !Task.isCancelled, cueRequestSequence == requestSequence else { return }
        cueInsight = insight
    }

    private var rhythmTaskKey: String {
        let metricsRevision = habitLogService.metricsRevision(for: habit.id)
        let projectionVersion = uiStateStore.projectionVersionByHabitID[habit.id] ?? 0
        let premiumStateToken: String = {
            switch purchaseService.premiumStatus {
            case .unknown:
                return "unknown"
            case .free:
                return "free"
            case .premium:
                return "premium"
            }
        }()
        return "\(habit.id.uuidString)-\(metricsRevision)-\(projectionVersion)-\(premiumStateToken)"
    }

    private func refreshRhythmData() async {
        let requestID = UUID()
        currentRhythmRequestID = requestID
        let startedAt = Date()
        rhythmDebugLog("compute-start request=\(requestID.uuidString) premium=\(String(describing: purchaseService.premiumStatus))")
        guard purchaseService.premiumStatus != .unknown else {
            rhythmSectionState = .loading
            rhythmDebugLog("compute-end request=\(requestID.uuidString) count=0 reason=premium-unknown elapsedMs=\(rhythmElapsedMs(since: startedAt))")
            return
        }

        let values = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: habit,
            globalLogs: [],
            isPremium: purchaseService.premiumStatus == .premium,
            now: .now,
            calendar: calculationCalendar
        )

        guard !Task.isCancelled else {
            rhythmDebugLog("compute-cancelled request=\(requestID.uuidString)")
            return
        }
        guard currentRhythmRequestID == requestID else {
            rhythmDebugLog("compute-stale request=\(requestID.uuidString)")
            return
        }
        rhythmSectionState = values.isEmpty ? .empty : .loaded(values)
        detailPerfLog("rhythm-resolve-ms=\(detailElapsedMs(since: startedAt)) count=\(values.count)")
        rhythmDebugLog("compute-end request=\(requestID.uuidString) count=\(values.count) elapsedMs=\(rhythmElapsedMs(since: startedAt))")
    }

    @MainActor
    private func bootstrapDetailSections(now: Date) async {
        await Task.yield()
        measureMainThreadWork("bootstrap.updateCalendar") {
            habitLogService.updateCalendar(calculationCalendar)
        }
        measureMainThreadWork("bootstrap.prepare") {
            habitLogService.prepare(habit)
        }
        measureMainThreadWork("bootstrap.historyProjectionSnapshot") {
            applyHistoryProjectionSnapshotRefresh(seedFromCommitted: false)
        }
        // Do not keep header/meta content blocked on progress snapshot timing.
        metadataSectionState = .loaded(())
        scheduleProgressSnapshotRefresh(now: now)
        debugPrintRecentHabitLogTimestamps()
        freezeStateModelOnAppear()
        refreshCoachingContextAndGuidance(now: now)
        aiCoachSectionState = {
            if let output = frozenGuidanceOutput {
                return .loaded(output)
            }
            return .empty
        }()
        coachPresentationState = aiCoach.isAppleIntelligenceAvailable()
            ? .loadingAI
            : .fallbackGuidance(guidanceCoachText)
        detailPerfLog("ai-section-ready")
        regenerateAICoachOnAppear()
    }

    private var aiCoachSectionPhase: Int {
        switch aiCoachSectionState {
        case .loading:
            return 0
        case .loaded:
            return 1
        case .empty:
            return 2
        }
    }

    private var rhythmSectionPhase: Int {
        switch rhythmSectionState {
        case .loading:
            return 0
        case .loaded:
            return 1
        case .empty:
            return 2
        }
    }

    private var rhythmPlaceholderData: [HourValue] {
        (0..<24).map { hour in
            let wave = (sin((Double(hour) / 24.0) * .pi * 2.0) + 1.0) * 0.35
            return HourValue(hour: hour, value: max(0.05, wave))
        }
    }

    private var rhythmZeroData: [HourValue] {
        (0..<24).map { HourValue(hour: $0, value: 0) }
    }

    private var placeholderGuidanceOutput: GuidanceOutput {
        GuidanceOutput(
            id: "detail-placeholder",
            title: "Building your rhythm",
            action: "Your guidance will appear here once this section resolves.",
            supportingContext: nil,
            emphasisLabel: nil,
            type: .identity,
            payload: GuidancePayload(
                state: .forming,
                strongestWindow: "—",
                confidence: .low,
                guidance: "Your guidance will appear here once this section resolves.",
                explanation: "Loading placeholder"
            )
        )
    }

    private var isRhythmDetailDebugEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["RHYTHM_DETAIL_DEBUG"]?.lowercased() == "1"
        #else
        false
        #endif
    }

    private func rhythmDebugLog(_ message: String) {
        guard isRhythmDetailDebugEnabled else { return }
        print("[RhythmDetail] \(message)")
    }

    private func rhythmElapsedMs(since start: Date) -> String {
        String(format: "%.1f", Date().timeIntervalSince(start) * 1000)
    }

    private var isDetailPerfDebugEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["DETAIL_PERF_DEBUG"]?.lowercased() == "1"
        #else
        false
        #endif
    }

    private func detailPerfLog(_ message: String) {
        guard isDetailPerfDebugEnabled else { return }
        print("[DetailPerf] \(message)")
    }

    private func detailElapsedMs(since start: Date) -> String {
        String(format: "%.1f", Date().timeIntervalSince(start) * 1000)
    }

    private func measureMainThreadWork(_ label: String, _ work: () -> Void) {
        let startedAt = Date()
        work()
        let elapsedMs = Date().timeIntervalSince(startedAt) * 1000
        guard elapsedMs > 16 else { return }
        detailPerfLog("main-thread-\(label)-ms=\(String(format: "%.1f", elapsedMs))")
    }

    private var detectedCueText: String? {
        guard let cueInsight,
              let sourceHabitName = cueSourceHabitName(for: cueInsight) else {
            return nil
        }
        return "You tend to \(habit.name.lowercased()) after \(sourceHabitName.lowercased())"
    }

    private func regenerateAICoach(requestKey: String) {
        guard viewModel.isActive else { return }
        refreshCoachingContextAndGuidance(now: appTime.now)
        guard let context = coachingContext else { return }

        let expectedSignals = expectedUsedSignals(
            depth: context.depth,
            selectedSignals: context.selectedSignals
        )

        guard aiCoach.isAppleIntelligenceAvailable() else {
            coachPresentationState = .fallbackGuidance(guidanceCoachText)
            return
        }

        if let cached = aiCoach.cachedTextIfFresh(
            habitID: habit.id,
            fingerprint: context.aiFingerprint,
            depth: context.depth
        ) {
            applyAICandidate(
                PendingAICandidate(
                    text: cached,
                    usedSignals: expectedSignals,
                    aiFingerprint: context.aiFingerprint
                )
            )
            return
        }

        let input = buildAICoachInput(context: context)
        coachPresentationState = .loadingAI
        aiCoach.generate(
            habitID: habit.id,
            input: input,
            fingerprint: context.aiFingerprint,
            requestKey: requestKey
        ) { finalText in
            self.applyAICandidate(
                PendingAICandidate(
                    text: finalText,
                    usedSignals: expectedSignals,
                    aiFingerprint: context.aiFingerprint
                )
            )
        }
    }

    private func regenerateAICoachOnAppear() {
        guard viewModel.isActive else { return }
        let requestKey = "onAppear-\(habit.id.uuidString)-\(Date().timeIntervalSince1970)"
        regenerateAICoach(requestKey: requestKey)
    }

    private func freezeStateModelOnAppear() {
        guard viewModel.isActive else { return }
        guard frozenStateModel == nil else { return }
        frozenStateModel = nil
    }

    private func freezeDetailState(resetCueInsight: Bool = true) {
        if resetCueInsight {
            cueInsight = nil
        }
        coachPresentationState = .fallbackGuidance(SafeMinimalCoaching.line)
        coachingContext = nil
        guidanceCoachText = SafeMinimalCoaching.line
        guidanceUsedSignals = []
        aiUsedSignals = []
        pendingAICandidate = nil
        coachRenderUnlockTask?.cancel()
        coachRenderLockedUntil = .distantPast
        aiCoachSectionState = .loading
        metadataSectionState = .loading
        currentRhythmRequestID = nil
        rhythmSectionState = .loading
        snapshotRefreshTask?.cancel()
        goalProgressAnimationResetTask?.cancel()
        detailScrollIdleTask?.cancel()
        isDetailScrollActive = false
        deferredRefreshQueue = DetailDeferredRefreshQueue()
        lastObservedDetailScrollOffset = nil
        shouldAnimateGoalProgress = false
    }

    private func triggerGoalProgressAnimation() {
        shouldAnimateGoalProgress = true
        goalProgressAnimationResetTask?.cancel()
        goalProgressAnimationResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            shouldAnimateGoalProgress = false
        }
    }

    private func buildAICoachInput(context: CoachingContext) -> AICoachInput {
        let strongestTime = context.input.timeOfDayInsights.strongestWindow
        let streakLabel: String = {
            let streak = currentStreakState(now: appTime.now)
            guard streak.currentStreak > 0 else { return "forming" }
            switch streak.status {
            case .safe:
                return "\(streak.currentStreak)-period streak"
            case .atRisk:
                return "\(streak.currentStreak)-period streak at risk"
            case .broken:
                return "streak broken"
            }
        }()

        return AICoachInput(
            coachingInput: context.input,
            depth: context.depth,
            selectedSignals: context.selectedSignals,
            habitName: habit.name,
            recentLogs: recentLogsSummary(),
            state: context.input.identityState,
            timingConfidence: context.input.timeOfDayInsights.confidence,
            strongestTime: strongestTime,
            weakestTime: nil,
            streakState: streakLabel,
            identity: userDefinedIdentityText,
            stacking: guidancePattern()?.description,
            todayStatus: context.input.todayStatus,
            behaviourSummary: context.input.recentBehaviourSummary
        )
    }

    private func allHabitsSnapshot() -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.orderIndex)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func recentLogsSummary() -> String {
        let recentDays = historyProjectedDayStates
            .filter { $0.value.count > 0 || $0.value.value > 0 }
            .map(\.key)
            .sorted(by: >)
            .prefix(3)
        guard !recentDays.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.locale = calculationCalendar.locale ?? .current
        formatter.calendar = calculationCalendar
        formatter.timeZone = calculationCalendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let labels = recentDays.map { formatter.string(from: $0) }
        return "Recent check-ins: \(labels.joined(separator: ", "))."
    }

    private func weakestTimeWindow() -> String? {
        let isPremium = purchaseService.premiumStatus == .premium
        guard let rhythm = TimeOfDayPerformanceService.shared.cachedRhythm(for: habit, isPremium: isPremium),
              rhythm.uniqueEventCount > 0 else {
            return nil
        }
        return "\(humanTime(for: rhythm.dipStart)) to \(humanTime(for: rhythm.dipEnd))"
    }

    private func behaviourSummary(
        for state: HabitState
    ) -> String {
        guard viewModel.historySnapshot.totalEntries > 0 else { return "Routine is still forming." }
        switch state {
        case .strong:
            return "Recent behaviour is stable and reliable."
        case .steady:
            return "Recent behaviour is settling into a routine."
        case .build:
            return "Repetition is forming a routine."
        case .start:
            return "Behaviour is just beginning."
        case .slip, .rebuild:
            return "Recent behaviour needs re-engagement."
        }
    }

    private func resolvedCoachMessage(for output: GuidanceOutput) -> String {
        switch coachPresentationState {
        case .loadingAI:
            return aiCoach.loadingText
        case .ai(let message):
            let trimmed = normalizeAICoachMessage(message).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? SafeMinimalCoaching.line : trimmed
        case .fallbackGuidance(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            let outputText = output.action.trimmingCharacters(in: .whitespacesAndNewlines)
            return outputText.isEmpty ? SafeMinimalCoaching.line : outputText
        }
    }

    private func normalizeAICoachMessage(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "Most active around", with: "Strongest window:")
            .replacingOccurrences(of: "most active around", with: "strongest window:")
            .replacingOccurrences(of: "Pattern still forming", with: "Timing is still forming")
        return normalized
    }

    private var isAICoachThinking: Bool {
        if case .loadingAI = coachPresentationState { return true }
        return false
    }

    private var aiCoachDetailMessage: String {
        switch aiCoachSectionState {
        case .loaded(let output):
            return resolvedCoachMessage(for: output)
        case .loading:
            return SafeMinimalCoaching.line
        case .empty:
            return SafeMinimalCoaching.line
        }
    }

    private var coachCardLabel: String {
        switch coachPresentationState {
        case .loadingAI, .ai:
            return "AI Coach"
        case .fallbackGuidance:
            return "Guidance"
        }
    }

    private var resolvedCoachingDepth: CoachingDepth {
        purchaseService.premiumStatus == .premium ? .premium : .basic
    }

    private func buildCoachingContext(
        now: Date,
        streakState: StreakState,
        identityState: HabitIdentityStateSnapshot
    ) -> CoachingContext {
        let cachedComputedState = habitLogService.computedStateByHabitID[habit.id]
        let resolvedIdentityState = (cachedComputedState?.identityState ?? identityState.state).habitState
        let strongestWindow = cachedComputedState?.timingInsight.map { humanTime(for: $0.peakHour) }
        let timingConfidence = frozenStateModel?.timingConfidence ?? .low
        let streakLabel = streakDescription(streakState)
        let consistencyMetrics = HabitInsightsService(calendar: calculationCalendar)
            .consistencyMetrics(for: habit, now: now)
        let consistency = consistencyMetrics.consistencyPercentage
        let startOfDay = calculationCalendar.startOfDay(for: now)
        let dayBucket = Int64(startOfDay.timeIntervalSince1970)
        let dayOrdinal = calculationCalendar.ordinality(of: .day, in: .era, for: startOfDay) ?? 0
        let input = CoachingInput(
            identityState: resolvedIdentityState,
            streakState: streakLabel,
            consistency: consistency,
            timeOfDayInsights: CoachingTimeOfDayInsights(
                strongestWindow: strongestWindow,
                confidence: timingConfidence
            ),
            recentBehaviourSummary: behaviourSummary(for: resolvedIdentityState),
            todayStatus: BehaviourCopyFormatter.dailyStatus(isDoneToday: hasActivityToday()),
            windowDays: max(1, consistencyMetrics.daysAvailable),
            dayBucket: dayBucket,
            dayOrdinal: dayOrdinal
        )
        let depth = resolvedCoachingDepth
        let selectedSignals = GuidanceEngine.selectSignals(for: input, depth: depth)
        let coreMeaningFingerprint = input.coreMeaningFingerprint(selectedSignals: selectedSignals)
        let aiFingerprint = input.aiFingerprint(depth: depth, selectedSignals: selectedSignals)
        return CoachingContext(
            input: input,
            depth: depth,
            selectedSignals: selectedSignals,
            coreMeaningFingerprint: coreMeaningFingerprint,
            aiFingerprint: aiFingerprint
        )
    }

    private func refreshCoachingContextAndGuidance(now: Date) {
        let previousAIFingerprint = coachingContext?.aiFingerprint
        let streakState = currentStreakState(now: now)
        let identityState = identityStateSummary()
        let context = buildCoachingContext(
            now: now,
            streakState: streakState,
            identityState: identityState
        )
        coachingContext = context
        if let previousAIFingerprint, previousAIFingerprint != context.aiFingerprint {
            aiUsedSignals = []
            pendingAICandidate = nil
            if case .ai = coachPresentationState {
                coachPresentationState = .fallbackGuidance(guidanceCoachText)
            }
        }

        let guidanceBody = GuidanceEngine.coachingBody(
            from: context.input,
            depth: context.depth,
            selectedSignals: context.selectedSignals,
            meaningScope: habit.id.uuidString
        )
        guidanceCoachText = guidanceBody.text
        guidanceUsedSignals = guidanceBody.usedSignals

        let baseOutput = guidanceOutput(
            streakState: streakState,
            identityState: identityState
        )
        let resolvedOutput = GuidanceOutput(
            id: baseOutput.id,
            title: baseOutput.title,
            action: guidanceBody.text,
            supportingContext: baseOutput.supportingContext,
            emphasisLabel: baseOutput.emphasisLabel,
            type: baseOutput.type,
            payload: GuidancePayload(
                state: baseOutput.payload.state,
                strongestWindow: baseOutput.payload.strongestWindow,
                confidence: baseOutput.payload.confidence,
                guidance: guidanceBody.text,
                explanation: baseOutput.payload.explanation
            ),
            usedSignals: guidanceBody.usedSignals
        )
        frozenGuidanceOutput = resolvedOutput
        if case .loaded = aiCoachSectionState {
            aiCoachSectionState = .loaded(resolvedOutput)
        }
    }

    private func streakDescription(_ streakState: StreakState) -> String {
        guard streakState.currentStreak > 0 else { return "forming" }
        switch streakState.status {
        case .safe:
            return "\(streakState.currentStreak)-period streak"
        case .atRisk:
            return "\(streakState.currentStreak)-period streak at risk"
        case .broken:
            return "streak broken"
        }
    }

    private func expectedUsedSignals(
        depth: CoachingDepth,
        selectedSignals: SelectedCoachingSignals
    ) -> Set<CoachingSignalID> {
        if depth == .premium, selectedSignals.secondary != nil {
            return selectedSignals.all
        }
        return [selectedSignals.primary]
    }

    private func applyAICandidate(_ candidate: PendingAICandidate) {
        guard viewModel.isActive else { return }
        let now = Date()
        if now < coachRenderLockedUntil {
            pendingAICandidate = candidate
            scheduleCoachRenderUnlock()
            return
        }
        publishAICandidate(candidate)
    }

    private func publishAICandidate(_ candidate: PendingAICandidate) {
        let text = normalizeAICoachMessage(candidate.text).trimmingCharacters(in: .whitespacesAndNewlines)
        let isUsable = !text.isEmpty && text.wordCount >= 8 && genericityScore(text) == 0
        guard isUsable else {
            if case .loadingAI = coachPresentationState {
                coachPresentationState = .fallbackGuidance(guidanceCoachText)
            }
            return
        }

        let guidanceText = guidanceCoachText.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = guidanceText
        coachPresentationState = .ai(text)
        aiUsedSignals = candidate.usedSignals
        lockCoachRenderWindow()
    }

    private func lockCoachRenderWindow() {
        coachRenderLockedUntil = Date().addingTimeInterval(1.0)
        scheduleCoachRenderUnlock()
    }

    private func scheduleCoachRenderUnlock() {
        coachRenderUnlockTask?.cancel()
        let waitNanos = UInt64(max(coachRenderLockedUntil.timeIntervalSinceNow, 0) * 1_000_000_000)
        coachRenderUnlockTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: waitNanos)
            guard !Task.isCancelled else { return }
            if let pending = pendingAICandidate {
                pendingAICandidate = nil
                publishAICandidate(pending)
            }
        }
    }

    private func genericityScore(_ text: String) -> Int {
        let normalized = normalizedCoachText(text)
        let genericPhrases = [
            "keep going",
            "you re doing great",
            "you are doing great",
            "stay consistent",
            "you will succeed",
            "you got this",
            "don t give up",
            "dont give up"
        ]
        return genericPhrases.reduce(into: 0) { score, phrase in
            if normalized.contains(phrase) {
                score += 1
            }
        }
    }

    private func normalizedCoachText(_ text: String) -> String {
        let collapsed = text.lowercased().replacingOccurrences(
            of: "[^a-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func openHistoryFromDetail(earliestCalendarDate: Date?) {
        if let earliestCalendarDate {
            let normalizedEarliest = calculationCalendar.startOfDay(for: earliestCalendarDate)
            if selectedDate < normalizedEarliest {
                selectedDate = normalizedEarliest
                selectionState.select(date: normalizedEarliest)
            }
        }
        isHistoryPresented = true
    }

}

private struct DetailHeaderIdentity: View {
    let habitName: String
    let iconName: String?
    let accent: Color

    private var resolvedIcon: String? {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            HabitBadge(
                iconName: resolvedIcon,
                accent: accent,
                habitName: habitName,
                size: 30
            )
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[.bottom] - 2
            }

            Text(habitName)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(CadenceTokens.Color.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct InsightsInlineNudgeRow: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CadenceTokens.Space.sm) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .regular))

                Text(text)
                    .font(CadenceTokens.Typography.body)
                    .lineLimit(1)

                Spacer(minLength: CadenceTokens.Space.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint("Open insights")
    }
}

struct CueInsightView: View {
    let text: String
    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.7))

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeIn(duration: 0.2), value: isVisible)
        .onAppear { isVisible = true }
        .accessibilityElement(children: .combine)
    }
}

private struct StreakCardConfiguration: Equatable {
    enum State: Equatable {
        case secured
        case atRisk
        case offTrack
    }

    let streakState: StreakState
    let state: State

    init(streakState: StreakState) {
        self.streakState = streakState
        switch streakState.status {
        case .safe:
            self.state = .secured
        case .atRisk:
            self.state = .atRisk
        case .broken:
            self.state = .offTrack
        }
    }

    var iconSystemName: String {
        switch state {
        case .secured:
            return "flame.fill"
        case .atRisk:
            return "exclamationmark.triangle.fill"
        case .offTrack:
            return "exclamationmark.triangle.fill"
        }
    }

    var titleText: String {
        if streakState.currentStreak <= 0 {
            switch state {
            case .secured:
                return "Ready to begin"
            case .atRisk:
                return "Ready to begin"
            case .offTrack:
                return "This is where it starts"
            }
        }

        let dayText = streakState.currentStreak == 1 ? "Day" : "Days"
        return "\(streakState.currentStreak) \(dayText.lowercased()) streak"
    }

    var supportingPrimaryText: String {
        streakTierMessage(for: streakState.currentStreak)
    }

    var supportingSecondaryText: String? {
        if streakState.currentStreak <= 0 {
            switch state {
            case .secured:
                return "Every habit starts with one"
            case .atRisk:
                return "Small start, strong finish"
            case .offTrack:
                return "Your first step counts"
            }
        }

        switch state {
        case .secured:
            return nil
        case .atRisk:
            return "Protect this streak today"
        case .offTrack:
            return nil
        }
    }

    private func streakTierMessage(for streak: Int) -> String {
        switch streak {
        case ..<1:
            return "Not started yet"
        case 1:
            return "Getting started"
        case 2...3:
            return "Building rhythm"
        case 4...6:
            return "Finding consistency"
        default:
            return "Strong rhythm"
        }
    }
}

private struct StreakNudgeCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let configuration: StreakCardConfiguration
    let accent: CadenceAccentTokens

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.xs + 2) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: configuration.iconSystemName)
                    .font(.system(size: configuration.state == .secured ? 18 : 17.1, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(iconColor)
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[.bottom] - 2
                    }

                Text(configuration.titleText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary.opacity(0.86))
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.supportingPrimaryText)
                    .font(CadenceTokens.Typography.supporting)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.78))
                    .lineLimit(1)

                if let secondary = configuration.supportingSecondaryText {
                    Text(secondary)
                        .font(CadenceTokens.Typography.supporting)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.74))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CadenceTokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: CadenceTokens.Surface.cardCornerRadius, style: .continuous)
                .fill(accent.primary.opacity(colorScheme == .dark ? 0.05 : 0.028))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CadenceTokens.Surface.cardCornerRadius, style: .continuous)
                .stroke(accent.primary.opacity(colorScheme == .dark ? 0.18 : 0.11), lineWidth: 1)
        )
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [configuration.titleText, configuration.supportingPrimaryText, configuration.supportingSecondaryText]
                .compactMap { $0 }
                .joined(separator: ". ")
        )
    }

    private var iconColor: Color {
        switch configuration.state {
        case .atRisk:
            return Color.orange.opacity(colorScheme == .dark ? 0.82 : 0.74)
        case .offTrack:
            return Color.orange.opacity(colorScheme == .dark ? 0.82 : 0.74)
        case .secured:
            return accent.primary.opacity(colorScheme == .dark ? 0.86 : 0.76)
        }
    }
}

private struct HeroTopRow: View {
    let categoryLabel: String
    let loggingContextText: String

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
            Text(categoryLabel)
                .font(.caption)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                .lineLimit(1)

            Text(loggingContextText)
                .font(CadenceTokens.Typography.body)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HabitIdentityCard: View {
    let identityText: String?
    let statText: String?
    let reflectionText: String
    let accent: CadenceAccentTokens
    let onTap: () -> Void
    @State private var isIdentityInfoPresented = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent.primary.opacity(0.72))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: InsightCardHeader.contentSpacing) {
                InsightCardHeader(
                    title: CadenceLanguage.identityTitle(),
                    onInfoTap: { isIdentityInfoPresented = true },
                    infoAccessibilityLabel: "Identity help"
                )

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let identityText {
                            Text(identityText)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.9))
                                .lineSpacing(2)
                                .lineLimit(2)

                            if let statText {
                                Text(statText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary.opacity(0.9))
                                    .lineLimit(2)

                                Text(reflectionText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary.opacity(0.94))
                                    .padding(.top, 3)
                                    .lineLimit(2)
                            }
                        } else {
                            Text("Someone who keeps moving forward")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.9))
                                .lineLimit(2)

                            Text("This is taking shape")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.9))
                                .lineLimit(2)

                            Text("This is how consistency builds")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.94))
                                .padding(.top, 3)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: CadenceTokens.Space.sm)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CadenceTokens.Space.lg)
        .padding(.top, InsightCardHeader.topPadding)
        .padding(.bottom, InsightCardHeader.bottomPadding)
        .background(
            RoundedRectangle(cornerRadius: CadenceTokens.Surface.cardCornerRadius, style: .continuous)
                .fill(tintColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CadenceTokens.Surface.cardCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .sheet(isPresented: $isIdentityInfoPresented) {
            IdentityExplainerSheet()
                .presentationDetents([.height(340), .medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }

    private var tintColor: Color {
        if identityText != nil {
            return accent.primary
        }

        return CadenceTokens.Color.Background.secondary
    }
}

private struct IdentityExplainerSheet: View {
    private let paragraphOne = "Identity-based habits start with the person you want to become. You act like that version of yourself before it fully feels true, using small consistent behaviours as proof. Instead of chasing outcomes, you focus on becoming someone who naturally does those things."
    private let paragraphTwo = "Each action reinforces that identity. Over time, the evidence builds, belief strengthens, and the behaviour feels automatic. What began as intention becomes reality. You are no longer trying to change, you have become the person who lives it."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
                Text("Identity")
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)

                Text(paragraphOne)
                    .font(CadenceTokens.Typography.supporting)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)

                Text(paragraphTwo)
                    .font(CadenceTokens.Typography.supporting)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CadenceTokens.Space.lg)
        }
        .presentationBackground(CadenceTokens.Color.Background.primary)
    }
}

private struct AICoachDetailSheet: View {
    let title: String
    let message: String
    let isLoading: Bool
    let loadingText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
                Text(title)
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)

                Text(isLoading ? loadingText : message)
                    .font(CadenceTokens.Typography.supporting)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CadenceTokens.Space.lg)
        }
        .presentationBackground(CadenceTokens.Color.Background.primary)
    }
}

private extension String {
    var wordCount: Int {
        split(whereSeparator: \.isWhitespace).count
    }
}

private struct ProgressSummarySection: View, Equatable {
    let snapshot: ProgressAsOfSnapshot?
    let accentHex: String
    let isCumulativeGoal: Bool
    let onTap: () -> Void

    static func == (lhs: ProgressSummarySection, rhs: ProgressSummarySection) -> Bool {
        lhs.snapshot == rhs.snapshot &&
        lhs.accentHex == rhs.accentHex &&
        lhs.isCumulativeGoal == rhs.isCumulativeGoal
    }

    var body: some View {
        Group {
            if let snapshot {
                HabitProgressSummary(
                    headline: snapshot.headlineText,
                    progress: snapshot.progressFraction,
                    overflowFraction: overflowFraction(snapshot),
                    overflowText: snapshot.overflowText,
                    accent: CadenceTokens.Color.accent(from: accentHex)
                )
                .pressableCardFeedback(scale: 0.985, opacity: 0.98)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isCumulativeGoal else { return }
                    onTap()
                }

                Divider().opacity(0.2)
            }
        }
    }

    private func overflowFraction(_ snapshot: ProgressAsOfSnapshot) -> Double {
        guard snapshot.target > 0 else { return 0 }
        return max((snapshot.current / snapshot.target) - 1, 0)
    }
}

private struct KeyActionsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let isCumulativeGoal: Bool
    let isCompleteToday: Bool
    let accentHex: String
    let onQuickLog: () -> Void
    let onManualEntry: () -> Void

    private var primaryLabelText: String {
        isCompleteToday ? "Add more" : "Log today"
    }

    private var accent: CadenceAccentTokens {
        CadenceTokens.Color.accent(from: accentHex)
    }

    private var primaryBaseAccent: Color {
        isCompleteToday ? accent.primary.opacity(0.84) : accent.primary
    }

    var body: some View {
        HStack(spacing: CadenceTokens.Space.sm + 2) {
            primaryButton
                .buttonStyle(QuickActionPressStyle())

            if isCumulativeGoal {
                secondaryButton
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            Haptics.impactLight()
            DispatchQueue.main.async(execute: onQuickLog)
        } label: {
            Label(primaryLabelText, systemImage: "checkmark.circle.fill")
                .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.95)
                .foregroundStyle(CadenceTokens.Color.Background.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CadenceTokens.Space.sm)
                .padding(.horizontal, CadenceTokens.Space.xs)
                .background(primaryButtonBackground)
        }
    }

    private var secondaryButton: some View {
        Button(action: onManualEntry) {
            Label("Add value", systemImage: "plus.circle")
                .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.95)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CadenceTokens.Space.sm)
                .padding(.horizontal, CadenceTokens.Space.xs)
                .background(secondaryButtonBackground)
        }
    }

    private var primaryButtonBackground: some View {
        Capsule()
            .fill(primaryBaseAccent)
            .overlay {
                Capsule()
                    .stroke(CadenceTokens.Color.Background.primary.opacity(colorScheme == .dark ? 0.1 : 0.08), lineWidth: CadenceTokens.Surface.strokeLineWidth)
            }
    }

    private var secondaryButtonBackground: some View {
        Capsule()
            .fill(Color.clear)
            .overlay {
                Capsule()
                    .stroke(CadenceTokens.Color.Text.tertiary.opacity(colorScheme == .dark ? 0.9 : 0.75), lineWidth: CadenceTokens.Surface.strokeLineWidth)
            }
    }
}

private struct QuickActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TodaySummarySection: View {
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
            Text("Today")
                .font(CadenceTokens.Typography.sectionHeader)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)

            Text(summaryText)
                .font(CadenceTokens.Typography.body)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
        }
    }
}

private struct CompactHeatmapPreviewSection: View {
    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let selectedDate: Date
    let earliestVisibleDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
            Text("Activity")
                .font(CadenceTokens.Typography.sectionHeader)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)

            HabitHeatmap(
                habit: habit,
                service: service,
                calendarProvider: calendarProvider,
                selectedDate: selectedDate,
                earliestVisibleDate: earliestVisibleDate,
                isInteractive: false,
                onSelectDay: { _ in },
                onTapLockedDay: { _ in },
                isCompact: true
            )
        }
    }
}

private struct HeatmapSection: View, Equatable {
    let habitID: UUID
    let selectedDate: Date
    let metricsRevision: Int
    let habitVersion: Int
    let earliestVisibleDate: Date?
    let historyDailyCounts: [Date: Int]
    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let onSelectDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    static func == (lhs: HeatmapSection, rhs: HeatmapSection) -> Bool {
        lhs.habitID == rhs.habitID &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.metricsRevision == rhs.metricsRevision &&
        lhs.habitVersion == rhs.habitVersion &&
        lhs.earliestVisibleDate == rhs.earliestVisibleDate &&
        lhs.historyDailyCounts == rhs.historyDailyCounts
    }

    var body: some View {
        HabitHeatmap(
            habit: habit,
            service: service,
            calendarProvider: calendarProvider,
            selectedDate: selectedDate,
            earliestVisibleDate: earliestVisibleDate,
            dailyCountsOverride: historyDailyCounts,
            isInteractive: true,
            onSelectDay: onSelectDay,
            onTapLockedDay: onTapLockedDay
        )
    }
}

private struct CalendarSection: View, Equatable {
    let habitID: UUID
    let selectedDate: Date
    let visibleMonth: Date
    let metricsRevision: Int
    let habitVersion: Int
    let monthSummaryText: String?
    let earliestVisibleDate: Date?
    let historyProjectedDayStates: [Date: HabitProjectedDayState]
    let isTapToLogEnabled: Bool
    let month: Binding<Date>
    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let premiumHistoryGate: PremiumHistoryGate.Context
    let onSelectDay: (Date) -> Void
    let onTapDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    static func == (lhs: CalendarSection, rhs: CalendarSection) -> Bool {
        lhs.habitID == rhs.habitID &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.visibleMonth == rhs.visibleMonth &&
        lhs.metricsRevision == rhs.metricsRevision &&
        lhs.habitVersion == rhs.habitVersion &&
        lhs.monthSummaryText == rhs.monthSummaryText &&
        lhs.earliestVisibleDate == rhs.earliestVisibleDate &&
        lhs.historyProjectedDayStates == rhs.historyProjectedDayStates
    }

    var body: some View {
        CalendarMonthView(
            month: month,
            habit: habit,
            service: service,
            calendarProvider: calendarProvider,
            projectedDayStatesByDate: historyProjectedDayStates,
            selectedDate: selectedDate,
            monthSummaryText: monthSummaryText,
            premiumHistoryGate: premiumHistoryGate,
            earliestVisibleDate: earliestVisibleDate,
            isTapToLogEnabled: isTapToLogEnabled,
            onSelectDay: onSelectDay,
            onTapDay: onTapDay,
            onTapLockedDay: onTapLockedDay
        )
    }
}

private struct HistoryInsightSummary: Equatable {
    let monthTitle: String
    let activeDays: Int
    let entries: Int
    let bestStreak: Int
}

private struct SelectedDayContextSummary: Equatable {
    let dayLabel: String
    let loggedText: String
}

private struct HistoryInsightSummarySection: View {
    let summary: HistoryInsightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
            Text("\(summary.monthTitle) Summary")
                .font(CadenceTokens.Typography.roleLabel.weight(.regular))
                .foregroundStyle(
                    CadenceTokens.Color.Text.secondary.opacity(CadenceTokens.Typography.roleLabelOpacity)
                )

            HistoryInsightMetricRow(value: "\(summary.activeDays)", label: "Active days")
            HistoryInsightMetricRow(value: "\(summary.entries)", label: "Total entries")
            HistoryInsightMetricRow(value: "\(summary.bestStreak)", label: "Longest run")
        }
        .padding(.horizontal, CadenceTokens.Space.sm)
        .padding(.bottom, CadenceTokens.Space.md)
    }
}

private struct SelectedDayContextSection: View {
    let context: SelectedDayContextSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(context.dayLabel)
                .font(CadenceTokens.Typography.roleBody.weight(.medium))
                .foregroundStyle(CadenceTokens.Color.Text.primary)

            Text("· \(context.loggedText)")
                .font(CadenceTokens.Typography.roleCaption.weight(.regular))
                .foregroundStyle(
                    CadenceTokens.Color.Text.secondary.opacity(CadenceTokens.Typography.roleCaptionOpacity)
                )
        }
        .lineLimit(1)
        .padding(.horizontal, CadenceTokens.Space.sm)
        .padding(.bottom, CadenceTokens.Space.sm)
    }
}

private struct HistoryInsightMetricRow: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CadenceTokens.Space.sm) {
            Text(value)
                .font(CadenceTokens.Typography.roleDataPrimaryCompact.weight(.semibold))
                .foregroundStyle(CadenceTokens.Color.Text.primary)
                .monospacedDigit()
                .frame(width: 42, alignment: .leading)

            Text(label)
                .font(CadenceTokens.Typography.roleDataSecondary.weight(.regular))
                .foregroundStyle(
                    CadenceTokens.Color.Text.secondary.opacity(CadenceTokens.Typography.roleDataSecondaryOpacity)
                )
        }
    }
}

private struct HabitProgressSummary: View {
    let headline: String
    let progress: Double
    let overflowFraction: Double
    let overflowText: String?
    let accent: CadenceAccentTokens

    var body: some View {
        let clampedProgress = min(max(progress, 0), 1)
        let progressAccent = accent.secondary
        let clampedOverflow = min(max(overflowFraction, 0), 0.22)

        return VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
            Text(headline)
                .font(CadenceTokens.Typography.body)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.18), value: headline)
                .lineLimit(1)
                .minimumScaleFactor(0.95)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)

            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = max(width * clampedProgress, clampedProgress > 0 ? 4 : 0)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(CadenceTokens.Color.Background.tertiary)

                    Capsule(style: .continuous)
                        .fill(progressAccent)
                        .frame(width: fillWidth)

                    if clampedOverflow > 0 {
                        Capsule(style: .continuous)
                            .fill(accent.tertiary)
                            .frame(width: width * clampedOverflow)
                            .offset(x: width - (width * clampedOverflow))
                    }
                }
            }
            .frame(height: 10)
            .padding(.bottom, 4)

            if let overflowText, clampedOverflow > 0 {
                Text(overflowText)
                    .font(CadenceTokens.Typography.supporting)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .lineLimit(1)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
