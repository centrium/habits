import XCTest
@testable import Habits

@MainActor
final class CadenceLanguageTests: XCTestCase {
    func testStateResolution() {
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: 0.8, hasRecentData: true),
            .holding
        )
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: 0.5, hasRecentData: true),
            .building
        )
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: 0.2, hasRecentData: true),
            .returning
        )
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: nil, hasRecentData: false),
            .starting
        )
    }

    func testCopyValidationForAllStates() {
        XCTAssertEqual(CadenceLanguage.shortLabel(for: .starting), "Starting")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .starting), "This is where the habit begins to take shape")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .starting), "This habit is just getting started")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .building), "Building")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .building), "You’re building this identity")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .building), "You’re building consistency with this habit")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .holding), "Holding")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .holding), "This is becoming part of who you are")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .holding), "This habit is holding strong")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .returning), "Returning")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .returning), "Getting back to this keeps the identity intact")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .returning), "You’re in the process of returning to this habit")
    }

    func testBehaviourLineFormattingAndFallback() {
        XCTAssertEqual(
            CadenceLanguage.behaviourLine(completions: 3, window: 7),
            "You’ve shown up 3 of the last 7 days"
        )
        XCTAssertEqual(
            CadenceLanguage.behaviourLine(completions: nil, window: nil),
            "This is where the habit begins"
        )
    }
}
