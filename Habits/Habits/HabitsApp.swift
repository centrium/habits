//
//  HabitsApp.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

enum StartupProfiler {
    nonisolated static let launchStartTime = CFAbsoluteTimeGetCurrent()
    @MainActor private static var hasLoggedFirstInteractiveRender = false

    @MainActor
    static func logFirstInteractiveRender() {
        guard !hasLoggedFirstInteractiveRender else { return }
        hasLoggedFirstInteractiveRender = true

        let elapsed = CFAbsoluteTimeGetCurrent() - launchStartTime
        print("Startup time to first interactive screen: \(elapsed)s")
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

    var body: some View {
        Group {
            switch purchaseService.premiumStatus {
            case .unknown:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .free, .premium:
                switch RootViewRouter.destination(hasCompletedOnboarding: userSettings.hasCompletedOnboarding) {
                case .habitsList:
                    HabitsListView()
                        .environmentObject(userSettings)
                        .environmentObject(deepLinkManager)
                case .onboarding:
                    OnboardingView()
                        .environmentObject(userSettings)
                        .environmentObject(deepLinkManager)
                }
            }
        }
        .onAppear {
            deepLinkManager.processPendingHabitIfNeeded()
            Task { @MainActor in
                await Task.yield()
                StartupProfiler.logFirstInteractiveRender()
            }
            KeyboardWarmup.warmAfterInitialRenderIfNeeded()
            scheduleWidgetSync(delayNanoseconds: 200_000_000, marksInitialSync: true)
        }
        .onChange(of: deepLinkManager.pendingHabitID) { _, _ in
            deepLinkManager.processPendingHabitIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
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

            await MainActor.run {
                _ = WidgetDataSync.sync(in: modelContext)
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
                    .environmentObject(habitLogService)
                } else {
                    Color.clear
                }
            }
            .task {
                await prepareContainerIfNeeded()
                if let container {
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
        let isRunningTests =
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isRunningTests {
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
                uiStateStore: habitUIStateStore
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
