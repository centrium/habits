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
                HabitInsightsView(habit: habit)
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

private struct HabitInsightsView: View {
    let habit: Habit

    @State private var hasAnimatedIn = false

    private let completionRate = 0.82
    private let completedDays = 24
    private let totalDays = 30
    private let averagePerDay = 1.7
    private let currentStreak = 5
    private let longestStreak = 12
    private let momentumPercentage = 12
    private let momentumDirection: HabitInsightsMomentumDirection = .up
    private let recentActivity = [1, 1, 2, 0, 1, 2, 3, 2, 1, 2, 2, 3, 2, 2]

    private var accent: Color {
        Color(hex: habit.colorHex)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 38) {
                HeroSection(
                    completionRate: completionRate,
                    completedDays: completedDays,
                    totalDays: totalDays,
                    momentumPercentage: momentumPercentage,
                    momentumDirection: momentumDirection,
                    accent: accent
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.32), value: hasAnimatedIn)

                TrendSection(
                    activity: recentActivity,
                    accent: accent,
                    animateBars: hasAnimatedIn
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.36).delay(0.03), value: hasAnimatedIn)

                PerformanceSection(
                    averagePerDay: averagePerDay,
                    currentStreak: currentStreak,
                    longestStreak: longestStreak
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.38).delay(0.06), value: hasAnimatedIn)

                MomentumSection(
                    percentage: momentumPercentage,
                    direction: momentumDirection
                )
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAnimatedIn)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DismissButton()
            }
        }
        .onAppear {
            hasAnimatedIn = false
            DispatchQueue.main.async {
                hasAnimatedIn = true
            }
        }
    }
}

private enum HabitInsightsMomentumDirection {
    case up
    case neutral
    case down

    var arrow: String {
        switch self {
        case .up:
            return "↑"
        case .neutral:
            return "→"
        case .down:
            return "↓"
        }
    }

    var color: Color {
        switch self {
        case .up:
            return .green
        case .neutral:
            return .secondary
        case .down:
            return .red
        }
    }

    var heroLabel: String {
        switch self {
        case .up:
            return "vs previous period"
        case .neutral:
            return "holding steady vs previous period"
        case .down:
            return "vs previous period"
        }
    }

    var momentumSummary: String {
        switch self {
        case .up:
            return "Activity increased compared to last week."
        case .neutral:
            return "Activity is in line with last week."
        case .down:
            return "Activity is below last week."
        }
    }
}

private struct HeroSection: View {
    let completionRate: Double
    let completedDays: Int
    let totalDays: Int
    let momentumPercentage: Int
    let momentumDirection: HabitInsightsMomentumDirection
    let accent: Color

    private var completionText: String {
        "\(Int((completionRate * 100).rounded()))%"
    }

    private func reinforcementMessage(for completionRate: Double) -> String {
        switch completionRate {
        case 0.8...:
            return "You're staying consistent."
        case 0.5..<0.8:
            return "You're building momentum."
        default:
            return "Consistency will strengthen this habit."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(completionText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .padding(.bottom, 10)

            Text("Completion (Last 30 Days)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 5)

            Text("\(completedDays) of \(totalDays) days completed")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(reinforcementMessage(for: completionRate))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 9)

            HStack(spacing: 6) {
                Text(momentumDirection.arrow)
                    .foregroundStyle(momentumDirection.color)

                Text("\(momentumPercentage)% \(momentumDirection.heroLabel)")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .padding(.top, 10)
        }
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct PerformanceSection: View {
    let averagePerDay: Double
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        HabitInsightsCard {
            VStack(alignment: .leading, spacing: 0) {
                performanceRow(label: "Average This Month", value: "\(averagePerDay.formatted(.number.precision(.fractionLength(1)))) / day")
                performanceRow(label: "Current Streak", value: "\(currentStreak) days")
                performanceRow(label: "Longest Streak", value: "\(longestStreak) days")
            }
        }
    }

    private func performanceRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.vertical, 13)
    }
}

private struct TrendSection: View {
    let activity: [Int]
    let accent: Color
    let animateBars: Bool

    private let chartHeight: CGFloat = 64
    private let barSpacing: CGFloat = 6

    private var maxValue: Int {
        max(activity.max() ?? 1, 1)
    }

    var body: some View {
        HabitInsightsCard(padding: 17) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Last 14 Days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    let barCount = CGFloat(max(activity.count, 1))
                    let totalSpacing = barSpacing * CGFloat(max(activity.count - 1, 0))
                    let barWidth = max(4, (geometry.size.width - totalSpacing) / barCount)

                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(activity.enumerated()), id: \.offset) { index, value in
                            RoundedRectangle(cornerRadius: min(3, barWidth / 2), style: .continuous)
                                .fill(fillColor(for: value))
                                .frame(
                                    width: barWidth,
                                    height: barHeight(for: value, availableHeight: geometry.size.height)
                                )
                                .animation(
                                    .spring(response: 0.42, dampingFraction: 0.88)
                                        .delay(0.06 + (Double(index) * 0.025)),
                                    value: animateBars
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(height: chartHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fillColor(for value: Int) -> Color {
        value == 0 ? Color.secondary.opacity(0.18) : accent.opacity(0.78)
    }

    private func barHeight(for value: Int, availableHeight: CGFloat) -> CGFloat {
        guard animateBars else { return 0 }
        guard value > 0 else { return 6 }

        let normalized = CGFloat(value) / CGFloat(maxValue)
        return max(12, normalized * availableHeight)
    }
}

private struct MomentumSection: View {
    let percentage: Int
    let direction: HabitInsightsMomentumDirection

    var body: some View {
        HabitInsightsCard(background: Color(.secondarySystemGroupedBackground).opacity(0.85)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Momentum")
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(direction.arrow)
                        .foregroundStyle(direction.color)

                    Text("\(percentage)% vs last week")
                        .foregroundStyle(.primary)
                }
                .font(.title3.weight(.semibold))
                .monospacedDigit()

                Text(direction.momentumSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HabitInsightsCard<Content: View>: View {
    let content: Content
    let background: Color
    let padding: CGFloat

    init(
        background: Color = Color(.secondarySystemGroupedBackground),
        padding: CGFloat = 19,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
