//
//  NotificationActionHandler.swift
//  Habits
//
//  Created by Matt Adams on 10/03/2026.
//


import UserNotifications
import SwiftData

protocol NotificationReminderSyncing {
    @MainActor
    func syncNotifications(for habit: Habit) async
}

protocol HabitLogServiceProtocol {
    @discardableResult
    func quickLog(for habit: Habit, on day: Date) -> Double
}

protocol HabitLogServiceBuilding {
    func make(modelContext: ModelContext) -> HabitLogServiceProtocol
}

protocol DeepLinkManaging: AnyObject {
    @MainActor
    func openHabit(_ id: UUID)
}

extension NotificationService: NotificationReminderSyncing {}
extension HabitLogService: HabitLogServiceProtocol {}
extension DeepLinkManager: DeepLinkManaging {}

final class SharedDeepLinkManager: DeepLinkManaging {
    @MainActor
    func openHabit(_ id: UUID) {
        DeepLinkManager.shared.openHabit(id)
    }
}

struct HabitLogServiceBuilder: HabitLogServiceBuilding {
    func make(modelContext: ModelContext) -> HabitLogServiceProtocol {
        HabitLogService(modelContext: modelContext)
    }
}

@MainActor
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationActionHandler()

    private let defaultModelContextProvider: () -> ModelContext?
    private var modelContextProviderStorage: (() -> ModelContext?)?
    private let notificationService: NotificationReminderSyncing
    private let notificationCenter: NotificationCenterProtocol
    private let deepLinkManager: DeepLinkManaging
    private let habitLogServiceBuilder: HabitLogServiceBuilding

    init(
        notificationService: NotificationReminderSyncing? = nil,
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        deepLinkManager: DeepLinkManaging? = nil,
        habitLogServiceBuilder: HabitLogServiceBuilding? = nil,
        modelContextProvider: @escaping () -> ModelContext? = { nil }
    ) {
        self.defaultModelContextProvider = modelContextProvider
        self.notificationService = notificationService ?? NotificationService.shared
        self.notificationCenter = notificationCenter
        self.deepLinkManager = deepLinkManager ?? SharedDeepLinkManager()
        self.habitLogServiceBuilder = habitLogServiceBuilder ?? HabitLogServiceBuilder()
    }

    func configureModelContextProvider(_ modelContextProvider: @escaping () -> ModelContext?) {
        self.modelContextProviderStorage = modelContextProvider
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handleAction(
            actionIdentifier: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo,
            notificationIdentifier: response.notification.request.identifier
        )
    }

    func handleAction(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any],
        notificationIdentifier: String? = nil
    ) async {

        guard
            let habitIDString = userInfo["habitID"] as? String,
            let habitID = UUID(uuidString: habitIDString)
        else { return }

        if actionIdentifier == NotificationActionID.logHabit {
            await logHabit(
                habitID: habitID,
                deliveredNotificationIdentifier: notificationIdentifier
            )
        }
        
        if actionIdentifier == NotificationActionID.openHabit ||
            actionIdentifier == UNNotificationDefaultActionIdentifier
        {
            deepLinkManager.openHabit(habitID)
        }
    }

    private func logHabit(
        habitID: UUID,
        deliveredNotificationIdentifier: String?
    ) async {

        guard let context = modelContextProviderStorage?() ?? defaultModelContextProvider() else { return }

        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.id == habitID }
        )

        guard let habit = try? context.fetch(descriptor).first else { return }

        let service = habitLogServiceBuilder.make(modelContext: context)

        service.quickLog(for: habit, on: Date())

        try? context.save()
        
        await notificationService.syncNotifications(for: habit)

        if let deliveredNotificationIdentifier {
            notificationCenter.removeDeliveredNotifications(
                withIdentifiers: [deliveredNotificationIdentifier]
            )
        }
    }
}
