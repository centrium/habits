import XCTest
@testable import Habits

@MainActor
final class IdentityStateEngineTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar

    func testGatedIdentityStateScenarioOneOneLogIsStart() {
        let gated = IdentityStateEngine.gatedIdentityState(
            rawState: .strong,
            totalLogs: 1,
            uniqueDays: 1,
            activeDaysLast14: 1
        )
        XCTAssertEqual(gated, .start)
    }

    func testGatedIdentityStateScenarioTwoThreeUniqueDaysCapsToBuild() {
        let gated = IdentityStateEngine.gatedIdentityState(
            rawState: .steady,
            totalLogs: 3,
            uniqueDays: 3,
            activeDaysLast14: 3
        )
        XCTAssertEqual(gated, .build)
    }

    func testGatedIdentityStateScenarioThreeEightUniqueDaysCapsToSteady() {
        let gated = IdentityStateEngine.gatedIdentityState(
            rawState: .strong,
            totalLogs: 8,
            uniqueDays: 8,
            activeDaysLast14: 8
        )
        XCTAssertEqual(gated, .steady)
    }

    func testGatedIdentityStateScenarioFiveFourteenPlusDaysAllowsStrong() {
        let gated = IdentityStateEngine.gatedIdentityState(
            rawState: .strong,
            totalLogs: 16,
            uniqueDays: 14,
            activeDaysLast14: 10
        )
        XCTAssertEqual(gated, .strong)
    }
}
