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

private struct ThemedAppContainer: View {
    let container: ModelContainer?
    @Binding var isBootstrapVisible: Bool
    let configureRuntimeServicesIfNeeded: (ModelContainer) -> Void
    let prepareContainerIfNeeded: @MainActor () async -> Void

    var body: some View {
        ZStack {
            if let container {
                RootView()
                    .modelContainer(container)
                    .task {
                        configureRuntimeServicesIfNeeded(container)
                    }
                    .onAppear {
                        guard isBootstrapVisible else { return }

                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 180_000_000)
                            withAnimation(.easeOut(duration: 0.18)) {
                                isBootstrapVisible = false
                            }
                            KeyboardWarmup.warm()
                        }
                    }
            }

            if isBootstrapVisible {
                AppBootstrapView()
                    .task {
                        await prepareContainerIfNeeded()
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
    @StateObject private var habitLogService = HabitLogServiceHolder()
    
    @State private var container: ModelContainer?
    @State private var isPreparingContainer = false
    @State private var hasConfiguredRuntimeServices = false
    @State private var isBootstrapVisible = true

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
            ThemedAppContainer(
                container: container,
                isBootstrapVisible: $isBootstrapVisible,
                configureRuntimeServicesIfNeeded: configureRuntimeServicesIfNeeded(using:),
                prepareContainerIfNeeded: prepareContainerIfNeeded
            )
            .environmentObject(userSettings)
            .environmentObject(deepLinkManager)
            .environmentObject(purchaseService)
            .environmentObject(habitUIStateStore)
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
    private let containerWidth: CGFloat = 248
    private let wordmarkWidth: CGFloat = 196
    private let titleSize: CGFloat = 44
    private let subtitleSize: CGFloat = 15
    private let swooshBottomSpacing: CGFloat = 14
    private let subtitleTopSpacing: CGFloat = 8
    private let verticalOffset: CGFloat = -24
    private let spinnerBottomPadding: CGFloat = 96

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ProSwoosh(size: .launch, toAnimate: false)
                        .padding(.bottom, swooshBottomSpacing)

                    Text("Cadence")
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(width: wordmarkWidth, alignment: .leading)

                Text("Where habits become performance")
                    .font(.system(size: subtitleSize, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.84))
                    .padding(.top, subtitleTopSpacing)
                    .frame(width: containerWidth)
            }
            .frame(width: containerWidth)
            .offset(y: verticalOffset)
            .padding(.horizontal, 24)

            VStack {
                Spacer()

                ProgressView()
                    .tint(.secondary.opacity(0.7))
                    .padding(.bottom, spinnerBottomPadding)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
