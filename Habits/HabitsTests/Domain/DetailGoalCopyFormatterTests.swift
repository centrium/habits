import XCTest
@testable import Habits

final class DetailGoalCopyFormatterTests: XCTestCase {
    func testSummaryUsesDailyLabel() {
        let text = DetailGoalCopyFormatter.summaryText(
            currentText: "1",
            targetText: "2",
            goalPeriod: .daily
        )
        XCTAssertEqual(text, "1 of 2 today")
    }

    func testSummaryUsesWeeklyLabel() {
        let text = DetailGoalCopyFormatter.summaryText(
            currentText: "3",
            targetText: "4",
            goalPeriod: .weekly
        )
        XCTAssertEqual(text, "3 of 4 this week")
    }

    func testSummaryUsesMonthlyLabel() {
        let text = DetailGoalCopyFormatter.summaryText(
            currentText: "£10",
            targetText: "£10",
            goalPeriod: .monthly
        )
        XCTAssertEqual(text, "£10 of £10 this month")
        XCTAssertFalse(text.contains("today"))
    }

    func testSummaryUsesYearlyLabel() {
        let text = DetailGoalCopyFormatter.summaryText(
            currentText: "50",
            targetText: "100",
            goalPeriod: .yearly
        )
        XCTAssertEqual(text, "50 of 100 this year")
    }

    func testFrequencyRemainingUsesPeriodLabel() {
        let text = DetailGoalCopyFormatter.remainingFrequencyText(
            baseSummary: "2 of 5 this month",
            remainingCount: 3,
            goalPeriod: .monthly
        )
        XCTAssertEqual(text, "2 of 5 this month • 3 more to hit this month")
        XCTAssertFalse(text.contains("today"))
    }
}
