import XCTest
@testable import Habits

@MainActor
final class WidgetHabitMappingTests: XCTestCase {
    func testCumulativeGoalHabitIncludesProgressFractionForWidgetRing() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let habit = TestHabitFactory.cumulative(
            target: 3,
            entries: [
                .init(timestamp: date, value: 1),
                .init(timestamp: date, value: 1),
            ],
            calendar: calendar
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .goal)
        XCTAssertEqual(try XCTUnwrap(widgetHabit.progress), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertTrue(widgetHabit.hasActivityToday)
        XCTAssertFalse(widgetHabit.isCompleteToday)
    }

    func testFrequencyGoalHabitIncludesExplicitGoalTypeAndProgress() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let habit = TestHabitFactory.frequency(
            target: 3,
            entries: [
                .init(timestamp: date, value: 1),
                .init(timestamp: date, value: 1),
            ],
            calendar: calendar
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .goal)
        XCTAssertEqual(try XCTUnwrap(widgetHabit.progress), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertTrue(widgetHabit.hasActivityToday)
        XCTAssertFalse(widgetHabit.isCompleteToday)
    }

    func testBinaryHabitIncludesExplicitBinaryGoalType() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [],
            calendar: calendar
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .binary)
        XCTAssertNil(widgetHabit.progress)
        XCTAssertFalse(widgetHabit.hasActivityToday)
        XCTAssertFalse(widgetHabit.isCompleteToday)
    }

    func testBinaryHabitWithLogSetsHasActivityTodayTrue() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let habit = TestHabitFactory.frequency(
            target: 1,
            entries: [.init(timestamp: date, value: 1)],
            calendar: calendar
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .binary)
        XCTAssertNil(widgetHabit.progress)
        XCTAssertTrue(widgetHabit.hasActivityToday)
        XCTAssertTrue(widgetHabit.isCompleteToday)
    }

    func testGoalHabitWithNoProgressStillIncludesZeroProgress() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [],
            calendar: calendar
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .goal)
        XCTAssertEqual(widgetHabit.progress, 0)
        XCTAssertEqual(widgetHabit.goalProgress, 0)
        XCTAssertFalse(widgetHabit.isCompleteToday)
    }

    func testCumulativeGoalWithInvalidTargetStillMapsAsGoalWithZeroProgress() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let habit = Habit(
            name: "Savings",
            colorHex: "#123456",
            hasStreakGoal: true,
            goalPeriod: .daily,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: 0,
            unit: "USD",
            allowsDecimals: true,
            createdAt: date
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .goal)
        XCTAssertEqual(widgetHabit.progress, 0)
        XCTAssertFalse(widgetHabit.hasActivityToday)
    }

    func testGoalWidgetHabitDecoderDefaultsMissingExplicitProgressToZero() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "name": "Hydrate",
          "isCompleteToday": false,
          "streak": 0,
          "goalType": "goal"
        }
        """.data(using: .utf8)!

        let widgetHabit = try JSONDecoder().decode(WidgetHabit.self, from: json)

        XCTAssertEqual(widgetHabit.goalType, .goal)
        XCTAssertEqual(widgetHabit.progress, 0)
        XCTAssertEqual(widgetHabit.goalProgress, 0)
    }

    func testOpenEndedHabitUsesExplicitOpenEndedTypeWhenLoggedToday() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: date, value: 1)],
            calendar: calendar
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .openEnded)
        XCTAssertNil(widgetHabit.progress)
        XCTAssertTrue(widgetHabit.hasActivityToday)
        XCTAssertFalse(widgetHabit.isCompleteToday)
    }

    func testOpenEndedHabitUsesExplicitOpenEndedTypeWithoutLogsToday() throws {
        let calendar = TestDateFactory.utcCalendar
        let date = TestDateFactory.referenceNow
        let previousDay = TestDateFactory.addingDays(-1, to: date, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: previousDay, value: 1)],
            calendar: calendar
        )

        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits([habit], referenceDate: date, calendar: calendar).first
        )

        XCTAssertEqual(widgetHabit.goalType, .openEnded)
        XCTAssertNil(widgetHabit.progress)
        XCTAssertFalse(widgetHabit.hasActivityToday)
        XCTAssertFalse(widgetHabit.isCompleteToday)
    }

    func testWidgetHabitDecodesLegacyPayloadWithoutExplicitGoalType() throws {
        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Read",
          "isCompleteToday": false,
          "streak": 2,
          "iconName": "book",
          "colorHex": "#1F7A8C"
        }
        """.data(using: .utf8)!

        let widgetHabit = try JSONDecoder().decode(WidgetHabit.self, from: legacyJSON)

        XCTAssertEqual(widgetHabit.goalType, .binary)
        XCTAssertNil(widgetHabit.progress)
        XCTAssertFalse(widgetHabit.hasActivityToday)
        XCTAssertEqual(widgetHabit.name, "Read")
    }
}
