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

    var id: String {
        switch self {
        case .addHabit:
            return "addHabit"
        case .paywall(let feature):
            return "paywall-\(String(describing: feature))"
        }
    }
}

private struct StackConnectorSegment: Identifiable {
    let firstHabitID: UUID
    let lastHabitID: UUID
    let rootHabitID: UUID
    let rootColorHex: String

    var id: String {
        "\(firstHabitID.uuidString)-\(lastHabitID.uuidString)"
    }
}

struct HabitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var habitLogService: HabitLogService
    @Query(sort: \Habit.orderIndex) private var habits: [Habit]

    @State private var activeSheet: ActiveSheet?
    @State private var selectedHabitID: Habit.ID?
    @State private var habitPendingDeletion: Habit?
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
    @State private var isFABPressed: Bool = false
    @State private var flowNudgeHabitID: UUID?
    @State private var clearFlowNudgeTask: Task<Void, Never>?
    @State private var emphasizedStackRootID: UUID?
    @State private var clearEmphasisTask: Task<Void, Never>?
    private let cardLeading: CGFloat = HabitRowGrid.cardLeadingInList
    private let cardTrailing: CGFloat = HabitRowGrid.cardTrailingInList
    private var spineX: CGFloat { HabitRowGrid.spineXInList }

    init() {}

    var body: some View {
        NavigationStack {
            listContent
                .cadenceSurface(
                    accent: activeSurfaceAccent,
                    accentKey: activeSurfaceAccentKey,
                    motionEnabled: userSettings.ambientSurfaceMotionEnabled
                )
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
                            .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                            .foregroundStyle(
                                isReordering
                                    ? CadenceTokens.Color.accent(from: HabitColor.default.hex).primary
                                    : CadenceTokens.Color.Text.secondary
                            )
                            .frame(width: 34, height: 34)
                            .padding(.horizontal, 4)
                            .cadenceControlChrome()
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel(isReordering ? "Done reordering" : "Reorder habits")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        openGlobalInsights()
                    } label: {
                        HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                                    .foregroundStyle(CadenceTokens.Color.accent(from: HabitColor.default.hex).primary)

                            if purchaseService.premiumStatus == .free {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            }
                        }
                        .frame(height: 34)
                        .padding(.horizontal, 10)
                        .cadenceControlChrome()
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel("Global Insights")

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .padding(.horizontal, 4)
                            .cadenceControlChrome()
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel("Settings")
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        withAnimation(.easeOut(duration: 0.08)) {
                            isFABPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            withAnimation(.easeOut(duration: 0.12)) {
                                isFABPressed = false
                            }
                        }
                        addHabit()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 27, weight: .medium))
                            .foregroundStyle(CadenceTokens.Color.Text.primary)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(CadenceTokens.Color.Background.primary)
                            )
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.14), radius: 14, y: 6)
                            .scaleEffect(isFABPressed ? 0.96 : 1)
                            .animation(.easeOut(duration: 0.12), value: isFABPressed)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add habit")

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
            clearFlowNudgeTask?.cancel()
            clearFlowNudgeTask = nil
            clearEmphasisTask?.cancel()
            clearEmphasisTask = nil
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

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: isReordering ? 20 : 12) {
                CustomHomeHeader(showsPremiumAccent: purchaseService.premiumStatus == .premium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, CadenceTokens.Space.xl)
                    .padding(.top, CadenceTokens.Space.sm)
                    .padding(.bottom, CadenceTokens.Space.sm)

                if let premiumInsightsSummary {
                    Button {
                        openGlobalInsights()
                    } label: {
                        PremiumInsightsStripView(summary: premiumInsightsSummary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }

                ForEach(visibleHabits) { habit in
                    habitRow(for: habit)
                }

                if habitLimitPolicy.showsUpgradeHint {
                    UpgradeHintRow()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }

                if habitLimitPolicy.showsLockedSlot {
                    lockedHabitSlot
                }

                if habits.isEmpty {
                    EmptyState()
                }
            }
            .padding(.leading, cardLeading)
            .padding(.trailing, cardTrailing)
            .padding(.top, CadenceTokens.Space.sm)
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
                    let activeViewModel = stackSnapshot.habitViewModelByID[activeItem.id]
                    DraggableHabitRow(
                        habit: activeItem,
                        isDragging: true,
                        isPressing: false,
                        isReordering: isReordering,
                        isStacked: activeViewModel?.isStacked ?? false,
                        relationText: nil,
                        flowRootColorHex: nil,
                        shouldNudgeFlow: false,
                        onFrequencyCompletion: nil,
                        trailingAccessory: AnyView(reorderHandle(for: activeItem)),
                        onTap: nil
                    )
                        .frame(width: frame.width, height: frame.height)
                        .position(
                            x: fingerLocation.x - touchOffset.width,
                            y: fingerLocation.y - touchOffset.height
                        )
                        .zIndex(1000)
                }

                if !isReordering {
                    StackConnectorOverlay(
                        segments: stackConnectorSegments,
                        frames: frames,
                        spineX: spineX,
                        pulseChildID: flowNudgeHabitID,
                        emphasizedRootID: emphasizedStackRootID,
                        parentByChildID: stackSnapshot.parentByChildID,
                        rootColorHexByHabitID: stackSnapshot.stackColorHexByHabitID
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .scrollDisabled(activeItem != nil)
        .navigationDestination(isPresented: $showGlobalInsights) {
               GlobalInsightsView()
           }
        .navigationDestination(isPresented: isHabitDetailPresentedBinding) {
            if let selectedHabit = selectedHabitForDetail {
                HabitDetailSheet(
                    habit: selectedHabit,
                    initialCalendar: calculationCalendar
                ) {
                    self.selectedHabitID = nil
                }
            }
        }
    }

    @ViewBuilder
    private func habitRow(for habit: Habit) -> some View {
        let habitViewModel = stackSnapshot.habitViewModelByID[habit.id]
        let isStacked = habitViewModel?.isStacked ?? false
        let isStackChild =
            isStacked &&
            habitViewModel?.stackRootID != habit.id
        let rowOpacity: Double = {
            if activeItem?.id == habit.id { return 0 }
            let baseOpacity = isReordering ? 0.96 : 1.0
            let hierarchyOpacity = (!isReordering && isStackChild) ? 0.96 : 1.0
            return baseOpacity * hierarchyOpacity
        }()

        DraggableHabitRow(
            habit: habit,
            isDragging: activeItem?.id == habit.id,
            isPressing: pressingItemID == habit.id && activeItem == nil,
            isReordering: isReordering,
            isStacked: habitViewModel?.isStacked ?? false,
            relationText: habitViewModel?.relationText,
            flowRootColorHex: habitViewModel?.stackColorHex,
            shouldNudgeFlow: flowNudgeHabitID == habit.id,
            onFrequencyCompletion: handleFrequencyCompletion,
            trailingAccessory: AnyView(reorderHandle(for: habit)),
            onTap: {
                if let viewModel = habitViewModel,
                   viewModel.isStacked,
                   let rootID = viewModel.stackRootID {
                    emphasizeStackConnector(rootID: rootID)
                }
                selectedHabitID = habit.id
            }
        )
        .opacity(rowOpacity)
        .frame(maxWidth: .infinity)
        .padding(.vertical, isReordering ? 2 : 0)
        .padding(.bottom, isReordering ? 0 : ((habitViewModel?.hasAdjacentChild ?? false) ? -6 : 0))
        .animation(.easeOut(duration: 0.2), value: isStacked)
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

    private var headerAccentColor: Color {
        if let firstHabit = firstVisibleHabitForAmbient {
            return CadenceTokens.Color.accent(for: firstHabit).primary
        }
        return .systemAccent
    }

    private var headerAccentKey: String {
        firstVisibleHabitForAmbient?.colorHex ?? "system-accent"
    }

    private var firstVisibleHabitForAmbient: Habit? {
        visibleHabits.first
    }

    private var activeSurfaceAccent: Color {
        showsHomeAmbientSurface ? headerAccentColor : .clear
    }

    private var activeSurfaceAccentKey: String {
        showsHomeAmbientSurface ? headerAccentKey : "home-ambient-hidden"
    }

    private var showsHomeAmbientSurface: Bool {
        selectedHabitID == nil && !showGlobalInsights
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
        let isPressed = pressingItemID == habit.id && activeItem == nil
        let isDraggingThisItem = activeItem?.id == habit.id

        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(CadenceTokens.Color.Background.tertiary)
            .overlay {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        isDraggingThisItem
                            ? CadenceTokens.Color.accent(for: habit).primary
                            : CadenceTokens.Color.accent(for: habit).secondary
                    )
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

    private var isHabitDetailPresentedBinding: Binding<Bool> {
        Binding(
            get: { selectedHabitID != nil && selectedHabitForDetail != nil },
            set: { isPresented in
                if !isPresented {
                    selectedHabitID = nil
                }
            }
        )
    }

    private var selectedHabitForDetail: Habit? {
        guard let selectedHabitID else { return nil }
        return habits.first(where: { $0.id == selectedHabitID })
    }

    private var stackSnapshot: HabitStackingSnapshot {
        HabitStackingOrder.resolve(baseHabits: habits)
    }

    private var visibleHabits: [Habit] {
        isReordering ? habits : stackSnapshot.displayHabits
    }

    private var stackConnectorSegments: [StackConnectorSegment] {
        guard !isReordering else { return [] }

        var segments: [StackConnectorSegment] = []
        segments.reserveCapacity(stackSnapshot.todayItems.count)

        for item in stackSnapshot.todayItems {
            guard case .stack(let stack) = item,
                  let firstHabit = stack.orderedHabits.first,
                  let lastHabit = stack.orderedHabits.last else { continue }
            segments.append(
                StackConnectorSegment(
                    firstHabitID: firstHabit.id,
                    lastHabitID: lastHabit.id,
                    rootHabitID: stack.rootHabit.id,
                    rootColorHex: stack.stackColorHex
                )
            )
        }

        return segments
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
        guard habits.contains(where: { $0.id == deepLinkedHabitID }) else { return }

        selectedHabitID = deepLinkedHabitID

        DispatchQueue.main.async {
            deepLinkManager.clearSelectedHabit(deepLinkedHabitID)
        }
    }

    private func handleFrequencyCompletion(_ habit: Habit) {
        guard !isReordering else { return }

        let currentDay = CurrentDayResolver.currentDay(calendar: calculationCalendar)
        guard let children = stackSnapshot.childrenByParentID[habit.id], !children.isEmpty else { return }

        let nextChild = children.first { child in
            !child.isComplete(
                for: currentDay,
                calendar: calculationCalendar,
                weekStartPreference: userSettings.weekStartPreference
            )
        } ?? children.first

        guard let nextChild else { return }
        flowNudgeHabitID = nextChild.id

        clearFlowNudgeTask?.cancel()
        clearFlowNudgeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            if flowNudgeHabitID == nextChild.id {
                flowNudgeHabitID = nil
            }
        }
    }

    private func emphasizeStackConnector(rootID: UUID) {
        emphasizedStackRootID = rootID
        clearEmphasisTask?.cancel()
        clearEmphasisTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            if emphasizedStackRootID == rootID {
                emphasizedStackRootID = nil
            }
        }
    }
}

private struct DraggableHabitRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let habit: Habit
    let isDragging: Bool
    let isPressing: Bool
    let isReordering: Bool
    let isStacked: Bool
    let relationText: String?
    let flowRootColorHex: String?
    let shouldNudgeFlow: Bool
    let onFrequencyCompletion: ((Habit) -> Void)?
    let trailingAccessory: AnyView?
    let onTap: (() -> Void)?

    var body: some View {
        HabitCard(
            habit: habit,
            isReordering: isReordering,
            relationText: relationText,
            flowRootColorHex: flowRootColorHex,
            shouldNudgeFlow: shouldNudgeFlow,
            onFrequencyCompletion: onFrequencyCompletion,
            trailingAccessory: trailingAccessory,
            onTap: onTap
        )
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressing ? 0.98 : (isDragging ? 1.038 : (isReordering ? 0.995 : 1.0)))
            .shadow(
                color: .black.opacity(
                    isDragging
                        ? (colorScheme == .dark ? 0.14 : 0.2)
                        : (isStacked ? 0.18 : 0.28)
                ),
                radius: isDragging
                    ? (colorScheme == .dark ? 16 : 20)
                    : (isStacked ? 8 : 12),
                y: isDragging
                    ? (colorScheme == .dark ? 7 : 10)
                    : (isStacked ? 4 : 6)
            )
            .zIndex(isDragging ? 1 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: isDragging)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
    }
}

private struct StackConnectorOverlay: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let segments: [StackConnectorSegment]
    let frames: [UUID: CGRect]
    let spineX: CGFloat
    let pulseChildID: UUID?
    let emphasizedRootID: UUID?
    let parentByChildID: [UUID: UUID]
    let rootColorHexByHabitID: [UUID: String]

    private let edgeInset: CGFloat = 18

    private var lineWidth: CGFloat {
        1.5
    }

    private let capDiameter: CGFloat = 6

    var body: some View {
        let connectorX = resolvedConnectorX()

        ZStack {
            // MARK: - Main stack connectors
            ForEach(segments) { segment in
                if let firstFrame = frames[segment.firstHabitID],
                   let lastFrame = frames[segment.lastHabitID] {

                    let isEmphasized = emphasizedRootID == segment.rootHabitID

                    connector(
                        x: connectorX,
                        startY: firstFrame.minY + edgeInset - 6,
                        endY: lastFrame.maxY - edgeInset + 6,
                        color: CadenceTokens.Color.accent(from: segment.rootColorHex).primary,
                        lineWidth: lineWidth,
                        capDiameter: capDiameter,
                        opacity: isEmphasized ? 0.6 : 0.6,
                        glowOpacity: isEmphasized ? 0.08 : 0.08,
                        glowBlur: isEmphasized ? 10 : 8
                    )
                    .animation(.easeOut(duration: 0.2), value: emphasizedRootID)
                }
            }

            // MARK: - Pulse connector
            if let pulseChildID,
               let parentID = parentByChildID[pulseChildID],
               let childFrame = frames[pulseChildID],
               let parentFrame = frames[parentID] {

                let rootHex =
                    rootColorHexByHabitID[pulseChildID] ??
                    rootColorHexByHabitID[parentID] ??
                    ""

                let pulseColor = CadenceTokens.Color.accent(from: rootHex).primary

                connector(
                    x: connectorX,
                    startY: min(parentFrame.midY, childFrame.midY),
                    endY: max(parentFrame.midY, childFrame.midY),
                    color: pulseColor,
                    lineWidth: lineWidth + 0.2,
                    capDiameter: capDiameter + 0.4,
                    opacity: 0.6,
                    glowOpacity: 0.08,
                    glowBlur: 10
                )
                .animation(.easeOut(duration: 0.26), value: pulseChildID)
            }
        }
    }

    // MARK: - Stable X Anchor (correct gutter positioning)
    private func resolvedConnectorX() -> CGFloat {
        spineX
    }

    // MARK: - Connector
    @ViewBuilder
    private func connector(
        x: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        color: Color,
        lineWidth: CGFloat,
        capDiameter: CGFloat,
        opacity: Double,
        glowOpacity: Double,
        glowBlur: CGFloat
    ) -> some View {

        let height = max(0, endY - startY)
        let visualInset: CGFloat = 1.5
        let nodeOpacity = min(1, opacity * 0.85)
        let nodeScale: CGFloat = 0.95

        VStack(spacing: 0) {
            // Top cap
            Circle()
                .fill(color.opacity(nodeOpacity))
                .frame(width: capDiameter, height: capDiameter)
                .scaleEffect(nodeScale)
                .overlay {
                    Circle()
                        .fill(color.opacity(glowOpacity))
                        .frame(width: capDiameter + 2, height: capDiameter + 2)
                        .blur(radius: glowBlur * 0.5)
                }

            // Line
            Capsule(style: .continuous)
                .fill(color.opacity(opacity))
                .frame(width: lineWidth, height: max(0, height - visualInset))
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: lineWidth, height: height)
                        .blendMode(.plusLighter)
                }

            // Bottom cap
            Circle()
                .fill(color.opacity(nodeOpacity))
                .frame(width: capDiameter, height: capDiameter)
                .scaleEffect(nodeScale)
                .overlay {
                    Circle()
                        .fill(color.opacity(glowOpacity))
                        .frame(width: capDiameter + 2, height: capDiameter + 2)
                        .blur(radius: glowBlur * 0.5)
                }
        }
        .frame(width: max(lineWidth, capDiameter))
        .position(x: x, y: startY + (height / 2))
    }
}

private struct CustomHomeHeader: View {
    let showsPremiumAccent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
            CadenceProWordmark(
                size: .large,
                animateSwoosh: showsPremiumAccent,
                showsProLabel: showsPremiumAccent
            )
            .opacity(0.94)
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, CadenceTokens.Space.xs)
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
        HStack(alignment: .top, spacing: CadenceTokens.Space.sm) {
            Image(systemName: "sparkles")
                .font(CadenceTokens.Typography.microCopy)

            Text("Free accounts can track up to 3 habits. Upgrade to add unlimited habits.")
                .font(CadenceTokens.Typography.microCopy)
        }
        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.85))
        .padding(.vertical, CadenceTokens.Space.xs)
    }
}

private struct PremiumInsightsStripView: View {
    let summary: PremiumInsightsStripSummary
    private let accentColor = CadenceTokens.Color.accent(from: HabitColor.default.hex).primary

    var body: some View {
        HStack(alignment: .top, spacing: CadenceTokens.Space.md) {
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

            VStack(alignment: .leading, spacing: CadenceTokens.Space.xs + 1) {
                ProSwoosh(size: .small)

                Text(primaryLine)
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .lineLimit(1)

                secondaryLine
                    .font(CadenceTokens.Typography.body)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, CadenceTokens.Space.lg)
        .padding(.vertical, CadenceTokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
    }

    private var primaryLine: AttributedString {
        var label = AttributedString(summary.primaryLabel)
        label.foregroundColor = CadenceTokens.Color.Text.primary

        var value = AttributedString(summary.primaryValue)
        value.foregroundColor = accentColor

        return label + value
    }

    private var secondaryLine: Text {
        Text(secondaryAttributedLine)
    }

    private var secondaryAttributedLine: AttributedString {
        var line = AttributedString(summary.secondaryLabel)
        line.foregroundColor = CadenceTokens.Color.Text.secondary

        var value = AttributedString(summary.secondaryValue)
        value.foregroundColor = accentColor
        line += value

        if let secondarySuffix = summary.secondarySuffix {
            var separator = AttributedString(" · ")
            separator.foregroundColor = CadenceTokens.Color.Text.secondary
            line += separator

            var suffix = AttributedString(secondarySuffix)
            suffix.foregroundColor = CadenceTokens.Color.Text.secondary
            line += suffix
        }

        return line
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: CadenceTokens.Space.sm + 2) {
            Text("No habits yet")
                .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
            Text("Tap the plus button below to create one. Then tap today’s square to log.")
                .font(CadenceTokens.Typography.body)
                .foregroundStyle(CadenceTokens.Color.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CadenceTokens.Space.lg)
        .padding(.vertical, CadenceTokens.Space.lg)
        .frame(maxWidth: .infinity)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
    }
}

private struct LockedHabitSlotCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: CadenceTokens.Space.md + 2) {
            ZStack {
                RoundedRectangle(cornerRadius: CadenceTokens.Space.md)
                    .fill(CadenceTokens.Color.Background.tertiary)
                    .frame(width: 44, height: 44)

                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
            }

            VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                Text("Unlock unlimited habits")
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)

                Text("Unlock more space for the routines you want to keep.")
                    .font(CadenceTokens.Typography.body)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, CadenceTokens.Space.lg)
        .padding(.vertical, CadenceTokens.Space.lg)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
        .opacity(colorScheme == .light ? 0.82 : 0.6)
    }
}
