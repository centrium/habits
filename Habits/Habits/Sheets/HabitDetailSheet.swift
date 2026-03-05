import SwiftData
import SwiftUI

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSettings: UserSettings
    @StateObject private var selectionState: HabitSelectionState
    @State private var service: HabitLogService
    @State private var showEdit = false
    @State private var showInsights = false
    @State private var showValueEntry = false
    @State private var manualLogValue: Double? = nil
    @State private var insightsDetent: PresentationDetent = .large

    let habit: Habit

    init(
        habit: Habit,
        modelContext: ModelContext,
        initialCalendar: Calendar = .autoupdatingCurrent
    ) {
        self.habit = habit
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

                        HStack {
                            Spacer()

                            Button {
                                insightsDetent = .large
                                showInsights = true
                            } label: {
                                Text("Insights")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        if let progressSnapshot {
                            HabitProgressSummary(
                                headline: progressSnapshot.headlineText,
                                contextText: progressSnapshot.contextText,
                                visibleRangeText: progressSnapshot.visibleMonthText,
                                percentText: percentText(progressSnapshot.progressFraction),
                                progress: progressSnapshot.progressFraction,
                                overflowText: progressSnapshot.overflowText,
                                streak: progressSnapshot.streak,
                                streakUnit: habit.goalPeriod.streakUnit,
                                accent: Color(hex: habit.colorHex)
                            )
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
                    DismissButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .presentationBackground(Color(.systemBackground))
        .sheet(isPresented: $showEdit) {
            EditHabitSheet(habit: habit)
        }
        .sheet(isPresented: $showInsights) {
            NavigationStack {
                HabitInsightsView(
                    habit: habit,
                    logAnchorDate: selectionState.selectedDate
                )
            }
            .presentationDetents([.medium, .large], selection: $insightsDetent)
            .presentationBackground(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showValueEntry) {
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
        showValueEntry = true
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
    let streak: Int
    let streakUnit: String
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

                if streak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(accent)

                        Text("\(streak) \(streakUnit) streak")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.15))
                    )
                }
            }

            Spacer()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}
