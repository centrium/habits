import XCTest
@testable import Habits

@MainActor
final class HabitComputationEngineTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testCase1OneLogIsStartAndTimingIsForming() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [.init(timestamp: now, value: 1)],
            calendar: calendar
        )

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.identityState, .gettingStarted)
        XCTAssertNil(state.timingInsight)
        XCTAssertTrue(state.rhythmState.isForming)
    }

    func testCase2ThreeCompletedDaysIsBuildNotSteady() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let entries: [TestHabitFactory.Entry] = (0..<3).map { offset in
            .init(timestamp: TestDateFactory.addingDays(-offset, to: now, calendar: calendar), value: 1)
        }
        let habit = TestHabitFactory.frequency(target: 1, entries: entries, calendar: calendar)

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.identityState, .building)
    }

    func testCase3EightCompletedDaysIsSteady() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let entries: [TestHabitFactory.Entry] = (0..<8).map { offset in
            .init(timestamp: TestDateFactory.addingDays(-offset, to: now, calendar: calendar), value: 1)
        }
        let habit = TestHabitFactory.frequency(target: 1, entries: entries, calendar: calendar)

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.identityState, .steady)
    }

    func testCase4SinglePerfectCumulativeDayIsStillStart() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 10,
            entries: [.init(timestamp: now, value: 10)],
            calendar: calendar
        )

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.identityState, .gettingStarted)
    }

    func testCase5FourteenPlusConsistentDaysCanBeStrong() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let entries: [TestHabitFactory.Entry] = (0..<14).map { offset in
            .init(timestamp: TestDateFactory.addingDays(-offset, to: now, calendar: calendar), value: 1)
        }
        let habit = TestHabitFactory.frequency(target: 1, entries: entries, calendar: calendar)

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.identityState, .strong)
    }

    func testCase8IdentityMatchesAcrossResolversAndWidgetMapping() throws {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let entries: [TestHabitFactory.Entry] = (0..<8).map { offset in
            .init(timestamp: TestDateFactory.addingDays(-offset, to: now, calendar: calendar), value: 1)
        }
        let habit = TestHabitFactory.frequency(target: 1, entries: entries, calendar: calendar)

        let computed = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )
        let resolved = HabitIdentityStateResolver.resolve(for: habit, calendar: calendar, now: now)
        let stateModel = HabitStateResolver.resolve(for: habit, calendar: calendar, now: now).state.identityState
        let widget = try XCTUnwrap(mapToWidgetHabits([habit], referenceDate: now, calendar: calendar).first)

        XCTAssertEqual(computed.identityState, resolved)
        XCTAssertEqual(computed.identityState, stateModel)
        XCTAssertEqual(computed.identityState, identityState(from: widget.identityState))
    }

    private func identityState(from widgetState: WidgetHabitIdentityState) -> HabitIdentityState {
        switch widgetState {
        case .gettingStarted:
            return .gettingStarted
        case .building:
            return .building
        case .steady:
            return .steady
        case .strong:
            return .strong
        case .slipping:
            return .slipping
        case .rebuilding:
            return .rebuilding
        }
    }
}
