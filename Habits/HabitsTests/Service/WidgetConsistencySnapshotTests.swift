import XCTest
@testable import Habits

final class WidgetConsistencySnapshotTests: XCTestCase {
    func testConsistencySnapshotMatchesAggregatedSevenDayData() {
        let calendar = TestDateFactory.utcCalendar
        let referenceDate = TestDateFactory.referenceNow
        let days = lastSevenDays(referenceDate: referenceDate, calendar: calendar)

        let reading = makeHabit(
            name: "Read",
            recentActivity: [
                .init(date: days[1], value: 1),
                .init(date: days[2], value: 1),
                .init(date: days[4], value: 1),
                .init(date: days[6], value: 3),
            ]
        )
        let walking = makeHabit(
            name: "Walk",
            recentActivity: [
                .init(date: days[2], value: 1),
                .init(date: days[4], value: 2),
                .init(date: days[6], value: 2),
            ]
        )

        let snapshot = makeWidgetConsistencySnapshot(
            from: [reading, walking],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.days.map(\.intensity), [0, 1, 2, 0, 3, 0, 4])
        XCTAssertEqual(snapshot.activeDayCount, 4)
        XCTAssertEqual(snapshot.lastActiveDayIndex, 6)
        XCTAssertEqual(snapshot.summaryText, "4/7 days")
    }

    func testConsistencySnapshotShowsLowStateClearlyForZeroActivity() {
        let calendar = TestDateFactory.utcCalendar
        let referenceDate = TestDateFactory.referenceNow
        let habit = makeHabit(name: "Read", recentActivity: [])

        let snapshot = makeWidgetConsistencySnapshot(
            from: [habit],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.days.map(\.intensity), [0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(snapshot.activeDayCount, 0)
        XCTAssertNil(snapshot.lastActiveDayIndex)
        XCTAssertEqual(snapshot.summaryText, "0/7 days")
        XCTAssertFalse(snapshot.hasActivity)
    }

    private func makeHabit(
        name: String,
        recentActivity: [WidgetActivitySample]
    ) -> WidgetHabit {
        WidgetHabit(
            id: UUID(),
            name: name,
            isCompleteToday: false,
            streak: 0,
            goalType: .binary,
            progress: nil,
            hasActivityToday: false,
            iconName: nil,
            colorHex: "#1F7A8C",
            recentActivity: recentActivity
        )
    }

    private func lastSevenDays(
        referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        let today = calendar.startOfDay(for: referenceDate)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -6 + offset, to: today)
        }
    }
}
