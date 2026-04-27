import XCTest
@testable import Habits

final class GuidanceEngineCoachingTests: XCTestCase {
    func testCoachingBodyIsStableForSameInputSameDay() {
        let store = InMemoryGuidanceRotationStore()
        let selected = SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: .consistency)
        let input = makeInput(dayBucket: 1_000, dayOrdinal: 100)

        let first = GuidanceEngine.coachingBody(
            from: input,
            depth: .premium,
            selectedSignals: selected,
            meaningScope: "habit-1",
            rotationStore: store
        )
        let second = GuidanceEngine.coachingBody(
            from: input,
            depth: .premium,
            selectedSignals: selected,
            meaningScope: "habit-1",
            rotationStore: store
        )

        XCTAssertEqual(first.text, second.text)
        XCTAssertEqual(first.usedSignals, selected.all)
    }

    func testCoachingBodyAvoidsConsecutiveDaySentenceRepeat() {
        let store = InMemoryGuidanceRotationStore()
        let selected = SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: .consistency)

        let dayOne = GuidanceEngine.coachingBody(
            from: makeInput(dayBucket: 2_000, dayOrdinal: 200),
            depth: .premium,
            selectedSignals: selected,
            meaningScope: "habit-2",
            rotationStore: store
        )
        let dayTwo = GuidanceEngine.coachingBody(
            from: makeInput(dayBucket: 2_001, dayOrdinal: 201),
            depth: .premium,
            selectedSignals: selected,
            meaningScope: "habit-2",
            rotationStore: store
        )

        XCTAssertNotEqual(normalized(dayOne.text), normalized(dayTwo.text))
    }

    func testCoachingBodyAvoidsRoboticTransitionPhrases() {
        let store = InMemoryGuidanceRotationStore()
        let selected = SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: .consistency)
        let banned = ["that suggests", "this indicates", "that means", "this implies", "that points to"]

        for offset in 0..<7 {
            let output = GuidanceEngine.coachingBody(
                from: makeInput(dayBucket: 3_000 + Int64(offset), dayOrdinal: 300 + offset),
                depth: .premium,
                selectedSignals: selected,
                meaningScope: "habit-3",
                rotationStore: store
            )
            let text = normalized(output.text)
            XCTAssertFalse(banned.contains(where: { text.contains($0) }))
        }
    }

    func testCoachingBodyContainsActionDirective() {
        let store = InMemoryGuidanceRotationStore()
        let selected = SelectedCoachingSignals(primary: .timeOfDayInsights, secondary: nil)
        let output = GuidanceEngine.coachingBody(
            from: makeInput(dayBucket: 4_000, dayOrdinal: 400),
            depth: .basic,
            selectedSignals: selected,
            meaningScope: "habit-4",
            rotationStore: store
        )
        let text = normalized(output.text)
        let directives = ["stick", "use", "lean into", "build around", "center"]
        XCTAssertTrue(directives.contains(where: { text.contains($0) }))
    }

    func testCoachingBodyDoesNotContainDoublePeriods() {
        let store = InMemoryGuidanceRotationStore()
        let selected = SelectedCoachingSignals(primary: .recentBehaviourSummary, secondary: nil)
        let output = GuidanceEngine.coachingBody(
            from: makeInput(dayBucket: 5_000, dayOrdinal: 500),
            depth: .basic,
            selectedSignals: selected,
            meaningScope: "habit-5",
            rotationStore: store
        )
        XCTAssertFalse(output.text.contains(".."))
    }

    func testCoachingBodySentencesStartWithCapitalLetter() {
        let store = InMemoryGuidanceRotationStore()
        let selected = SelectedCoachingSignals(primary: .recentBehaviourSummary, secondary: .timeOfDayInsights)
        let output = GuidanceEngine.coachingBody(
            from: makeInput(dayBucket: 6_000, dayOrdinal: 600),
            depth: .premium,
            selectedSignals: selected,
            meaningScope: "habit-6",
            rotationStore: store
        )
        let parts = output.text
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        XCTAssertFalse(parts.isEmpty)
        XCTAssertTrue(parts.allSatisfy { sentence in
            guard let first = sentence.first else { return false }
            return String(first) == String(first).uppercased()
        })
    }

    private func makeInput(dayBucket: Int64, dayOrdinal: Int) -> CoachingInput {
        CoachingInput(
            version: 1,
            identityState: .steady,
            streakState: "5-period streak",
            consistency: 68,
            timeOfDayInsights: CoachingTimeOfDayInsights(strongestWindow: "evening", confidence: .high),
            recentBehaviourSummary: "You usually follow through after work.",
            todayStatus: "Not yet today",
            windowDays: 14,
            dayBucket: dayBucket,
            dayOrdinal: dayOrdinal
        )
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class InMemoryGuidanceRotationStore: GuidanceRotationStoring {
    private var backing = GuidanceRotationSnapshot()

    func snapshot() -> GuidanceRotationSnapshot {
        backing
    }

    func save(_ snapshot: GuidanceRotationSnapshot) {
        backing = snapshot
    }
}
