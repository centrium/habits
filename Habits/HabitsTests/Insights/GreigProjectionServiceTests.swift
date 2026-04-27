import XCTest
@testable import Habits

final class GreigProjectionServiceTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testMinimumWindowIsSevenDays() {
        let now = TestDateFactory.date(2026, 3, 12, hour: 10, calendar: calendar)
        let periodStart = calendar.startOfDay(for: now)
        let periodEnd = TestDateFactory.addingDays(1, to: periodStart, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: now, value: 1, calendar: calendar),
        ]

        let progress = GreigInsightProgress(
            currentTotal: 1,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )
        let goal = GreigInsightGoal(kind: .open, period: .daily)

        let result = GreigProjectionService(calendar: calendar).projection(for: goal, progress: progress)

        XCTAssertEqual(result?.behaviourWindowDays, 7)
    }

    func testProjectionCapsOutliers() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 10, calendar: calendar)

        let baselineLogs = (0..<7).map { offset in
            TestHabitFactory.entryLog(
                on: TestDateFactory.date(2026, 3, 2 + offset, calendar: calendar),
                value: 10,
                calendar: calendar
            )
        }
        let spike = TestHabitFactory.entryLog(
            on: TestDateFactory.date(2026, 3, 11, hour: 8, calendar: calendar),
            value: 200,
            calendar: calendar
        )

        let progress = GreigInsightProgress(
            currentTotal: 200,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: baselineLogs + [spike],
            unit: "£"
        )
        let goal = GreigInsightGoal(kind: .cumulative(target: 100), period: .weekly)

        let result = GreigProjectionService(calendar: calendar).projection(for: goal, progress: progress)

        guard let projection = result else {
            XCTFail("Expected projection for capped outlier case")
            return
        }

        guard let dailyAverage = projection.dailyAverage else {
            XCTFail("Expected dailyAverage for capped outlier case")
            return
        }
        XCTAssertEqual(dailyAverage, 15, accuracy: 0.001)
        guard let projectedTotal = projection.projectedTotal else {
            XCTFail("Expected projectedTotal for capped outlier case")
            return
        }
        XCTAssertEqual(projectedTotal, 105, accuracy: 0.001)
    }

    func testHighStreakIncreasesConfidence() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 18, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 1, calendar: calendar),
        ]

        let progress = GreigInsightProgress(
            currentTotal: 4,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            logs: logs
        )
        let goal = GreigInsightGoal(kind: .frequency(target: 5), period: .weekly)

        let result = GreigProjectionService(calendar: calendar).projection(for: goal, progress: progress)

        XCTAssertEqual(result?.currentStreak, 4)
        XCTAssertEqual(result?.confidence, .high)
    }
}
