//
//  NotificationService.swift
//  Habits
//
//  Created by Matt Adams on 09/03/2026.
//

import Foundation
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
    
    // MARK: Evening Reflection

    private var legacyDailyCheckInIdentifier: String { "daily-checkin" }

    func scheduleEveningReflection(hour: Int, minute: Int, referenceDate: Date = Date()) async {
        removeEveningReflection()

        let reflectionContent = EveningReflection.content(
            for: eveningReflectionProgress(for: referenceDate)
        )

        let content = UNMutableNotificationContent()
        content.title = reflectionContent.title
        content.body = reflectionContent.body
        content.sound = .default

        let normalized = EveningReflection.clamped(hour: hour, minute: minute)
        var components = DateComponents()
        components.hour = normalized.hour
        components.minute = normalized.minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: EveningReflection.identifier,
            content: content,
            trigger: trigger
        )

        try? await notificationCenter.add(request)
    }

    func syncEveningReflectionFromStoredSettings(referenceDate: Date = Date()) async {
        let defaults = UserDefaults.standard

        let enabled =
            (defaults.object(forKey: "settings.eveningReflectionEnabled") as? Bool)
            ?? (defaults.object(forKey: "settings.dailyCheckInEnabled") as? Bool)
            ?? false

        guard enabled else {
            removeEveningReflection()
            return
        }

        let storedHour =
            (defaults.object(forKey: "settings.eveningReflectionHour") as? Int)
            ?? (defaults.object(forKey: "settings.dailyCheckInHour") as? Int)
            ?? EveningReflection.defaultHour

        let storedMinute =
            (defaults.object(forKey: "settings.eveningReflectionMinute") as? Int)
            ?? (defaults.object(forKey: "settings.dailyCheckInMinute") as? Int)
            ?? EveningReflection.defaultMinute

        let normalized = EveningReflection.clamped(hour: storedHour, minute: storedMinute)
        await scheduleEveningReflection(
            hour: normalized.hour,
            minute: normalized.minute,
            referenceDate: referenceDate
        )
    }

    func removeEveningReflection() {
        let identifiers = [EveningReflection.identifier, legacyDailyCheckInIdentifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    // Habit Notifications
    nonisolated func habitReminderIdentifier(for habitID: UUID) -> String {
        "habit-reminder-\(habitID.uuidString)"
    }

    nonisolated func habitReminderIdentifier(
        for habitID: UUID,
        reminderID: UUID
    ) -> String {
        "habit-reminder-\(habitID.uuidString)-\(reminderID.uuidString)"
    }

    func removeHabitReminder(for habit: Habit) {
        let identifiers =
            [habitReminderIdentifier(for: habit.id)] +
            habit.reminders.map { reminder in
                habitReminderIdentifier(for: habit.id, reminderID: reminder.id)
            }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func syncNotifications(for habit: Habit) async {
        removeHabitReminder(for: habit)

        if let context = resolvedModelContext() {
            await syncAllHabitReminders(in: context)
            return
        }

        await syncSingleHabitRemindersWithoutBundling(for: habit)
    }

    func syncHabitReminder(for habit: Habit) async {
        await syncNotifications(for: habit)
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

    private func syncSingleHabitRemindersWithoutBundling(for habit: Habit) async {
        let today = Calendar.current.startOfDay(for: Date())
        if habit.isComplete(for: today, calendar: .current) {
            return
        }

        var status = await notificationStatus()

        if status == .notDetermined {
            _ = await requestPermission()
            status = await notificationStatus()
        }

        guard status == .authorized || status == .provisional else { return }

        for reminder in habit.reminders where reminder.isEnabled {
            await scheduleHabitReminder(for: habit, reminder: reminder)
        }
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
        for reminder in habit.reminders {
            await scheduleHabitReminder(for: habit, reminder: reminder)
        }
    }

    private func scheduleHabitReminder(
        for habit: Habit,
        reminder: HabitReminder
    ) async {
        let identifier = habitReminderIdentifier(for: habit.id, reminderID: reminder.id)

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard reminder.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = HabitReminderNotificationCopy.singleHabitTitle
        content.body = HabitReminderNotificationCopy.body(for: habit.name)
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryID.habitReminder
        content.userInfo = [
            "habitID": habit.id.uuidString
        ]

        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute

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

    private func eveningReflectionProgress(for referenceDate: Date) -> EveningReflectionProgress {
        guard let context = resolvedModelContext() else {
            return EveningReflectionProgress(totalHabits: 0, completedHabitsToday: 0)
        }

        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)

        let completedHabitsToday = habits
            .filter { habit in
                habit.logs.contains { log in
                    calendar.isDate(log.day, inSameDayAs: referenceDay)
                }
            }
            .count

        return EveningReflectionProgress(
            totalHabits: habits.count,
            completedHabitsToday: completedHabitsToday
        )
    }
}
