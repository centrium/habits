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
                            selectedDate: selectedDate,
                            showsQuickLogButton: false,
                            onQuickLog: { _ in }
                        )
                        
                        if let details = habit.progressDetails(for: selectedDate),
                           let progress = habit.progress(for: selectedDate) {

                            let target = details.target
                            let current = details.current
                            let capped = min(current, target)
                            let surplus = max(0, current - target)
                            let streak = habit.currentStreak(referenceDate: selectedDate)

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

    private enum LayoutMetrics {
        static let verticalSpacing: CGFloat = 8
        static let inlineSpacing: CGFloat = 12
        static let inlineBarTopSpacing: CGFloat = 8
        static let metaSpacing: CGFloat = 8
        static let streakIconSpacing: CGFloat = 6
        static let badgeHorizontalPadding: CGFloat = 10
        static let badgeVerticalPadding: CGFloat = 6
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            inlineLayout
            stackedLayout
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var inlineLayout: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.inlineBarTopSpacing) {
            HStack(alignment: .top, spacing: LayoutMetrics.inlineSpacing) {
                progressTextLabel
                    .layoutPriority(1)

                Spacer(minLength: LayoutMetrics.inlineSpacing)

                inlineMetaGroup
                    .fixedSize(horizontal: true, vertical: true)
            }

            progressBar
        }
    }

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.verticalSpacing) {
            primaryGroup

            if hasVisibleMeta {
                metaGroup
            }
        }
    }

    private var hasVisibleMeta: Bool {
        surplus > 0 || streak > 0
    }

    private var primaryGroup: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.verticalSpacing) {
            progressTextLabel
            progressBar
        }
    }

    private var progressTextLabel: some View {
        Text(progressText)
            .font(.headline)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var progressBar: some View {
        ProgressView(value: progress)
            .tint(accent)
            .animation(.easeInOut(duration: 0.25), value: progress)
    }

    @ViewBuilder
    private var metaGroup: some View {
        HStack(spacing: LayoutMetrics.metaSpacing) {
            if surplus > 0 {
                extraLabel(value: surplus)
            }

            if streak > 0 {
                streakBadge(value: streak)
            }
        }
    }

    private var inlineMetaGroup: some View {
        HStack(spacing: LayoutMetrics.metaSpacing) {
            extraLabel(value: max(surplus, 1))
                .opacity(surplus > 0 ? 1 : 0)
                .accessibilityHidden(surplus <= 0)

            streakBadge(value: max(streak, 1))
                .opacity(streak > 0 ? 1 : 0)
                .accessibilityHidden(streak <= 0)
        }
    }

    private func extraLabel(value: Int) -> some View {
        Text("+\(max(value, 1)) extra")
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private func streakBadge(value: Int) -> some View {
        HStack(spacing: LayoutMetrics.streakIconSpacing) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(accent)

            Text("\(max(value, 1)) \(streakUnit) streak")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, LayoutMetrics.badgeHorizontalPadding)
        .padding(.vertical, LayoutMetrics.badgeVerticalPadding)
        .background(
            Capsule()
                .fill(accent.opacity(0.15))
        )
    }
}
