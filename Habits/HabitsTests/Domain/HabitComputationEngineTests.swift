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

    func testWeeklyPatternTracksRecentAndHistoricalTopDaysIndependently() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let recentThursdays = dates(
            matchingWeekday: 5,
            count: 4,
            endingAt: now,
            minOffset: 0,
            maxOffset: 13
        )
        let recentMondays = dates(
            matchingWeekday: 2,
            count: 3,
            endingAt: now,
            minOffset: 0,
            maxOffset: 13
        )
        let historicalSundays = dates(
            matchingWeekday: 1,
            count: 8,
            endingAt: now,
            minOffset: 14,
            maxOffset: 220
        )

        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: (recentThursdays + recentMondays + historicalSundays).map { .init(timestamp: $0, value: 1) },
            calendar: calendar
        )

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.weeklyPattern.sampleSize, 7)
        XCTAssertEqual(state.weeklyPattern.recentTopDay, .thursday)
        XCTAssertEqual(state.weeklyPattern.historicalTopDay, .sunday)
    }

    func testWeeklyPatternUsesRecentWindowForSampleSize() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let historicalOnly = dates(
            matchingWeekday: 1,
            count: 9,
            endingAt: now,
            minOffset: 20,
            maxOffset: 220
        )
        let habit = TestHabitFactory.openEnded(
            entries: historicalOnly.map { .init(timestamp: $0, value: 1) },
            calendar: calendar
        )

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.weeklyPattern.sampleSize, 0)
        XCTAssertNil(state.weeklyPattern.recentTopDay)
        XCTAssertEqual(state.weeklyPattern.historicalTopDay, .sunday)
    }

    func testWeeklyPatternDoesNotPickTopDayWhenRecentWindowIsTied() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let recentDays = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }
        let habit = TestHabitFactory.openEnded(
            entries: recentDays.map { .init(timestamp: $0, value: 1) },
            calendar: calendar
        )

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        XCTAssertEqual(state.weeklyPattern.sampleSize, 7)
        XCTAssertNil(state.weeklyPattern.recentTopDay)
    }

    func testWeeklyPatternBlendsConsistencyAndEntryIntensityForFrequencyHabits() {
        let now = TestDateFactory.date(2026, 4, 20, hour: 10, calendar: calendar)
        let recentMonday = dates(
            matchingWeekday: 2,
            count: 1,
            endingAt: now,
            minOffset: 0,
            maxOffset: 13
        )
        let recentThursday = dates(
            matchingWeekday: 5,
            count: 1,
            endingAt: now,
            minOffset: 0,
            maxOffset: 13
        )
        guard let monday = recentMonday.first, let thursday = recentThursday.first else {
            return XCTFail("Expected at least one Monday and one Thursday in recent window")
        }
        let entries: [TestHabitFactory.Entry] = [
            .init(timestamp: monday, value: 1),
            .init(timestamp: thursday, value: 1),
            .init(timestamp: calendar.date(byAdding: .hour, value: 1, to: thursday) ?? thursday, value: 1),
            .init(timestamp: calendar.date(byAdding: .hour, value: 2, to: thursday) ?? thursday, value: 1),
        ]
        let habit = TestHabitFactory.openEnded(entries: entries, calendar: calendar)

        let state = HabitComputationEngine(calendar: calendar).compute(
            habit: habit,
            logs: habit.logs,
            globalLogs: habit.logs,
            now: now
        )

        let mondayScore = state.weeklyPattern.weekdayDistribution[.monday] ?? 0
        let thursdayScore = state.weeklyPattern.weekdayDistribution[.thursday] ?? 0
        XCTAssertGreaterThan(thursdayScore, mondayScore)
        XCTAssertEqual(state.weeklyPattern.weekdayActiveDayCounts[.monday], 1)
        XCTAssertEqual(state.weeklyPattern.weekdayActiveDayCounts[.thursday], 1)
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

    private func dates(
        matchingWeekday targetWeekday: Int,
        count: Int,
        endingAt now: Date,
        minOffset: Int,
        maxOffset: Int
    ) -> [Date] {
        var result: [Date] = []
        for offset in minOffset...maxOffset {
            let candidate = TestDateFactory.addingDays(-offset, to: now, calendar: calendar)
            if calendar.component(.weekday, from: candidate) == targetWeekday {
                result.append(candidate)
                if result.count == count {
                    return result
                }
            }
        }
        return result
    }
}
