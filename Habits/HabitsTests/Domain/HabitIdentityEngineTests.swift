import XCTest
@testable import Habits

final class HabitIdentityEngineTests: XCTestCase {
    func testNoIdentityReturnsNil() {
        // GIVEN
        let identity: String? = nil

        // WHEN
        let result = HabitIdentityEngine.narrative(
            identity: identity,
            completionRate: 0.8,
            recentCompletions: 6,
            window: 7
        )

        // THEN
        XCTAssertNil(result)
    }

    func testNoDataReturnsEarlyStageBehaviourAndNoEmotion() throws {
        // GIVEN
        let identity = "Someone who trains daily"

        // WHEN
        let result = HabitIdentityEngine.narrative(
            identity: identity,
            completionRate: nil,
            recentCompletions: nil,
            window: nil
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.identityLine, "Someone who trains daily")
        XCTAssertEqual(output.behaviourLine, "This is where the habit begins to take shape")
        XCTAssertNil(output.emotionalLine)
    }

    func testStrongRateReturnsStrongEmotionalLine() throws {
        // GIVEN
        let completionRate = 0.8

        // WHEN
        let result = HabitIdentityEngine.narrative(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 5,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.behaviourLine, "You’ve shown up 5 of the last 7 days")
        XCTAssertEqual(output.emotionalLine, "This is becoming part of who you are")
    }

    func testMediumRateReturnsMediumEmotionalLine() throws {
        // GIVEN
        let completionRate = 0.5

        // WHEN
        let result = HabitIdentityEngine.narrative(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 4,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.behaviourLine, "You’ve shown up 4 of the last 7 days")
        XCTAssertEqual(output.emotionalLine, "You’re building this identity — keep going")
    }

    func testLowRateReturnsLowEmotionalLine() throws {
        // GIVEN
        let completionRate = 0.2

        // WHEN
        let result = HabitIdentityEngine.narrative(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 1,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.behaviourLine, "You’ve shown up 1 of the last 7 days")
        XCTAssertEqual(output.emotionalLine, "This habit supports the person you want to be")
    }

    func testCompletionRateExactlyPointSevenMapsToStrong() throws {
        // GIVEN
        let completionRate = 0.7

        // WHEN
        let result = HabitIdentityEngine.narrative(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 5,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.emotionalLine, "This is becoming part of who you are")
    }

    func testCompletionRateExactlyPointFourMapsToMedium() throws {
        // GIVEN
        let completionRate = 0.4

        // WHEN
        let result = HabitIdentityEngine.narrative(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 3,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.emotionalLine, "You’re building this identity — keep going")
    }

    func testNarrativeIsDeterministicForSameInputs() throws {
        // GIVEN
        let identity = "Someone who trains daily"
        let completionRate = 0.8
        let recentCompletions = 5
        let window = 7

        // WHEN
        let first = try XCTUnwrap(
            HabitIdentityEngine.narrative(
                identity: identity,
                completionRate: completionRate,
                recentCompletions: recentCompletions,
                window: window
            )
        )
        let second = try XCTUnwrap(
            HabitIdentityEngine.narrative(
                identity: identity,
                completionRate: completionRate,
                recentCompletions: recentCompletions,
                window: window
            )
        )

        // THEN
        XCTAssertEqual(first.identityLine, second.identityLine)
        XCTAssertEqual(first.behaviourLine, second.behaviourLine)
        XCTAssertEqual(first.emotionalLine, second.emotionalLine)
    }
}
