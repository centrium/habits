//
//  HabitsApp.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

enum RuntimeEnvironment {
    nonisolated static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

enum StartupProfiler {
    nonisolated static let launchStartTime = CFAbsoluteTimeGetCurrent()
    @MainActor private static var hasLoggedFirstInteractiveRender = false
    @MainActor private static var loggedMilestones: Set<String> = []

    @MainActor
    static func logFirstInteractiveRender() {
        guard !hasLoggedFirstInteractiveRender else { return }
        hasLoggedFirstInteractiveRender = true

        let elapsed = CFAbsoluteTimeGetCurrent() - launchStartTime
        print("Startup time to first interactive screen: \(elapsed)s")
        logStartupPhase("today_rendered")
    }

    @MainActor
    static func logStartupPhase(_ phase: String) {
        guard !loggedMilestones.contains(phase) else { return }
        loggedMilestones.insert(phase)
        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - launchStartTime) * 1000)
        print("STARTUP: \(phase) (\(elapsedMs) ms)")
    }
}

enum RootDestination: Equatable {
    case onboarding
    case habitsList
}

enum RootViewRouter {
    static func destination(hasCompletedOnboarding: Bool) -> RootDestination {
        hasCompletedOnboarding ? .habitsList : .onboarding
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var userSettings: UserSettings
    @State private var hasCompletedInitialWidgetSync = false
    @State private var hasActivatedHydratedData = false

    var body: some View {
        Group {
            switch RootViewRouter.destination(hasCompletedOnboarding: userSettings.hasCompletedOnboarding) {
            case .habitsList:
                HabitsListView(hasActivatedData: hasActivatedHydratedData)
                    .environmentObject(userSettings)
                    .environmentObject(deepLinkManager)
            case .onboarding:
                OnboardingView()
                    .environmentObject(userSettings)
                    .environmentObject(deepLinkManager)
            }
        }
        .onAppear {
            guard !RuntimeEnvironment.isRunningTests else { return }
            deepLinkManager.processPendingHabitIfNeeded()
            if hasActivatedHydratedData == false {
                DispatchQueue.main.async {
                    hasActivatedHydratedData = true
                }
            }
            Task { @MainActor in
                await Task.yield()
                StartupProfiler.logFirstInteractiveRender()
            }
            KeyboardWarmup.warmAfterInitialRenderIfNeeded()
            scheduleWidgetSync(delayNanoseconds: 200_000_000, marksInitialSync: true)
        }
        .onChange(of: deepLinkManager.pendingHabitID) { _, _ in
            guard !RuntimeEnvironment.isRunningTests else { return }
            deepLinkManager.processPendingHabitIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard !RuntimeEnvironment.isRunningTests else { return }
            guard phase == .active else { return }
            guard hasCompletedInitialWidgetSync else { return }
            scheduleWidgetSync(delayNanoseconds: 200_000_000, marksInitialSync: false)
        }
    }

    private func scheduleWidgetSync(
        delayNanoseconds: UInt64,
        marksInitialSync: Bool
    ) {
        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            let modelContainer = await MainActor.run { modelContext.container }
            _ = await WidgetDataSync.syncAsync(in: modelContainer)

            await MainActor.run {
                if marksInitialSync {
                    hasCompletedInitialWidgetSync = true
                }
            }
        }
    }
}

@main
struct HabitsApp: App {
    @StateObject var deepLinkManager = DeepLinkManager.shared
    @StateObject private var userSettings = UserSettings()
    @StateObject private var purchaseService = PurchaseService()
    @StateObject private var habitUIStateStore = HabitUIStateStore()
    @StateObject private var habitVersionStore = HabitVersionStore()
    @State private var habitLogService: HabitLogService?
    
    @State private var container: ModelContainer?
    @State private var startupModelContext: ModelContext?
    @State private var isPreparingContainer = false
    @State private var hasConfiguredRuntimeServices = false

    init() {
        self.init(container: nil)
    }

    init(container: ModelContainer?) {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationActionHandler.shared
        _container = State(initialValue: container)
    }


    var body: some Scene {
        WindowGroup {
            Group {
                if let container, let habitLogService {
                    RootView()
                        .modelContainer(container)
                    .environmentObject(userSettings)
                    .environmentObject(deepLinkManager)
                    .environmentObject(purchaseService)
                    .environmentObject(habitUIStateStore)
                    .environmentObject(habitVersionStore)
                    .environmentObject(habitLogService)
                } else {
                    Color.clear
                }
            }
            .task {
                guard !RuntimeEnvironment.isRunningTests else { return }
                await MainActor.run {
                    StartupProfiler.logStartupPhase("app_launch")
                }
                await prepareContainerIfNeeded()
                if let container {
                    await MainActor.run {
                        StartupProfiler.logStartupPhase("swiftdata_loaded")
                    }
                    configureRuntimeServicesIfNeeded(using: container)
                }
            }
            .onOpenURL { url in
                deepLinkManager.handle(url: url)
            }
        }
    }

    @MainActor
    private func prepareContainerIfNeeded() async {
        guard container == nil, !isPreparingContainer else { return }
        isPreparingContainer = true

        let loadedContainer = await Task.detached(priority: .userInitiated) {
            Self.makeInitialContainer()
        }.value

        container = loadedContainer
        isPreparingContainer = false
    }

    nonisolated private static func makeInitialContainer() -> ModelContainer {
        if RuntimeEnvironment.isRunningTests {
            return try! Persistence.makeInMemoryContainer()
        }

        if let appContainer = try? Persistence.makeAppContainer() {
            return appContainer
        }

        return try! Persistence.makeInMemoryContainer()
    }

    private func configureRuntimeServicesIfNeeded(using container: ModelContainer) {
        if startupModelContext == nil {
            startupModelContext = ModelContext(container)
        }

        guard let startupModelContext else { return }

        if habitLogService == nil {
            habitLogService = HabitLogService(
                modelContext: startupModelContext,
                uiStateStore: habitUIStateStore,
                habitVersionStore: habitVersionStore
            )
        }

        guard !hasConfiguredRuntimeServices else { return }

        NotificationService.shared.configureModelContextProvider { [startupModelContext] in
            startupModelContext
        }
        NotificationService.shared.registerNotificationCategories()
        NotificationActionHandler.shared.configureModelContextProvider { [startupModelContext] in
            startupModelContext
        }
        NotificationActionHandler.shared.configureHabitLogServiceProvider { [habitLogService] in
            habitLogService
        }

        hasConfiguredRuntimeServices = true
    }
}
