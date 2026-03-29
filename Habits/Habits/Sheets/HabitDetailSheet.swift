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

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        EquatableView(
                            content: HeaderSection(
                                habit: habit,
                                selectedDate: selectedDate,
                                metricsRevision: progressRevision,
                                calendar: calculationCalendar,
                                weekStartPreference: userSettings.weekStartPreference,
                                loggingContextText: loggingContextText,
                                currentStreak: displayedStreak,
                                onQuickLog: { date in
                                    if habit.goalType == .frequency {
                                        _ = habitLogService.quickLog(for: habit, on: date)
                                    } else {
                                        presentManualEntry()
                                    }
                                },
                                onQuickLogLongPress: habit.goalType == .cumulative ? { _ in
                                    presentManualEntry()
                                } : nil
                            )
                        )

                        EquatableView(
                            content: ProgressSummarySection(
                                snapshot: progressSnapshot,
                                accentHex: habit.colorHex,
                                isCumulativeGoal: habit.goalType == .cumulative,
                                onTap: {
                                    presentManualEntry()
                                }
                            )
                        )

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
                                onTapLockedDay: { _ in
                                    showPaywall(feature: .fullHeatmapHistory)
                                }
                            )
                        )
                    }
                    .padding(14)
                    .appSurface(level: .standard, cornerRadius: 16)
                    .overlay {
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
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.18) : .clear,
                        radius: colorScheme == .dark ? 18 : 0,
                        y: colorScheme == .dark ? 10 : 0
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Color.clear
                        .frame(height: 200)
                        .allowsHitTesting(false)
                }
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 44, height: 44) // 👈 critical
                            .contentShape(Rectangle())    // 👈 ensures full tap area
                    }
                    .buttonStyle(TactileButtonStyle())
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {

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
        }
        .toolbarRole(.navigationStack)
        .presentationBackground(Color(.systemBackground))
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
                    formattingContext: habitLogService.valueFormattingContext(for: habit),
                    inputContext: habitLogService.valueInputContext(for: habit)
                ) { newValue in
                    _ = habitLogService.addLog(for: habit, on: selectedDate, value: max(0, newValue))
                    manualLogValue = newValue
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

    private var loggingContextText: String {
        "Logging for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func presentManualEntry() {
        manualLogValue = habitLogService.suggestedQuickEntryValue(for: habit)
        activeSheet = .valueEntry
    }

    private func showPaywall(feature: PremiumFeature) {
        guard purchaseService.premiumStatus != .unknown else { return }
        activeSheet = .paywall(feature)
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
                    contextText: snapshot.contextText,
                    visibleRangeText: snapshot.visibleMonthText,
                    percentText: percentText(snapshot.progressFraction),
                    progress: snapshot.progressFraction,
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
    let month: Binding<Date>
    let habit: Habit
    let service: HabitLogService
    let calendarProvider: CalendarProvider
    let premiumHistoryGate: PremiumHistoryGate.Context
    let onSelectDay: (Date) -> Void
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
            onSelectDay: onSelectDay,
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
    let overflowText: String?
    let accent: Color

    private let ringSize: CGFloat = 104
    private let ringLineWidth: CGFloat = 8

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.15), lineWidth: ringLineWidth)

                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(percentText)
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: ringSize, height: ringSize)

            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.title3.weight(.semibold))

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

            Spacer()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
