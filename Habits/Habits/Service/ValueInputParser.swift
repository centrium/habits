//
//  ValueInputParser.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import Foundation

struct ValueInputContext {
    let metricKind: MetricKind
    let allowsDecimals: Bool
    let locale: Locale

    init(metricKind: MetricKind, allowsDecimals: Bool, locale: Locale = .current) {
        self.metricKind = metricKind
        self.allowsDecimals = allowsDecimals
        self.locale = locale
    }

    init(habit: Habit, locale: Locale = .current) {
        self.init(
            metricKind: MetricKindResolver.resolve(habit),
            allowsDecimals: habit.allowsDecimals,
            locale: locale
        )
    }
}

enum ValueInputParser {
    static func parse(_ text: String, context: ValueInputContext) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let locale = context.locale
        let groupingSeparator = locale.groupingSeparator ?? ","
        let decimalSeparator = locale.decimalSeparator ?? "."

        var normalized = trimmed
            .replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: " ", with: "")

        for symbol in ["$", "£", "€", "¥", "₹", "₩", "₽"] {
            normalized = normalized.replacingOccurrences(of: symbol, with: "")
        }

        if decimalSeparator != "." {
            normalized = normalized.replacingOccurrences(of: decimalSeparator, with: ".")
        } else if normalized.contains(",") && !normalized.contains(".") {
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }

        switch context.metricKind {
        case .count:
            guard let intValue = Int(normalized) else { return nil }
            return Decimal(intValue)
        case .currency, .genericValue:
            guard let decimalValue = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
                return nil
            }
            return sanitizedDecimal(decimalValue, context: context)
        }
    }

    static func sanitizeForStorage(_ decimal: Decimal, context: ValueInputContext) -> Double {
        let sanitized = sanitizedDecimal(decimal, context: context)
        return NSDecimalNumber(decimal: sanitized).doubleValue
    }

    private static func sanitizedDecimal(_ decimal: Decimal, context: ValueInputContext) -> Decimal {
        switch context.metricKind {
        case .count:
            return rounded(decimal, scale: 0)
        case .currency:
            return rounded(decimal, scale: 2)
        case .genericValue:
            guard !context.allowsDecimals else { return decimal }
            return rounded(decimal, scale: 0)
        }
    }

    private static func rounded(_ decimal: Decimal, scale: Int) -> Decimal {
        var source = decimal
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
