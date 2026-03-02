//
//  ValueFormatter.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import Foundation

struct ValueFormattingContext {
    let metricKind: MetricKind
    let allowsDecimals: Bool
    let currencyCode: String?
    let locale: Locale

    init(
        metricKind: MetricKind,
        allowsDecimals: Bool,
        currencyCode: String?,
        locale: Locale = .current
    ) {
        self.metricKind = metricKind
        self.allowsDecimals = allowsDecimals
        self.currencyCode = currencyCode
        self.locale = locale
    }

    init(habit: Habit, locale: Locale = .current) {
        let metricKind = MetricKindResolver.resolve(habit)
        let currency = CurrencyDetection.detect(unit: habit.trimmedUnit)

        self.init(
            metricKind: metricKind,
            allowsDecimals: habit.allowsDecimals,
            currencyCode: currency.currencyCode,
            locale: locale
        )
    }

    var showsUnitSuffix: Bool {
        metricKind == .genericValue
    }
}

enum HabitValueFormatter {
    static func string(for value: Double, context: ValueFormattingContext) -> String {
        let decimalValue = NSDecimalNumber(value: value).decimalValue
        return string(for: decimalValue, context: context)
    }

    static func string(for decimal: Decimal, context: ValueFormattingContext) -> String {
        let formatter = formatter(for: context, forInput: false)
        let normalizedDecimal = normalizedDecimal(decimal, for: context)
        let number = NSDecimalNumber(decimal: normalizedDecimal)
        return formatter.string(from: number) ?? "\(number)"
    }

    static func inputString(for decimal: Decimal, context: ValueFormattingContext) -> String {
        let formatter = formatter(for: context, forInput: true)
        let normalizedDecimal = normalizedDecimal(decimal, for: context)
        let number = NSDecimalNumber(decimal: normalizedDecimal)
        return formatter.string(from: number) ?? "\(number)"
    }

    private static func formatter(for context: ValueFormattingContext, forInput: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = context.locale

        switch context.metricKind {
        case .count:
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        case .currency:
            formatter.numberStyle = forInput ? .decimal : .currency
            formatter.currencyCode = context.currencyCode
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = forInput ? 2 : 2
        case .genericValue:
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = context.allowsDecimals ? 2 : 0
            formatter.minimumFractionDigits = 0
        }

        return formatter
    }

    private static func normalizedDecimal(_ decimal: Decimal, for context: ValueFormattingContext) -> Decimal {
        switch context.metricKind {
        case .count:
            return rounded(decimal, scale: 0)
        case .currency:
            return rounded(decimal, scale: 2)
        case .genericValue:
            guard context.allowsDecimals else {
                return rounded(decimal, scale: 0)
            }
            return decimal
        }
    }

    private static func rounded(_ decimal: Decimal, scale: Int) -> Decimal {
        var source = decimal
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
