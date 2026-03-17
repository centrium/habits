//
//  NotificationScheduler.swift
//  Habits
//
//  Created by Codex on 12/03/2026.
//

import Foundation
import SwiftData

enum HabitReminderNotificationCopy {
    static let singleHabitTitle = "Time for your habit"
    static let singleHabitFallbackBody = "Keep your streak going"

    static func body(for habitName: String) -> String {
        let trimmedName = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return singleHabitFallbackBody }
        return "Your \"\(trimmedName)\" habit is waiting"
    }
}

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
            .flatMap { habit in
                habit.reminders.compactMap { reminder -> ReminderCandidate? in
                    guard reminder.isEnabled else {
                        return nil
                    }

                    guard
                        let reminderDate = calendar.date(
                            bySettingHour: reminder.hour,
                            minute: reminder.minute,
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
            }

        let groupedByRequestedDate = Dictionary(grouping: candidates, by: \.requestedDate)

        let groupedCandidates = groupedByRequestedDate.keys.sorted().compactMap { requestedDate -> ReminderGroup? in
            guard let grouped = groupedByRequestedDate[requestedDate] else { return nil }
            let activeHabits = grouped
                .filter { !$0.isLoggedToday }
                .map(\.habit)
                .uniqued(by: \.id)
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
                totalHabitCountAtTime: Set(grouped.map(\.habit.id)).count,
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
        if group.activeHabits.count == 1 {
            return HabitReminderNotificationCopy.singleHabitTitle
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
        if let habit = group.activeHabits.only {
            return HabitReminderNotificationCopy.body(for: habit.name)
        }

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

private extension Array {
    var only: Element? {
        count == 1 ? first : nil
    }

    func uniqued<Value: Hashable>(by keyPath: KeyPath<Element, Value>) -> [Element] {
        var seen: Set<Value> = []

        return filter { element in
            seen.insert(element[keyPath: keyPath]).inserted
        }
    }
}
