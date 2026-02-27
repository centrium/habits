//
//  Models.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import Foundation
import SwiftData
import SwiftUI

import SwiftData
import Foundation

enum StreakGoalType: String, Codable, CaseIterable, Identifiable {
    case daily
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "Daily"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var unit: String {
        switch self {
        case .daily: return "day"
        case .monthly: return "month"
        case .yearly: return "year"
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

    var streakGoalType: StreakGoalType {
        get { StreakGoalType(rawValue: streakGoalTypeRaw) ?? .daily }
        set { streakGoalTypeRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        name: String,
        colorHex: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        hasStreakGoal: Bool = false,
        streakGoalType: StreakGoalType = .daily,
        streakTarget: Int = 1,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.subtitle = subtitle
        self.iconName = iconName
        self.colorHex = colorHex

        self.hasStreakGoal = hasStreakGoal
        self.streakGoalTypeRaw = streakGoalType.rawValue
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
        referenceDate: Date = .now
    ) -> Bool {
        let today = calendar.startOfDay(for: referenceDate)

        switch streakGoalType {
        case .daily:
            let count = logs.first {
                calendar.isDate($0.day, inSameDayAs: today)
            }?.count ?? 0
            return count >= streakTarget

        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: today)
            let monthlyTotal = logs.filter {
                calendar.dateComponents([.year, .month], from: $0.day) == components
            }.map(\.count).reduce(0, +)
            return monthlyTotal >= streakTarget

        case .yearly:
            let year = calendar.component(.year, from: today)
            let yearlyTotal = logs.filter {
                calendar.component(.year, from: $0.day) == year
            }.map(\.count).reduce(0, +)
            return yearlyTotal >= streakTarget
        }
    }
}
