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

    func testCachedTextReturnsMissWhenFingerprintDiffers() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()

        service.updateCacheForTesting(
            habitID: habitID,
            text: "Fingerprint scoped guidance",
            fingerprint: "fingerprint-a",
            depth: .basic,
            generatedAt: now.addingTimeInterval(-300)
        )

        let cached = service.cachedTextIfFresh(
            habitID: habitID,
            fingerprint: "fingerprint-b",
            depth: .basic,
            now: now
        )

        XCTAssertNil(cached)
    }

    func testCachedTextReturnsMissWhenDepthDiffers() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()

        service.updateCacheForTesting(
            habitID: habitID,
            text: "Premium guidance",
            fingerprint: "fingerprint-a",
            depth: .premium,
            generatedAt: now.addingTimeInterval(-300)
        )

        let cached = service.cachedTextIfFresh(
            habitID: habitID,
            fingerprint: "fingerprint-a",
            depth: .basic,
            now: now
        )

        XCTAssertNil(cached)
    }

    func testCachedTextReturnsHitWhenFingerprintAndDepthMatch() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let habitID = UUID()

        service.updateCacheForTesting(
            habitID: habitID,
            text: "Matching cache",
            fingerprint: "fingerprint-a",
            depth: .premium,
            generatedAt: now.addingTimeInterval(-300)
        )

        let cached = service.cachedTextIfFresh(
            habitID: habitID,
            fingerprint: "fingerprint-a",
            depth: .premium,
            now: now
        )

        XCTAssertEqual(cached, "Matching cache")
    }

    func testCoachingFingerprintChangesWhenVersionChanges() {
        let inputV1 = CoachingInput(
            version: 1,
            identityState: .build,
            streakState: "forming",
            consistency: 30,
            timeOfDayInsights: CoachingTimeOfDayInsights(strongestWindow: "7 PM", confidence: .medium),
            recentBehaviourSummary: "Routine is taking shape.",
            todayStatus: "Not yet today",
            windowDays: 7,
            dayBucket: 1000,
            dayOrdinal: 100
        )
        let inputV2 = CoachingInput(
            version: 2,
            identityState: .build,
            streakState: "forming",
            consistency: 30,
            timeOfDayInsights: CoachingTimeOfDayInsights(strongestWindow: "7 PM", confidence: .medium),
            recentBehaviourSummary: "Routine is taking shape.",
            todayStatus: "Not yet today",
            windowDays: 7,
            dayBucket: 1000,
            dayOrdinal: 100
        )
        let selected = SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: .consistency)

        let v1Fingerprint = inputV1.aiFingerprint(depth: .premium, selectedSignals: selected)
        let v2Fingerprint = inputV2.aiFingerprint(depth: .premium, selectedSignals: selected)

        XCTAssertNotEqual(v1Fingerprint, v2Fingerprint)
    }

    func testAIFingerprintIgnoresDayBucketWhenMeaningUnchanged() {
        let selected = SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: .consistency)
        let dayOne = CoachingInput(
            version: 1,
            identityState: .steady,
            streakState: "3-period streak",
            consistency: 62,
            timeOfDayInsights: CoachingTimeOfDayInsights(strongestWindow: "8 PM", confidence: .high),
            recentBehaviourSummary: "Recent behaviour is settling into a routine.",
            todayStatus: "Not yet today",
            windowDays: 14,
            dayBucket: 1_000,
            dayOrdinal: 100
        )
        let dayTwo = CoachingInput(
            version: 1,
            identityState: .steady,
            streakState: "3-period streak",
            consistency: 62,
            timeOfDayInsights: CoachingTimeOfDayInsights(strongestWindow: "8 PM", confidence: .high),
            recentBehaviourSummary: "Recent behaviour is settling into a routine.",
            todayStatus: "Not yet today",
            windowDays: 14,
            dayBucket: 2_000,
            dayOrdinal: 101
        )

        XCTAssertEqual(
            dayOne.aiFingerprint(depth: .premium, selectedSignals: selected),
            dayTwo.aiFingerprint(depth: .premium, selectedSignals: selected)
        )
        XCTAssertNotEqual(
            dayOne.guidanceVariationKey(selectedSignals: selected),
            dayTwo.guidanceVariationKey(selectedSignals: selected)
        )
    }

    func testSignalFamilyValidationAcceptsNaturalStreakAndConsistencyPhrasing() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .streakState, secondary: .consistency)
        )

        let output = "You have been consistent recently and kept it going in a row. Try to use the same window today."

        XCTAssertTrue(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationAcceptsExplicitTimeExpressionForTimeOfDay() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        )

        let output = "You tend to follow through around 18:00. Focus on that window again today."

        XCTAssertTrue(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationRejectsGenericOutput() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: .consistency)
        )

        let output = "Keep going, you are doing great. You got this."

        XCTAssertFalse(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationAcceptsReliabilityAndRhythmLanguageForConsistency() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .consistency, secondary: nil)
        )

        let output = "Your rhythm looks reliable this week. Use the same window again today."

        XCTAssertTrue(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationBasicRequiresAtLeastOneMatch() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .consistency, secondary: nil),
            depth: .basic
        )
        let output = "Your routine is steady this week. Use the same window again today."
        XCTAssertTrue(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationPremiumAllowsOneMiss() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .consistency, secondary: .timeOfDayInsights),
            depth: .premium
        )
        let output = "Your routine has been reliable this week. Use the same window again today."
        XCTAssertTrue(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationPremiumFailsWhenAllSelectedSignalsMissing() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .consistency, secondary: .timeOfDayInsights),
            depth: .premium
        )
        let output = "You are making good progress and this can keep improving."
        XCTAssertFalse(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationRejectsStayConsistentGenericPhrase() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .consistency, secondary: nil),
            depth: .basic
        )
        let output = "Stay consistent."
        XCTAssertFalse(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testSignalFamilyValidationRequiresAllSelectedSignals() {
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .consistency, secondary: .timeOfDayInsights),
            depth: .premium
        )
        let output = "Your routine has been reliable this week."
        XCTAssertFalse(service.outputReferencesSelectedSignalsForTesting(output, input: input))
    }

    func testGenerateReturnsFailureWhenRunReturnsEmptyResult() async {
        let habitID = UUID()
        let requestKey = "nil-result-\(UUID().uuidString)"
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        )

        service.setRunOverrideForTesting { _, _ in
            .failure(.emptyResult)
        }

        let completionExpectation = expectation(description: "terminal called for empty result")
        var received: AICoachService.Outcome?
        service.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-nil",
            requestKey: requestKey
        ) { outcome in
            received = outcome
            completionExpectation.fulfill()
        }

        await fulfillment(of: [completionExpectation], timeout: 1.0)
        XCTAssertEqual(received, .failure(.emptyResult))
    }

    func testGenerateTimesOutAndReturnsFailureOutcome() async {
        let localService = AICoachService(generationTimeout: 0.05)
        localService.resetCacheForTesting()
        let habitID = UUID()
        let requestKey = "timeout-\(UUID().uuidString)"
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        )

        localService.setRunOverrideForTesting { _, _ in
            try? await Task.sleep(nanoseconds: 500_000_000)
            return .success("Late AI text that should not win before timeout")
        }

        let completionExpectation = expectation(description: "terminal called on timeout")
        var received: AICoachService.Outcome?
        localService.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-timeout",
            requestKey: requestKey
        ) { outcome in
            received = outcome
            completionExpectation.fulfill()
        }

        await fulfillment(of: [completionExpectation], timeout: 1.0)
        XCTAssertEqual(received, .failure(.timeout))
    }

    func testGenerateIgnoresLateOlderRequestWhenNewRequestStarts() async {
        let localService = AICoachService(generationTimeout: 1.0)
        localService.resetCacheForTesting()
        let habitID = UUID()
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        )

        localService.setRunOverrideForTesting { _, sequence in
            if sequence == 1 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                return .success("old-result")
            }
            return .success("new-result")
        }

        let newRequestExpectation = expectation(description: "new request completes")
        var oldRequestOutcome: AICoachService.Outcome?
        var newRequestOutcome: AICoachService.Outcome?

        localService.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-old",
            requestKey: "old-\(UUID().uuidString)"
        ) { outcome in
            oldRequestOutcome = outcome
        }

        localService.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-new",
            requestKey: "new-\(UUID().uuidString)"
        ) { outcome in
            newRequestOutcome = outcome
            newRequestExpectation.fulfill()
        }

        await fulfillment(of: [newRequestExpectation], timeout: 1.0)
        XCTAssertEqual(newRequestOutcome, .success("new-result"))
        XCTAssertEqual(oldRequestOutcome, .discarded(.stale))
    }

    func testGenerateReturnsDiscardedWhenCurrentStateValidatorFails() async {
        let localService = AICoachService(generationTimeout: 1.0)
        localService.resetCacheForTesting()
        let habitID = UUID()
        let requestKey = "stale-discard-\(UUID().uuidString)"
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        )

        localService.setRunOverrideForTesting { _, _ in
            .success("stale-result")
        }

        let staleDiscarded = expectation(description: "stale result discarded")
        var received: AICoachService.Outcome?
        localService.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-stale",
            requestKey: requestKey,
            isStillCurrent: { false }
        ) { outcome in
            received = outcome
            if outcome == .discarded(.stale) {
                staleDiscarded.fulfill()
            }
        }

        await fulfillment(of: [staleDiscarded], timeout: 1.0)
        XCTAssertEqual(received, .discarded(.stale))
        XCTAssertNil(
            localService.cachedTextIfFresh(
                habitID: habitID,
                fingerprint: "fp-stale",
                depth: input.depth
            )
        )
    }

    func testGeneratePublishesWhenCurrentStateValidatorPasses() async {
        let localService = AICoachService(generationTimeout: 1.0)
        localService.resetCacheForTesting()
        let habitID = UUID()
        let requestKey = "current-pass-\(UUID().uuidString)"
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        )

        localService.setRunOverrideForTesting { _, _ in
            .success("fresh-result")
        }

        let completionExpectation = expectation(description: "completion called")
        var received: AICoachService.Outcome?
        localService.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-fresh",
            requestKey: requestKey,
            isStillCurrent: { true }
        ) { outcome in
            received = outcome
            completionExpectation.fulfill()
        }

        await fulfillment(of: [completionExpectation], timeout: 1.0)
        XCTAssertEqual(received, .success("fresh-result"))
        XCTAssertEqual(
            localService.cachedTextIfFresh(
                habitID: habitID,
                fingerprint: "fp-fresh",
                depth: input.depth
            ),
            "fresh-result"
        )
    }

    func testGenerateDuplicateRequestKeyReturnsDiscarded() async {
        let habitID = UUID()
        let requestKey = "duplicate-\(UUID().uuidString)"
        let input = makeAICoachInput(
            selectedSignals: SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        )
        service.setRunOverrideForTesting { _, _ in
            .success("first")
        }

        let firstDone = expectation(description: "first done")
        service.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-1",
            requestKey: requestKey
        ) { _ in
            firstDone.fulfill()
        }
        await fulfillment(of: [firstDone], timeout: 1.0)

        let secondDone = expectation(description: "second done")
        var second: AICoachService.Outcome?
        service.generate(
            habitID: habitID,
            input: input,
            fingerprint: "fp-1",
            requestKey: requestKey
        ) { outcome in
            second = outcome
            secondDone.fulfill()
        }

        await fulfillment(of: [secondDone], timeout: 1.0)
        XCTAssertEqual(second, .discarded(.stale))
    }

    private func makeAICoachInput(
        selectedSignals: SelectedCoachingSignals,
        depth: CoachingDepth = .premium
    ) -> AICoachInput {
        let coachingInput = CoachingInput(
            version: 1,
            identityState: .build,
            streakState: "4-period streak",
            consistency: 62,
            timeOfDayInsights: CoachingTimeOfDayInsights(strongestWindow: "evening", confidence: .high),
            recentBehaviourSummary: "You usually follow through after dinner.",
            todayStatus: "Not yet today",
            windowDays: 14,
            dayBucket: 2_000,
            dayOrdinal: 120
        )
        return AICoachInput(
            coachingInput: coachingInput,
            depth: depth,
            selectedSignals: selectedSignals,
            habitName: "Walk",
            recentLogs: "Mon 19:00, Tue 18:30",
            state: .build,
            timingConfidence: .high,
            strongestTime: "evening",
            weakestTime: "morning",
            streakState: coachingInput.streakState,
            identity: "builder",
            stacking: nil,
            todayStatus: coachingInput.todayStatus,
            behaviourSummary: coachingInput.recentBehaviourSummary
        )
    }

}
