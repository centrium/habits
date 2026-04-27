import XCTest
@testable import Habits

final class HabitIdentityEngineTests: BaseTestCase {
    func testNoIdentityReturnsNil() {
        // GIVEN
        let identity: String? = nil

        // WHEN
        let result = buildOutput(
            identity: identity,
            completionRate: 0.8,
            recentCompletions: 6,
            window: 7
        )

        // THEN
        XCTAssertNil(result)
    }

    func testNoDataReturnsIdentityAndStatOnly() throws {
        // GIVEN
        let identity = "Someone who trains daily"

        // WHEN
        let result = buildOutput(
            identity: identity,
            completionRate: nil,
            recentCompletions: nil,
            window: nil
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.identityLine, "Someone who trains daily")
        XCTAssertEqual(output.behaviourLine, "Getting started this week")
        XCTAssertNil(output.emotionalLine)
    }

    func testStrongRateReturnsStatOnly() throws {
        // GIVEN
        let completionRate = 0.8

        // WHEN
        let result = buildOutput(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 5,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.behaviourLine, "5 days this week")
        XCTAssertNil(output.emotionalLine)
    }

    func testMediumRateReturnsStatOnly() throws {
        // GIVEN
        let completionRate = 0.5

        // WHEN
        let result = buildOutput(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 4,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.behaviourLine, "4 days this week")
        XCTAssertNil(output.emotionalLine)
    }

    func testLowRateReturnsStatOnly() throws {
        // GIVEN
        let completionRate = 0.2

        // WHEN
        let result = buildOutput(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 1,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertEqual(output.behaviourLine, "1 day this week")
        XCTAssertNil(output.emotionalLine)
    }

    func testCompletionRateExactlyPointSevenMapsToStrong() throws {
        // GIVEN
        let completionRate = 0.7

        // WHEN
        let result = buildOutput(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 5,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertNil(output.emotionalLine)
    }

    func testCompletionRateExactlyPointFourMapsToMedium() throws {
        // GIVEN
        let completionRate = 0.4

        // WHEN
        let result = buildOutput(
            identity: "Someone who trains daily",
            completionRate: completionRate,
            recentCompletions: 3,
            window: 7
        )
        let output = try XCTUnwrap(result)

        // THEN
        XCTAssertNil(output.emotionalLine)
    }

    func testNarrativeIsDeterministicForSameInputs() throws {
        // GIVEN
        let identity = "Someone who trains daily"
        let completionRate = 0.8
        let recentCompletions = 5
        let window = 7

        // WHEN
        let first = try XCTUnwrap(
            buildOutput(
                identity: identity,
                completionRate: completionRate,
                recentCompletions: recentCompletions,
                window: window
            )
        )
        let second = try XCTUnwrap(
            buildOutput(
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

    private func buildOutput(
        identity: String?,
        completionRate: Double?,
        recentCompletions: Int?,
        window: Int?
    ) -> HabitIdentityOutput? {
        HabitIdentityEngine.build(
            identity: identity,
            metrics: HabitIdentityMetrics(
                completionRate: completionRate,
                recentCompletions: recentCompletions,
                window: window
            )
        )
    }
}
