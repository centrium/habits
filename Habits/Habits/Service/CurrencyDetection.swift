//
//  CurrencyDetection.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import Foundation

struct CurrencyDetectionResult: Equatable {
    let isCurrency: Bool
    let currencyCode: String?
    let currencySymbol: String?

    static let none = CurrencyDetectionResult(
        isCurrency: false,
        currencyCode: nil,
        currencySymbol: nil
    )
}

enum CurrencyDetection {
    private static let symbolToCode: [String: String] = [
        "$": "USD",
        "£": "GBP",
        "€": "EUR",
        "¥": "JPY",
        "₹": "INR",
        "₩": "KRW",
        "₽": "RUB",
    ]

    private static let codeToSymbol: [String: String] = [
        "USD": "$",
        "GBP": "£",
        "EUR": "€",
        "JPY": "¥",
        "INR": "₹",
        "KRW": "₩",
        "RUB": "₽",
        "CAD": "$",
        "AUD": "$",
        "NZD": "$",
        "SGD": "$",
        "HKD": "$",
    ]

    private static let supportedCodes: Set<String> = [
        "USD", "GBP", "EUR", "JPY", "INR", "CAD", "AUD", "NZD", "SGD", "HKD", "CHF", "KRW", "RUB",
    ]

    static func detect(unit: String?) -> CurrencyDetectionResult {
        let trimmed = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return .none }

        for character in trimmed {
            let symbol = String(character)
            if let currencyCode = symbolToCode[symbol] {
                return CurrencyDetectionResult(
                    isCurrency: true,
                    currencyCode: currencyCode,
                    currencySymbol: symbol
                )
            }
        }

        let tokens = trimmed.uppercased().split { !$0.isLetter && !$0.isNumber }
        for token in tokens {
            let code = String(token)
            guard supportedCodes.contains(code) else { continue }
            return CurrencyDetectionResult(
                isCurrency: true,
                currencyCode: code,
                currencySymbol: codeToSymbol[code]
            )
        }

        return .none
    }
}
