//
//  HabitsListView.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI
import SwiftData
import UIKit

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
    @State private var isReordering: Bool = false
    @State private var activeItem: Habit?
    @State private var pressingItemID: Habit.ID?
    @State private var dragOffset: CGSize = .zero
    @State private var fingerLocation: CGPoint = .zero
    @State private var touchOffset: CGSize = .zero
    @State private var frames: [Habit.ID: CGRect] = [:]
    @State private var initialFrame: CGRect = .zero
    

    init() {}

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: isReordering ? 18 : 12) {
                    CustomHomeHeader(showsPremiumAccent: purchaseService.premiumStatus == .premium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    if let premiumInsightsSummary {
                        Button {
                            openGlobalInsights()
                        } label: {
                            PremiumInsightsStripView(summary: premiumInsightsSummary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 4)
                    }

                    ForEach(habits) { habit in
                        DraggableHabitRow(
                            habit: habit,
                            isDragging: activeItem?.id == habit.id,
                            isPressing: pressingItemID == habit.id && activeItem == nil,
                            isReordering: isReordering,
                            trailingAccessory: AnyView(reorderHandle(for: habit))
                        )
                        .opacity(activeItem?.id == habit.id ? 0 : (isReordering ? 0.96 : 1))
                        .padding(.vertical, isReordering ? 2 : 0)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        frames[habit.id] = geo.frame(in: .named("container"))
                                    }
                                    .onChange(of: geo.frame(in: .named("container"))) { _, newFrame in
                                        frames[habit.id] = newFrame
                                    }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                requestDeletion(of: habit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }

                    if habitLimitPolicy.showsUpgradeHint {
                        UpgradeHintRow()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                    }

                    if habitLimitPolicy.showsLockedSlot {
                        lockedHabitSlot
                            .padding(.horizontal, 16)
                    }

                    if habits.isEmpty {
                        EmptyState()
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isReordering)
            }
            .coordinateSpace(name: "container")
            .overlay {
                ZStack {
                    Color.black.opacity(activeItem != nil ? 0.03 : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    if let activeItem,
                       let frame = frames[activeItem.id] {
                        DraggableHabitRow(
                            habit: activeItem,
                            isDragging: true,
                            isPressing: false,
                            isReordering: isReordering,
                            trailingAccessory: AnyView(reorderHandle(for: activeItem))
                        )
                            .frame(width: frame.width, height: frame.height)
                            .position(
                                x: fingerLocation.x - touchOffset.width,
                                y: fingerLocation.y - touchOffset.height
                            )
                            .zIndex(1000)
                    }
                }
            }
            .scrollDisabled(activeItem != nil)
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
            .contentMargins(.top, 12, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if !isReordering {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            isReordering.toggle()
                        }
                    } label: {
                        Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isReordering ? Color.systemAccent : Color.secondary)
                            .frame(width: 36, height: 36)
                            .background {
                                if isReordering {
                                    Circle()
                                        .fill(Color.systemAccent.opacity(0.12))
                                }
                            }
                    }
                    .accessibilityLabel(isReordering ? "Done reordering" : "Reorder habits")
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
    }

    private func reorderHabit(from source: Int, to destination: Int) {
        guard source != destination else { return }

        var reordered = habits
        reordered.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: destination
        )

        let didChange = reordered.enumerated().contains { index, habit in
            habit.orderIndex != index
        }
        guard didChange else { return }

        _ = HabitListMutation.applyOrderIndexesInMemory(to: reordered)

        scheduleReorderPersistence()
    }

    private func reorderGesture(for habit: Habit) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("container")))
            .onChanged { value in
                switch value {
                case .first(true):
                    if activeItem == nil {
                        pressingItemID = habit.id
                    }
                    break

                case .second(true, let drag?):
                    if activeItem == nil {
                        guard let frame = frames[habit.id] else { return }
                        fingerLocation = drag.location
                        activeItem = habit
                        pressingItemID = nil
                        initialFrame = frame
                        touchOffset = CGSize(
                            width: drag.startLocation.x - frame.midX,
                            height: drag.startLocation.y - frame.midY
                        )
                        dragOffset = .zero
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }

                    guard activeItem?.id == habit.id else { return }
                    fingerLocation = drag.location
                    dragOffset = drag.translation
                    handleReorder(translation: drag.translation)

                default:
                    break
                }
            }
            .onEnded { _ in
                if activeItem != nil {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    activeItem = nil
                    pressingItemID = nil
                    dragOffset = .zero
                    fingerLocation = .zero
                    touchOffset = .zero
                }
            }
    }

    @ViewBuilder
    private func reorderHandle(for habit: Habit) -> some View {
        let accent = Color(hex: habit.colorHex)
        let isPressed = pressingItemID == habit.id && activeItem == nil
        let isDraggingThisItem = activeItem?.id == habit.id

        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill).opacity(0.7))
            .overlay {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDraggingThisItem ? accent : accent.opacity(0.6))
            }
            .frame(width: 40, height: 40)
            .frame(width: 44, height: 44)
            .scaleEffect(isPressed ? 0.96 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .gesture(reorderGesture(for: habit))
            .animation(.spring(response: 0.2, dampingFraction: 0.78), value: isPressed)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: isDraggingThisItem)
            .accessibilityLabel("Reorder \(habit.name)")
    }

    private func handleReorder(translation: CGSize) {
        guard let activeItem,
              frames[activeItem.id] != nil else { return }

        let locationY = initialFrame.midY + translation.height

        guard let currentIndex = habits.firstIndex(where: { $0.id == activeItem.id }) else {
            return
        }

        for (index, habit) in habits.enumerated() {
            guard habit.id != activeItem.id,
                  let frame = frames[habit.id] else { continue }

            if locationY > frame.midY && index > currentIndex {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                    reorderHabit(from: currentIndex, to: index + 1)
                }
                return
            }

            if locationY < frame.midY && index < currentIndex {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                    reorderHabit(from: currentIndex, to: index)
                }
                return
            }
        }
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

private struct DraggableHabitRow: View {
    let habit: Habit
    let isDragging: Bool
    let isPressing: Bool
    let isReordering: Bool
    let trailingAccessory: AnyView?

    var body: some View {
        HabitCard(
            habit: habit,
            isReordering: isReordering,
            trailingAccessory: trailingAccessory
        )
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressing ? 0.98 : (isDragging ? 1.038 : (isReordering ? 0.995 : 1.0)))
            .shadow(
                color: .black.opacity(isDragging ? 0.2 : 0.06),
                radius: isDragging ? 20 : 6,
                y: isDragging ? 10 : 2
            )
            .zIndex(isDragging ? 1 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: isDragging)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
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
