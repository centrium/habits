import XCTest
@testable import Habits

final class GoalProgressTests: XCTestCase {
    func testGoalProgressEdgeCases() {
        let cases: [(actual: Int, goal: Int, clamped: Int, extra: Int, fraction: Double, complete: Bool)] = [
            (actual: 0, goal: 1, clamped: 0, extra: 0, fraction: 0, complete: false),
            (actual: 1, goal: 1, clamped: 1, extra: 0, fraction: 1, complete: true),
            (actual: 2, goal: 1, clamped: 1, extra: 1, fraction: 1, complete: true),
            (actual: 3, goal: 2, clamped: 2, extra: 1, fraction: 1, complete: true)
        ]

        for progressCase in cases {
            let progress = GoalProgress(actual: progressCase.actual, goal: progressCase.goal)
            XCTAssertEqual(progress.clamped, progressCase.clamped)
            XCTAssertEqual(progress.extra, progressCase.extra)
            XCTAssertEqual(progress.fraction, progressCase.fraction, accuracy: 0.0001)
            XCTAssertEqual(progress.isComplete, progressCase.complete)
        }
    }
}
