import SwiftUI

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

private enum DetailTab: Hashable {
    case today
    case history
}

struct HabitDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
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
    @State private var selectedTab: DetailTab = .today
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

        TabView(selection: $selectedTab) {
            todayTabContent(
                progressSnapshot: progressSnapshot,
                displayedStreak: displayedStreak,
                progressRevision: progressRevision,
                earliestCalendarDate: earliestCalendarDate,
                behaviourNudgeText: behaviourNudgeText(displayedStreak: displayedStreak)
            )
            .tabItem {
                VStack(alignment: .leading, spacing: 1) {
                    Image(systemName: "sun.max.fill")
                    Text("Today")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)
            }
            .tag(DetailTab.today)

            historyTabContent(
                progressRevision: progressRevision,
                calendarMonthSummaryText: calendarMonthSummaryText,
                earliestCalendarDate: earliestCalendarDate,
                premiumHistoryGate: premiumHistoryGate,
                calendar: calendar
            )
            .tabItem {
                VStack(alignment: .leading, spacing: 1) {
                    Image(systemName: "calendar")
                    Text("History")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)
            }
            .tag(DetailTab.history)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.systemAccent)

                        if purchaseService.premiumStatus == .free {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(TactileButtonStyle())

                Button {
                    activeSheet = .edit
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(TactileButtonStyle())

            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit:
                EditHabitSheet(habit: habit) {
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
                .presentationBackground(Color(.systemGroupedBackground))
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
        }
        .onReceive(uiStateStore.$progressByHabitAndDate) { _ in
            scheduleProgressSnapshotRefresh()
        }
    }

    @ViewBuilder
    private func todayTabContent(
        progressSnapshot: ProgressAsOfSnapshot?,
        displayedStreak: Int,
        progressRevision: Int,
        earliestCalendarDate: Date?,
        behaviourNudgeText: String
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    EquatableView(
                        content: HeaderSection(
                            habit: habit,
                            selectedDate: selectedDate,
                            metricsRevision: progressRevision,
                            calendar: calculationCalendar,
                            weekStartPreference: userSettings.weekStartPreference,
                            loggingContextText: loggingContextText,
                            currentStreak: displayedStreak,
                            onQuickLog: { selectedDay in
                                let resolvedDay = calculationCalendar.startOfDay(for: selectedDay)
                                selectedDate = resolvedDay
                                selectionState.select(date: resolvedDay)
                                if habit.goalType == .frequency {
                                    _ = habitLogService.quickLog(for: habit, on: resolvedDay)
                                } else {
                                    presentManualEntry(for: resolvedDay)
                                }
                            },
                            onQuickLogLongPress: habit.goalType == .cumulative ? { selectedDay in
                                presentManualEntry(for: selectedDay)
                            } : nil
                        )
                    )

                    EquatableView(
                        content: ProgressSummarySection(
                            snapshot: progressSnapshot,
                            accentHex: habit.colorHex,
                            behaviourNudgeText: behaviourNudgeText,
                            isCumulativeGoal: habit.goalType == .cumulative,
                            onTap: {
                                presentManualEntry(for: selectedDate)
                            }
                        )
                    )

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
                    .padding(.top, 8)

                    Divider().opacity(0.2)

                    TodaySummarySection(summaryText: loggingContextText)
                        .padding(.top, 6)

                    CompactHeatmapPreviewSection(
                        habit: habit,
                        service: habitLogService,
                        calendarProvider: heatmapCalendarProvider,
                        selectedDate: selectedDate,
                        earliestVisibleDate: earliestCalendarDate
                    )
                    .padding(.top, 8)
                }
                .padding(12)
                .appSurface(level: .standard, cornerRadius: 16)
                .overlay {
                    cardOverlay
                }
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.18) : .clear,
                    radius: colorScheme == .dark ? 18 : 0,
                    y: colorScheme == .dark ? 10 : 0
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if shouldShowInsightsInlineNudge {
                    InsightsInlineNudgeRow(
                        text: insightsInlineNudgeText,
                        action: openInsightsOrPaywall
                    )
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                } else {
                    Color.clear
                        .frame(height: 30)
                        .allowsHitTesting(false)
                }

                Color.clear
                    .frame(height: 22)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
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
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
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
                                selectedDate = normalized

                                if !calendar.isDate(normalized, equalTo: selectionState.visibleMonth, toGranularity: .month) {
                                    selectionState.selectCalendarMonth(normalized)
                                }
                            },
                            onTapLockedDay: { _ in
                                showPaywall(feature: .fullHeatmapHistory)
                            }
                        )
                    )

                    Divider().opacity(0.2)

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
                                set: { selectionState.selectCalendarMonth($0) }
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
                }
                .padding(12)
                .appSurface(level: .standard, cornerRadius: 16)
                .overlay {
                    cardOverlay
                }
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.18) : .clear,
                    radius: colorScheme == .dark ? 18 : 0,
                    y: colorScheme == .dark ? 10 : 0
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Color.clear
                    .frame(height: 72)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, 16)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var cardOverlay: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .allowsHitTesting(false)
        }
    }

    private var loggingContextText: String {
        "Logging for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
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
        _ = habitLogService.quickLog(for: habit, on: resolvedDay)
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

    private var shouldShowInsightsInlineNudge: Bool {
        purchaseService.premiumStatus == .free && habit.logs.count >= 3
    }

    private var insightsInlineNudgeText: String {
        let trimmedUnit = habit.trimmedUnit
        if let trimmedUnit, !trimmedUnit.isEmpty {
            return "Spot trends in your \(trimmedUnit.lowercased())"
        }
        return "Understand your habits over time"
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

    private func behaviourNudgeText(displayedStreak: Int) -> String {
        if displayedStreak >= 2 {
            return "You're on a \(displayedStreak)-day streak."
        }

        let today = calculationCalendar.startOfDay(for: Date())
        let nonTodayTimestamps = habit.logs
            .map(\.effectiveTimestamp)
            .filter { !calculationCalendar.isDate($0, inSameDayAs: today) }
        let todayTimestamps = habit.logs
            .map(\.effectiveTimestamp)
            .filter { calculationCalendar.isDate($0, inSameDayAs: today) }

        let usualHour: Double? = {
            guard !nonTodayTimestamps.isEmpty else { return nil }
            let total = nonTodayTimestamps.reduce(0.0) { partialResult, date in
                let hour = Double(calculationCalendar.component(.hour, from: date))
                let minute = Double(calculationCalendar.component(.minute, from: date))
                return partialResult + hour + (minute / 60.0)
            }
            return total / Double(nonTodayTimestamps.count)
        }()

        if let usualHour, let firstTodayLog = todayTimestamps.min() {
            let todayHour = Double(calculationCalendar.component(.hour, from: firstTodayLog))
                + (Double(calculationCalendar.component(.minute, from: firstTodayLog)) / 60.0)
            if todayHour + 0.25 < usualHour {
                return "Nice - earlier than usual."
            }
            return "You're following your usual pace."
        }

        if let usualHour {
            let currentHour = Double(calculationCalendar.component(.hour, from: Date()))
                + (Double(calculationCalendar.component(.minute, from: Date())) / 60.0)
            if currentHour < usualHour {
                return "You're ahead of your usual pace."
            }
            return "You're close to your usual log time."
        }

        return "You're building consistency."
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
                    .font(.caption2)
                    .lineLimit(1)
                    .opacity(0.6)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.46)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint("Open insights")
    }
}

private struct HeaderSection: View, Equatable {
    let habit: Habit
    let selectedDate: Date
    let metricsRevision: Int
    let calendar: Calendar
    let weekStartPreference: WeekStartPreference
    let loggingContextText: String
    let currentStreak: Int
    let onQuickLog: (Date) -> Void
    let onQuickLogLongPress: ((Date) -> Void)?

    static func == (lhs: HeaderSection, rhs: HeaderSection) -> Bool {
        lhs.habit.id == rhs.habit.id &&
        lhs.habit.name == rhs.habit.name &&
        lhs.habit.subtitle == rhs.habit.subtitle &&
        lhs.habit.iconName == rhs.habit.iconName &&
        lhs.habit.colorHex == rhs.habit.colorHex &&
        lhs.habit.goalTypeRaw == rhs.habit.goalTypeRaw &&
        lhs.habit.streakGoalTypeRaw == rhs.habit.streakGoalTypeRaw &&
        lhs.habit.targetValue == rhs.habit.targetValue &&
        lhs.habit.unit == rhs.habit.unit &&
        lhs.habit.allowsDecimals == rhs.habit.allowsDecimals &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.metricsRevision == rhs.metricsRevision &&
        lhs.weekStartPreference == rhs.weekStartPreference &&
        lhs.loggingContextText == rhs.loggingContextText &&
        lhs.currentStreak == rhs.currentStreak
    }

    var body: some View {
        HabitHeader(
            habit: habit,
            selectedDate: selectedDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            showsQuickLogButton: true,
            showsQuickLogForFrequencyHabits: false,
            showsInlineProgressText: false,
            secondaryTextOverride: loggingContextText,
            currentStreak: currentStreak,
            onQuickLog: onQuickLog,
            onQuickLogLongPress: onQuickLogLongPress
        )
    }
}

private struct ProgressSummarySection: View, Equatable {
    let snapshot: ProgressAsOfSnapshot?
    let accentHex: String
    let behaviourNudgeText: String
    let isCumulativeGoal: Bool
    let onTap: () -> Void

    static func == (lhs: ProgressSummarySection, rhs: ProgressSummarySection) -> Bool {
        lhs.snapshot == rhs.snapshot &&
        lhs.accentHex == rhs.accentHex &&
        lhs.behaviourNudgeText == rhs.behaviourNudgeText &&
        lhs.isCumulativeGoal == rhs.isCumulativeGoal
    }

    var body: some View {
        Group {
            if let snapshot {
                HabitProgressSummary(
                    headline: snapshot.headlineText,
                    contextText: snapshot.contextText,
                    visibleRangeText: snapshot.visibleMonthText,
                    percentText: percentText(snapshot.progressFraction),
                    progress: snapshot.progressFraction,
                    behaviourNudgeText: behaviourNudgeText,
                    overflowText: snapshot.overflowText,
                    accent: Color(hex: accentHex)
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

    private func percentText(_ progress: Double) -> String {
        let percent = Int((progress * 100).rounded())
        return "\(percent)%"
    }
}

private struct KeyActionsSection: View {
    let isCumulativeGoal: Bool
    let isCompleteToday: Bool
    let accentHex: String
    let onQuickLog: () -> Void
    let onManualEntry: () -> Void
    @State private var isPrimaryPressed: Bool = false

    private var primaryLabelText: String {
        isCompleteToday ? "Add more" : "Log Today"
    }

    var body: some View {
        HStack(spacing: 10) {
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
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.95)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: accentHex))
            .scaleEffect(isPrimaryPressed ? 0.985 : 1)

            if isCumulativeGoal {
                Button(action: onManualEntry) {
                    Label("Add Value", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.95)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.bordered)
                .tint(Color(hex: accentHex))
            }
        }
    }
}

private struct TodaySummarySection: View {
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

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
    let contextText: String
    let visibleRangeText: String?
    let percentText: String
    let progress: Double
    let behaviourNudgeText: String
    let overflowText: String?
    let accent: Color

    var body: some View {
        let clampedProgress = min(max(progress, 0), 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(headline)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(percentText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = max(width * clampedProgress, clampedProgress > 0 ? 4 : 0)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .secondarySystemFill))

                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 10)
            .padding(.bottom, 4)

            Text(behaviourNudgeText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(0.82)
                .lineLimit(1)
                .padding(.top, 8)
                .padding(.bottom, 8)

            Text(contextText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let visibleRangeText {
                Text(visibleRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let overflowText {
                Text(overflowText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
