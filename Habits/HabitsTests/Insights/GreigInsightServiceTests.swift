import XCTest
@testable import Habits

final class GreigInsightServiceTests: XCTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testProjectionIncludesDailyAverage() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 12, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 80, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 90, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 95, calendar: calendar),
        ]

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .cumulative(target: 500), period: .weekly),
            progress: GreigInsightProgress(
                currentTotal: 265,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: logs,
                unit: "£",
                formatValue: { value in "£\(Int(value.rounded()))" }
            )
        )

        XCTAssertEqual(insight?.confidence, .medium)
        XCTAssertTrue(insight?.title.contains("on track for about") ?? false)
        XCTAssertTrue(insight?.body?.contains("/day") ?? false)
    }

    func testLowConfidenceUsesSoftLanguage() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 10, hour: 20, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 80, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 90, calendar: calendar),
        ]

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .cumulative(target: 500), period: .weekly),
            progress: GreigInsightProgress(
                currentTotal: 170,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: logs,
                unit: "£",
                formatValue: { value in "£\(Int(value.rounded()))" }
            )
        )

        XCTAssertEqual(insight?.confidence, .low)
        XCTAssertTrue(insight?.title.contains("could reach around") ?? false)
        XCTAssertFalse(insight?.title.contains("on track for") ?? true)
        XCTAssertTrue(insight?.body?.contains("early estimate") ?? false)
    }

    func testHighStreakIncreasesConfidence() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 21, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 11, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 1, calendar: calendar),
        ]

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .frequency(target: 5), period: .weekly),
            progress: GreigInsightProgress(
                currentTotal: 4,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: logs
            )
        )

        XCTAssertEqual(insight?.confidence, .high)
        XCTAssertTrue(insight?.body?.contains("4-day streak") ?? false)
    }

    func testStrongPatternNotOverriddenByMissedToday() {
        let now = TestDateFactory.date(2026, 3, 12, hour: 20, calendar: calendar)
        let periodStart = TestDateFactory.date(2026, 3, 12, calendar: calendar)
        let periodEnd = TestDateFactory.addingDays(1, to: periodStart, calendar: calendar)
        let logs: [HabitLog] = (1...7).map { offset in
            TestHabitFactory.entryLog(
                on: TestDateFactory.addingDays(-offset, to: now, calendar: calendar),
                value: 1,
                calendar: calendar
            )
        }

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .open, period: .daily),
            progress: GreigInsightProgress(
                currentTotal: 0,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: logs
            )
        )

        XCTAssertEqual(insight?.title, "You've been consistent recently")
        XCTAssertTrue(insight?.body?.contains("7 of the last 8 days") ?? false)
        XCTAssertTrue(insight?.body?.contains("7-day streak") ?? false)
        XCTAssertTrue(insight?.body?.contains("Log today to keep that momentum going.") ?? false)
    }

    func testHighCompletionRateIsStrongConsistency() {
        let now = TestDateFactory.date(2026, 3, 12, hour: 20, calendar: calendar)
        let periodStart = TestDateFactory.date(2026, 3, 12, calendar: calendar)
        let periodEnd = TestDateFactory.addingDays(1, to: periodStart, calendar: calendar)
        let logs: [HabitLog] = (0...4).map { offset in
            TestHabitFactory.entryLog(
                on: TestDateFactory.addingDays(-offset, to: now, calendar: calendar),
                value: 1,
                calendar: calendar
            )
        }

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .open, period: .daily),
            progress: GreigInsightProgress(
                currentTotal: 0,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: logs
            )
        )

        XCTAssertEqual(insight?.title, "You've been consistent recently")
        XCTAssertEqual(insight?.confidence, .high)
    }

    func testProjectionAlwaysHasExplanation() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 12, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 9, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 10, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 3, 12, calendar: calendar), value: 1, calendar: calendar),
        ]

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .frequency(target: 6), period: .weekly),
            progress: GreigInsightProgress(
                currentTotal: 3,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: logs
            )
        )

        XCTAssertTrue(insight?.title.contains("on track") ?? false)
        XCTAssertNotNil(insight?.body)
        XCTAssertTrue(insight?.body?.contains("/day") ?? false)
    }

    func testNoProjectionWithoutExplanation() {
        let periodStart = TestDateFactory.date(2026, 3, 9, calendar: calendar)
        let periodEnd = TestDateFactory.date(2026, 3, 16, calendar: calendar)
        let now = TestDateFactory.date(2026, 3, 12, hour: 12, calendar: calendar)

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .cumulative(target: 500), period: .weekly),
            progress: GreigInsightProgress(
                currentTotal: 0,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: [],
                unit: "£",
                formatValue: { value in "£\(Int(value.rounded()))" }
            )
        )

        XCTAssertTrue(insight?.title.contains("Projection needs more data") ?? false)
        XCTAssertTrue(insight?.body?.contains("of the last") ?? false)
        XCTAssertFalse(insight?.title.contains("on track for") ?? true)
    }

    func testNoLastOneDayMessaging() {
        let now = TestDateFactory.date(2026, 3, 12, hour: 20, calendar: calendar)
        let periodStart = TestDateFactory.date(2026, 3, 12, calendar: calendar)
        let periodEnd = TestDateFactory.addingDays(1, to: periodStart, calendar: calendar)

        let insight = makeInsight(
            goal: GreigInsightGoal(kind: .open, period: .daily),
            progress: GreigInsightProgress(
                currentTotal: 0,
                periodStart: periodStart,
                periodEnd: periodEnd,
                now: now,
                logs: []
            )
        )

        XCTAssertFalse(insight?.title.lowercased().contains("last 1 day") ?? true)
        XCTAssertFalse(insight?.body?.lowercased().contains("last 1 day") ?? true)
    }

    private func makeInsight(
        goal: GreigInsightGoal,
        progress: GreigInsightProgress
    ) -> GreigInsight? {
        GreigInsightService(calendar: calendar).generateInsight(for: goal, progress: progress)
    }
}
