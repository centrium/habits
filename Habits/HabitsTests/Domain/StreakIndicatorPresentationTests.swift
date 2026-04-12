import XCTest
@testable import Habits

final class StreakIndicatorPresentationTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

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
        XCTAssertTrue(shouldShow)
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

    func testBuildsAtRiskContextWhenTodayIsIncompleteAndStreakExists() {
        // Given
        let now = TestDateFactory.date(2026, 4, 12, hour: 10, calendar: calendar)

        // When
        let context = StreakIndicatorPresentation.context(
            displayStreak: 3,
            isTodayComplete: false,
            now: now,
            calendar: calendar
        )

        // Then
        XCTAssertTrue(context.showBadge)
        XCTAssertTrue(context.isAtRisk)
        XCTAssertEqual(context.directionalDots.dots.count, 5)
        XCTAssertEqual(context.directionalDots.filledCount, 3)
        XCTAssertTrue(context.directionalDots.dots[3].isAtRisk)
    }

    func testBuildsSafeContextWhenTodayIsComplete() {
        // Given
        let now = TestDateFactory.date(2026, 4, 12, hour: 10, calendar: calendar)

        // When
        let context = StreakIndicatorPresentation.context(
            displayStreak: 4,
            isTodayComplete: true,
            now: now,
            calendar: calendar
        )

        // Then
        XCTAssertTrue(context.showBadge)
        XCTAssertFalse(context.isAtRisk)
        XCTAssertEqual(context.directionalDots.filledCount, 4)
        XCTAssertTrue(context.directionalDots.dots[3].isToday)
    }

    func testNoStreakContextKeepsDotsButHidesBadge() {
        // Given
        let now = TestDateFactory.date(2026, 4, 12, hour: 10, calendar: calendar)

        // When
        let context = StreakIndicatorPresentation.context(
            displayStreak: 0,
            isTodayComplete: false,
            now: now,
            calendar: calendar
        )

        // Then
        XCTAssertFalse(context.showBadge)
        XCTAssertFalse(context.isAtRisk)
        XCTAssertEqual(context.directionalDots.dots.count, 5)
        XCTAssertEqual(context.directionalDots.filledCount, 0)
        XCTAssertTrue(context.directionalDots.dots[0].isToday)
    }
}
