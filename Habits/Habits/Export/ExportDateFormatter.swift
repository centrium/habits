//
//  ExportDateFormatter.swift
//  Habits
//
//  Created by Matt Adams on 13/03/2026.
//


import Foundation

enum ExportDateFormatter {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
