import XCTest
@testable import Habits

final class ValueInputParserTests: XCTestCase {
    func testCurrencyParsingRoundsToTwoDecimalPlaces() {
        let context = ValueInputContext(
            metricKind: .currency,
            allowsDecimals: true,
            locale: Locale(identifier: "en_GB")
        )

        let parsed = ValueInputParser.parse("12.345", context: context)

        XCTAssertEqual(parsed, Decimal(string: "12.35"))
    }

    func testCurrencyParsingAcceptsGroupingSeparators() {
        let context = ValueInputContext(
            metricKind: .currency,
            allowsDecimals: true,
            locale: Locale(identifier: "en_US")
        )

        let parsed = ValueInputParser.parse("1,234.50", context: context)

        XCTAssertEqual(parsed, Decimal(string: "1234.50"))
    }

    func testCountParsingProducesWholeNumber() {
        let context = ValueInputContext(metricKind: .count, allowsDecimals: false)

        XCTAssertEqual(ValueInputParser.parse("42", context: context), Decimal(42))
    }
}
