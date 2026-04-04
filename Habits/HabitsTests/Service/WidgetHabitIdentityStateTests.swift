import XCTest
@testable import Habits

@MainActor
final class WidgetHabitIdentityStateTests: XCTestCase {
    func testIdentitySummaryUsesStateLabelAndRecentCompletionText() {
        let habit = makeHabit(
            identityState: .holding,
            recentActivity: samples(values: [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1])
        )

        let summary = habit.identityStateSummary

        XCTAssertEqual(summary.state, .holding)
        XCTAssertEqual(summary.shortLabel, "Holding")
        XCTAssertEqual(summary.recentCompletionText, "5 of last 7 days")
        XCTAssertEqual(summary.insightLine, "This habit is holding strong")
    }

    func testIdentitySummaryUsesReturningInsightCopy() {
        let habit = makeHabit(identityState: .returning, recentActivity: [])

        let summary = habit.identityStateSummary

        XCTAssertEqual(summary.insightLine, "You’re in the process of returning to this habit")
    }

    func testDecodingWithoutIdentityStateDefaultsToStarting() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000099",
          "name": "Read",
          "isCompleteToday": false,
          "streak": 0,
          "goalType": "binary"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WidgetHabit.self, from: json)
        XCTAssertEqual(decoded.identityState, .starting)
    }

    private func makeHabit(
        identityState: WidgetHabitIdentityState,
        recentActivity: [WidgetActivitySample]
    ) -> WidgetHabit {
        WidgetHabit(
            id: UUID(),
            name: "Habit",
            isCompleteToday: false,
            streak: 0,
            goalType: .binary,
            progress: nil,
            hasActivityToday: false,
            iconName: nil,
            colorHex: nil,
            identityState: identityState,
            recentActivity: recentActivity
        )
    }

    private func samples(values: [Double]) -> [WidgetActivitySample] {
        let calendar = TestDateFactory.utcCalendar
        let referenceDate = TestDateFactory.referenceNow

        return values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .day, value: -13 + index, to: referenceDate) else {
                return nil
            }

            return WidgetActivitySample(date: date, value: value)
        }
    }
}
