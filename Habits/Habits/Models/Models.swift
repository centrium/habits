//
//  Models.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import Foundation
import SwiftData
import SwiftUI

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case frequency
    case cumulative

    var id: String { rawValue }

    var label: String {
        switch self {
        case .frequency:
            return "Frequency"
        case .cumulative:
            return "Cumulative"
        }
    }
}

enum GoalPeriod: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var unit: String {
        switch self {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }

    var streakUnit: String {
        unit
    }

    var relativeLabel: String {
        switch self {
        case .daily: return "today"
        case .weekly: return "this week"
        case .monthly: return "this month"
        case .yearly: return "this year"
        }
    }

    var heatmapAggregationUnit: Calendar.Component {
        .day
    }

    func periodStart(
        for date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Date {
        periodRange(for: date, calendar: calendar, weekStartPreference: weekStartPreference).start
    }

    func periodEnd(
        for date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Date {
        periodRange(for: date, calendar: calendar, weekStartPreference: weekStartPreference).end
    }

    func nextPeriodStart(
        after date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Date {
        periodEnd(for: date, calendar: calendar, weekStartPreference: weekStartPreference)
    }

    func previousPeriodStart(
        before date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> Date {
        let shiftedDate = calendar.date(byAdding: calendarComponent, value: -1, to: date) ?? date
        return periodStart(for: shiftedDate, calendar: calendar, weekStartPreference: weekStartPreference)
    }

    func periodRange(
        for date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> DateInterval {
        switch self {
        case .weekly:
            return WeekBoundaryCalculator.weekInterval(
                containing: date,
                calendar: calendar,
                weekStart: weekStartPreference
            )
        case .daily, .monthly, .yearly:
            return calendar.dateInterval(of: calendarComponent, for: date)
                ?? fallbackPeriodRange(for: date, calendar: calendar)
        }
    }

    func displayLabel(
        for date: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone

        switch self {
        case .daily:
            formatter.dateStyle = .medium
            return formatter.string(from: periodStart(for: date, calendar: calendar, weekStartPreference: weekStartPreference))
        case .weekly:
            let start = periodStart(for: date, calendar: calendar, weekStartPreference: weekStartPreference)
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            return "Week of \(formatter.string(from: start))"
        case .monthly:
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return formatter.string(from: periodStart(for: date, calendar: calendar, weekStartPreference: weekStartPreference))
        case .yearly:
            formatter.setLocalizedDateFormatFromTemplate("yyyy")
            return formatter.string(from: periodStart(for: date, calendar: calendar, weekStartPreference: weekStartPreference))
        }
    }

    private func fallbackPeriodRange(for date: Date, calendar: Calendar) -> DateInterval {
        switch self {
        case .daily:
            let start = calendar.startOfDay(for: date)
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start) ?? start)
        case .weekly:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
            let nextStart = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return DateInterval(start: start, end: nextStart)
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
            return DateInterval(start: start, end: calendar.date(byAdding: .month, value: 1, to: start) ?? start)
        case .yearly:
            let components = calendar.dateComponents([.year], from: date)
            let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
            return DateInterval(start: start, end: calendar.date(byAdding: .year, value: 1, to: start) ?? start)
        }
    }
}

enum HabitCategory: String, CaseIterable, Codable, Identifiable {
    case health = "Health"
    case wellbeing = "Wellbeing"
    case focus = "Focus"
    case learning = "Learning"
    case lifestyle = "Lifestyle"
    case general = "General"

    var id: String { rawValue }
}

enum HabitLogKind: String, Codable {
    case legacyDailyTotal
    case entry
}

@Model
final class HabitReminder: Identifiable {
    @Attribute(.unique) var id: UUID

    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var createdAt: Date

    init(hour: Int, minute: Int, isEnabled: Bool = true) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.createdAt = .now
    }
}

@Model
final class Habit: Identifiable {
    @Attribute(.unique) var id: UUID

    // Core identity
    var name: String
    var identity: String?
    var subtitle: String?
    var iconName: String?
    var colorHex: String
    var categoryRaw: String = HabitCategory.general.rawValue

    // Goal configuration (optional)
    var hasStreakGoal: Bool               // NEW
    var streakGoalTypeRaw: String         // backed by enum
    var streakTarget: Int                 // target per period
    var goalTypeRaw: String
    var targetValue: Double?
    var unit: String?
    var allowsDecimals: Bool

    var createdAt: Date
    var orderIndex: Int

    @Relationship(deleteRule: .cascade)
    var reminders: [HabitReminder] = []

    // Logs
    @Relationship(deleteRule: .cascade)
    var logs: [HabitLog] = []

    // MARK: - Computed wrapper

    var goalPeriod: GoalPeriod {
        get { GoalPeriod(rawValue: streakGoalTypeRaw) ?? .daily }
        set { streakGoalTypeRaw = newValue.rawValue }
    }

    var streakGoalType: GoalPeriod {
        get { goalPeriod }
        set { goalPeriod = newValue }
    }

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .frequency }
        set { goalTypeRaw = newValue.rawValue }
    }

    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        name: String,
        colorHex: String,
        identity: String? = nil,
        category: HabitCategory = .general,
        subtitle: String? = nil,
        iconName: String? = nil,
        hasStreakGoal: Bool = false,
        goalPeriod: GoalPeriod = .daily,
        goalType: GoalType = .frequency,
        streakTarget: Int = 1,
        targetValue: Double? = nil,
        unit: String? = nil,
        allowsDecimals: Bool = false,
        createdAt: Date = .now,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.identity = identity
        self.subtitle = subtitle
        self.iconName = iconName
        self.colorHex = colorHex
        self.categoryRaw = category.rawValue

        self.hasStreakGoal = hasStreakGoal
        self.streakGoalTypeRaw = goalPeriod.rawValue
        self.streakTarget = max(1, streakTarget)
        self.goalTypeRaw = goalType.rawValue
        self.targetValue = targetValue
        self.unit = unit
        self.allowsDecimals = allowsDecimals

        self.createdAt = createdAt
        self.orderIndex = orderIndex
    }
}

@Model
final class HabitLog {
    @Attribute(.unique) var id: UUID
    var day: Date   // Normalised to startOfDay
    var count: Int
    var timestamp: Date?
    var value: Double?
    var logKindRaw: String?
    var createdAt: Date

    var kind: HabitLogKind {
        HabitLogKind(rawValue: logKindRaw ?? "") ?? (value == nil ? .legacyDailyTotal : .entry)
    }

    var effectiveTimestamp: Date {
        timestamp ?? day
    }

    var numericValue: Double {
        switch kind {
        case .legacyDailyTotal:
            return Double(max(0, count))
        case .entry:
            return max(0, value ?? Double(max(0, count)))
        }
    }

    var frequencyContribution: Int {
        switch kind {
        case .legacyDailyTotal:
            return max(0, count)
        case .entry:
            return numericValue > 0 ? 1 : 0
        }
    }

    init(day: Date, count: Int = 1, createdAt: Date = .now, calendar: Calendar = .current) {
        self.id = UUID()
        self.day = calendar.startOfDay(for: day)
        self.count = count
        self.timestamp = nil
        self.value = nil
        self.logKindRaw = HabitLogKind.legacyDailyTotal.rawValue
        self.createdAt = createdAt
    }

    init(timestamp: Date, value: Double, createdAt: Date = .now, calendar: Calendar = .current) {
        self.id = UUID()
        self.day = calendar.startOfDay(for: timestamp)
        self.count = 0
        self.timestamp = timestamp
        self.value = max(0, value)
        self.logKindRaw = HabitLogKind.entry.rawValue
        self.createdAt = createdAt
    }
}

// MARK: - Helpers

extension Date {
    func startOfDay(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}


extension Color {
    // Minimal hex support (e.g. "#7C3AED")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8: (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default:(a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Habit {
    func isGoalMet(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        referenceDate: Date
    ) -> Bool {
        hasHitTarget(in: periodRange(
            for: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ))
    }
}
