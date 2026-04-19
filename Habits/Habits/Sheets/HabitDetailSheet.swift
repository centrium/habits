import SwiftUI
import SwiftData

private enum ActiveSheet: Identifiable {
    case edit
    case insights
    case valueEntry
    case paywall(PremiumFeature)

    var id: String {
        switch self {
        case .edit:
            return "edit"
        case .insights:
            return "insights"
        case .valueEntry:
            return "valueEntry"
        case .paywall(let feature):
            return "paywall-\(String(describing: feature))"
        }
    }
}

private struct IdentityReinforcement {
    let line: String
}

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Habit.orderIndex) private var allHabits: [Habit]
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
    @State private var rhythmData: [HourValue] = []
    @State private var prefersIdentityFocusOnEdit = false
    @State private var aiCoachTitle: String = "AI Coach"
    @State private var aiCoachText: String = ""
    @State private var frozenGuidanceOutput: GuidanceOutput?
    @State private var frozenStateModel: HabitStateModel?
    @State private var lastReconcileProbeKey: String?
    private let onDeleted: (() -> Void)?

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
        let logsVersion = habitLogService.logsVersion
        let today = CurrentDayResolver.currentDay(calendar: calculationCalendar)
        let optimisticProgress = uiStateStore.progress(habitId: habit.id, date: today)
        let optimisticComplete = uiStateStore.isComplete(habitId: habit.id, date: today)
        let hasActivityToday = (optimisticProgress ?? 0) > 0
            || !habit.logs(on: today, calendar: calculationCalendar).isEmpty
        let streakState = StreakStateEngine(
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        ).streakState(
            for: habit,
            referenceDate: now,
            progressOverride: optimisticProgress,
            isCompleteOverride: optimisticComplete,
            hasActivityOverride: hasActivityToday
        )
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

            case .paywall(let feature):
                PaywallView(feature: feature)

            }

        }
        .onAppear {
            habitLogService.updateCalendar(calculationCalendar)
            habitLogService.prepare(habit)
            scheduleProgressSnapshotRefresh(now: now)
            debugPrintRecentHabitLogTimestamps()
            freezeStateModelOnAppear()
            freezeGuidanceOutputOnAppear(now: now)
            updateAICoachTitleOnAppear()
            regenerateAICoachOnAppear()

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
        .onChange(of: userSettings.weekStartPreference) { _, _ in
            habitLogService.updateCalendar(calculationCalendar)
            scheduleProgressSnapshotRefresh()
        }
        .onChange(of: selectedDate) { _, _ in
            scheduleProgressSnapshotRefresh()
        }
        .onChange(of: selectionState.visibleMonth) { _, _ in
            scheduleProgressSnapshotRefresh()
        }
        .onChange(of: progressRevision) { _, _ in
            scheduleProgressSnapshotRefresh()
            Task { await refreshCueInsight() }
        }
        .onChange(of: logsVersion) { _, _ in
            recordUIReconcileProbe(stage: "logsVersion")
            scheduleProgressSnapshotRefresh()
        }
        .onReceive(uiStateStore.$progressByHabitAndDate) { _ in
            recordUIReconcileProbe(stage: "uiState.progress")
        }
        .task(id: habit.id) {
            await refreshCueInsight()
        }
        .task(id: rhythmTaskKey) {
            await refreshRhythmData()
        }
        .navigationDestination(isPresented: $isHistoryPresented) {
            ZStack(alignment: .top) {
                backgroundColor
                    .ignoresSafeArea()

                TopAmbientGradient()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea()

                historyTabContent(
                    progressRevision: progressRevision,
                    logsVersion: logsVersion,
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
        let sectionCornerRadius = CadenceTokens.Surface.cardCornerRadius
        let accent = CadenceTokens.Color.accent(for: habit)
        let stateModel = frozenStateModel ?? habitStateModel()
        let identityState = identityStateSummary()
        let heroStatus = CadenceLanguage.shortLabel(for: stateModel.state)
        let logCount = habit.logs.count
        let isLowDataActivityState = logCount == 0
        let isCumulativeGoal = habit.goalType == .cumulative
        let showsInsightsSection = hasInsightsInlineAction
        let heroSupportingText = heroSupportingInsightText(identityState: identityState)
        let identityText = userDefinedIdentityText
        let identityStatText = identityText == nil
            ? nil
            : CadenceLanguage.identityStat(days: identityState.activeDays, window: identityState.windowDays)
        let streakCardConfiguration = streakCardConfiguration(streakState: streakState)
        let guidanceOutput = frozenGuidanceOutput
        let identityReflectionText = pairedIdentityReflection(for: guidanceOutput)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHeaderIdentity(
                    habitName: habit.name,
                    iconName: habit.iconName,
                    accent: accent.primary
                )
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md)

                VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
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

                    if let heroSupportingText {
                        Text(heroSupportingText)
                            .font(CadenceTokens.Typography.body)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.sm)

                VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                    if logCount == 0 {
                        Text("Your progress starts here")
                            .font(CadenceTokens.Typography.supporting)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .lineLimit(1)
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

                if let guidanceOutput {
                    GuidanceCard(
                        output: guidanceOutput,
                        accent: accent,
                        variant: GuidanceEngine.visualVariant(for: guidanceOutput),
                        label: aiCoachTitle,
                        guidanceText: aiCoachText,
                        isLoading: false,
                        loadingText: aiCoach.loadingText
                    )
                    .padding(.horizontal, sectionPadding)
                    .padding(.top, 12)
                }

                if let streakCardConfiguration {
                    StreakNudgeCard(
                        configuration: streakCardConfiguration,
                        accent: accent
                    )
                    .padding(.horizontal, sectionPadding)
                    .padding(.top, guidanceOutput == nil ? CadenceTokens.Space.md : CadenceTokens.Space.sm + 2)
                    .opacity(guidanceOutput == nil ? 1 : 0.94)
                }

                if !rhythmData.isEmpty {
                    RhythmCardView(
                        isPremium: purchaseService.premiumStatus == .premium,
                        data: rhythmData,
                        rhythm: TimeOfDayPerformanceService.shared.cachedRhythm(
                            for: habit,
                            isPremium: purchaseService.premiumStatus == .premium
                        ),
                        stateModel: stateModel,
                        habit: habit,
                        onUnlock: {
                            showPaywall(feature: .advancedInsights)
                        }
                    )
                    .padding(.horizontal, sectionPadding)
                    .padding(.top, guidanceOutput == nil ? CadenceTokens.Space.md : CadenceTokens.Space.sm + 2)
                    .opacity(guidanceOutput == nil ? 1 : 0.95)
                }

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
                .padding(.top, CadenceTokens.Space.md)
                .opacity(guidanceOutput == nil ? 1 : 0.985)

                Button {
                    if let earliestCalendarDate {
                        let normalizedEarliest = calculationCalendar.startOfDay(for: earliestCalendarDate)
                        if selectedDate < normalizedEarliest {
                            selectedDate = normalizedEarliest
                            selectionState.select(date: normalizedEarliest)
                        }
                    }
                    isHistoryPresented = true
                } label: {
                    VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                        Text("Activity")
                            .font(CadenceTokens.Typography.sectionHeader)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)

                        Text(
                            isLowDataActivityState
                                ? "Your entries will appear here"
                                : "Recent check-ins"
                        )
                        .font(CadenceTokens.Typography.supporting)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        .lineLimit(1)

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
                            showsIdentityStateSummary: false
                        )
                        .opacity(isLowDataActivityState ? 0.7 : 1)

                        HStack(spacing: 4) {
                            Text("See all activity →")
                                .font(CadenceTokens.Typography.microCopy)
                                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(CadenceTokens.Space.lg)
                .frame(minHeight: 112, alignment: .topLeading)
                .cadenceSurface(cornerRadius: sectionCornerRadius)
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md)
                .opacity(guidanceOutput == nil ? 1 : 0.97)

                if showsInsightsSection {
                    VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                        InsightsInlineNudgeRow(
                            text: insightsInlineNudgeText,
                            action: openInsightsOrPaywall
                        )
                    }
                    .padding(CadenceTokens.Space.lg)
                    .frame(minHeight: 48, alignment: .leading)
                    .cadenceSurface(cornerRadius: sectionCornerRadius)
                    .padding(.horizontal, sectionPadding)
                    .padding(.top, CadenceTokens.Space.md)
                }

                Color.clear
                    .frame(height: CadenceTokens.Space.lg + 2)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, CadenceTokens.Space.md)
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
        logsVersion: UUID,
        calendarMonthSummaryText: String?,
        earliestCalendarDate: Date?,
        premiumHistoryGate: PremiumHistoryGate.Context,
        calendar: Calendar
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
                VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                    Text("History")
                        .font(CadenceTokens.Typography.sectionHeader)
                        .foregroundStyle(CadenceTokens.Color.Text.primary)

                    HStack(spacing: 4) {
                        fadingHistorySecondaryText(
                            historyMonthLabel(for: selectionState.visibleMonth),
                            id: "history-month-label-\(historyMonthKey(for: selectionState.visibleMonth, calendar: calendar))"
                        )

                        Text("•")
                            .font(CadenceTokens.Typography.supporting)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)

                        fadingHistorySecondaryText(
                            historyTotalText(for: selectionState.visibleMonth, calendar: calendar),
                            id: "history-month-total-\(historyMonthKey(for: selectionState.visibleMonth, calendar: calendar))-\(historyTotalText(for: selectionState.visibleMonth, calendar: calendar))"
                        )
                    }
                }
                .padding(.horizontal, CadenceTokens.Space.lg)
                .padding(.top, CadenceTokens.Space.sm)

                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        EquatableView(
                            content: HeatmapSection(
                                habitID: habit.id,
                                selectedDate: selectedDate,
                                metricsRevision: progressRevision,
                                logsVersion: logsVersion,
                                earliestVisibleDate: earliestCalendarDate,
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

                    EquatableView(
                        content: CalendarSection(
                            habitID: habit.id,
                            selectedDate: selectedDate,
                            visibleMonth: selectionState.visibleMonth,
                            metricsRevision: progressRevision,
                            logsVersion: logsVersion,
                            monthSummaryText: calendarMonthSummaryText,
                            earliestVisibleDate: earliestCalendarDate,
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
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = calendar.startOfDay(for: day)
                                }
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
        HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calculationCalendar,
            now: Date(),
            windowDays: 7
        )
    }

    private func streakCardConfiguration(streakState: StreakState) -> StreakCardConfiguration? {
        StreakCardConfiguration(streakState: streakState)
    }

    private func guidanceOutput(
        streakState: StreakState,
        identityState: HabitIdentityStateSnapshot
    ) -> GuidanceOutput? {
        guard purchaseService.hasAccess(to: .guidanceLayer) else {
            return nil
        }

        return GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: Date(),
                isCompletedToday: hasActivityToday(),
                streakState: streakState,
                completionHistory: habit.logs,
                globalHistory: allHabits.flatMap(\.logs),
                pattern: guidancePattern(),
                goalType: habit.goalType
            ),
            calendar: calculationCalendar,
            identitySnapshot: identityState
        )
    }

    private func hasActivityToday() -> Bool {
        let today = CurrentDayResolver.currentDay(calendar: calculationCalendar)
        let optimisticProgress = uiStateStore.progress(habitId: habit.id, date: today)
        return (optimisticProgress ?? 0) > 0 || !habit.logs(on: today, calendar: calculationCalendar).isEmpty
    }

    private func heroSupportingInsightText(
        identityState: HabitIdentityStateSnapshot
    ) -> String? {
        if habit.logs.isEmpty {
            return CadenceLanguage.insightLine(for: .gettingStarted)
        }

        return "Logged on \(identityState.activeDays) of the last \(identityState.windowDays) days"
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

    private func recordUIReconcileProbe(stage: String) {
        guard let startedAt = habitLogService.lastLogUserActionAt else { return }
        let deltaMs = Date().timeIntervalSince(startedAt) * 1000

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

    private func historyTotalText(for visibleMonth: Date, calendar: Calendar) -> String {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else {
            return "0"
        }

        switch habit.goalType {
        case .frequency:
            let totalEntries = habit.logs.reduce(into: 0) { partial, log in
                let timestamp = log.effectiveTimestamp
                guard timestamp >= monthInterval.start, timestamp < monthInterval.end else {
                    return
                }
                partial += log.frequencyContribution
            }
            let label = totalEntries == 1 ? "entry" : "entries"
            return "\(totalEntries) \(label)"

        case .cumulative:
            let totalValue = habitLogService.value(for: habit, in: monthInterval)
            let valueText = habitLogService.formatValue(totalValue, for: habit)
            return "\(valueText)\(habitLogService.displayUnitSuffix(for: habit))"
        }
    }

    private func fadingHistorySecondaryText(_ text: String, id: String) -> some View {
        ZStack {
            Text(text)
                .id(id)
                .font(CadenceTokens.Typography.body)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
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
        guard habit.logs.count >= 3 else { return false }
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
        if let optimistic = uiStateStore.isComplete(habitId: habit.id, date: selectedDate) {
            return optimistic
        }

        return habit.isComplete(
            for: selectedDate,
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        )
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

    private func cueSourceHabitName(for insight: CueInsight) -> String? {
        allHabits.first(where: { $0.id == insight.sourceHabitId })?.name
    }

    private func guidancePattern() -> HabitPattern? {
        if let triggerHabitID = habit.triggerHabitID,
           let triggerHabit = allHabits.first(where: { $0.id == triggerHabitID }) {
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
        cueInsight = await habitLogService.detectCue(for: habit.id)
    }

    private var rhythmTaskKey: String {
        let newestTimestamp = habit.logs
            .map(\.effectiveTimestamp)
            .max()?
            .timeIntervalSince1970 ?? 0
        let premiumFlag = purchaseService.premiumStatus == .premium ? "premium" : "free"
        return "\(habit.id.uuidString)-\(habit.logs.count)-\(newestTimestamp)-\(premiumFlag)"
    }

    private func refreshRhythmData() async {
        guard purchaseService.premiumStatus != .unknown else {
            rhythmData = []
            return
        }

        let values = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: habit,
            globalLogs: allHabits.flatMap(\.logs),
            isPremium: purchaseService.premiumStatus == .premium,
            now: .now,
            calendar: calculationCalendar
        )

        guard !Task.isCancelled else { return }
        rhythmData = values
    }

    private var detectedCueText: String? {
        guard let cueInsight,
              let sourceHabitName = cueSourceHabitName(for: cueInsight) else {
            return nil
        }
        return "You tend to \(habit.name.lowercased()) after \(sourceHabitName.lowercased())"
    }

    private func regenerateAICoach(requestKey: String) {
        let input = buildAICoachInput()
        aiCoach.generate(input: input, requestKey: requestKey) { finalText in
            self.aiCoachText = finalText
        }
    }

    private func regenerateAICoachOnAppear() {
        let requestKey = "onAppear-\(habit.id.uuidString)-\(Date().timeIntervalSince1970)"
        regenerateAICoach(requestKey: requestKey)
    }

    private func updateAICoachTitleOnAppear() {
        let stateModel = frozenStateModel ?? habitStateModel(now: appTime.now)
        aiCoachTitle = "AI Coach • \(CadenceLanguage.shortLabel(for: stateModel.state))"
    }

    private func freezeStateModelOnAppear() {
        guard frozenStateModel == nil else { return }
        frozenStateModel = habitStateModel(now: appTime.now)
    }

    private func freezeGuidanceOutputOnAppear(now: Date) {
        guard frozenGuidanceOutput == nil else { return }

        let today = CurrentDayResolver.currentDay(calendar: calculationCalendar)
        let optimisticProgress = uiStateStore.progress(habitId: habit.id, date: today)
        let optimisticComplete = uiStateStore.isComplete(habitId: habit.id, date: today)
        let hasActivityToday = (optimisticProgress ?? 0) > 0
            || !habit.logs(on: today, calendar: calculationCalendar).isEmpty

        let streakState = StreakStateEngine(
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        ).streakState(
            for: habit,
            referenceDate: now,
            progressOverride: optimisticProgress,
            isCompleteOverride: optimisticComplete,
            hasActivityOverride: hasActivityToday
        )

        let identityState = identityStateSummary()
        frozenGuidanceOutput = guidanceOutput(
            streakState: streakState,
            identityState: identityState
        )
    }

    private func buildAICoachInput() -> AICoachInput {
        let stateModel = frozenStateModel ?? habitStateModel(now: appTime.now)
        return AICoachInput(
            habitName: habit.name,
            recentLogs: recentLogsSummary(),
            state: stateModel.state,
            timingConfidence: stateModel.timingConfidence,
            strongestTime: stateModel.strongestTime,
            weakestTime: weakestTimeWindow(),
            streakState: stateModel.streakState,
            identity: userDefinedIdentityText,
            stacking: guidancePattern()?.description,
            todayStatus: hasActivityToday() ? "completed" : "not completed yet",
            behaviourSummary: behaviourSummary(for: stateModel.state)
        )
    }

    private func habitStateModel(now: Date = Date()) -> HabitStateModel {
        HabitStateResolver.resolve(
            for: habit,
            globalLogs: allHabits.flatMap(\.logs),
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference,
            now: now
        )
    }

    private func recentLogsSummary() -> String {
        let recent = habit.logs
            .map(\.effectiveTimestamp)
            .sorted(by: >)
            .prefix(3)
        guard !recent.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.locale = calculationCalendar.locale ?? .current
        formatter.calendar = calculationCalendar
        formatter.timeZone = calculationCalendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")
        let labels = recent.map { formatter.string(from: $0) }
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
        guard !habit.logs.isEmpty else { return "Pattern still forming." }
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
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.52)

                Text(text)
                    .font(CadenceTokens.Typography.microCopy)
                    .lineLimit(1)
                    .opacity(0.85)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.46)
            }
            .foregroundStyle(CadenceTokens.Color.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.primary.opacity(0.72))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    Text(CadenceLanguage.identityTitle())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

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
            .padding(CadenceTokens.Space.lg)
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
        }
        .buttonStyle(.plain)
    }

    private var tintColor: Color {
        if identityText != nil {
            return accent.primary
        }

        return CadenceTokens.Color.Background.secondary
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
    @State private var isPrimaryPressed: Bool = false

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
            .buttonStyle(.plain)
            .scaleEffect(isPrimaryPressed ? 0.985 : 1)

            if isCumulativeGoal {
                secondaryButton
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            Haptics.impactLight()
            withAnimation(.easeOut(duration: 0.08)) {
                isPrimaryPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.14)) {
                    isPrimaryPressed = false
                }
            }
            onQuickLog()
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
    let logsVersion: UUID
    let earliestVisibleDate: Date?
    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let onSelectDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    static func == (lhs: HeatmapSection, rhs: HeatmapSection) -> Bool {
        lhs.habitID == rhs.habitID &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.metricsRevision == rhs.metricsRevision &&
        lhs.logsVersion == rhs.logsVersion &&
        lhs.earliestVisibleDate == rhs.earliestVisibleDate
    }

    var body: some View {
        HabitHeatmap(
            habit: habit,
            service: service,
            calendarProvider: calendarProvider,
            selectedDate: selectedDate,
            earliestVisibleDate: earliestVisibleDate,
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
    let logsVersion: UUID
    let monthSummaryText: String?
    let earliestVisibleDate: Date?
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
        lhs.logsVersion == rhs.logsVersion &&
        lhs.monthSummaryText == rhs.monthSummaryText &&
        lhs.earliestVisibleDate == rhs.earliestVisibleDate
    }

    var body: some View {
        CalendarMonthView(
            month: month,
            habit: habit,
            service: service,
            calendarProvider: calendarProvider,
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
