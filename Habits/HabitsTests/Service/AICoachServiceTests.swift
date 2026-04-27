import XCTest
@testable import Habits

@MainActor
final class AICoachServiceTests: XCTestCase {
    private var service: AICoachService!

    override func setUp() {
        super.setUp()
        service = AICoachService()
        service.resetCacheForTesting()
    }

    override func tearDown() {
        service.resetCacheForTesting()
        service = nil
        super.tearDown()
    }

    func testCachedTextReturnsHitWithinOneHourForSameHabitAndInput() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()

        service.updateCacheForTesting(
            habitID: habitID,
            text: "Cached guidance",
            generatedAt: now.addingTimeInterval(-3_599)
        )

        let cached = service.cachedTextForTesting(
            habitID: habitID,
            now: now
        )

        XCTAssertEqual(cached, "Cached guidance")
    }

    func testCachedTextReturnsMissAfterOneHour() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()

        service.updateCacheForTesting(
            habitID: habitID,
            text: "Expired guidance",
            generatedAt: now.addingTimeInterval(-3_601)
        )

        let cached = service.cachedTextForTesting(
            habitID: habitID,
            now: now
        )

        XCTAssertNil(cached)
    }

    func testCachedTextReturnsHitWhenInputChangesWithinTTL() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()
        service.updateCacheForTesting(
            habitID: habitID,
            text: "Cached guidance",
            generatedAt: now.addingTimeInterval(-1_800)
        )

        let cached = service.cachedTextForTesting(
            habitID: habitID,
            now: now
        )

        XCTAssertEqual(cached, "Cached guidance")
    }

    func testCachedTextIsHabitSpecific() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let sourceHabitID = UUID()
        let otherHabitID = UUID()

        service.updateCacheForTesting(
            habitID: sourceHabitID,
            text: "Habit one guidance",
            generatedAt: now.addingTimeInterval(-600)
        )

        let cached = service.cachedTextForTesting(
            habitID: otherHabitID,
            now: now
        )

        XCTAssertNil(cached)
    }

}
