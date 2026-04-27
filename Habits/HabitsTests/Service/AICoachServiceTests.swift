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
        let input = makeInput()

        service.updateCacheForTesting(
            habitID: habitID,
            input: input,
            text: "Cached guidance",
            generatedAt: now.addingTimeInterval(-3_599)
        )

        let cached = service.cachedTextForTesting(
            habitID: habitID,
            input: input,
            now: now
        )

        XCTAssertEqual(cached, "Cached guidance")
    }

    func testCachedTextReturnsMissAfterOneHour() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()
        let input = makeInput()

        service.updateCacheForTesting(
            habitID: habitID,
            input: input,
            text: "Expired guidance",
            generatedAt: now.addingTimeInterval(-3_601)
        )

        let cached = service.cachedTextForTesting(
            habitID: habitID,
            input: input,
            now: now
        )

        XCTAssertNil(cached)
    }

    func testCachedTextReturnsMissWhenInputChangesWithinTTL() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()
        let initialInput = makeInput(todayStatus: "Not yet today")
        let changedInput = makeInput(todayStatus: "Completed today")

        service.updateCacheForTesting(
            habitID: habitID,
            input: initialInput,
            text: "Stale guidance",
            generatedAt: now.addingTimeInterval(-1_800)
        )

        let cached = service.cachedTextForTesting(
            habitID: habitID,
            input: changedInput,
            now: now
        )

        XCTAssertNil(cached)
    }

    func testCachedTextIsHabitSpecific() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let sourceHabitID = UUID()
        let otherHabitID = UUID()
        let input = makeInput()

        service.updateCacheForTesting(
            habitID: sourceHabitID,
            input: input,
            text: "Habit one guidance",
            generatedAt: now.addingTimeInterval(-600)
        )

        let cached = service.cachedTextForTesting(
            habitID: otherHabitID,
            input: input,
            now: now
        )

        XCTAssertNil(cached)
    }

    private func makeInput(todayStatus: String = "Not yet today") -> AICoachInput {
        AICoachInput(
            habitName: "Read",
            recentLogs: "Recent check-ins: Apr 20, Apr 21.",
            state: .build,
            timingConfidence: .medium,
            strongestTime: "9PM",
            weakestTime: nil,
            streakState: "forming",
            identity: "A consistent reader",
            stacking: "After dinner",
            todayStatus: todayStatus,
            behaviourSummary: "Repetition is forming a routine."
        )
    }
}
