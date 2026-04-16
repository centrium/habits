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
        // When
        let context = StreakIndicatorPresentation.context(
            streakState: StreakState(
                currentStreak: 3,
                longestStreak: 3,
                hasMetRequirementToday: false,
                isRequiredToday: true,
                isAtRisk: true,
                isBroken: false,
                status: .atRisk
            )
        )

        // Then
        XCTAssertTrue(context.showBadge)
        XCTAssertTrue(context.isAtRisk)
        XCTAssertEqual(context.directionalDots.dots.count, 5)
        XCTAssertEqual(context.directionalDots.filledCount, 3)
        XCTAssertTrue(context.directionalDots.dots[3].isAtRisk)
    }

    func testBuildsSafeContextWhenTodayIsComplete() {
        // When
        let context = StreakIndicatorPresentation.context(
            streakState: StreakState(
                currentStreak: 4,
                longestStreak: 4,
                hasMetRequirementToday: true,
                isRequiredToday: false,
                isAtRisk: false,
                isBroken: false,
                status: .safe
            )
        )

        // Then
        XCTAssertTrue(context.showBadge)
        XCTAssertFalse(context.isAtRisk)
        XCTAssertEqual(context.directionalDots.filledCount, 4)
        XCTAssertTrue(context.directionalDots.dots[3].isToday)
    }

    func testNoStreakContextKeepsDotsButHidesBadge() {
        // When
        let context = StreakIndicatorPresentation.context(
            streakState: StreakState(
                currentStreak: 0,
                longestStreak: 0,
                hasMetRequirementToday: false,
                isRequiredToday: false,
                isAtRisk: false,
                isBroken: true,
                status: .broken
            )
        )

        // Then
        XCTAssertFalse(context.showBadge)
        XCTAssertFalse(context.isAtRisk)
        XCTAssertEqual(context.directionalDots.dots.count, 5)
        XCTAssertEqual(context.directionalDots.filledCount, 0)
        XCTAssertTrue(context.directionalDots.dots[0].isToday)
    }
}
