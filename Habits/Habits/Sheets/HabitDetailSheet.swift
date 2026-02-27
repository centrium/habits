import SwiftUI
import SwiftData

struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var month = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var service: HabitLogService
    @State private var showEdit = false

    let habit: Habit

    init(habit: Habit, modelContext: ModelContext) {
        self.habit = habit
        _service = State(initialValue: HabitLogService(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Card container
                    VStack(alignment: .leading, spacing: 12) {

                        HabitHeader(
                            habit: habit,
                            showsQuickLogButton: false,
                            onQuickLog: {}
                        )
                        
                        if let details = habit.progressDetails(for: selectedDate),
                           let progress = habit.progress(for: selectedDate) {

                            let target = details.target
                            let current = details.current
                            let capped = min(current, target)
                            let surplus = max(0, current - target)
                            let streak = habit.currentStreak()

                            HabitProgressSummary(
                                progressText: "\(capped) / \(target) this \(habit.streakGoalType.unit)",
                                progress: progress,
                                surplus: surplus,
                                streak: streak,
                                streakUnit: habit.streakGoalType.unit,
                                accent: Color(hex: habit.colorHex)
                            )
                            Divider().opacity(0.2)
                        }
                        HabitHeatmap(
                            habit: habit,
                            service: service,
                            selectedDate: selectedDate,
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

                    // Intentional breathing room / future expansion
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
                // X dismiss (left)
                ToolbarItem(placement: .navigationBarLeading) {
                    DismissButton()
                }

                // Edit (right)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button() {
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
    }
}

private struct HabitProgressSummary: View {
    let progressText: String
    let progress: Double
    let surplus: Int
    let streak: Int
    let streakUnit: String
    let accent: Color

    @State private var reservedSurplus: Int = 1
    @State private var reservedStreak: Int = 1

    private enum LayoutMetrics {
        static let minimumInlineWidth: CGFloat = 375
        static let verticalSpacing: CGFloat = 8
        static let inlineSpacing: CGFloat = 12
        static let metaSpacing: CGFloat = 8
        static let streakIconSpacing: CGFloat = 6
        static let badgeHorizontalPadding: CGFloat = 10
        static let badgeVerticalPadding: CGFloat = 6
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            inlineLayout
                .frame(width: LayoutMetrics.minimumInlineWidth, alignment: .leading)

            stackedLayout
        }
        .onAppear {
            refreshReservedValues()
        }
        .onChange(of: surplus) {
            refreshReservedValues()
        }
        .onChange(of: streak) {
            refreshReservedValues()
        }
    }

    private var inlineLayout: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.verticalSpacing) {
            HStack(alignment: .top, spacing: LayoutMetrics.inlineSpacing) {
                Text(progressText)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: LayoutMetrics.inlineSpacing)

                metaGroup(reserveSlots: true)
                    .fixedSize(horizontal: true, vertical: false)
            }

            progressBar
        }
    }

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.verticalSpacing) {
            Text(progressText)
                .font(.headline)

            progressBar

            metaGroup(reserveSlots: false)
        }
    }

    private var progressBar: some View {
        ProgressView(value: progress)
            .tint(accent)
            .animation(.easeInOut(duration: 0.25), value: progress)
    }

    @ViewBuilder
    private func metaGroup(reserveSlots: Bool) -> some View {
        let hasVisibleMeta = surplus > 0 || streak > 0
        if reserveSlots || hasVisibleMeta {
            HStack(spacing: LayoutMetrics.metaSpacing) {
                extraSlot(reserveSlot: reserveSlots)
                streakSlot(reserveSlot: reserveSlots)
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private func extraSlot(reserveSlot: Bool) -> some View {
        let isVisible = surplus > 0
        if reserveSlot || isVisible {
            extraLabel(value: isVisible ? surplus : reservedSurplus)
                .opacity(isVisible ? 1 : 0)
                .accessibilityHidden(!isVisible)
                .allowsHitTesting(isVisible)
        }
    }

    @ViewBuilder
    private func streakSlot(reserveSlot: Bool) -> some View {
        let isVisible = streak > 0
        if reserveSlot || isVisible {
            streakBadge(value: isVisible ? streak : reservedStreak)
                .opacity(isVisible ? 1 : 0)
                .accessibilityHidden(!isVisible)
                .allowsHitTesting(isVisible)
        }
    }

    private func extraLabel(value: Int) -> some View {
        Text("+\(max(value, 1)) extra")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func streakBadge(value: Int) -> some View {
        HStack(spacing: LayoutMetrics.streakIconSpacing) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(accent)

            Text("\(max(value, 1)) \(streakUnit) streak")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, LayoutMetrics.badgeHorizontalPadding)
        .padding(.vertical, LayoutMetrics.badgeVerticalPadding)
        .background(
            Capsule()
                .fill(accent.opacity(0.15))
        )
    }

    private func refreshReservedValues() {
        if surplus > 0 {
            reservedSurplus = surplus
        }

        if streak > 0 {
            reservedStreak = streak
        }
    }
}
