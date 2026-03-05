import XCTest
@testable import Habits

final class HabitInsightsEngineTests: XCTestCase {
    private enum Fixtures {
        static let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            calendar.locale = Locale(identifier: "en_US_POSIX")
            calendar.firstWeekday = 2
            return calendar
        }()

        static let weekStart: WeekStartPreference = .monday

        static func makeDate(
            year: Int,
            month: Int,
            day: Int,
            hour: Int = 12,
            minute: Int = 0
        ) -> Date {
            let components = DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
            return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        }

        static func makeMonthlyFrequencyHabit(target: Int, createdAt: Date) -> Habit {
            Habit(
                name: "Dog Walking",
                colorHex: "#00AA88",
                hasStreakGoal: true,
                goalPeriod: .monthly,
                goalType: .frequency,
                streakTarget: target,
                createdAt: createdAt
            )
        }

        static func makeMonthlyCumulativeHabit(target: Double, createdAt: Date) -> Habit {
            Habit(
                name: "Run",
                colorHex: "#00AA88",
                hasStreakGoal: true,
                goalPeriod: .monthly,
                goalType: .cumulative,
                streakTarget: 1,
                targetValue: target,
                unit: "km",
                allowsDecimals: true,
                createdAt: createdAt
            )
        }
    }

    func testDetailHeaderAndInsightsUseIdenticalCurrentProgress() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 9)
        let selectedDate = Fixtures.makeDate(year: 2026, month: 3, day: 8, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        for day in 1...8 {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let detailService = ProgressAsOfService(
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: { now }
        )

        let detailSnapshot = try XCTUnwrap(
            detailService.snapshot(
                for: habit,
                visibleMonth: Fixtures.makeDate(year: 2026, month: 3, day: 1),
                selectedDate: selectedDate
            )
        )

        let insightsSnapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: selectedDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(detailSnapshot.current, insightsSnapshot.currentPeriod.progress, accuracy: 0.0001)
        XCTAssertEqual(detailSnapshot.target, insightsSnapshot.currentPeriod.target ?? 0, accuracy: 0.0001)
        XCTAssertEqual(insightsSnapshot.currentPeriod.progressCount, 8)
        XCTAssertEqual(insightsSnapshot.currentPeriod.progressClamped, 7, accuracy: 0.0001)
        XCTAssertEqual(insightsSnapshot.currentPeriod.surplus, 1, accuracy: 0.0001)
        XCTAssertEqual(detailSnapshot.overflowText, "+1 extra")
    }

    func testMonthlyCadenceUsesTrueCalendarMonthBoundaries() {
        let anchorDate = Fixtures.makeDate(year: 2026, month: 3, day: 5)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        XCTAssertEqual(snapshot.currentPeriod.start, Fixtures.makeDate(year: 2026, month: 3, day: 1, hour: 0))
        XCTAssertEqual(snapshot.currentPeriod.end, Fixtures.makeDate(year: 2026, month: 4, day: 1, hour: 0))

        let days = Fixtures.calendar.dateComponents(
            [.day],
            from: snapshot.currentPeriod.start,
            to: snapshot.currentPeriod.end
        ).day
        XCTAssertEqual(days, 31)
    }

    func testProjectionChangesWhenAnchorDateChanges() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 25, hour: 9)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        for _ in 0..<5 {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8), calendar: Fixtures.calendar)
        }

        let mar4 = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: Fixtures.makeDate(year: 2026, month: 3, day: 4, hour: 12),
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let mar5 = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 12),
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(mar4.currentPeriodSoFar.progressCount, 0)
        XCTAssertEqual(mar5.currentPeriodSoFar.progressCount, 5)
        XCTAssertNotEqual(mar4.pace.projectedTotal, mar5.pace.projectedTotal, accuracy: 0.0001)
    }

    func testCompletionHistoryExcludesPreCreationPeriods() throws {
        let anchorDate = Fixtures.makeDate(year: 2026, month: 6, day: 20)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 2,
            createdAt: Fixtures.makeDate(year: 2026, month: 4, day: 15)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 5, day: 3), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 5, day: 10), calendar: Fixtures.calendar)

        habit.log(on: Fixtures.makeDate(year: 2026, month: 6, day: 3), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 6, day: 8), calendar: Fixtures.calendar)

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        let completion = try XCTUnwrap(snapshot.completionHistory)
        XCTAssertEqual(completion.total, 3)   // Apr, May, Jun only
        XCTAssertEqual(completion.completed, 2)
    }

    func testMonthlyTrendWindowUsesSixBucketsAndLabel() throws {
        let anchorDate = Fixtures.makeDate(year: 2026, month: 3, day: 20)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 3, day: 1)
        )

        for day in [2, 5, 9] {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day), calendar: Fixtures.calendar)
        }

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )
        XCTAssertEqual(snapshot.trendBuckets.count, 6)

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        let trend = try XCTUnwrap(trendBlock(from: model))
        XCTAssertEqual(trend.heading, "Last 6 months")
    }

    func testPaceStatusUsesCalendarAlignedProjection() {
        let anchorDate = Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 12)

        let likelyHit = Fixtures.makeMonthlyCumulativeHabit(
            target: 20,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )
        likelyHit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 1, hour: 8), value: 6, calendar: Fixtures.calendar)
        likelyHit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 3, hour: 8), value: 6, calendar: Fixtures.calendar)

        let likelyShort = Fixtures.makeMonthlyCumulativeHabit(
            target: 20,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )
        likelyShort.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8), value: 1, calendar: Fixtures.calendar)

        let onTrackSnapshot = HabitInsightsEngine.snapshot(
            for: likelyHit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        let shortSnapshot = HabitInsightsEngine.snapshot(
            for: likelyShort,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        if case .likelyToHitTarget = onTrackSnapshot.pace.status {
            // expected
        } else {
            XCTFail("Expected likely-to-hit-target pace status")
        }

        if case .likelyShort = shortSnapshot.pace.status {
            // expected
        } else {
            XCTFail("Expected likely-short pace status")
        }
    }

    func testInsightsAlwaysUseTodayAnchorRegardlessOfLogAnchorDate() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let janAnchor = Fixtures.makeDate(year: 2026, month: 1, day: 10, hour: 12)
        let marAnchor = Fixtures.makeDate(year: 2026, month: 3, day: 10, hour: 12)

        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )
        for day in [1, 4, 9, 12, 18] {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let janModel = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: janAnchor,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        let marModel = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: marAnchor,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let janHero = try XCTUnwrap(heroBlock(from: janModel))
        let marHero = try XCTUnwrap(heroBlock(from: marModel))

        XCTAssertEqual(janHero.valueText, marHero.valueText)
        XCTAssertEqual(janHero.periodLabel, marHero.periodLabel)
    }

    func testInsightsIncludeMotivationCard() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        for day in [1, 2, 3, 4] {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: Fixtures.makeDate(year: 2026, month: 3, day: 5),
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let motivation = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertFalse(motivation.message.isEmpty)
    }

    func testProjectionMessagingWaitsForEnoughElapsedUnits() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 1, hour: 6)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 1, hour: 5), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: Fixtures.makeDate(year: 2026, month: 1, day: 20),
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let intent = try XCTUnwrap(intentBlock(from: model))
        XCTAssertEqual(intent.projectionText, "Log a bit more this month to get a stable projection.")
    }

    func testSnapshotSeparatesPeriodProgressAndProgressSoFar() {
        let anchorDate = Fixtures.makeDate(year: 2026, month: 2, day: 1, hour: 12)
        let now = Fixtures.makeDate(year: 2026, month: 2, day: 1, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        for day in [2, 3, 4, 5] {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(snapshot.currentPeriod.progressCount, 4)
        XCTAssertEqual(snapshot.currentPeriodSoFar.progressCount, 0)
    }

    private func trendBlock(from model: HabitInsightsViewModel) -> HabitInsightsTrendBlock? {
        for card in model.cards {
            if case .trend(let block) = card {
                return block
            }
        }
        return nil
    }

    private func heroBlock(from model: HabitInsightsViewModel) -> HabitInsightsHeroBlock? {
        for card in model.cards {
            if case .hero(let block) = card {
                return block
            }
        }
        return nil
    }

    private func motivationBlock(from model: HabitInsightsViewModel) -> MotivationCard? {
        for card in model.cards {
            if case .motivation(let block) = card {
                return block
            }
        }
        return nil
    }

    private func intentBlock(from model: HabitInsightsViewModel) -> HabitInsightsIntentBlock? {
        for card in model.cards {
            if case .intent(let block) = card {
                return block
            }
        }
        return nil
    }
}
