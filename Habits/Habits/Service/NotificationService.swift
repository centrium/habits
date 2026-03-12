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

@MainActor
final class NotificationService {

    static let shared = NotificationService()

    private let notificationCenter: NotificationCenterProtocol
    private let scheduler: NotificationScheduler
    private let modelContextProvider: () -> ModelContext?

    init(
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        scheduler: NotificationScheduler? = nil,
        modelContextProvider: @escaping () -> ModelContext? = { nil }
    ) {
        self.notificationCenter = notificationCenter
        self.scheduler = scheduler ?? NotificationScheduler()
        self.modelContextProvider = modelContextProvider
    }

    func configureModelContextProvider(_ modelContextProvider: @escaping () -> ModelContext?) {
        self.modelContextProviderStorage = modelContextProvider
    }

    private var modelContextProviderStorage: (() -> ModelContext?)?

    private func resolvedModelContext() -> ModelContext? {
        modelContextProviderStorage?() ?? modelContextProvider()
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
    nonisolated func habitReminderIdentifier(for habitID: UUID) -> String {
        "habit-reminder-\(habitID.uuidString)"
    }

    func removeHabitReminder(habitID: UUID) {
        let identifier = habitReminderIdentifier(for: habitID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func syncHabitReminder(for habit: Habit) async {

        removeHabitReminder(habitID: habit.id)

        if let context = resolvedModelContext() {
            await syncAllHabitReminders(in: context)
            return
        }

        await syncSingleHabitReminderWithoutBundling(for: habit)
    }

    func syncAllHabitReminders(referenceDate: Date = Date()) async {
        guard let context = resolvedModelContext() else { return }
        await syncAllHabitReminders(in: context, referenceDate: referenceDate)
    }

    private func syncAllHabitReminders(
        in context: ModelContext,
        referenceDate: Date = Date()
    ) async {
        clearSmartReminderSlots()

        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let legacyIdentifiers = habits.map { habitReminderIdentifier(for: $0.id) }

        if !legacyIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: legacyIdentifiers)
            notificationCenter.removeDeliveredNotifications(withIdentifiers: legacyIdentifiers)
        }

        let schedule = scheduler.schedule(for: habits, referenceDate: referenceDate)
        guard !schedule.isEmpty else { return }

        var status = await notificationStatus()

        if status == .notDetermined {
            _ = await requestPermission()
            status = await notificationStatus()
        }

        guard status == .authorized || status == .provisional else { return }

        for scheduledNotification in schedule {
            await submit(scheduledNotification)
        }
    }

    private func clearSmartReminderSlots() {
        let identifiers = (0..<NotificationScheduler.smartIdentifierCleanupLimit)
            .map(NotificationScheduler.smartIdentifier(for:))

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func syncSingleHabitReminderWithoutBundling(for habit: Habit) async {
        guard habit.reminderEnabled else { return }

        if let context = resolvedModelContext() {
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

    private func submit(_ scheduledNotification: ScheduledNotification) async {
        guard !scheduledNotification.habitIDs.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = scheduledNotification.title
        content.body = scheduledNotification.body
        content.sound = .default

        let userInfo: [String: Any] = [
            "habitID": scheduledNotification.habitIDs[0].uuidString,
            "habitIDs": scheduledNotification.habitIDs.map(\.uuidString)
        ]
        content.userInfo = userInfo

        if scheduledNotification.habitIDs.count == 1 {
            content.categoryIdentifier = NotificationCategoryID.habitReminder
        }

        var components = DateComponents()
        components.hour = Calendar.current.component(.hour, from: scheduledNotification.deliveryDate)
        components.minute = Calendar.current.component(.minute, from: scheduledNotification.deliveryDate)

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: scheduledNotification.id,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Ignore scheduling errors in production flow; callers can inspect authorization separately.
        }
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
        } catch {
            // Ignore scheduling errors in production flow; callers can inspect authorization separately.
        }
    }
}

extension HabitLogService {

    func isHabitCompletedToday(_ habit: Habit) -> Bool {
        let today = calendar.startOfDay(for: Date())
        return habit.isComplete(for: today, calendar: calendar)
    }

}
