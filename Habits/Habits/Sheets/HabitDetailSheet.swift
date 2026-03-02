import SwiftData
import SwiftUI

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var month = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var service: HabitLogService
    @State private var showEdit = false
    @State private var showValueEntry = false
    @State private var manualLogValue: Double? = nil

    let habit: Habit

    init(habit: Habit, modelContext: ModelContext) {
        self.habit = habit
        _service = State(initialValue: HabitLogService(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HabitHeader(
                            habit: habit,
                            selectedDate: selectedDate,
                            showsQuickLogButton: true,
                            showsInlineProgressText: false,
                            secondaryTextOverride: loggingContextText,
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

                        if let details = habit.progressDetails(for: selectedDate),
                           let progress = habit.progress(for: selectedDate) {
                            HabitProgressSummary(
                                headline: habit.detailProgressText(for: selectedDate) ?? "",
                                contextText: habit.activePeriodText(for: selectedDate),
                                visibleRangeText: visibleRangeText,
                                percentText: percentText(progress),
                                progress: progress,
                                overflowText: overflowText(details),
                                streak: habit.currentStreak(referenceDate: selectedDate),
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
                            selectedDate: selectedDate,
                            isInteractive: true,
                            onSelectDay: { day in
                                selectedDate = day
                            }
                        )

                        Divider().opacity(0.2)

                        CalendarMonthView(
                            month: $month,
                            habit: habit,
                            service: service,
                            selectedDate: selectedDate,
                            onSelectDay: { day in
                                selectedDate = day
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
        .sheet(isPresented: $showValueEntry) {
            CumulativeQuickEntrySheet(
                goalName: habit.name,
                unitLabel: habit.trimmedUnit,
                initialValue: manualLogValue,
                allowsDecimals: habit.allowsDecimals,
            ) { newValue in
                let sanitizedValue = habit.allowsDecimals ? newValue : Double(Int(newValue.rounded()))
                _ = service.addLog(for: habit, on: selectedDate, value: max(0, sanitizedValue))
                manualLogValue = sanitizedValue
            }
        }
        .onAppear {
            service.prepare(habit)
        }
        .onChange(of: month) { _, newMonth in
            let calendar = Calendar.current
            guard !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) else {
                return
            }

            if let firstVisibleDay = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) {
                selectedDate = firstVisibleDay
            }
        }
    }

    private func percentText(_ progress: Double) -> String {
        let percent = Int((progress * 100).rounded())
        return "\(percent)%"
    }

    private var loggingContextText: String {
        "Logging for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var visibleRangeText: String? {
        guard habit.goalType == .cumulative else { return nil }

        let interval = Calendar.current.dateInterval(of: .month, for: month) ?? DateInterval(start: month, end: month)
        let totalText = service.formattedValue(for: habit, in: interval) ?? habit.formatProgressValue(0)
        let unitSuffix = habit.trimmedUnit.map { " \($0)" } ?? ""

        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return "\(formatter.string(from: month)): \(totalText)\(unitSuffix)"
    }

    private func overflowText(_ details: HabitProgressDetails) -> String? {
        let overflow = max(0, details.current - details.target)
        guard overflow > 0 else { return nil }
        return "+\(habit.formatProgressValue(overflow)) extra"
    }

    private func presentManualEntry() {
        manualLogValue = service.suggestedQuickEntryValue(for: habit)
        showValueEntry = true
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
