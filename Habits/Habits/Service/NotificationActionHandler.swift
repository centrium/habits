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

protocol DeepLinkManaging: AnyObject {
    @MainActor
    func openHabit(_ id: UUID)
}

extension NotificationService: NotificationReminderSyncing {}
extension DeepLinkManager: DeepLinkManaging {}

final class SharedDeepLinkManager: DeepLinkManaging {
    @MainActor
    func openHabit(_ id: UUID) {
        DeepLinkManager.shared.openHabit(id)
    }
}

@MainActor
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationActionHandler()

    private let defaultModelContextProvider: () -> ModelContext?
    private var modelContextProviderStorage: (() -> ModelContext?)?
    private let defaultHabitLogServiceProvider: () -> HabitLogService?
    private var habitLogServiceProviderStorage: (() -> HabitLogService?)?
    private let notificationService: NotificationReminderSyncing
    private let notificationCenter: NotificationCenterProtocol
    private let deepLinkManager: DeepLinkManaging

    init(
        notificationService: NotificationReminderSyncing? = nil,
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        deepLinkManager: DeepLinkManaging? = nil,
        modelContextProvider: @escaping () -> ModelContext? = { nil },
        habitLogServiceProvider: @escaping () -> HabitLogService? = { nil }
    ) {
        self.defaultModelContextProvider = modelContextProvider
        self.defaultHabitLogServiceProvider = habitLogServiceProvider
        self.notificationService = notificationService ?? NotificationService.shared
        self.notificationCenter = notificationCenter
        self.deepLinkManager = deepLinkManager ?? SharedDeepLinkManager()
    }

    func configureModelContextProvider(_ modelContextProvider: @escaping () -> ModelContext?) {
        self.modelContextProviderStorage = modelContextProvider
    }

    func configureHabitLogServiceProvider(_ habitLogServiceProvider: @escaping () -> HabitLogService?) {
        self.habitLogServiceProviderStorage = habitLogServiceProvider
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

        guard let service = habitLogServiceProviderStorage?() ?? defaultHabitLogServiceProvider() else { return }

        service.quickLog(for: habit, on: Date())

        _ = context.saveAndSyncWidgetData()
        
        await notificationService.syncNotifications(for: habit)

        if let deliveredNotificationIdentifier {
            notificationCenter.removeDeliveredNotifications(
                withIdentifiers: [deliveredNotificationIdentifier]
            )
        }
    }
}
