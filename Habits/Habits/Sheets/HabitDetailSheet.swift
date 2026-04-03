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

struct HabitDetailSheet: View {
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
    @State private var isHistoryPresented = false
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

        detailContent(
            progressSnapshot: progressSnapshot,
            displayedStreak: displayedStreak,
            progressRevision: progressRevision,
            earliestCalendarDate: earliestCalendarDate
        )
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
        .navigationDestination(isPresented: $isHistoryPresented) {
            historyTabContent(
                progressRevision: progressRevision,
                calendarMonthSummaryText: calendarMonthSummaryText,
                earliestCalendarDate: earliestCalendarDate,
                premiumHistoryGate: premiumHistoryGate,
                calendar: calendar
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("History")
        }
    }

    @ViewBuilder
    private func detailContent(
        progressSnapshot: ProgressAsOfSnapshot?,
        displayedStreak: Int,
        progressRevision: Int,
        earliestCalendarDate: Date?
    ) -> some View {
        let sectionPadding: CGFloat = 16
        let sectionSpacing: CGFloat = 14
        let sectionCornerRadius: CGFloat = 16
        let heroStatus = heroCenterStatusText(progressSnapshot: progressSnapshot)
        let momentum = momentumSummary()
        let logCount = habit.logs.count
        let isLowDataActivityState = logCount == 0
        let showsProgressSummary = logCount > 0 && progressSnapshot != nil
        let isCumulativeGoal = habit.goalType == .cumulative
        let showsInsightsSection = hasInsightsInlineAction

        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
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

                    Text(heroStatus)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)
                        .frame(maxWidth: .infinity, alignment: .center)

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
                }
                .padding(14)
                .frame(minHeight: 206, alignment: .topLeading)
                .cadenceSurface(cornerRadius: sectionCornerRadius)
                .padding(.horizontal, sectionPadding)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 8) {
                    if logCount == 0 {
                        Text("Your progress starts here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .padding(14)
                .frame(minHeight: 70)
                .cadenceSurface(cornerRadius: sectionCornerRadius)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(
                            isLowDataActivityState
                                ? "Your entries will appear here"
                                : "Recent check-ins"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                            showsMomentumSummary: false
                        )
                        .opacity(isLowDataActivityState ? 0.7 : 1)

                        HStack(spacing: 4) {
                            Text("See all activity →")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(14)
                .frame(minHeight: 112, alignment: .topLeading)
                .cadenceSurface(cornerRadius: sectionCornerRadius)
                .padding(.horizontal, sectionPadding)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Momentum")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(momentum.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(momentum.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: momentum.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .padding(.top, 2)
                }
                .padding(14)
                .frame(minHeight: 82, alignment: .topLeading)
                .cadenceSurface(cornerRadius: sectionCornerRadius)
                .padding(.horizontal, sectionPadding)

                if showsInsightsSection {
                    VStack(alignment: .leading, spacing: 4) {
                        InsightsInlineNudgeRow(
                            text: insightsInlineNudgeText,
                            action: openInsightsOrPaywall
                        )
                    }
                    .padding(14)
                    .frame(minHeight: 48, alignment: .leading)
                    .cadenceSurface(cornerRadius: sectionCornerRadius)
                    .padding(.horizontal, sectionPadding)
                }

                Color.clear
                    .frame(height: 18)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
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
                VStack(alignment: .leading, spacing: 0) {
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
                    .padding(.top, 14)
                    .padding(.bottom, 16)

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
                    .padding(.top, 12)
                    .opacity(0.96)
                }
                .padding(12)
                .cadenceSurface(cornerRadius: 16)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Color.clear
                    .frame(height: 72)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, 16)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private var loggingContextText: String {
        let shortDate = selectedDate.formatted(
            Date.FormatStyle()
                .day()
                .month(.abbreviated)
        )
        return "Logging for \(shortDate)"
    }

    private func heroCenterStatusText(
        progressSnapshot: ProgressAsOfSnapshot?
    ) -> String {
        guard !habit.logs.isEmpty else {
            return "Start today"
        }

        if let progressSnapshot, progressSnapshot.current > progressSnapshot.target {
            return "Beyond target"
        }

        if isCompleteForSelectedDate {
            return "Done for today"
        }

        _ = progressSnapshot
        return "Ready to log"
    }

    private func momentumSummary() -> (title: String, detail: String, symbolName: String) {
        let today = calculationCalendar.startOfDay(for: Date())
        let range: [Date] = (0..<7).compactMap {
            calculationCalendar.date(byAdding: .day, value: -$0, to: today)
        }
        let metrics = habitLogService.dayMetrics(for: habit, on: range)
        let activeDays = range.reduce(0) { count, day in
            let intensity = metrics[day]?.intensity ?? 0
            return count + (intensity > 0 ? 1 : 0)
        }

        let title: String = {
            switch activeDays {
            case 5...7:
                return "On track"
            case 3...4:
                return "Building"
            default:
                return "Slipping"
            }
        }()

        let symbolName: String = {
            switch title {
            case "On track":
                return "arrow.up.right"
            case "Building":
                return "waveform.path.ecg"
            default:
                return "arrow.down.right"
            }
        }()

        return (title, "\(activeDays) of last 7 days", symbolName)
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
            showsQuickLogButton: false,
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
                    accent: HabitColor.from(hex: accentHex).color
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
        _ = isCompleteToday
        return "Log today"
    }

    private var accent: Color {
        HabitColor.from(hex: accentHex).color
    }

    private var primaryBaseAccent: Color {
        isCompleteToday ? accent.opacity(0.88) : accent
    }

    private var secondaryBaseAccent: Color {
        accent
    }

    private var secondaryTextColor: Color {
        accent.opacity(colorScheme == .dark ? 0.9 : 0.95)
    }

    var body: some View {
        HStack(spacing: 10) {
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
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.95)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(primaryButtonBackground)
        }
    }

    private var secondaryButton: some View {
        Button(action: onManualEntry) {
            Label("Add value", systemImage: "plus.circle")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.95)
                .foregroundStyle(secondaryTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(secondaryButtonBackground)
        }
    }

    private var primaryButtonBackground: some View {
        Capsule()
            .fill(primaryBaseAccent)
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.08), lineWidth: 1)
            }
    }

    private var secondaryButtonBackground: some View {
        Capsule()
            .fill(Color.clear)
            .overlay {
                Capsule()
                    .stroke(secondaryBaseAccent.opacity(colorScheme == .dark ? 0.55 : 0.45), lineWidth: 1)
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
            Text("Activity")
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
    let progress: Double
    let overflowFraction: Double
    let overflowText: String?
    let accent: Color

    var body: some View {
        let clampedProgress = min(max(progress, 0), 1)
        let progressAccent = accent.opacity(0.82)
        let clampedOverflow = min(max(overflowFraction, 0), 0.22)

        return VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.95)

            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = max(width * clampedProgress, clampedProgress > 0 ? 4 : 0)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .secondarySystemFill))

                    Capsule(style: .continuous)
                        .fill(progressAccent)
                        .frame(width: fillWidth)

                    if clampedOverflow > 0 {
                        Capsule(style: .continuous)
                            .fill(progressAccent.opacity(0.34))
                            .frame(width: width * clampedOverflow)
                            .offset(x: width - (width * clampedOverflow))
                    }
                }
            }
            .frame(height: 10)
            .padding(.bottom, 4)

            if let overflowText, clampedOverflow > 0 {
                Text(overflowText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
