//
//  HabitsListView.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI
import SwiftData
import UIKit

private enum TodayIntroDisclosureState {
    private static let key = "today.intro.isExpanded"

    static func isExpanded(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    static func setExpanded(_ isExpanded: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isExpanded, forKey: key)
    }
}

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

private enum TodayLayoutSpacing {
    static let growthPlanBottomInternal: CGFloat = 2
}

struct HabitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var habitLogService: HabitLogService
    @EnvironmentObject private var uiStateStore: HabitUIStateStore
    @Query(sort: \Habit.orderIndex) private var habits: [Habit]
    @ObservedObject private var appTime = AppTime.shared

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
    @State private var rhythmData: [HourValue] = []
    @State private var selectedInsightHabitID: Habit.ID?
    @State private var todayInsight: TodayInsight?
    @State private var globalInsightsSnapshot: GlobalInsightsSnapshot?
    @State private var coachingInsight: TodayCoachingInsight?
    @State private var isIntroExpanded: Bool = TodayIntroDisclosureState.isExpanded()
    @State private var pendingGlobalInsightsRefreshTask: Task<Void, Never>?
    @State private var todayInsightRequestSequence: UInt64 = 0
    @State private var globalInsightsRequestSequence: UInt64 = 0
    @State private var hasResolvedInitialTodayInsight: Bool = false
    @State private var hasResolvedInitialCoachingInsight: Bool = false
    @State private var didLogTodayHeaderFirstPaint: Bool = false
    @State private var didLogGrowthPlanInjection: Bool = false
    @State private var didLogCoachingInjection: Bool = false

    init() {}

    private var globalSemanticAccent: CadenceSemanticAccentTokens {
        CadenceTokens.Color.globalSemanticAccent(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                backgroundColor
                    .ignoresSafeArea()

                TopAmbientGradient()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea()

                listContent
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
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
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
                                .foregroundStyle(globalSemanticAccent.cadenceAccentPrimary)

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
                            .shadow(color: Color.black.opacity(0.11), radius: 12, y: 5)
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
            appTime.refreshIfNeeded()
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
            appTime.refreshIfNeeded()
            presentHabitDetailForDeepLinkIfNeeded()
        }
        .task(id: insightSelectionTaskKey) {
            await refreshTodayInsightSelection()
        }
        .task(id: rhythmTaskKey) {
            await refreshRhythmData()
        }
        .task(id: rhythmPrefetchTaskKey) {
            await prefetchRhythmDataForVisibleHabits()
        }
        .task(id: globalInsightsTaskKey) {
            scheduleGlobalInsightsSummaryRefresh()
        }
        .onDisappear {
            pendingGlobalInsightsRefreshTask?.cancel()
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

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                TodayHeaderContainer(
                    symbolName: greetingPresentation.symbolName,
                    greeting: greetingLine,
                    renderState: todayHeaderRenderState,
                    onToggle: toggleIntroExpansion
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, CadenceTokens.Space.xs)
                .onAppear(perform: markTodayHeaderFirstPaintIfNeeded)

                LazyVStack(spacing: cardToCardSpacing) {
                    ForEach(visibleHabits) { habit in
                        habitRow(for: habit)
                    }
                }
                .padding(.top, headerToFirstCardSpacing)

                if habitLimitPolicy.showsUpgradeHint {
                    UpgradeHintRow()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, CadenceTokens.Space.xs)
                }

                if habitLimitPolicy.showsLockedSlot {
                    lockedHabitSlot
                }

                if habits.isEmpty {
                    EmptyState()
                }
            }
            .padding(.horizontal, CadenceTokens.Space.lg)
            .padding(.top, CadenceTokens.Space.sm)
            .padding(.bottom, CadenceTokens.Space.x3l)
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
        let rowOpacity: Double = {
            if activeItem?.id == habit.id { return 0 }
            return isReordering ? 0.96 : 1.0
        }()

        DraggableHabitRow(
            habit: habit,
            isDragging: activeItem?.id == habit.id,
            isPressing: pressingItemID == habit.id && activeItem == nil,
            isReordering: isReordering,
            trailingAccessory: AnyView(reorderHandle(for: habit)),
            onTap: {
                selectedHabitID = habit.id
            }
        )
        .opacity(rowOpacity)
        .frame(maxWidth: .infinity)
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

    private var momentumHabit: Habit? {
        if let selectedInsightHabitID,
           let selected = visibleHabits.first(where: { $0.id == selectedInsightHabitID }) {
            return selected
        }

        return visibleHabits.first
    }

    private var greetingPresentation: TodayGreetingPresentation {
        let hour = calculationCalendar.component(.hour, from: appTime.now)

        switch hour {
        case 5..<12:
            return TodayGreetingPresentation(greeting: "Good morning.", symbolName: "sun.max.fill")
        case 12..<17:
            return TodayGreetingPresentation(greeting: "Good afternoon.", symbolName: "sun.and.horizon.fill")
        case 17..<22:
            return TodayGreetingPresentation(greeting: "Good evening.", symbolName: "moon.fill")
        default:
            return TodayGreetingPresentation(greeting: "Hello.", symbolName: "moon.stars.fill")
        }
    }

    private var greetingLine: String {
        greetingPresentation.greeting
    }

    private var rhythmTaskKey: String {
        guard let momentumHabit else { return "no-momentum-habit" }

        let projectionVersion = uiStateStore.projectionVersionByHabitID[momentumHabit.id] ?? 0
        let premiumFlag = purchaseService.premiumStatus == .premium ? "premium" : "free"
        return "\(momentumHabit.id.uuidString)-\(projectionVersion)-\(premiumFlag)"
    }

    private var rhythmPrefetchTaskKey: String {
        let premiumFlag = purchaseService.premiumStatus == .premium ? "premium" : "free"
        let keyParts = visibleHabits.map(\.id.uuidString)
        return "\(premiumFlag)|\(keyParts.joined(separator: "|"))"
    }

    private var insightSelectionTaskKey: String {
        let premiumFlag = purchaseService.premiumStatus == .premium ? "premium" : "free"
        let currentHour = calculationCalendar.component(.hour, from: appTime.now)
        let momentumProjectionVersion: UInt64 = {
            guard let momentumHabit else { return 0 }
            return uiStateStore.projectionVersionByHabitID[momentumHabit.id] ?? 0
        }()
        let parts = visibleHabits.map(\.id.uuidString)
        return "\(premiumFlag)-\(currentHour)-\(momentumProjectionVersion)-\(parts.joined(separator: "|"))"
    }

    private var globalInsightsTaskKey: String {
        let currentHour = calculationCalendar.component(.hour, from: appTime.now)
        let parts = habits.map(\.id.uuidString)
        return "\(currentHour)-\(parts.joined(separator: "|"))"
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

    private func refreshRhythmData() async {
        guard let momentumHabit else {
            rhythmData = []
            return
        }

        guard purchaseService.premiumStatus != .unknown else {
            return
        }

        let values = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: momentumHabit,
            globalLogs: [],
            isPremium: purchaseService.premiumStatus == .premium,
            now: .now,
            calendar: calculationCalendar
        )

        guard !Task.isCancelled else { return }
        rhythmData = values
    }

    private func refreshTodayInsightSelection() async {
        guard !visibleHabits.isEmpty else {
            todayInsight = nil
            selectedInsightHabitID = nil
            hasResolvedInitialTodayInsight = true
            return
        }

        let isPremium = purchaseService.premiumStatus == .premium
        let now = appTime.now
        await habitLogService.ensureComputedStates(
            for: visibleHabits.map(\.id),
            referenceDate: now
        )
        let requestSequence = todayInsightRequestSequence + 1
        todayInsightRequestSequence = requestSequence

        let insight = await computeTodayInsightSelection(
            habits: visibleHabits,
            isPremium: isPremium,
            now: now,
            calendar: calculationCalendar
        )

        guard !Task.isCancelled, todayInsightRequestSequence == requestSequence else { return }
        todayInsight = insight
        selectedInsightHabitID = insight?.habit.id
        if hasResolvedInitialTodayInsight == false {
            hasResolvedInitialTodayInsight = true
        }
        if didLogGrowthPlanInjection == false, insight != nil {
            logTodayHeaderPhase("growth-plan.content-injection")
            didLogGrowthPlanInjection = true
        }
        logTodayTimingTrace()
    }

    private func refreshGlobalInsightsSummary() async {
        guard !habits.isEmpty else {
            globalInsightsSnapshot = nil
            coachingInsight = nil
            hasResolvedInitialCoachingInsight = true
            return
        }

        let requestSequence = globalInsightsRequestSequence + 1
        globalInsightsRequestSequence = requestSequence
        let now = appTime.now

        let snapshot = GlobalInsightsService(
            calendar: calculationCalendar,
            weekStartPreference: userSettings.weekStartPreference
        ).snapshot(for: habits, now: now)

        guard !Task.isCancelled, globalInsightsRequestSequence == requestSequence else { return }
        globalInsightsSnapshot = snapshot

        if let snapshot {
            coachingInsight = InsightSelectionService.shared.selectInsight(
                from: snapshot,
                now: appTime.now,
                calendar: calculationCalendar
            )
        } else {
            coachingInsight = nil
        }
        if hasResolvedInitialCoachingInsight == false {
            hasResolvedInitialCoachingInsight = true
        }
        if didLogCoachingInjection == false, coachingInsight != nil {
            logTodayHeaderPhase("greeting.content-injection")
            didLogCoachingInjection = true
        }
        logTodayTimingTrace()
    }

    private func scheduleGlobalInsightsSummaryRefresh() {
        pendingGlobalInsightsRefreshTask?.cancel()
        pendingGlobalInsightsRefreshTask = Task(priority: .background) {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await refreshGlobalInsightsSummary()
        }
    }

    private func computeTodayInsightSelection(
        habits: [Habit],
        isPremium: Bool,
        now: Date,
        calendar: Calendar
    ) async -> TodayInsight? {
        let today = calendar.startOfDay(for: now)
        let candidates: [TodayInsightCandidate] = habits.map { habit in
            let computedState = habitLogService.resolvedComputedStateForDisplay(
                habit: habit,
                referenceDate: now,
                weekStartPreference: userSettings.weekStartPreference
            )
            StateConsistencyTraceLogger.log(
                surface: "Today",
                habitID: habit.id,
                state: computedState
            )
            let projectedToday = uiStateStore.projectedDayState(
                habitID: habit.id,
                day: today,
                calendar: calendar
            )

            return TodayInsightCandidate(
                habit: habit,
                computedState: computedState,
                rhythm: TimeOfDayPerformanceService.shared.cachedRhythm(for: habit, isPremium: isPremium),
                isCompletedToday: projectedToday?.isComplete ?? false,
                lastCompletedDate: TimeOfDayPerformanceService.shared.cachedLastCompletedDate(
                    for: habit,
                    isPremium: isPremium
                ),
                streak: computedState.streakState.currentStreak
            )
        }

        return TodayInsightSelectionService.shared.selectInsight(
            from: candidates,
            now: now,
            calendar: calendar
        )
    }

    private func prefetchRhythmDataForVisibleHabits() async {
        guard purchaseService.premiumStatus != .unknown else { return }

        let isPremium = purchaseService.premiumStatus == .premium
        for habit in visibleHabits {
            guard !Task.isCancelled else { return }
            _ = await TimeOfDayPerformanceService.shared.hourlyValues(
                for: habit,
                globalLogs: [],
                isPremium: isPremium,
                now: .now,
                calendar: calculationCalendar
            )
        }

        guard !Task.isCancelled else { return }
        await refreshTodayInsightSelection()
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

    private var visibleHabits: [Habit] {
        habits
    }

    private var cardToCardSpacing: CGFloat {
        isReordering ? CadenceTokens.Space.xl : CadenceTokens.Space.md
    }

    private var headerToFirstCardSpacing: CGFloat {
        max(0, cardToCardSpacing - TodayLayoutSpacing.growthPlanBottomInternal)
    }

    private var todayHeaderRenderState: TodayHeaderRenderState {
        TodayHeaderRenderState(
            hasVisibleHabits: !visibleHabits.isEmpty,
            isIntroExpanded: isIntroExpanded,
            hasResolvedInitialCoachingInsight: hasResolvedInitialCoachingInsight,
            hasResolvedInitialTodayInsight: hasResolvedInitialTodayInsight,
            coachingParagraph: coachingParagraph,
            growthPlanLines: growthPlanLines
        )
    }

    private var growthPlanLines: [AttributedString] {
        guard let todayInsight else {
            return []
        }

        var lines: [String] = [
            bestTimeSummary(from: todayInsight.message) ?? todayInsight.message
        ]

        if let atRiskMessage = growthPlanAtRiskMessage {
            lines.append(atRiskMessage)
        }

        let sentenceBullets = lines.flatMap(splitGrowthPlanSentences(from:))

        return sentenceBullets.map { message in
            var line = AttributedString(message)
            line.foregroundColor = CadenceTokens.Color.Text.secondary.opacity(0.92)

            guard let momentumHabit,
                  !rhythmData.isEmpty else {
                return line
            }

            let semanticAccent = CadenceTokens.Color.semanticAccent(
                for: momentumHabit,
                colorScheme: colorScheme
            )
            if let highlight = todayInsightHighlightToken(for: todayInsight),
               let range = line.range(of: highlight) {
                line[range].foregroundColor = semanticAccent.cadenceAccentPrimary
            }
            return line
        }
        .prefix(TodayHeaderRenderState.growthPlanLineCount)
        .map { $0 }
    }

    private func splitGrowthPlanSentences(from message: String) -> [String] {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }

        let pattern = "(?<=[.!?])\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [trimmed]
        }

        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let matches = regex.matches(in: trimmed, options: [], range: nsRange)
        guard matches.isEmpty == false else { return [trimmed] }

        var bullets: [String] = []
        var start = trimmed.startIndex

        for match in matches {
            guard let range = Range(match.range, in: trimmed) else { continue }
            let sentence = trimmed[start..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.isEmpty == false {
                bullets.append(sentence)
            }
            start = range.upperBound
        }

        let trailing = trimmed[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        if trailing.isEmpty == false {
            bullets.append(trailing)
        }

        return bullets.isEmpty ? [trimmed] : bullets
    }

    private func bestTimeSummary(from message: String) -> String? {
        let prefixes = [
            "Best time for ",
            "Best time tomorrow for ",
            "Strongest window for ",
            "Strongest window tomorrow for "
        ]

        for prefix in prefixes {
            guard message.hasPrefix(prefix),
                  let separatorIndex = message.lastIndex(of: ":") else {
                continue
            }

            let timeStart = message.index(after: separatorIndex)
            let time = message[timeStart...].trimmingCharacters(in: .whitespaces)
            if prefix == "Best time tomorrow for " || prefix == "Strongest window tomorrow for " {
                return "Best time tomorrow: \(time)"
            }
            return "Best time: \(time)"
        }

        return nil
    }

    private var growthPlanAtRiskMessage: String? {
        guard let atRiskCount = globalInsightsSnapshot?.metrics.atRiskCount,
              atRiskCount > 0 else {
            return nil
        }

        if atRiskCount == 1 {
            return "1 habit is ready for a quick check-in today."
        }
        if atRiskCount == 2 {
            return "2 habits are ready to keep your streak going."
        }
        return "A couple of habits are ready when you are."
    }

    private func todayInsightHighlightToken(for insight: TodayInsight) -> String? {
        switch insight.type {
        case .strongestWindow:
            return insight.habit.name
        case .dipRisk:
            return insight.habit.name
        case .nearPeakWindow:
            return insight.habit.name
        case .reinforcement, .fallback:
            return nil
        }
    }

    private func toggleIntroExpansion() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.22)) {
            isIntroExpanded.toggle()
        }
        TodayIntroDisclosureState.setExpanded(isIntroExpanded)
    }

    private var coachingParagraph: AttributedString? {
        guard let coachingInsight else {
            return nil
        }

        var message = AttributedString(coachingInsight.message)
        message.foregroundColor = CadenceTokens.Color.Text.primary

        if let highlightedText = coachingInsight.primaryHighlight,
           let range = message.range(of: highlightedText) {
            message[range].foregroundColor = globalSemanticAccent.cadenceAccentPrimary
            message[range].font = CadenceTokens.Typography.body.weight(.semibold)
        }

        if let highlightedText = coachingInsight.secondaryHighlight,
           let range = message.range(of: highlightedText) {
            message[range].foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)
            message[range].font = CadenceTokens.Typography.body.weight(.medium)
        }

        return message
    }

    private func logTodayTimingTrace() {
        #if DEBUG
        guard TimeInsightTraceLogger.isEnabled else { return }
        guard let snapshot = globalInsightsSnapshot else { return }
        let enginePeak = snapshot.introSummary.peakHour
        let todayMatch = snapshot.introSummary.typicalLoggingTime == humanTime(for: enginePeak)
        TimeInsightTraceLogger.logConsistency(
            surface: "Today",
            enginePeak: enginePeak,
            consumerHour: enginePeak
        )
        let growthConsumerHour = todayInsight?.habit.id == nil ? -1 : enginePeak
        TimeInsightTraceLogger.logConsistency(
            surface: "Growth Plan",
            enginePeak: enginePeak,
            consumerHour: growthConsumerHour
        )
        assert(todayMatch, "today screen displayed time must equal global engine peakHour")
        #endif
    }

    private func markTodayHeaderFirstPaintIfNeeded() {
        guard didLogTodayHeaderFirstPaint == false else { return }
        didLogTodayHeaderFirstPaint = true
        logTodayHeaderPhase("header-shell.first-paint")
    }

    private func logTodayHeaderPhase(_ phase: String) {
        #if DEBUG
        guard TimeInsightTraceLogger.isEnabled else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[TodayHeader PHASE]")
        print("phase: \(phase)")
        print("timestamp: \(timestamp)")
        #endif
    }

    private var backgroundColor: Color {
        colorScheme == .light
            ? Color(white: 0.96)
            : Color(white: 0.04)
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

}

private struct DraggableHabitRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let habit: Habit
    let isDragging: Bool
    let isPressing: Bool
    let isReordering: Bool
    let trailingAccessory: AnyView?
    let onTap: (() -> Void)?

    var body: some View {
        HabitCard(
            habit: habit,
            isReordering: isReordering,
            trailingAccessory: trailingAccessory,
            onTap: onTap
        )
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressing ? 0.98 : (isDragging ? 1.038 : (isReordering ? 0.995 : 1.0)))
            .zIndex(isDragging ? 1 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: isDragging)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
    }
}

private struct TodayGreetingPresentation {
    let greeting: String
    let symbolName: String
}

struct TodayHeaderRenderState {
    static let greetingLineLimit = 3
    static let growthPlanLineCount = 3
    static let growthPlanLineLimitPerBullet = 2
    static let growthPlanReservedLineCount = 2
    private static let growthPlanRowSpacing: CGFloat = 2
    private static let growthPlanFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    static let growthPlanMinHeight =
        (growthPlanFont.lineHeight * CGFloat(growthPlanReservedLineCount)) +
        (growthPlanRowSpacing * CGFloat(growthPlanReservedLineCount - 1))
    static let fallbackGreetingMessage = "You're building a steady rhythm, and a quick check-in keeps things moving."
    static let greetingPlaceholderMessage = "Cadence insight loading.\nCadence insight loading.\nCadence insight loading."
    static let fallbackGrowthPlanMessage = "A quick check-in today keeps your momentum steady."

    let hasVisibleHabits: Bool
    let isIntroExpanded: Bool
    let hasResolvedInitialCoachingInsight: Bool
    let hasResolvedInitialTodayInsight: Bool
    let coachingParagraph: AttributedString?
    let growthPlanLines: [AttributedString]

    var showsGreetingBlock: Bool {
        hasVisibleHabits && isIntroExpanded
    }

    var showsGreetingPlaceholder: Bool {
        showsGreetingBlock && hasResolvedInitialCoachingInsight == false
    }

    var resolvedGreetingParagraph: AttributedString {
        if let coachingParagraph {
            return coachingParagraph
        }
        return AttributedString(Self.fallbackGreetingMessage)
    }

    var greetingHeightTemplate: String {
        Array(repeating: "Cadence rhythm template.", count: Self.greetingLineLimit).joined(separator: "\n")
    }

    var resolvedGrowthPlanLines: [AttributedString] {
        let clipped = Array(growthPlanLines.prefix(Self.growthPlanLineCount))
        if clipped.isEmpty {
            var fallback = AttributedString(Self.fallbackGrowthPlanMessage)
            fallback.foregroundColor = CadenceTokens.Color.Text.secondary.opacity(0.92)
            return [fallback]
        }
        return clipped
    }

    var showsGrowthPlanPlaceholder: Bool {
        hasVisibleHabits && hasResolvedInitialTodayInsight == false
    }

    var growthPlanPlaceholderLines: [AttributedString] {
        var firstLine = AttributedString("Best time for today")
        firstLine.foregroundColor = CadenceTokens.Color.Text.secondary.opacity(0.92)
        var secondLine = AttributedString("One habit is ready for a check-in")
        secondLine.foregroundColor = CadenceTokens.Color.Text.secondary.opacity(0.92)
        var thirdLine = AttributedString("Keep your strongest window available this afternoon")
        thirdLine.foregroundColor = CadenceTokens.Color.Text.secondary.opacity(0.92)
        return [firstLine, secondLine, thirdLine]
    }
}

private struct TodayHeaderContainer: View {
    let symbolName: String
    let greeting: String
    let renderState: TodayHeaderRenderState
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TodayIntroBlock(
                symbolName: symbolName,
                greeting: greeting,
                renderState: renderState,
                onToggle: onToggle
            )
            .padding(.bottom, renderState.isIntroExpanded ? 12 : 8)

            if renderState.hasVisibleHabits {
                Text("Growth Plan")
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.bottom, CadenceTokens.Space.xs)
                    .accessibilityAddTraits(.isHeader)

                GrowthPlanBlock(renderState: renderState)
                    .padding(.bottom, TodayLayoutSpacing.growthPlanBottomInternal)
            }
        }
    }
}

private struct TodayIntroBlock: View {
    let symbolName: String
    let greeting: String
    let renderState: TodayHeaderRenderState
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: renderState.showsGreetingBlock ? 4 : 0) {
            HStack(alignment: .firstTextBaseline, spacing: CadenceTokens.Space.sm) {
                HStack(alignment: .firstTextBaseline, spacing: CadenceTokens.Space.sm) {
                    Image(systemName: symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CadenceTokens.Color.accent(from: HabitColor.default.hex).secondary)

                    Text(greeting)
                        .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                        .foregroundStyle(CadenceTokens.Color.Text.primary.opacity(0.8))
                }

                Spacer(minLength: CadenceTokens.Space.sm)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.easeInOut(duration: 0.22), value: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(greeting)
            .accessibilityValue(isExpanded ? "Insights expanded" : "Insights collapsed")
            .accessibilityHint("Double-tap to toggle insights")
            .accessibilityAddTraits(.isButton)

            if renderState.showsGreetingBlock {
                ZStack(alignment: .topLeading) {
                    Text(renderState.greetingHeightTemplate)
                        .font(CadenceTokens.Typography.body.weight(.medium))
                        .lineSpacing(1)
                        .lineLimit(TodayHeaderRenderState.greetingLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(0)
                        .accessibilityHidden(true)

                    Text(renderState.resolvedGreetingParagraph)
                        .font(CadenceTokens.Typography.body.weight(.medium))
                        .foregroundStyle(CadenceTokens.Color.Text.primary)
                        .lineSpacing(1)
                        .lineLimit(TodayHeaderRenderState.greetingLineLimit)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(renderState.showsGreetingPlaceholder ? 0 : 1)

                    Text(TodayHeaderRenderState.greetingPlaceholderMessage)
                        .font(CadenceTokens.Typography.body.weight(.medium))
                        .foregroundStyle(CadenceTokens.Color.Text.primary)
                        .lineSpacing(1)
                        .lineLimit(TodayHeaderRenderState.greetingLineLimit)
                        .redacted(reason: .placeholder)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(renderState.showsGreetingPlaceholder ? 1 : 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .clipped()
                .animation(AppMotion.quickFade, value: renderState.showsGreetingPlaceholder)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: renderState.isIntroExpanded)
    }

    private var isExpanded: Bool {
        renderState.isIntroExpanded
    }
}

private struct GrowthPlanBlock: View {
    let renderState: TodayHeaderRenderState

    var body: some View {
        ZStack(alignment: .topLeading) {
            GrowthPlanLineList(lines: renderState.resolvedGrowthPlanLines)
                .opacity(renderState.showsGrowthPlanPlaceholder ? 0 : 1)

            GrowthPlanLineList(lines: renderState.growthPlanPlaceholderLines)
                .redacted(reason: .placeholder)
                .opacity(renderState.showsGrowthPlanPlaceholder ? 1 : 0)
        }
        .frame(minHeight: TodayHeaderRenderState.growthPlanMinHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(AppMotion.quickFade, value: renderState.showsGrowthPlanPlaceholder)
    }
}

private struct GrowthPlanLineList: View {
    let lines: [AttributedString]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.prefix(TodayHeaderRenderState.growthPlanLineCount).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                        .font(CadenceTokens.Typography.body)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.9))

                    Text(line)
                        .font(CadenceTokens.Typography.body)
                        .lineLimit(TodayHeaderRenderState.growthPlanLineLimitPerBullet)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
