//
//  NotificationActionHandler.swift
//  Habits
//
//  Created by Matt Adams on 10/03/2026.
//


import UserNotifications
import SwiftData

protocol NotificationReminderSyncing {
    func syncHabitReminder(for habit: Habit) async
    func habitReminderIdentifier(for habitID: UUID) -> String
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

final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationActionHandler()

    var modelContainer: ModelContainer?
    private let notificationService: NotificationReminderSyncing
    private let notificationCenter: NotificationCenterProtocol
    private let deepLinkManager: DeepLinkManaging
    private let habitLogServiceBuilder: HabitLogServiceBuilding

    init(
        notificationService: NotificationReminderSyncing = NotificationService.shared,
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        deepLinkManager: DeepLinkManaging = SharedDeepLinkManager(),
        habitLogServiceBuilder: HabitLogServiceBuilding = HabitLogServiceBuilder()
    ) {
        self.notificationService = notificationService
        self.notificationCenter = notificationCenter
        self.deepLinkManager = deepLinkManager
        self.habitLogServiceBuilder = habitLogServiceBuilder
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handleAction(
            actionIdentifier: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo
        )
    }

    func handleAction(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) async {

        guard
            let habitIDString = userInfo["habitID"] as? String,
            let habitID = UUID(uuidString: habitIDString)
        else { return }

        if actionIdentifier == NotificationActionID.logHabit {
            await logHabit(habitID: habitID)
        }
        
        if actionIdentifier == NotificationActionID.openHabit ||
            actionIdentifier == UNNotificationDefaultActionIdentifier
        {
            await MainActor.run {
                deepLinkManager.openHabit(habitID)
            }

        }
    }

    private func logHabit(habitID: UUID) async {

        guard let modelContainer else { return }

        let context = ModelContext(modelContainer)

        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.id == habitID }
        )

        guard let habit = try? context.fetch(descriptor).first else { return }

        let service = habitLogServiceBuilder.make(modelContext: context)

        service.quickLog(for: habit, on: Date())

        try? context.save()
        
        await notificationService.syncHabitReminder(for: habit)

        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [notificationService.habitReminderIdentifier(for: habitID)]
        )
    }
}
