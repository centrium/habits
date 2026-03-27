//
//  HabitsApp.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

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
    @EnvironmentObject private var userSettings: UserSettings

    var body: some View {
        Group {
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
        .onAppear {
            WidgetDataSync.sync(in: modelContext)
            deepLinkManager.processPendingHabitIfNeeded()
        }
        .onChange(of: deepLinkManager.pendingHabitID) { _, _ in
            deepLinkManager.processPendingHabitIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            WidgetDataSync.sync(in: modelContext)
        }
    }
}

@main
struct HabitsApp: App {
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.system.rawValue
    @StateObject var deepLinkManager = DeepLinkManager.shared
    @StateObject private var userSettings = UserSettings()
    @StateObject private var purchaseService = PurchaseService()
    @State private var container: ModelContainer?
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
                if let container {
                    RootView()
                        .modelContainer(container)
                        .task {
                            configureRuntimeServicesIfNeeded(using: container)
                        }
                } else {
                    AppBootstrapView(isPremiumUnlocked: purchaseService.isPremiumUnlocked)
                        .task {
                            await prepareContainerIfNeeded()
                        }
                }
            }
            .environmentObject(userSettings)
            .environmentObject(deepLinkManager)
            .environmentObject(purchaseService)
            .preferredColorScheme(appAppearance.preferredColorScheme)
            .onOpenURL { url in
                deepLinkManager.handle(url: url)
            }
        }
    }

    private var appAppearance: AppAppearance {
        get { AppAppearance(rawValue: appAppearanceRawValue) ?? .system }
        set { appAppearanceRawValue = newValue.rawValue }
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
        guard !hasConfiguredRuntimeServices else { return }

        NotificationService.shared.configureModelContextProvider { [container] in
            ModelContext(container)
        }
        NotificationService.shared.registerNotificationCategories()
        NotificationActionHandler.shared.configureModelContextProvider { [container] in
            ModelContext(container)
        }

        hasConfiguredRuntimeServices = true
    }
}

private struct AppBootstrapView: View {
    let isPremiumUnlocked: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.appBackground,
                    Color.appBackground.opacity(0.96),
                    Color.systemAccent.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                CadenceProWordmark(
                    size: .large,
                    animateSwoosh: isPremiumUnlocked,
                    showsProLabel: isPremiumUnlocked
                )

                ProgressView()
                    .tint(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 24)
        }
        .task {
            KeyboardWarmup.warm()
        }
    }
}
