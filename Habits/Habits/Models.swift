//
//  Models.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    // Store logs separately so querying + editing stays sane.
    @Relationship(deleteRule: .cascade) var logs: [HabitLog] = []

    init(name: String, colorHex: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

@Model
final class HabitLog {
    @Attribute(.unique) var id: UUID
    var day: Date   // Normalised to startOfDay
    var count: Int
    var createdAt: Date

    init(day: Date, count: Int = 1, createdAt: Date = .now) {
        self.id = UUID()
        self.day = day
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
