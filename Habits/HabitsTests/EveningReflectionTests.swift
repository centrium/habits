import XCTest
@testable import Habits

final class EveningReflectionTests: XCTestCase {
    private var calendar: Calendar {
        TestDateFactory.utcCalendar
    }

    private var referenceDate: Date {
        TestDateFactory.date(2026, 1, 1, hour: 12, minute: 0, calendar: calendar)
    }

    func testTimeRangeRestrictionIsLimitedToEveningWindow() {
        // Given
        let range = EveningReflection.timeRange(for: referenceDate, calendar: calendar)

        // Then
        XCTAssertEqual(hourMinute(range.lowerBound), HourMinute(hour: 17, minute: 0))
        XCTAssertEqual(hourMinute(range.upperBound), HourMinute(hour: 22, minute: 0))
        XCTAssertFalse(EveningReflection.isAllowed(hour: 16, minute: 59))
        XCTAssertTrue(EveningReflection.isAllowed(hour: 17, minute: 0))
        XCTAssertTrue(EveningReflection.isAllowed(hour: 21, minute: 45))
        XCTAssertTrue(EveningReflection.isAllowed(hour: 22, minute: 0))
        XCTAssertFalse(EveningReflection.isAllowed(hour: 22, minute: 1))
    }

    func testNoHabitsLoggedMessage() {
        // Given
        let progress = EveningReflectionProgress(
            totalHabits: 4,
            completedHabitsToday: 0,
            remainingHabits: 4
        )

        // When
        let content = EveningReflection.content(for: progress)

        // Then
        XCTAssertEqual(content.title, "Evening Reflection")
        XCTAssertTrue(content.body.contains("You haven't logged any habits today."))
    }

    func testSomeProgressMessage() {
        // Given
        let progress = EveningReflectionProgress(
            totalHabits: 5,
            completedHabitsToday: 2,
            remainingHabits: 3
        )

        // When
        let content = EveningReflection.content(for: progress)

        // Then
        XCTAssertEqual(content.title, "Evening Reflection")
        XCTAssertEqual(content.body, "Nice progress today. Keep building the habit.")
    }

    func testNearlyCompleteMessage() {
        // Given
        let progress = EveningReflectionProgress(
            totalHabits: 5,
            completedHabitsToday: 4,
            remainingHabits: 1
        )

        // When
        let content = EveningReflection.content(for: progress)

        // Then
        XCTAssertEqual(content.title, "Evening Reflection")
        XCTAssertTrue(content.body.contains("Just one habit left today."))
    }

    func testAllHabitsCompletedUsesCongratulatoryMessageOrCancellation() {
        // Given
        let progress = EveningReflectionProgress(
            totalHabits: 3,
            completedHabitsToday: 3,
            remainingHabits: 0
        )

        // When
        let content = EveningReflection.content(for: progress)

        // Then
        XCTAssertEqual(content.title, "Evening Reflection")
        XCTAssertTrue(content.body.contains("Everything completed today."))
    }

    private func hourMinute(_ date: Date) -> HourMinute {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return HourMinute(hour: components.hour ?? -1, minute: components.minute ?? -1)
    }
}
private struct HourMinute: Equatable {
    let hour: Int
    let minute: Int
}

