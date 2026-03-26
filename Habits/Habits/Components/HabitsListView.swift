//
//  HabitsListView.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI
import SwiftData

private enum ActiveSheet: Identifiable {
    case addHabit
    case paywall(PremiumFeature)
    case habitDetail(Habit)

    var id: String {
        switch self {
        case .addHabit:
            return "addHabit"
        case .paywall(let feature):
            return "paywall-\(String(describing: feature))"
        case .habitDetail(let habit):
            return "habitDetail-\(habit.id.uuidString)"
        }
    }
}

struct HabitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    
    @Query(sort: \Habit.orderIndex) private var habits: [Habit]

    @State private var activeSheet: ActiveSheet?
    @State private var habitPendingDeletion: Habit?
    @State private var detailPresentationDetent: PresentationDetent = .large

    init() {}

    var body: some View {
        NavigationStack {
            List {
                if let premiumInsightsSummary {
                    PremiumInsightsStripView(summary: premiumInsightsSummary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(
                                top: 4,
                                leading: 16,
                                bottom: 6,
                                trailing: 16
                            )
                        )
                }

                ForEach(habits) { habit in
                    HabitCard(habit: habit)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                requestDeletion(of: habit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
                .onMove(perform: moveHabit)

                if habitLimitPolicy.showsUpgradeHint {
                    UpgradeHintRow()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                if habitLimitPolicy.showsLockedSlot {
                    lockedHabitSlot
                }

                if habits.isEmpty {
                    EmptyState()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .alert(
                "Delete Habit?",
                isPresented: HabitDeletionConfirmationState.isPresentedBinding(
                    for: $habitPendingDeletion
                ),
                presenting: habitPendingDeletion
            ) { habit in
                Button("Delete Habit", role: .destructive) {
                    confirmDeletion(of: habit)
                }

                Button("Cancel", role: .cancel) {
                    cancelDeletion()
                }
            } message: { habit in
                Text(HabitDeletionConfirmationState.message(for: habit))
            }
            .listStyle(.plain)
            .contentMargins(.top, 12, for: .scrollContent)
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle(HabitsListTitleCopy.baseTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        addHabit()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }

                    Spacer()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addHabit:
                    AddHabitSheet()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                case .paywall(let feature):
                    PaywallView(feature: feature)
                case .habitDetail(let habit):
                    HabitDetailSheet(
                        habit: habit,
                        modelContext: modelContext,
                        initialCalendar: calculationCalendar
                    ) {
                        activeSheet = nil
                    }
                    .presentationDetents([.medium, .large], selection: $detailPresentationDetent)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if purchaseService.isPremiumUnlocked {
                PremiumTitleUnderline()
            }
        }
        .environmentObject(userSettings)
        .onAppear {
            presentHabitDetailForDeepLinkIfNeeded()
        }
        .onChange(of: deepLinkManager.selectedHabitID) { _, _ in
            presentHabitDetailForDeepLinkIfNeeded()
        }
        .onChange(of: habits.map(\.id)) { _, _ in
            presentHabitDetailForDeepLinkIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            presentHabitDetailForDeepLinkIfNeeded()
        }
        .task {
            if userSettings.eveningReflectionEnabled {
                await NotificationService.shared.scheduleEveningReflection(
                    hour: userSettings.eveningReflectionHour,
                    minute: userSettings.eveningReflectionMinute
                )
            } else {
                NotificationService.shared.removeEveningReflection()
            }
        }
    }

    private var habitLimitPolicy: HabitLimitPolicy {
        HabitLimitPolicy(
            habitCount: habits.count,
            hasUnlimitedHabitsAccess: purchaseService.hasAccess(to: .unlimitedHabits)
        )
    }

    private var premiumInsightsSummary: PremiumInsightsStripSummary? {
        guard purchaseService.isPremiumUnlocked, !habits.isEmpty else {
            return nil
        }

        let now = Date()
        let momentumService = MomentumScoreService(
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        )
        let insightsService = HabitInsightsService(calendar: calculationCalendar)

        let momentumScores = habits.map { habit in
            momentumService.score(for: habit, now: now)
        }
        let consistencyScores = habits.map { habit in
            insightsService.snapshot(for: habit, now: now).consistency
        }
        let atRiskCount = habits.reduce(into: 0) { count, habit in
            let riskScore = PerformanceSignalsCalculator.habitRiskScore(
                for: habit,
                calendar: calculationCalendar,
                now: now
            )
            if riskScore >= 0.5 {
                count += 1
            }
        }

        let averageMomentum = Int(
            (
                Double(momentumScores.reduce(0, +)) /
                Double(max(momentumScores.count, 1))
            ).rounded()
        )
        let averageConsistency = Int(
            (
                Double(consistencyScores.reduce(0, +)) /
                Double(max(consistencyScores.count, 1))
            ).rounded()
        )

        return PremiumInsightsStripCopy.summary(
            momentum: averageMomentum,
            consistency: averageConsistency,
            atRiskCount: atRiskCount
        )
    }

    private var lockedHabitSlot: some View {
        Button {
            showPaywall(feature: .unlimitedHabits)
        } label: {
            LockedHabitSlotCard()
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func moveHabit(from source: IndexSet, to destination: Int) {
        withAnimation(AppMotion.reorder) {
            var reordered = habits
            reordered.move(fromOffsets: source, toOffset: destination)
            HabitListMutation.applyOrderIndexes(to: reordered, in: modelContext)
        }
    }

    private func addHabit() {
        if purchaseService.hasAccess(to: .unlimitedHabits) {
            activeSheet = .addHabit
        } else if habits.count >= HabitLimitPolicy.freeHabitLimit {
            showPaywall(feature: .unlimitedHabits)
        } else {
            activeSheet = .addHabit
        }
    }

    private func showPaywall(feature: PremiumFeature) {
        activeSheet = .paywall(feature)
    }

    private func requestDeletion(of habit: Habit) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            habitPendingDeletion = habit
        }
    }

    private func cancelDeletion() {
        habitPendingDeletion = nil
    }

    private func confirmDeletion(of habit: Habit) {
        cancelDeletion()

        Haptics.impactMedium()

        withAnimation(AppMotion.quickFade) {
            HabitDeletionAction.perform(
                habit: habit,
                modelContext: modelContext
            )
        }
    }

    private var weekLayoutStrategy: WeekLayoutStrategy {
        userSettings.weekLayoutStrategy()
    }

    private var calculationCalendar: Calendar {
        weekLayoutStrategy.calendarForCalculations()
    }

    private func presentHabitDetailForDeepLinkIfNeeded() {
        guard let deepLinkedHabitID = deepLinkManager.selectedHabitID else { return }
        guard let habit = habits.first(where: { $0.id == deepLinkedHabitID }) else { return }

        activeSheet = .habitDetail(habit)

        DispatchQueue.main.async {
            deepLinkManager.clearSelectedHabit(deepLinkedHabitID)
        }
    }
}

enum HabitsListTitleCopy {
    static let baseTitle = "Cadence"
}

enum HabitDeletionConfirmationState {
    static func isPresentedBinding(for pendingHabit: Binding<Habit?>) -> Binding<Bool> {
        Binding(
            get: { pendingHabit.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    pendingHabit.wrappedValue = nil
                }
            }
        )
    }

    static func message(for habit: Habit) -> String {
        "This will permanently delete \"\(habit.name)\" and its history."
    }
}

private struct UpgradeHintRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.footnote)

            Text("Free accounts can track up to 3 habits. Upgrade to add unlimited habits.")
                .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }
}

private struct PremiumInsightsStripSummary {
    let primaryLabel: String
    let primaryValue: String
    let secondaryLabel: String
    let secondaryValue: String
    let secondarySuffix: String?
}

private enum PremiumInsightsStripCopy {
    static func summary(momentum: Int, consistency: Int, atRiskCount: Int) -> PremiumInsightsStripSummary {
        PremiumInsightsStripSummary(
            primaryLabel: "Momentum ",
            primaryValue: "\(momentum)%",
            secondaryLabel: "Consistency ",
            secondaryValue: "\(consistency)%",
            secondarySuffix: secondarySuffix(for: atRiskCount)
        )
    }

    private static func secondarySuffix(for atRiskCount: Int) -> String? {
        switch atRiskCount {
        case 0:
            return "Steady today"
        case 1:
            return "1 needs attention"
        default:
            return "\(atRiskCount) need attention"
        }
    }
}

private struct PremiumInsightsStripView: View {
    let summary: PremiumInsightsStripSummary
    private let accentColor = Color.systemAccent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.28),
                    accentColor.opacity(0.12),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 5)
            .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 5) {
                (
                    Text(summary.primaryLabel)
                        .foregroundStyle(.primary) +
                    Text(summary.primaryValue)
                        .foregroundStyle(accentColor)
                )
                    .font(.headline)
                    .lineLimit(1)

                secondaryLine
                    .font(.caption)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accentColor.opacity(0.04))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.22),
                                    accentColor.opacity(0.08),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        )
        .shadow(color: accentColor.opacity(0.12), radius: 8, y: 2)
    }

    private var secondaryLine: Text {
        var line =
            Text(summary.secondaryLabel)
            .foregroundStyle(.secondary) +
            Text(summary.secondaryValue)
            .foregroundStyle(accentColor)

        if let secondarySuffix = summary.secondarySuffix {
            line = line +
                Text(" · ")
                .foregroundStyle(.secondary) +
                Text(secondarySuffix)
                .foregroundStyle(.secondary)
        }

        return line
    }
}

private struct PremiumTitleUnderline: View {
    private let underlineWidth: CGFloat = 60
    private let underlineHeight: CGFloat = 2.5

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.systemAccent.opacity(0.6))
                .frame(width: underlineWidth, height: underlineHeight)
                .offset(x: 20, y: geometry.safeAreaInsets.top + 46)
        }
        .allowsHitTesting(false)
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("No habits yet")
                .font(.headline)
            Text("Tap the plus button below to create one. Then tap today’s square to log.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct LockedHabitSlotCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 44, height: 44)

                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Unlock unlimited habits")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Unlock more space for the routines you want to keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(0.6)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
