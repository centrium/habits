//
//  CSVExportService.swift
//  Habits
//
//  Created by Matt Adams on 13/03/2026.
//

import Foundation
import SwiftData

struct CSVExportService {
    private let modelContext: ModelContext
    private let csvBuilder = CSVBuilder()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func export() throws -> [URL] {
        let habits = try fetchHabits()

        let habitsCSV = csvBuilder.makeCSV(
            headers: ["name", "goal_type", "goal_target", "created_at", "order"],
            rows: buildHabitRows(from: habits)
        )

        let logsCSV = csvBuilder.makeCSV(
            headers: ["habit", "date", "value"],
            rows: buildLogRows(from: habits)
        )

        let dateStamp = fileSafeDate()
        let habitsURL = try writeTemporaryFile(
            contents: habitsCSV,
            filename: "habits-export-\(dateStamp).csv"
        )
        let logsURL = try writeTemporaryFile(
            contents: logsCSV,
            filename: "habit-logs-export-\(dateStamp).csv"
        )

        return [habitsURL, logsURL]
    }

    private func fetchHabits() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func buildHabitRows(from habits: [Habit]) -> [[String]] {
        habits.map { habit in
            [
                habit.name,
                exportGoalType(for: habit),
                exportGoalTarget(for: habit),
                isoDate(habit.createdAt),
                String(habit.orderIndex)
            ]
        }
    }

    private func buildLogRows(from habits: [Habit]) -> [[String]] {
        habits.flatMap { habit in
            habit.logs
                .sorted {
                    if $0.effectiveTimestamp != $1.effectiveTimestamp {
                        return $0.effectiveTimestamp < $1.effectiveTimestamp
                    }
                    return $0.id.uuidString < $1.id.uuidString
                }
                .map { log in
                    [
                        habit.name,
                        isoDate(log.effectiveTimestamp),
                        formattedNumber(log.numericValue)
                    ]
                }
        }
    }

    private func exportGoalType(for habit: Habit) -> String {
        guard habit.hasStreakGoal else { return "open" }
        return habit.goalType.rawValue
    }

    private func exportGoalTarget(for habit: Habit) -> String {
        guard habit.hasStreakGoal else { return "" }

        switch habit.goalType {
        case .frequency:
            return formattedNumber(Double(max(1, habit.streakTarget)))
        case .cumulative:
            guard let target = habit.targetValue, target > 0 else { return "" }
            return formattedNumber(target)
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100

        if abs(rounded) < 0.000_000_1 {
            return "0"
        }

        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }

        var text = String(format: "%.2f", rounded)
        while text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }

        return text
    }

    private func isoDate(_ date: Date) -> String {
        ExportDateFormatter.iso8601.string(from: date)
    }

    private func writeTemporaryFile(contents: String, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func fileSafeDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}
