import XCTest
@testable import Habits

final class GuidanceEngineTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testCompletedTodayUsesMomentumWithoutUrgency() throws {
        let now = TestDateFactory.date(2026, 4, 16, hour: 9, calendar: calendar)
        let today = TestHabitFactory.entry(on: now)
        let habit = TestHabitFactory.frequency(
            entries: [today],
            calendar: calendar
        )

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: true,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertEqual(output.type, .momentum)
        XCTAssertEqual(output.title, "You’re in your strongest window")
        XCTAssertTrue(output.action.contains("now"))
        assertNoForbiddenLanguage(in: output)
    }

    func testMorningWithoutPatternFallsBackToMomentum() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 9, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 9, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 8, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertEqual(output.type, .momentum)
        assertNoForbiddenLanguage(in: output)
    }

    func testEveningUsesAtRiskWithoutStreakLanguage() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 20, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 8, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertEqual(output.type, .atRisk)
        XCTAssertTrue(output.action.contains("on track"))
        assertNoForbiddenLanguage(in: output)
    }

    func testPatternWithinWindowUsesPatternAwareCopy() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 8, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 8, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: HabitPattern(description: "after coffee", anchor: "Coffee"),
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertEqual(output.type, .momentum)
        XCTAssertTrue([
            "You’re in your strongest window",
            "Close to your best timing"
        ].contains(output.title))
        assertNoForbiddenLanguage(in: output)
    }

    func testPatternPassedWindowUsesRecoveryCopy() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 13, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 8, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: HabitPattern(description: "after coffee", anchor: "Coffee"),
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertEqual(output.type, .recovery)
        XCTAssertEqual(output.title, "Your strongest window was earlier")
        assertNoForbiddenLanguage(in: output)
    }

    func testStrongIdentityPushAppearsWithoutDuplication() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 11, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            entries: [
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 10, hour: 11, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 11, hour: 11, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 12, hour: 11, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 11, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 11, calendar: calendar)),
                TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 11, calendar: calendar))
            ],
            calendar: calendar
        )

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertEqual(output.type, .identity)
        assertNoForbiddenLanguage(in: output)
    }

    func testGuidanceStaysStableWithinSameDayAndState() {
        let store = InMemoryGuidanceRotationStore()
        let now = TestDateFactory.date(2026, 4, 16, hour: 9, calendar: calendar)
        let habit = stableMomentumHabit()

        let first = GuidanceEngine.build(
            input: guidanceInput(habit: habit, now: now),
            calendar: calendar,
            rotationStore: store
        )
        let second = GuidanceEngine.build(
            input: guidanceInput(habit: habit, now: now.addingTimeInterval(60 * 60)),
            calendar: calendar,
            rotationStore: store
        )

        XCTAssertEqual(first.id, second.id)
    }

    func testGuidanceRotatesAcrossDaysBeforeRepeating() {
        let store = InMemoryGuidanceRotationStore()
        let habit = stableMomentumHabit()
        let dayOne = TestDateFactory.date(2026, 4, 16, hour: 9, calendar: calendar)
        let dayTwo = TestDateFactory.date(2026, 4, 17, hour: 9, calendar: calendar)

        let first = GuidanceEngine.build(
            input: guidanceInput(habit: habit, now: dayOne),
            calendar: calendar,
            rotationStore: store
        )
        let second = GuidanceEngine.build(
            input: guidanceInput(habit: habit, now: dayTwo),
            calendar: calendar,
            rotationStore: store
        )

        XCTAssertNotEqual(first.id, second.id)
    }

    func testGuidanceProvidesSupportingContextForPremiumFeel() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 8, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 8, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: HabitPattern(description: "after coffee", anchor: "Coffee"),
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertTrue(output.supportingContext?.contains("Usually") == true)
        XCTAssertFalse(output.supportingContext?.contains("After coffee") == true)
    }

    func testClusteredTimingContextUsesBucketLanguage() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 12, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 10, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 11, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 12, hour: 13, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 13, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertTrue(output.supportingContext?.contains("midday") == true)
        XCTAssertFalse(output.supportingContext?.contains("AM") == true)
        XCTAssertFalse(output.supportingContext?.contains("PM") == true)
    }

    func testClusteredTimingContextFallsBackWhenPatternIsEvenlySpread() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 12, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 10, hour: 6, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 11, hour: 9, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 12, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 15, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 18, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 22, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertTrue(output.supportingContext?.contains("finding your rhythm") == true)
    }

    func testGuardrailReplacesBullet2WhenTitleAlreadyCarriesTimePosition() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 12, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 10, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 11, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 12, hour: 12, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 12, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        let lines = output.supportingContext?
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []

        XCTAssertGreaterThanOrEqual(lines.count, 2)
        XCTAssertTrue(lines[0].lowercased().contains("usually"))
        let bullet2 = lines[1].lowercased()
        XCTAssertFalse(bullet2.contains("window"))
        XCTAssertFalse(bullet2.contains("earlier"))
        XCTAssertFalse(bullet2.contains("later"))
        XCTAssertFalse(bullet2.contains("now"))
    }

    func testGuardrailPreventsBehaviourDuplicationInBullet2() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 18, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 10, hour: 18, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 11, hour: 18, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 12, hour: 18, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 18, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        let lines = output.supportingContext?
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []

        XCTAssertGreaterThanOrEqual(lines.count, 2)
        let bullet2 = lines[1].lowercased()
        XCTAssertFalse(bullet2.contains("usually"))
        XCTAssertFalse(bullet2.contains("midday"))
        XCTAssertFalse(bullet2.contains("morning"))
        XCTAssertFalse(bullet2.contains("afternoon"))
        XCTAssertFalse(bullet2.contains("evening"))
    }

    func testBullet2UsesReinforcementLibraryAfterOptimal() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 13, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 10, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 11, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 12, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        XCTAssertEqual(output.title, "Your strongest window was earlier")
        let bullet2 = secondBullet(from: output)
        XCTAssertNotNil(bullet2)
        XCTAssertTrue(allowedBullet2Lines.contains(bullet2 ?? ""))
    }

    func testBullet2DoesNotRepeatActionLineMeaning() {
        let now = TestDateFactory.date(2026, 4, 16, hour: 8, calendar: calendar)
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 10, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 11, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 12, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar))
        ]
        let habit = TestHabitFactory.frequency(entries: history, calendar: calendar)

        let output = GuidanceEngine.build(
            input: GuidanceInput(
                habit: habit,
                now: now,
                isCompletedToday: false,
                streakState: streakState(for: habit, now: now),
                completionHistory: habit.logs,
                pattern: nil,
                goalType: habit.goalType
            ),
            calendar: calendar,
            rotationStore: InMemoryGuidanceRotationStore()
        )

        let bullet2 = secondBullet(from: output)?.lowercased() ?? ""
        let action = output.action.lowercased()
        XCTAssertFalse(bullet2.contains("on track") && action.contains("on track"))
        XCTAssertFalse(bullet2.contains("lock it in") && action.contains("lock it in"))
    }

    private var allowedBullet2Lines: Set<String> {
        [
            "Even now, it still counts",
            "It’s not too late to show up",
            "A later session still adds value",
            "Showing up now still matters",
            "You can still make this count",
            "Any progress now is a win",
            "This still moves things forward",
            "It all adds up, even now",
            "This keeps your progress intact",
            "Every check-in strengthens this",
            "You’re building something steady",
            "This helps lock it in",
            "You’re reinforcing the habit",
            "This is how consistency forms",
            "Small steps keep it moving",
            "This keeps your rhythm alive",
            "You’re right there - keep it going",
            "This is a great moment to act",
            "Lean into it while it’s there",
            "You’ve got momentum - use it",
            "This is a strong moment to move",
            "Stay with it - you’re on track",
            "You’re in a good place - continue",
            "Keep this going while it feels natural",
            "This is what someone consistent does",
            "You’re becoming someone who shows up",
            "This is part of who you’re building",
            "You’re proving it to yourself",
            "This is how it becomes natural",
            "You’re shaping the habit right now",
            "This is what it looks like in practice",
            "You’re reinforcing who you want to be"
        ]
    }

    private func secondBullet(from output: GuidanceOutput) -> String? {
        let lines = output.supportingContext?
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        guard lines.count > 1 else { return nil }
        return lines[1]
    }

    private func streakState(for habit: Habit, now: Date) -> StreakState {
        StreakStateEngine(
            calendar: calendar,
            weekStartPreference: .monday
        ).streakState(for: habit, referenceDate: now)
    }

    private func assertNoForbiddenLanguage(in output: GuidanceOutput, file: StaticString = #filePath, line: UInt = #line) {
        let combined = "\(output.title) \(output.action)".lowercased()
        let forbidden = [
            "streak",
            "don't break",
            "protect your streak",
            "extend your streak",
            "reset",
            "who you are",
            "becoming",
            "identity",
            "part of you"
        ]
        for fragment in forbidden {
            XCTAssertFalse(combined.contains(fragment), file: file, line: line)
        }
    }

    private func stableMomentumHabit() -> Habit {
        let history = [
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 13, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 14, hour: 8, calendar: calendar)),
            TestHabitFactory.entry(on: TestDateFactory.date(2026, 4, 15, hour: 8, calendar: calendar))
        ]
        return TestHabitFactory.frequency(entries: history, calendar: calendar)
    }

    private func guidanceInput(habit: Habit, now: Date) -> GuidanceInput {
        GuidanceInput(
            habit: habit,
            now: now,
            isCompletedToday: false,
            streakState: streakState(for: habit, now: now),
            completionHistory: habit.logs,
            pattern: nil,
            goalType: habit.goalType
        )
    }
}

private final class InMemoryGuidanceRotationStore: GuidanceRotationStoring {
    private var value = GuidanceRotationSnapshot()

    func snapshot() -> GuidanceRotationSnapshot {
        value
    }

    func save(_ snapshot: GuidanceRotationSnapshot) {
        value = snapshot
    }
}
