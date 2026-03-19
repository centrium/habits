import XCTest
@testable import Habits

final class MomentumServiceTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testHighMomentumScore() {
        // Given: 6/7 completed and a 5-day streak
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: TestDateFactory.addingDays(0, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-3, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-4, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-6, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = MomentumService(calendar: calendar, weekStartPreference: .monday)

        // When
        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        // Then
        XCTAssertGreaterThan(breakdown.score, 75)
        XCTAssertEqual(breakdown.band, .strong)
    }

    func testMomentumDropsWithGaps() {
        // Given
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [
                .init(timestamp: TestDateFactory.addingDays(0, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-4, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = MomentumService(calendar: calendar, weekStartPreference: .monday)

        // When
        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        // Then
        XCTAssertLessThan(breakdown.score, 40)
    }

    func testOpenGoalMomentumUsesBinaryCompletion() {
        // Given: multiple logs in one day still count as one completed day
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: now, value: 1),
                .init(timestamp: now, value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = MomentumService(calendar: calendar, weekStartPreference: .monday)

        // When
        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        // Then
        XCTAssertEqual(breakdown.completedDays, 3)
        XCTAssertEqual(breakdown.completionRate, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testFrequencyGoalMomentumRequiresTargetMet() {
        // Given: only one day reaches target 2
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                .init(timestamp: now, value: 1),
                .init(timestamp: now, value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = MomentumService(calendar: calendar, weekStartPreference: .monday)

        // When
        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        // Then
        XCTAssertEqual(breakdown.completedDays, 1)
        XCTAssertEqual(breakdown.completionRate, 1.0 / 7.0, accuracy: 0.0001)
    }

    func testCumulativeGoalMomentumCountsAnyProgress() {
        // Given: any positive value counts, independent of target
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [
                .init(timestamp: now, value: 0.5),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 12),
            ],
            calendar: calendar
        )
        let service = MomentumService(calendar: calendar, weekStartPreference: .monday)

        // When
        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        // Then
        XCTAssertEqual(breakdown.completedDays, 2)
        XCTAssertEqual(breakdown.completionRate, 2.0 / 7.0, accuracy: 0.0001)
    }

    func testMomentumIndependentOfBestStreak() {
        // Given
        let now = TestDateFactory.date(2026, 3, 19, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: now, value: 1),
                .init(timestamp: TestDateFactory.addingDays(-1, to: now, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.addingDays(-2, to: now, calendar: calendar), value: 1),
            ],
            calendar: calendar
        )
        let service = MomentumService(calendar: calendar, weekStartPreference: .monday)

        // When
        let breakdown = service.breakdown(for: habit, now: now, windowDays: 7)

        // Then
        XCTAssertEqual(breakdown.streak, 3)
        XCTAssertGreaterThan(breakdown.score, 0)
    }
}
