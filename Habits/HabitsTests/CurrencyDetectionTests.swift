import XCTest
@testable import Habits

final class CurrencyDetectionTests: XCTestCase {
    func testDetectsCurrencyFromSymbol() {
        let result = CurrencyDetection.detect(unit: "£")

        XCTAssertTrue(result.isCurrency)
        XCTAssertEqual(result.currencyCode, "GBP")
        XCTAssertEqual(result.currencySymbol, "£")
    }

    func testDetectsCurrencyFromISOCodeCaseInsensitively() {
        let result = CurrencyDetection.detect(unit: "usd")

        XCTAssertTrue(result.isCurrency)
        XCTAssertEqual(result.currencyCode, "USD")
        XCTAssertEqual(result.currencySymbol, "$")
    }

    func testDetectsCurrencyFromTokenizedUnit() {
        let result = CurrencyDetection.detect(unit: "save EUR monthly")

        XCTAssertTrue(result.isCurrency)
        XCTAssertEqual(result.currencyCode, "EUR")
        XCTAssertEqual(result.currencySymbol, "€")
    }

    func testDoesNotInferCurrencyFromGenericUnit() {
        let result = CurrencyDetection.detect(unit: "books")

        XCTAssertFalse(result.isCurrency)
        XCTAssertNil(result.currencyCode)
        XCTAssertNil(result.currencySymbol)
    }

    func testEmptyUnitIsNotCurrency() {
        XCTAssertEqual(CurrencyDetection.detect(unit: nil), .none)
        XCTAssertEqual(CurrencyDetection.detect(unit: " "), .none)
    }
}
