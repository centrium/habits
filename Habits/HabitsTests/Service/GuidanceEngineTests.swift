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
        XCTAssertEqual(output.title, "You've shown up today")
        XCTAssertEqual(output.action, "Keep your rhythm going")
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
        XCTAssertTrue(output.action.contains("stay consistent"))
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
        XCTAssertEqual(output.title, "Post-coffee window open")
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
        XCTAssertEqual(output.title, "You’ve missed your usual time")
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

        XCTAssertEqual(output.supportingContext, "After Coffee • Window open")
    }

    private func streakState(for habit: Habit, now: Date) -> StreakState {
        StreakStateEngine(
            calendar: calendar,
            weekStartPreference: .monday
        ).streakState(for: habit, referenceDate: now)
    }

    private func assertNoForbiddenLanguage(in output: GuidanceOutput, file: StaticString = #filePath, line: UInt = #line) {
        let combined = "\(output.title) \(output.action)".lowercased()
        let forbidden = ["streak", "don't break", "protect your streak", "extend your streak", "reset"]
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
