import XCTest
@testable import Habits

final class StreakIndicatorPresentationTests: XCTestCase {
    func testDoesNotShowIndicatorWhenStreakIsZero() {
        // Given
        let streak = 0

        // When
        let shouldShow = StreakIndicatorPresentation.shouldShow(streak: streak)

        // Then
        XCTAssertFalse(shouldShow)
    }

    func testDoesNotShowIndicatorWhenStreakIsOne() {
        // Given
        let streak = 1

        // When
        let shouldShow = StreakIndicatorPresentation.shouldShow(streak: streak)

        // Then
        XCTAssertFalse(shouldShow)
    }

    func testShowsIndicatorWhenStreakIsTwoOrMore() {
        // Given
        let streak = 2

        // When
        let shouldShow = StreakIndicatorPresentation.shouldShow(streak: streak)

        // Then
        XCTAssertTrue(shouldShow)
    }

    func testFormatsIndicatorWithStreakValueOnly() {
        // Given
        let streak = 5

        // When
        let valueText = StreakIndicatorPresentation.valueText(for: streak)

        // Then
        XCTAssertEqual(valueText, "5")
    }

    func testReservesTrailingWidthForStableHeaderLayout() {
        // Given
        let reservedWidth = StreakIndicatorPresentation.reservedWidth

        // When
        let isStableWidth = reservedWidth >= 40

        // Then
        XCTAssertTrue(isStableWidth)
    }
}
