//
//  Models.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import Foundation
import SwiftData
import SwiftUI

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

    var heatmapAggregationUnit: Calendar.Component {
        .day
    }

    func periodStart(for date: Date, calendar: Calendar = .current) -> Date {
        periodRange(for: date, calendar: calendar).start
    }

    func periodEnd(for date: Date, calendar: Calendar = .current) -> Date {
        periodRange(for: date, calendar: calendar).end
    }

    func nextPeriodStart(after date: Date, calendar: Calendar = .current) -> Date {
        periodEnd(for: date, calendar: calendar)
    }

    func previousPeriodStart(before date: Date, calendar: Calendar = .current) -> Date {
        let shiftedDate = calendar.date(byAdding: calendarComponent, value: -1, to: date) ?? date
        return periodStart(for: shiftedDate, calendar: calendar)
    }

    func periodRange(for date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: calendarComponent, for: date) ?? fallbackPeriodRange(for: date, calendar: calendar)
    }

    func displayLabel(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone

        switch self {
        case .daily:
            formatter.dateStyle = .medium
            return formatter.string(from: periodStart(for: date, calendar: calendar))
        case .weekly:
            let start = periodStart(for: date, calendar: calendar)
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            return "Week of \(formatter.string(from: start))"
        case .monthly:
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return formatter.string(from: periodStart(for: date, calendar: calendar))
        case .yearly:
            formatter.setLocalizedDateFormatFromTemplate("yyyy")
            return formatter.string(from: periodStart(for: date, calendar: calendar))
        }
    }

    private var calendarComponent: Calendar.Component {
        switch self {
        case .daily:
            return .day
        case .weekly:
            return .weekOfYear
        case .monthly:
            return .month
        case .yearly:
            return .year
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

@Model
final class Habit {
    @Attribute(.unique) var id: UUID

    // Core identity
    var name: String
    var subtitle: String?
    var iconName: String?
    var colorHex: String

    // Goal configuration (optional)
    var hasStreakGoal: Bool               // NEW
    var streakGoalTypeRaw: String         // backed by enum
    var streakTarget: Int                 // target per period

    var createdAt: Date

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

    // MARK: - Init

    init(
        name: String,
        colorHex: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        hasStreakGoal: Bool = false,
        goalPeriod: GoalPeriod = .daily,
        streakTarget: Int = 1,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.subtitle = subtitle
        self.iconName = iconName
        self.colorHex = colorHex

        self.hasStreakGoal = hasStreakGoal
        self.streakGoalTypeRaw = goalPeriod.rawValue
        self.streakTarget = max(1, streakTarget)

        self.createdAt = createdAt
    }
}

@Model
final class HabitLog {
    @Attribute(.unique) var id: UUID
    var day: Date   // Normalised to startOfDay
    var count: Int
    var createdAt: Date
    
    init(day: Date, count: Int = 1, createdAt: Date = .now, calendar: Calendar = .current) {
        self.id = UUID()
        self.day = calendar.startOfDay(for: day)
        self.count = count
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
        referenceDate: Date
    ) -> Bool {
        hasHitTarget(in: periodRange(for: referenceDate, calendar: calendar))
    }
}
