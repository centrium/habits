//
//  NotificationScheduler.swift
//  Habits
//
//  Created by Codex on 12/03/2026.
//

import Foundation
import SwiftData

struct ScheduledNotification: Equatable {
    let id: String
    let deliveryDate: Date
    let habitIDs: [UUID]
    let title: String
    let body: String
}

struct NotificationScheduler {
    static let minimumNotificationSpacing: TimeInterval = 10 * 60
    static let smartIdentifierPrefix = "habit-reminder-smart-"
    static let smartIdentifierCleanupLimit = 512
    static let maxVisibleHabitsInBody = 2

    private let calendar: Calendar
    private let minimumSpacing: TimeInterval

    init(
        calendar: Calendar = .current,
        minimumSpacing: TimeInterval = NotificationScheduler.minimumNotificationSpacing
    ) {
        self.calendar = calendar
        self.minimumSpacing = minimumSpacing
    }

    func schedule(
        using modelContext: ModelContext,
        referenceDate: Date = Date()
    ) throws -> [ScheduledNotification] {
        let habits = try modelContext.fetch(FetchDescriptor<Habit>())
        return schedule(for: habits, referenceDate: referenceDate)
    }

    func schedule(
        for habits: [Habit],
        referenceDate: Date = Date()
    ) -> [ScheduledNotification] {
        let referenceDayStart = calendar.startOfDay(for: referenceDate)

        let candidates = habits
            .filter(\.reminderEnabled)
            .compactMap { habit -> ReminderCandidate? in
                guard
                    let reminderDate = calendar.date(
                        bySettingHour: habit.reminderHour,
                        minute: habit.reminderMinute,
                        second: 0,
                        of: referenceDayStart
                    )
                else {
                    return nil
                }

                let isLoggedToday = isLoggedToday(
                    habit: habit,
                    referenceDate: referenceDayStart
                )

                return ReminderCandidate(
                    habit: habit,
                    requestedDate: reminderDate,
                    isLoggedToday: isLoggedToday
                )
            }

        let groupedByRequestedDate = Dictionary(grouping: candidates, by: \.requestedDate)

        let groupedCandidates = groupedByRequestedDate.keys.sorted().compactMap { requestedDate -> ReminderGroup? in
            guard let grouped = groupedByRequestedDate[requestedDate] else { return nil }
            let activeHabits = grouped
                .filter { !$0.isLoggedToday }
                .map(\.habit)
                .sorted {
                    let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
                    if nameOrder == .orderedSame {
                        return $0.id.uuidString < $1.id.uuidString
                    }
                    return nameOrder == .orderedAscending
                }

            guard !activeHabits.isEmpty else { return nil }

            return ReminderGroup(
                requestedDate: requestedDate,
                totalHabitCountAtTime: grouped.count,
                activeHabits: activeHabits
            )
        }

        var scheduled: [ScheduledNotification] = []
        var previousDeliveryDate: Date?

        for (index, group) in groupedCandidates.enumerated() {
            let deliveryDate: Date
            if
                let previousDeliveryDate,
                group.requestedDate.timeIntervalSince(previousDeliveryDate) < minimumSpacing
            {
                deliveryDate = previousDeliveryDate.addingTimeInterval(minimumSpacing)
            } else {
                deliveryDate = group.requestedDate
            }

            let id = Self.smartIdentifier(for: index)
            let habitIDs = group.activeHabits.map(\.id)
            let title = notificationTitle(for: group, deliveryDate: deliveryDate)
            let body = notificationBody(for: group)

            scheduled.append(
                ScheduledNotification(
                    id: id,
                    deliveryDate: deliveryDate,
                    habitIDs: habitIDs,
                    title: title,
                    body: body
                )
            )

            previousDeliveryDate = deliveryDate
        }

        return scheduled
            .sorted { lhs, rhs in
                if lhs.deliveryDate == rhs.deliveryDate {
                    return lhs.id < rhs.id
                }
                return lhs.deliveryDate < rhs.deliveryDate
            }
    }

    static func smartIdentifier(for index: Int) -> String {
        "\(smartIdentifierPrefix)\(String(format: "%03d", index))"
    }

    private func notificationTitle(
        for group: ReminderGroup,
        deliveryDate: Date
    ) -> String {
        if group.totalHabitCountAtTime == 1, let habit = group.activeHabits.first {
            return "Time to log \(habit.name)"
        }

        let hour = calendar.component(.hour, from: deliveryDate)
        switch hour {
        case 5..<12:
            return "Morning Habits"
        case 12..<17:
            return "Afternoon Habits"
        case 17..<22:
            return "Evening Habits"
        default:
            return "Daily Habits"
        }
    }

    private func notificationBody(for group: ReminderGroup) -> String {
        let names = group.activeHabits.map(\.name)
        let count = names.count
        let noun = count == 1 ? "habit" : "habits"
        let state = count < group.totalHabitCountAtTime ? "remaining" : "ready"

        let visibleNames = Array(names.prefix(Self.maxVisibleHabitsInBody))
        var details = visibleNames.joined(separator: " • ")

        let remainingCount = count - visibleNames.count
        if remainingCount > 0 {
            details += " +\(remainingCount) more"
        }

        return "\(count) \(noun) \(state): \(details)"
    }

    private func isLoggedToday(
        habit: Habit,
        referenceDate: Date
    ) -> Bool {
        habit.logs.contains { log in
            calendar.isDate(log.day, inSameDayAs: referenceDate)
        }
    }
}

private struct ReminderCandidate {
    let habit: Habit
    let requestedDate: Date
    let isLoggedToday: Bool
}

private struct ReminderGroup {
    let requestedDate: Date
    let totalHabitCountAtTime: Int
    let activeHabits: [Habit]
}
