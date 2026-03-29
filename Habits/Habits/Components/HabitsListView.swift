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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var habitLogService: HabitLogService
    @Query(sort: \Habit.orderIndex) private var habits: [Habit]

    @State private var activeSheet: ActiveSheet?
    @State private var habitPendingDeletion: Habit?
    @State private var detailPresentationDetent: PresentationDetent = .large
    @State private var pendingReorderCommitTask: Task<Void, Never>?
    @State private var showGlobalInsights = false
    

    init() {}

    var body: some View {
        NavigationStack {
            List {
                CustomHomeHeader(showsPremiumAccent: purchaseService.premiumStatus == .premium)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: 8,
                            leading: 20,
                            bottom: 8,
                            trailing: 20
                        )
                    )

                if let premiumInsightsSummary {
                    Button {
                           openGlobalInsights()
                       } label: {
                           PremiumInsightsStripView(summary: premiumInsightsSummary)
                       }
                       .buttonStyle(.plain)
                       .listRowSeparator(.hidden)
                       .listRowBackground(Color.clear)
                       .listRowInsets(
                           EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16)
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
            .navigationDestination(isPresented: $showGlobalInsights) {
                   GlobalInsightsView()
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        openGlobalInsights()
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
                    .accessibilityLabel("Global Insights")

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
                            .font(.body.weight(.semibold))
                            .foregroundStyle(colorScheme == .light ? Color.white : Color.accentColor)
                            .padding(.horizontal, colorScheme == .light ? 14 : 0)
                            .padding(.vertical, colorScheme == .light ? 10 : 0)
                            .background {
                                if colorScheme == .light {
                                    Capsule()
                                        .fill(Color.systemAccent)
                                        .shadow(color: Color.black.opacity(0.1), radius: 14, y: 6)
                                }
                            }
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

        .environmentObject(userSettings)
        .onAppear {
            habitLogService.updateCalendar(calculationCalendar)
            presentHabitDetailForDeepLinkIfNeeded()
        }
        .onChange(of: userSettings.weekStartPreference) { _, _ in
            habitLogService.updateCalendar(calculationCalendar)
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
        .onDisappear {
            flushPendingReorderPersistence()
        }
        .task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
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
        let hasUnlimitedHabitsAccess: Bool
        switch purchaseService.premiumStatus {
        case .premium, .unknown:
            hasUnlimitedHabitsAccess = true
        case .free:
            hasUnlimitedHabitsAccess = false
        }

        return HabitLimitPolicy(
            habitCount: habits.count,
            hasUnlimitedHabitsAccess: hasUnlimitedHabitsAccess
        )
    }
    
    private func openGlobalInsights() {
        switch purchaseService.premiumStatus {
        case .unknown:
            return

        case .premium:
            showGlobalInsights = true

        case .free:
            showPaywall(feature: .advancedInsights)
        }
    }

    private var premiumInsightsSummary: PremiumInsightsStripSummary? {
        guard purchaseService.premiumStatus == .premium,
              userSettings.showPremiumInsightsView,
              userSettings.greigModeEnabled,
              !habits.isEmpty else {
            return nil
        }

        return GlobalInsightsService(
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        ).snapshot(for: habits, now: .now)?.stripSummary
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
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: destination)

        let didChange = reordered.enumerated().contains { index, habit in
            habit.orderIndex != index
        }
        guard didChange else { return }

        _ = HabitListMutation.applyOrderIndexesInMemory(to: reordered)

        scheduleReorderPersistence()
    }

    private func addHabit() {
        switch purchaseService.premiumStatus {
        case .unknown:
            return
        case .premium:
            activeSheet = .addHabit
        case .free:
            if habits.count >= HabitLimitPolicy.freeHabitLimit {
                showPaywall(feature: .unlimitedHabits)
            } else {
                activeSheet = .addHabit
            }
        }
    }

    private func showPaywall(feature: PremiumFeature) {
        guard purchaseService.premiumStatus != .unknown else { return }
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

    private func scheduleReorderPersistence() {
        pendingReorderCommitTask?.cancel()
        pendingReorderCommitTask = Task(priority: .utility) { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }

            guard modelContext.saveWithoutWidgetSync() else {
                pendingReorderCommitTask = nil
                return
            }

            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            _ = WidgetDataSync.sync(in: modelContext)
            pendingReorderCommitTask = nil
        }
    }

    private func flushPendingReorderPersistence() {
        guard pendingReorderCommitTask != nil else { return }
        pendingReorderCommitTask?.cancel()
        pendingReorderCommitTask = nil
        _ = HabitListMutation.persistOrderChanges(in: modelContext)
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

private struct CustomHomeHeader: View {
    let showsPremiumAccent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CadenceProWordmark(
                size: .large,
                animateSwoosh: showsPremiumAccent,
                showsProLabel: showsPremiumAccent
            )
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
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

private struct PremiumInsightsStripView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                ProSwoosh(size: .small)

                Text(primaryLine)
                    .font(.headline)
                    .lineLimit(1)

                secondaryLine
                    .font(.caption)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .appSurface(level: .highlighted, accent: accentColor, tinted: colorScheme == .light, cornerRadius: 16)
    }

    private var primaryLine: AttributedString {
        var label = AttributedString(summary.primaryLabel)
        label.foregroundColor = .primary

        var value = AttributedString(summary.primaryValue)
        value.foregroundColor = accentColor

        return label + value
    }

    private var secondaryLine: Text {
        Text(secondaryAttributedLine)
    }

    private var secondaryAttributedLine: AttributedString {
        var line = AttributedString(summary.secondaryLabel)
        line.foregroundColor = .secondary

        var value = AttributedString(summary.secondaryValue)
        value.foregroundColor = accentColor
        line += value

        if let secondarySuffix = summary.secondarySuffix {
            var separator = AttributedString(" · ")
            separator.foregroundColor = .secondary
            line += separator

            var suffix = AttributedString(secondarySuffix)
            suffix.foregroundColor = .secondary
            line += suffix
        }

        return line
    }
}

private struct EmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
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
        .appSurface(level: .standard, cornerRadius: 16)
    }
}

private struct LockedHabitSlotCard: View {
    @Environment(\.colorScheme) private var colorScheme
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
        .appSurface(level: .standard, cornerRadius: 16)
        .opacity(colorScheme == .light ? 0.82 : 0.6)
    }
}
