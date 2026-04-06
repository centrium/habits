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

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Habit.orderIndex) private var allHabits: [Habit]
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var uiStateStore: HabitUIStateStore
    @EnvironmentObject private var habitLogService: HabitLogService
    @StateObject private var selectionState: HabitSelectionState
    @State private var activeSheet: ActiveSheet?
    @State private var manualLogValue: Double? = nil
    @State private var insightsDetent: PresentationDetent = .large
    @State private var cachedProgressSnapshot: ProgressAsOfSnapshot?
    @State private var snapshotRefreshTask: Task<Void, Never>?
    @State private var selectedDate: Date
    @State private var isHistoryPresented = false
    @State private var cueInsight: CueInsight?
    @State private var prefersIdentityFocusOnEdit = false
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
        let displayedStreak = habit.displayStreak(
            referenceDate: now,
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
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

            TopAmbientGradient(accent: CadenceTokens.Color.accent(for: habit).primary)
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea()

            detailContent(
                progressSnapshot: progressSnapshot,
                displayedStreak: displayedStreak,
                progressRevision: progressRevision,
                earliestCalendarDate: earliestCalendarDate
            )
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle(habit.name)
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
        .onReceive(uiStateStore.$progressByHabitAndDate) { _ in
            scheduleProgressSnapshotRefresh()
        }
        .task(id: habit.id) {
            await refreshCueInsight()
        }
        .navigationDestination(isPresented: $isHistoryPresented) {
            ZStack(alignment: .top) {
                backgroundColor
                    .ignoresSafeArea()

                TopAmbientGradient(accent: CadenceTokens.Color.accent(for: habit).primary)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea()

                historyTabContent(
                    progressRevision: progressRevision,
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

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .padding(.horizontal, 4)
                            .cadenceControlChrome()
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }

    @ViewBuilder
    private func detailContent(
        progressSnapshot: ProgressAsOfSnapshot?,
        displayedStreak: Int,
        progressRevision: Int,
        earliestCalendarDate: Date?
    ) -> some View {
        let sectionPadding = CadenceTokens.Space.lg
        let sectionSpacing = CadenceTokens.Space.lg
        let sectionCornerRadius = CadenceTokens.Surface.cardCornerRadius
        let accent = CadenceTokens.Color.accent(for: habit)
        let identityState = identityStateSummary()
        let heroStatus = heroCenterStatusText(identityState: identityState.state)
        let logCount = habit.logs.count
        let isLowDataActivityState = logCount == 0
        let showsProgressSummary = logCount > 0 && progressSnapshot != nil
        let isCumulativeGoal = habit.goalType == .cumulative
        let showsInsightsSection = hasInsightsInlineAction
        let heroSupportingText = heroSupportingInsightText(identityState: identityState)
        let identityText = userDefinedIdentityText
        let identityStatText = identityText == nil
            ? nil
            : CadenceLanguage.identityStat(days: identityState.activeDays, window: identityState.windowDays)

        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
                    HeroTopRow(
                        habitName: habit.name,
                        categoryLabel: habit.category.rawValue,
                        loggingContextText: loggingContextText,
                        accent: accent.tertiary
                    )

                    Text(heroStatus)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.92)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 3)

                    if showsProgressSummary {
                        EquatableView(
                            content: ProgressSummarySection(
                                snapshot: progressSnapshot,
                                accentHex: habit.colorHex,
                                isCumulativeGoal: isCumulativeGoal,
                                onTap: {
                                    presentManualEntry(for: selectedDate)
                                }
                            )
                        )
                    }

                    if let userCueText = userDefinedCueText {
                        CueInsightView(text: userCueText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    } else if let detectedCueText {
                        CueInsightView(text: detectedCueText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }

                    if let heroSupportingText {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary.opacity(0.7))

                            Text(heroSupportingText)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary.opacity(0.9))
                        }
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                }
                .padding(CadenceTokens.Space.lg)
                .frame(minHeight: 206, alignment: .topLeading)
                .cadenceSurface(cornerRadius: sectionCornerRadius)
                .padding(.horizontal, sectionPadding)
                .padding(.top, CadenceTokens.Space.md)

                HabitIdentityCard(
                    identityText: identityText,
                    statText: identityStatText,
                    accent: CadenceTokens.Color.accent(for: habit)
                ) {
                    prefersIdentityFocusOnEdit = true
                    activeSheet = .edit
                }
                .padding(.top, 6)
                .padding(.horizontal, sectionPadding)

                VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                    if logCount == 0 {
                        Text("Your progress starts here")
                            .font(CadenceTokens.Typography.supporting)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .lineLimit(1)
                    }

                    KeyActionsSection(
                        isCumulativeGoal: habit.goalType == .cumulative,
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
                .padding(CadenceTokens.Space.lg)
                .frame(minHeight: 70)
                .cadenceSurface(cornerRadius: sectionCornerRadius)
                .padding(.top, 6)
                .padding(.horizontal, sectionPadding)

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
            : Color.black
    }

    @ViewBuilder
    private func historyTabContent(
        progressRevision: Int,
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

    private func heroCenterStatusText(identityState: HabitIdentityState) -> String {
        CadenceLanguage.shortLabel(for: identityState)
    }

    private func identityStateSummary() -> HabitIdentityStateSnapshot {
        HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calculationCalendar,
            now: Date(),
            windowDays: 7
        )
    }

    private func heroSupportingInsightText(
        identityState: HabitIdentityStateSnapshot
    ) -> String? {
        if habit.logs.isEmpty {
            return CadenceLanguage.insightLine(for: .gettingStarted)
        }

        return "Logged on \(identityState.activeDays) of the last \(identityState.windowDays) days"
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

    private func refreshCueInsight() async {
        cueInsight = await habitLogService.detectCue(for: habit.id)
    }

    private var detectedCueText: String? {
        guard let cueInsight,
              let sourceHabitName = cueSourceHabitName(for: cueInsight) else {
            return nil
        }
        return "You tend to \(habit.name.lowercased()) after \(sourceHabitName.lowercased())"
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

private struct HeroTopRow: View {
    let habitName: String
    let categoryLabel: String
    let loggingContextText: String
    let accent: Color

    var body: some View {
        HStack(spacing: CadenceTokens.Space.md) {
            Circle()
                .fill(accent)
                .frame(width: CadenceTokens.Space.md, height: CadenceTokens.Space.md)

            VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                HStack(spacing: CadenceTokens.Space.sm) {
                    Text(habitName)
                        .font(CadenceTokens.Typography.title)
                        .tracking(CadenceTokens.Typography.titleTracking)
                        .foregroundStyle(CadenceTokens.Color.Text.primary)
                        .lineLimit(1)

                    Text(categoryLabel)
                        .font(.caption)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CadenceTokens.Color.Background.tertiary.opacity(0.75))
                        )
                }

                Text(loggingContextText)
                    .font(CadenceTokens.Typography.body)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: CadenceTokens.Space.sm)
        }
    }
}

private struct HabitIdentityCard: View {
    let identityText: String?
    let statText: String?
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
                                    .foregroundStyle(.primary.opacity(0.85))
                                    .lineSpacing(2)
                                    .lineLimit(2)

                                if let statText {
                                    Text(statText)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)

                                    Text(CadenceLanguage.identityReinforcement())
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary.opacity(0.9))
                                        .padding(.top, 3)
                                        .lineLimit(2)
                                }
                            } else {
                                Text(CadenceLanguage.identityEmptyPrompt())
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.85))
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
