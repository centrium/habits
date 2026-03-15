import SwiftData
import SwiftUI

private enum ActiveSheet: Identifiable {
    case edit
    case insights
    case valueEntry
    case paywall

    var id: Int { hashValue }
}

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @StateObject private var selectionState: HabitSelectionState
    @State private var service: HabitLogService
    @State private var activeSheet: ActiveSheet?
    @State private var manualLogValue: Double? = nil
    @State private var insightsDetent: PresentationDetent = .large
    private let onDeleted: (() -> Void)?

    let habit: Habit

    init(
        habit: Habit,
        modelContext: ModelContext,
        initialCalendar: Calendar = .autoupdatingCurrent,
        onDeleted: (() -> Void)? = nil
    ) {
        self.habit = habit
        self.onDeleted = onDeleted
        _selectionState = StateObject(wrappedValue: HabitSelectionState(calendar: initialCalendar))
        _service = State(initialValue: HabitLogService(modelContext: modelContext, calendar: initialCalendar))
    }

    var body: some View {
        let progressService = ProgressAsOfService(
            calendar: service.calendar,
            weekStartPreference: userSettings.weekStartPreference
        )
        let progressSnapshot = progressService.snapshot(
            for: habit,
            visibleMonth: selectionState.visibleMonth,
            selectedDate: selectionState.selectedDate
        )
        let now = Date()
        let today = service.calendar.startOfDay(for: now)
        let streakSnapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: today,
            respectCreatedAtBoundary: false,
            calendar: service.calendar,
            weekStartPreference: userSettings.weekStartPreference,
            now: now
        ).streak

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HabitHeader(
                            habit: habit,
                            selectedDate: selectionState.selectedDate,
                            calendar: service.calendar,
                            weekStartPreference: userSettings.weekStartPreference,
                            showsQuickLogButton: true,
                            showsInlineProgressText: false,
                            secondaryTextOverride: loggingContextText,
                            currentStreak: streakSnapshot.current,
                            progressFractionOverride: progressSnapshot?.progressFraction,
                            isCompleteOverride: progressSnapshot?.isComplete,
                            onQuickLog: { date in
                                if habit.goalType == .frequency {
                                    _ = service.quickLog(for: habit, on: date)
                                } else {
                                    presentManualEntry()
                                }
                            },
                            onQuickLogLongPress: habit.goalType == .cumulative ? { _ in
                                presentManualEntry()
                            } : nil
                        )

                        if let progressSnapshot {
                            HabitProgressSummary(
                                headline: progressSnapshot.headlineText,
                                contextText: progressSnapshot.contextText,
                                visibleRangeText: progressSnapshot.visibleMonthText,
                                percentText: percentText(progressSnapshot.progressFraction),
                                progress: progressSnapshot.progressFraction,
                                overflowText: progressSnapshot.overflowText,
                                accent: Color(hex: habit.colorHex)
                            )
                            .pressableCardFeedback(scale: 0.985, opacity: 0.98)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if habit.goalType == .cumulative {
                                    presentManualEntry()
                                }
                            }

                            Divider().opacity(0.2)
                        }

                        HabitHeatmap(
                            habit: habit,
                            service: service,
                            calendarProvider: heatmapCalendarProvider,
                            selectedDate: selectionState.selectedDate,
                            isInteractive: true,
                            onSelectDay: { day in
                                selectionState.select(heatmapDate: day)
                            }
                        )

                        Divider().opacity(0.2)

                        CalendarMonthView(
                            month: Binding(
                                get: { selectionState.visibleMonth },
                                set: { selectionState.selectCalendarMonth($0) }
                            ),
                            habit: habit,
                            service: service,
                            calendarProvider: calendarViewProvider,
                            selectedDate: selectionState.selectedDate,
                            monthSummaryText: progressSnapshot?.visibleMonthText,
                            onSelectDay: { day in
                                selectionState.select(date: day)
                            }
                        )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
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
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { })
            .background(
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(TactileButtonStyle())
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {

                    Button {
                        if purchaseService.hasAccess(to: .advancedInsights) {
                            activeSheet = .insights
                        } else {
                            activeSheet = .paywall
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.82, green: 0.68, blue: 0.42))
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
                        logAnchorDate: selectionState.selectedDate
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
                    formattingContext: service.valueFormattingContext(for: habit),
                    inputContext: service.valueInputContext(for: habit)
                ) { newValue in
                    _ = service.addLog(for: habit, on: selectionState.selectedDate, value: max(0, newValue))
                    manualLogValue = newValue
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)

            case .paywall:
                PaywallView(feature: .advancedInsights)

            }

        }
        .onAppear {
            service.updateCalendar(calculationCalendar)
            service.prepare(habit)
        }
        .onChange(of: userSettings.weekStartPreference) { _, _ in
            service.updateCalendar(calculationCalendar)
        }
    }

    private func percentText(_ progress: Double) -> String {
        let percent = Int((progress * 100).rounded())
        return "\(percent)%"
    }

    private var loggingContextText: String {
        "Logging for \(selectionState.selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func presentManualEntry() {
        manualLogValue = service.suggestedQuickEntryValue(for: habit)
        activeSheet = .valueEntry
    }

    private var weekLayoutStrategy: WeekLayoutStrategy {
        userSettings.weekLayoutStrategy(base: service.calendar)
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
