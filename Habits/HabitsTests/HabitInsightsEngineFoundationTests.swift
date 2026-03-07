import XCTest
@testable import Habits

final class HabitInsightsEngineFoundationTests: XCTestCase {
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
    }

    func testFrequencyGoalAchievementUsesFrequencyProgress() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 5)
        let habit = Habit(
            name: "Walk",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 3,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 3), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 4), calendar: Fixtures.calendar)

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(snapshot.currentPeriod.progress, 2, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentPeriod.target, 3, accuracy: 0.0001)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        let achievement = try XCTUnwrap(achievementBlock(from: model))
        XCTAssertEqual(achievement.progressText, "2 / 3")
    }

    func testCumulativeGoalAchievementUsesCumulativeProgress() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20)
        let habit = Habit(
            name: "Run",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: 20,
            unit: "km",
            allowsDecimals: true,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 2), value: 5, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 10), value: 7, calendar: Fixtures.calendar)

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(snapshot.currentPeriod.progress, 12, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currentPeriod.target, 20, accuracy: 0.0001)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        let achievement = try XCTUnwrap(achievementBlock(from: model))
        XCTAssertEqual(achievement.progressText, "12 / 20")
    }

    func testOpenEndedAchievementShowsActivityCountOnly() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20)
        let habit = Habit(
            name: "Journal",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 9), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 10), calendar: Fixtures.calendar)

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(snapshot.currentPeriod.progress, 3, accuracy: 0.0001)
        XCTAssertNil(snapshot.currentPeriod.target)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        let achievement = try XCTUnwrap(achievementBlock(from: model))
        XCTAssertEqual(achievement.progressText, "3")
    }

    func testTrendUsesLastSixCalendarMonthsForOpenEndedHabit() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20)
        let habit = Habit(
            name: "Journal",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2025, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 1, day: 5), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 4), calendar: Fixtures.calendar)

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(foundation.trend.months.count, 6)

        let expectedStarts: [Date] = [
            Fixtures.makeDate(year: 2025, month: 10, day: 1, hour: 0),
            Fixtures.makeDate(year: 2025, month: 11, day: 1, hour: 0),
            Fixtures.makeDate(year: 2025, month: 12, day: 1, hour: 0),
            Fixtures.makeDate(year: 2026, month: 1, day: 1, hour: 0),
            Fixtures.makeDate(year: 2026, month: 2, day: 1, hour: 0),
            Fixtures.makeDate(year: 2026, month: 3, day: 1, hour: 0)
        ]
        XCTAssertEqual(foundation.trend.months.map(\.monthStart), expectedStarts)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        let trend = try XCTUnwrap(trendBlock(from: model))
        XCTAssertEqual(trend.points.count, 6)
        XCTAssertFalse(trend.isCompletionRatioBars)
    }

    func testConsistencyNeverExceedsOneHundredPercent() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 31, hour: 10)
        let habit = Habit(
            name: "Read",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1, hour: 8)
        )

        for day in 1...30 {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 9), calendar: Fixtures.calendar)
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 11), calendar: Fixtures.calendar)
        }

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertLessThanOrEqual(foundation.consistency.activeDayRatio, 1.0)
        XCTAssertEqual(foundation.consistency.activeDayRatio, 1.0, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(foundation.consistency.averageActiveDaysPerWeek, 7.0)
        XCTAssertEqual(foundation.consistency.averageActiveDaysPerWeek, 30.0 / 4.3, accuracy: 0.0001)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )
        XCTAssertFalse(model.cards.isEmpty)
    }

    func testConsistencyUsesUniqueActiveDaysWithinRollingThirtyDayWindow() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 12, hour: 12)
        let habit = Habit(
            name: "Read",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 3,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 2, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 10), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 12), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 8, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 12, hour: 8), calendar: Fixtures.calendar)

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(foundation.consistency.activeDayRatio, 4.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(foundation.consistency.averageActiveDaysPerWeek, 4.0 / 4.3, accuracy: 0.0001)
    }

    func testConsistencyForCumulativeHabitStillUsesActiveDaysNotValues() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 12, hour: 12)
        let habit = Habit(
            name: "Run",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: 20,
            unit: "km",
            allowsDecimals: true,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8), value: 12, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 10), value: 8, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 6, hour: 8), value: 1, calendar: Fixtures.calendar)

        let foundation = HabitInsightsEngine.habitInsightSnapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(foundation.consistency.activeDayRatio, 2.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(foundation.consistency.averageActiveDaysPerWeek, 2.0 / 4.3, accuracy: 0.0001)
    }

    func testGoalBasedMonthlyStreakIncludesCurrentPeriodWhenTargetAlreadyMet() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Walk",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .frequency,
            streakTarget: 2,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: 2), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: 8), calendar: Fixtures.calendar)

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 1), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5), calendar: Fixtures.calendar)

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(snapshot.streak.current, 2)
    }

    func testGoalBasedMonthlyStreakBreaksAtFirstMissedPeriod() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Walk",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .frequency,
            streakTarget: 2,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 1, day: 3), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 1, day: 5), calendar: Fixtures.calendar)

        habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: 9), calendar: Fixtures.calendar)

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 1), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 3), calendar: Fixtures.calendar)

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(snapshot.streak.current, 1)
        XCTAssertEqual(snapshot.streak.longest, 1)
    }

    func testGoalBasedMonthlyStreakDoesNotClipToCreatedAtBoundary() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Walk",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .frequency,
            streakTarget: 8,
            createdAt: Fixtures.makeDate(year: 2026, month: 3, day: 2)
        )

        for day in 1...8 {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: day, hour: 8), calendar: Fixtures.calendar)
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let snapshot = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: now,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertEqual(snapshot.streak.current, 2)
        XCTAssertEqual(snapshot.streak.longest, 2)
    }

    func testGoalHabitMomentumUsesPaceProjectionMessage() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 6, hour: 12)
        let habit = Habit(
            name: "Walk",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 3,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 2, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 4, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 6, hour: 8), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let momentum = try XCTUnwrap(momentumBlock(from: model))
        XCTAssertFalse(momentum.paceText.isEmpty)
    }

    func testOpenEndedMomentumUsesActivitySummaryMessage() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 12, hour: 12)
        let habit = Habit(
            name: "Journal",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 10, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 11, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 12, hour: 8), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let momentum = try XCTUnwrap(momentumBlock(from: model))
        XCTAssertFalse(momentum.paceText.isEmpty)
        XCTAssertFalse(momentum.paceText.contains("goal"))
    }

    func testBehaviourInsightsAppearWhenEnoughSamplesExist() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Journal",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 3, hour: 19), calendar: Fixtures.calendar)  // Monday
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 10, hour: 20), calendar: Fixtures.calendar) // Monday
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 17, hour: 21), calendar: Fixtures.calendar) // Monday
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 19), calendar: Fixtures.calendar)  // Wednesday
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 7, hour: 19), calendar: Fixtures.calendar)  // Friday

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let behaviour = try XCTUnwrap(behaviourInsightsBlock(from: model))
        XCTAssertFalse(behaviour.observations.isEmpty)
        XCTAssertFalse(behaviour.suggestion.isEmpty)
    }

    func testBehaviourInsightsAreHiddenBelowMinimumSampleSize() {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Journal",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 3, hour: 19), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 4, hour: 19), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 19), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 6, hour: 19), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertNil(behaviourInsightsBlock(from: model))
    }

    func testOpenEndedHabitUsesActivityCardAndHidesAchievementCard() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 12, hour: 12)
        let habit = Habit(
            name: "Journal",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 10, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 11, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 12, hour: 8), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        XCTAssertNil(achievementBlock(from: model))
        let activity = try XCTUnwrap(intentBlock(from: model))
        XCTAssertEqual(activity.heading, "Activity")
    }

    func testMomentumCardUsesMotivatingStreakFormat() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 6, hour: 12)
        let habit = Habit(
            name: "Walk",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 2,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 2, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 4, hour: 8), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let momentum = try XCTUnwrap(momentumBlock(from: model))
        XCTAssertFalse(momentum.currentStreakText.contains("🔥"))
        XCTAssertTrue(momentum.longestStreakText.hasPrefix("Best:"))
    }

    func testTrendIncludesInterpretationText() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Run",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: 20,
            unit: "km",
            allowsDecimals: true,
            createdAt: Fixtures.makeDate(year: 2025, month: 10, day: 1)
        )

        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 1, day: 10), value: 8, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 2, day: 10), value: 12, calendar: Fixtures.calendar)
        habit.logValue(on: Fixtures.makeDate(year: 2026, month: 3, day: 10), value: 16, calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let trend = try XCTUnwrap(trendBlock(from: model))
        XCTAssertNotNil(trend.insightText)
    }

    func testMomentumStreakGrammarUsesSingularCadenceUnit() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Run",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .frequency,
            streakTarget: 2,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: 1), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: 2), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 1), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 2), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let momentum = try XCTUnwrap(momentumBlock(from: model))
        XCTAssertTrue(momentum.currentStreakText.contains("month streak"))
        XCTAssertFalse(momentum.currentStreakText.contains("months streak"))
    }

    func testTrendStableMessageWhenLatestEqualsPrevious() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Journal",
            colorHex: "#00AA88",
            hasStreakGoal: false,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2025, month: 10, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 2, day: 5), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let trend = try XCTUnwrap(trendBlock(from: model))
        XCTAssertEqual(trend.insightText, "You've stayed consistent recently")
    }

    func testCoachingCardAppearsFirst() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Walk",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .weekly,
            goalType: .frequency,
            streakTarget: 3,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 18, hour: 8), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        guard let first = model.cards.first else {
            return XCTFail("Expected first card")
        }
        if case .motivation = first {
            // expected
        } else {
            XCTFail("Coaching card should be first")
        }
    }

    func testCoachingShowsStreakProtectionWhenNotLoggedToday() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Meditate",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        // Build an active streak through yesterday, no log today.
        for day in 12...19 {
            habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: day, hour: 8), calendar: Fixtures.calendar)
        }

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let coaching = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertTrue(coaching.message.contains("Log today to keep your"))
        XCTAssertTrue(coaching.message.contains("streak alive"))
        XCTAssertFalse(coaching.headline.isEmpty)
        XCTAssertFalse(coaching.supportingText.isEmpty)
    }

    func testCoachingBehindPaceIncludesNumericAction() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 15, hour: 12)
        let habit = Habit(
            name: "Exercise",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .monthly,
            goalType: .frequency,
            streakTarget: 12,
            createdAt: Fixtures.makeDate(year: 2026, month: 1, day: 1)
        )

        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 1, hour: 8), calendar: Fixtures.calendar)
        habit.log(on: Fixtures.makeDate(year: 2026, month: 3, day: 5, hour: 8), calendar: Fixtures.calendar)

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let coaching = try XCTUnwrap(motivationBlock(from: model))
        XCTAssertTrue(coaching.headline.contains("behind pace"))
        XCTAssertTrue(coaching.supportingText.contains("sessions"))
    }

    func testMomentumShowsEncouragingEmptyStateWhenNoStreak() throws {
        let now = Fixtures.makeDate(year: 2026, month: 3, day: 20, hour: 12)
        let habit = Habit(
            name: "Read",
            colorHex: "#00AA88",
            hasStreakGoal: true,
            goalPeriod: .daily,
            goalType: .frequency,
            streakTarget: 1,
            createdAt: Fixtures.makeDate(year: 2026, month: 3, day: 1)
        )

        let model = HabitInsightsEngine.insights(
            for: habit,
            calendar: Fixtures.calendar,
            weekStartPreference: Fixtures.weekStart,
            now: now
        )

        let momentum = try XCTUnwrap(momentumBlock(from: model))
        XCTAssertEqual(momentum.currentStreakText, "No streak yet")
        XCTAssertEqual(momentum.longestStreakText, "Start today to begin your streak")
        XCTAssertEqual(momentum.paceText, "Your streak begins with the next log")
    }

    private func achievementBlock(from model: HabitInsightsViewModel) -> HabitInsightsAchievementBlock? {
        for card in model.cards {
            if case .achievement(let block) = card {
                return block
            }
        }
        return nil
    }

    private func trendBlock(from model: HabitInsightsViewModel) -> HabitInsightsTrendBlock? {
        for card in model.cards {
            if case .trend(let block) = card {
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
