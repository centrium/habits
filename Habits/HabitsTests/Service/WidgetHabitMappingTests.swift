import XCTest
@testable import Habits

@MainActor
final class WidgetHabitMappingTests: BaseTestCase {

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
        XCTAssertEqual(widgetHabit.identityState, .gettingStarted)
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
        XCTAssertEqual(widgetHabit.identityState, .gettingStarted)
        XCTAssertEqual(widgetHabit.name, "Read")
    }

    func testGoalWidgetHabitWithNonFiniteProgressNormalizesToZeroAndEncodes() throws {
        let habit = WidgetHabit(
            id: UUID(),
            name: "Hydrate",
            isCompleteToday: false,
            streak: 0,
            goalType: .goal,
            progress: .nan,
            hasActivityToday: true,
            iconName: nil,
            colorHex: "#00AEEF"
        )

        XCTAssertEqual(habit.progress, 0)
        XCTAssertEqual(habit.goalProgress, 0)
        XCTAssertNoThrow(try JSONEncoder().encode(habit))
    }

    func testNonGoalWidgetHabitWithNonFiniteProgressDropsProgressValue() {
        let habit = WidgetHabit(
            id: UUID(),
            name: "Read",
            isCompleteToday: true,
            streak: 5,
            goalType: .binary,
            progress: .infinity,
            hasActivityToday: true,
            iconName: "book",
            colorHex: "#1F7A8C"
        )

        XCTAssertNil(habit.progress)
    }

    private func activityValue(
        on date: Date,
        in widgetHabit: WidgetHabit,
        calendar: Calendar
    ) -> Double {
        let day = calendar.startOfDay(for: date)
        return widgetHabit.recentActivity.first(where: {
            calendar.isDate($0.date, inSameDayAs: day)
        })?.value ?? -1
    }
}
