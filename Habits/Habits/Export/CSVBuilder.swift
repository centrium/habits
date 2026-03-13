//
//  CSVBuilder.swift
//  Habits
//
//  Created by Matt Adams on 13/03/2026.
//


import Foundation

struct CSVBuilder {
    private let delimiter = ","
    private let lineBreak = "\n"

    func makeCSV(headers: [String], rows: [[String]]) -> String {
        let headerLine = headers.map(escape).joined(separator: delimiter)
        let rowLines = rows.map { row in
            row.map(escape).joined(separator: delimiter)
        }

        return ([headerLine] + rowLines).joined(separator: lineBreak)
    }

    private func escape(_ value: String) -> String {
        let needsQuotes =
            value.contains(delimiter) ||
            value.contains("\"") ||
            value.contains("\n") ||
            value.contains("\r")

        guard needsQuotes else { return value }

        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}