import XCTest
@testable import Habits

final class ValueFormatterTests: XCTestCase {
    func testCountFormattingUsesIntegerGrouping() {
        let context = ValueFormattingContext(
            metricKind: .count,
            allowsDecimals: false,
            currencyCode: nil,
            locale: Locale(identifier: "en_GB")
        )

        XCTAssertEqual(HabitValueFormatter.string(for: 1234, context: context), "1,234")
    }

    func testGenericValueFormattingRespectsDecimalRules() {
        let context = ValueFormattingContext(
            metricKind: .genericValue,
            allowsDecimals: true,
            currencyCode: nil,
            locale: Locale(identifier: "en_GB")
        )

        XCTAssertEqual(HabitValueFormatter.string(for: 12.5, context: context), "12.5")
    }

    func testCurrencyFormattingUsesLocaleAndTwoFractionDigits() {
        let context = ValueFormattingContext(
            metricKind: .currency,
            allowsDecimals: true,
            currencyCode: "GBP",
            locale: Locale(identifier: "en_GB")
        )

        XCTAssertEqual(HabitValueFormatter.string(for: 1234.5, context: context), "£1,234.50")
    }

    func testCurrencyInputStringKeepsTwoFractionDigitsWithoutSymbol() {
        let context = ValueFormattingContext(
            metricKind: .currency,
            allowsDecimals: true,
            currencyCode: "USD",
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(
            HabitValueFormatter.inputString(for: Decimal(string: "1")!, context: context),
            "1.00"
        )
    }
}
