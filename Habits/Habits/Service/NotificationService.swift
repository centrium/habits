//
//  NotificationService.swift
//  Habits
//
//  Created by Matt Adams on 09/03/2026.
//

import UserNotifications
import SwiftData

protocol NotificationCenterProtocol {
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func notificationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func notificationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }
}

enum NotificationActionID {
    static let logHabit = "LOG_HABIT"
    static let openHabit = "OPEN_HABIT"
}

enum NotificationCategoryID {
    static let habitReminder = "HABIT_REMINDER"
}

final class NotificationService {

    static let shared = NotificationService()

    private let notificationCenter: NotificationCenterProtocol
    private let modelContainerProvider: () -> ModelContainer?

    init(
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        modelContainerProvider: @escaping () -> ModelContainer? = { NotificationActionHandler.shared.modelContainer }
    ) {
        self.notificationCenter = notificationCenter
        self.modelContainerProvider = modelContainerProvider
    }
    
    func registerNotificationCategories() {
        let logAction = UNNotificationAction(
            identifier: NotificationActionID.logHabit,
            title: "Log",
            options: []
        )

        let openAction = UNNotificationAction(
            identifier: NotificationActionID.openHabit,
            title: "Open",
            options: [.foreground]
        )

        let habitCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.habitReminder,
            actions: [logAction, openAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([habitCategory])
    }

    // MARK: Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func notificationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationStatus()
    }
    
    // MARK: Global Check In

    func scheduleDailyCheckIn(hour: Int, minute: Int) async {

        let content = UNMutableNotificationContent()
        content.title = "Habit Check-In"
        content.body = "How did today go?"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "daily-checkin",
            content: content,
            trigger: trigger
        )

        try? await notificationCenter.add(request)
    }
    
    func removeDailyCheckIn() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-checkin"])
    }
    
    // Habit Notifications
    func habitReminderIdentifier(for habitID: UUID) -> String {
        "habit-reminder-\(habitID.uuidString)"
    }

    func removeHabitReminder(habitID: UUID) {
        let identifier = habitReminderIdentifier(for: habitID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func syncHabitReminder(for habit: Habit) async {

        removeHabitReminder(habitID: habit.id)

        guard habit.reminderEnabled else { return }

        // Do not remind if already completed today
        if let modelContainer = modelContainerProvider() {
            let context = ModelContext(modelContainer)
            let logService = HabitLogService(modelContext: context)
            if logService.isHabitCompletedToday(habit) {
                return
            }
        }

        var status = await notificationStatus()

        if status == .notDetermined {
            _ = await requestPermission()
            status = await notificationStatus()
        }

        guard status == .authorized || status == .provisional else { return }

        await scheduleHabitReminder(for: habit)
    }
    
    func scheduleHabitReminder(for habit: Habit) async {
        let identifier = habitReminderIdentifier(for: habit.id)

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard habit.reminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to log \(habit.name)"
        content.body = "Stay consistent today."
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryID.habitReminder
        content.userInfo = [
            "habitID": habit.id.uuidString
        ]

        var components = DateComponents()
        components.hour = habit.reminderHour
        components.minute = habit.reminderMinute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("Scheduled habit reminder for \(habit.name) at \(habit.reminderHour):\(habit.reminderMinute)")
        } catch {
            print("Failed to schedule habit reminder for \(habit.name): \(error)")
        }
    }
}

extension HabitLogService {

    func isHabitCompletedToday(_ habit: Habit) -> Bool {
        let today = calendar.startOfDay(for: Date())
        return habit.isComplete(for: today, calendar: calendar)
    }

}
