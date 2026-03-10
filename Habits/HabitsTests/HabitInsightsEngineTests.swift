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
        XCTAssertEqual(insightsSnapshot.currentPeriod.progress, 8, accuracy: 0.0001)
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

    func testProjectionChangesWhenAnchorDateChanges() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 25, hour: 9)
        let habit = Habit(
            name: "Dog Walking",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        for _ in 0..<5 {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 21, hour: 8), calendar: Fixtures.calendar)
        }

        let mar15 = Fixtures.makeDate(year: 2026, month: 3, day: 15, hour: 12)
        let mar22 = Fixtures.makeDate(year: 2026, month: 3, day: 22, hour: 12)

        let earlySnapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: mar15,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let lateSnapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: mar22,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(earlySnapshot.currentPeriod.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(lateSnapshot.currentPeriod.progress, 5, accuracy: 0.0001)

        let earlyFoundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: mar15,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let lateFoundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: mar22,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let earlyPace = try XCTUnwrap(earlyFoundation.pace)
        let latePace = try XCTUnwrap(lateFoundation.pace)
        XCTAssertNotEqual(earlyPace.projectedTotal, latePace.projectedTotal, accuracy: 0.0001)
    }

    func testTrendBucketsIncludePreCreationMonthsAsZeros() {
        let anchorDate = Fixtures.makeDate(year: 2026, month: 6, day: 20)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 2,
            createdAt: Fixtures.makeDate(year: 2026, month: 4, day: 15)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 5, day: 3), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 5, day: 10), calendar: Fixtures.calendar)

        habit.log(on: Fixtures.makeDate(year: 2026, month: 6, day: 3), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 6, day: 8), calendar: Fixtures.calendar)

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        XCTAssertEqual(foundation.trend.months.count, 6)
        let totals = foundation.trend.months.map(\.total)
        let expectedTotals: [Double] = [0, 0, 0, 0, 2, 2]
        XCTAssertEqual(totals.count, expectedTotals.count)
        for (actual, expected) in zip(totals, expectedTotals) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
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

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )
        XCTAssertEqual(foundation.trend.months.count, 6)

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

        let onTrackSnapshot = HabitInsightsEngine.habitInsightSnapshot(
            for: likelyHit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        let shortSnapshot = HabitInsightsEngine.habitInsightSnapshot(
            for: likelyShort,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: anchorDate
        )

        let onTrackPace = try? XCTUnwrap(onTrackSnapshot.pace)
        if case .likelyToHitTarget = onTrackPace?.status {
            // expected
        } else {
            XCTFail("Expected likely-to-hit-target pace status")
        }

        let shortPace = try? XCTUnwrap(shortSnapshot.pace)
        if case .likelyShort = shortPace?.status {
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

        let janAchievement = try XCTUnwrap(achievementBlock(from: janModel))
        let marAchievement = try XCTUnwrap(achievementBlock(from: marModel))

        XCTAssertEqual(janAchievement.progressText, marAchievement.progressText)
    }

    func testInsightsIncludeMotivationMessage() throws {
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

        let momentum = try XCTUnwrap(momentumBlock(from: model))
        XCTAssertEqual(momentum.paceText, "Log a bit more this month to get a stable projection.")
    }

    func testSnapshotSeparatesPeriodProgressAndProgressSoFar() throws {
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

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: anchorDate,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        let pace = try XCTUnwrap(foundation.pace)

        XCTAssertEqual(snapshot.currentPeriod.progress, 4, accuracy: 0.0001)
        XCTAssertEqual(pace.projectedTotal, 0, accuracy: 0.0001)
    }

    func testLastSixMonthsUsesHistoricalMonthlySummaries() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 4,
            createdAt: Fixtures.makeDate(year: 2025, month: 8, day: 1)
        )

        // Oct (0), Nov (2), Dec (4), Jan (3), Feb (4), Mar (1)
        [5, 12].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2025, month: 11, day: day, hour: 8), calendar: Fixtures.calendar)
        }
        [1, 7, 14, 21].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2025, month: 12, day: day, hour: 8), calendar: Fixtures.calendar)
        }
        [3, 10, 17].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 1, day: day, hour: 8), calendar: Fixtures.calendar)
        }
        [4, 11, 18, 25].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: day, hour: 8), calendar: Fixtures.calendar)
        }
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8), calendar: Fixtures.calendar)

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(foundation.trend.months.count, 6)
        let totals = foundation.trend.months.map(\.total)
        let expectedTotals: [Double] = [0, 2, 4, 3, 4, 1]
        XCTAssertEqual(totals.count, expectedTotals.count)
        for (actual, expected) in zip(totals, expectedTotals) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }

        let targets = foundation.trend.months.map { $0.target ?? 0 }
        let expectedTargets: [Double] = [4, 4, 4, 4, 4, 4]
        XCTAssertEqual(targets.count, expectedTargets.count)
        for (actual, expected) in zip(targets, expectedTargets) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
        let ratios = foundation.trend.months.compactMap(\.completionRatio)
        let expectedRatios: [Double] = [0, 0.5, 1, 0.75, 1, 0.25]
        XCTAssertEqual(ratios.count, expectedRatios.count)
        for (actual, expected) in zip(ratios, expectedRatios) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
    }

    func testMonthlyTrendCardUsesCompletionRatioBarsFromLastSixMonths() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 4,
            createdAt: Fixtures.makeDate(year: 2025, month: 8, day: 1)
        )

        [1, 8, 15, 22].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: day, hour: 8), calendar: Fixtures.calendar)
        }
        [3, 10].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let trend = try XCTUnwrap(trendBlock(from: model))
        XCTAssertTrue(trend.isCompletionRatioBars)
        XCTAssertEqual(try XCTUnwrap(trend.targetLine), 1, accuracy: 0.0001)
        XCTAssertEqual(trend.points.count, 6)
        let trailingValues = Array(trend.points.suffix(2).map(\.value))
        XCTAssertEqual(trailingValues[0], 1, accuracy: 0.0001)
        XCTAssertEqual(trailingValues[1], 0.5, accuracy: 0.0001)
    }

    func testMotivationCelebratesEarlyGoalCompletion() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 10, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 3,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        [1, 2, 3].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        let motivation = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertTrue(motivation.supportingText.contains("hit your goal early"))
    }

    func testBehaviourInsightsHiddenForLimitedData() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        [1, 4, 7].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertNil(behaviourInsightsBlock(from: model))
    }

    func testBehaviourInsightsDoesNotShowLargeMilestoneValues() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 50,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        [1, 3, 5, 7, 9].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let behaviour = try XCTUnwrap(behaviourInsightsBlock(from: model))
        XCTAssertFalse(behaviour.observations.contains { $0.contains("48") && $0.contains("milestone") })
        XCTAssertFalse(behaviour.suggestion.contains("48") && behaviour.suggestion.contains("milestone"))
    }

    func testBehaviourInsightsUsesAtMostThreeLines() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Fixtures.makeMonthlyFrequencyHabit(
            target: 7,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        [1, 2, 3, 5, 7, 9, 11].forEach { day in
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let behaviour = try XCTUnwrap(behaviourInsightsBlock(from: model))
        XCTAssertLessThanOrEqual(behaviour.observations.count + 1, 3)
        XCTAssertFalse(behaviour.suggestion.isEmpty)
    }

    func testBehaviourInsightSuggestionUsesTodayWhenWeakestDayIsToday() throws {
        let now = firstDate(
            onOrAfter: Fixtures.makeDate(year: 2026, month: 3, day: 1),
            weekday: 2 // Monday
        )
        let habit = makeBehaviourInsightHabit(weakestWeekday: 2, strongestWeekday: 4)

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let motivation = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertEqual(motivation.supportingText, "Today is a great day for a quick check-in")
    }

    func testBehaviourInsightSuggestionUsesTomorrowWhenWeakestDayIsTomorrow() throws {
        let now = firstDate(
            onOrAfter: Fixtures.makeDate(year: 2026, month: 3, day: 1),
            weekday: 1 // Sunday
        )
        let habit = makeBehaviourInsightHabit(weakestWeekday: 2, strongestWeekday: 4)

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let motivation = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertEqual(motivation.supportingText, "Try a quick check-in tomorrow")
    }

    func testBehaviourInsightSuggestionUsesLaterThisWeekWhenWeakestDayIsAhead() throws {
        let now = firstDate(
            onOrAfter: Fixtures.makeDate(year: 2026, month: 3, day: 1),
            weekday: 3 // Tuesday
        )
        let habit = makeBehaviourInsightHabit(weakestWeekday: 6, strongestWeekday: 4)

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let motivation = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertEqual(motivation.supportingText, "A quick check-in later this week could strengthen your routine")
    }

    func testBehaviourInsightSuggestionUsesEarlyNextWeekWhenWeakestDayHasPassed() throws {
        let now = firstDate(
            onOrAfter: Fixtures.makeDate(year: 2026, month: 3, day: 1),
            weekday: 7 // Saturday
        )
        let habit = makeBehaviourInsightHabit(weakestWeekday: 6, strongestWeekday: 4)

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let motivation = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertEqual(motivation.supportingText, "A quick check-in early next week could strengthen your routine")
    }

    func testBehaviourInsightsSuggestionUsesRelativeTimeWhenWeakestDayHasPassed() throws {
        let now = firstDate(
            onOrAfter: Fixtures.makeDate(year: 2026, month: 3, day: 1),
            weekday: 7 // Saturday
        )
        let habit = makeBehaviourInsightHabit(weakestWeekday: 6, strongestWeekday: 4) // Friday weakest

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let behaviour = try XCTUnwrap(behaviourInsightsBlock(from: model))
        XCTAssertTrue(behaviour.suggestion.contains("early next week"))
        XCTAssertFalse(behaviour.suggestion.contains("Friday"))
    }

    func testBehaviourInsightsUsesTonightPhrasingForEveningWindowToday() throws {
        let now = firstDate(
            onOrAfter: Fixtures.makeDate(year: 2026, month: 3, day: 1),
            weekday: 6 // Friday
        )
        let habit = makeBehaviourInsightHabit(
            weakestWeekday: 6,
            strongestWeekday: 4,
            commonHour: 21
        )

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let behaviour = try XCTUnwrap(behaviourInsightsBlock(from: model))
        XCTAssertTrue(behaviour.suggestion.contains("tonight"))
        XCTAssertFalse(behaviour.suggestion.contains("today night"))
    }

    func testBehaviourInsightsSuggestionReferencesGoalWhenHabitHasGoal() throws {
        let now = firstDate(
            onOrAfter: Fixtures.makeDate(year: 2026, month: 3, day: 1),
            weekday: 6 // Friday
        )
        let habit = Habit(
            name: "Workout",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 4,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )

        let firstDay = Fixtures.makeDate(year: 2026, month: 1, day: 1, hour: 20)
        dates(onOrAfter: firstDay, matchingWeekday: 4, count: 4).forEach { date in
            habit.log(on: date, calendar: Fixtures.calendar)
        }
        dates(onOrAfter: firstDay, matchingWeekday: 6, count: 1).forEach { date in
            habit.log(on: date, calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            logAnchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let behaviour = try XCTUnwrap(behaviourInsightsBlock(from: model))
        XCTAssertTrue(behaviour.suggestion.contains("goal"))
        XCTAssertTrue(behaviour.suggestion.contains("week"))
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

    private func achievementBlock(from model: HabitInsightsViewModel) -> HabitInsightsAchievementBlock? {
        for card in model.cards {
            if case .achievement(let block) = card {
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

    private func momentumBlock(from model: HabitInsightsViewModel) -> HabitInsightsMomentumBlock? {
        for card in model.cards {
            if case .momentum(let block) = card {
                return block
            }
        }
        return nil
    }

    private func behaviourInsightsBlock(from model: HabitInsightsViewModel) -> HabitInsightsBehaviourBlock? {
        for card in model.cards {
            if case .behaviourInsights(let block) = card {
                return block
            }
        }
        return nil
    }

    private func makeBehaviourInsightHabit(
        weakestWeekday: Int,
        strongestWeekday: Int,
        commonHour: Int = 8
    ) -> Habit {
        let habit = Habit(
            name: "Journaling",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )

        let firstDay = Fixtures.makeDate(year: 2026, month: 1, day: 1, hour: commonHour)
        dates(onOrAfter: firstDay, matchingWeekday: strongestWeekday, count: 4).forEach { date in
            habit.log(on: date, calendar: Fixtures.calendar)
        }
        dates(onOrAfter: firstDay, matchingWeekday: weakestWeekday, count: 1).forEach { date in
            habit.log(on: date, calendar: Fixtures.calendar)
        }

        return habit
    }

    private func dates(
        onOrAfter start: Date,
        matchingWeekday weekday: Int,
        count: Int
    ) -> [Date] {
        var matches: [Date] = []
        var cursor = start
        while matches.count < count {
            if Fixtures.calendar.component(.weekday, from: cursor) == weekday {
                matches.append(cursor)
            }
            cursor = Fixtures.calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return matches
    }

    private func firstDate(
        onOrAfter start: Date,
        weekday: Int
    ) -> Date {
        var cursor = start
        while Fixtures.calendar.component(.weekday, from: cursor) != weekday {
            cursor = Fixtures.calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return cursor
    }
}
