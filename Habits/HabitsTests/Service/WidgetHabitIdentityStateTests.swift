import XCTest
@testable import Habits

@MainActor
final class WidgetHabitIdentityStateTests: BaseTestCase {
    func testIdentitySummaryUsesStateLabelAndRecentCompletionText() {
        let habit = makeHabit(
            identityState: .building,
            recentActivity: samples(values: [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1])
        )

        let summary = habit.identityStateSummary

        XCTAssertEqual(summary.state, .building)
        XCTAssertEqual(summary.shortLabel, "Build")
        XCTAssertEqual(summary.recentCompletionText, "5 days this week")
        XCTAssertEqual(summary.insightLine, "This habit is taking shape.")
    }

    func testIdentitySummaryUsesRebuildingInsightCopy() {
        let habit = makeHabit(identityState: .rebuilding, recentActivity: [])

        let summary = habit.identityStateSummary

        XCTAssertEqual(summary.insightLine, "This habit is getting back into it.")
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
        XCTAssertEqual(decoded.identityState, .gettingStarted)
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
