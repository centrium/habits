import XCTest
@testable import Habits

@MainActor
final class CadenceLanguageTests: XCTestCase {
    func testStateResolution() {
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: 0.8, hasRecentData: true),
            .steady
        )
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: 0.5, hasRecentData: true),
            .building
        )
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: 0.2, hasRecentData: true),
            .rebuilding
        )
        XCTAssertEqual(
            HabitIdentityStateResolver.resolve(completionRate: nil, hasRecentData: false),
            .gettingStarted
        )
    }

    func testCopyValidationForAllStates() {
        XCTAssertEqual(CadenceLanguage.shortLabel(for: .gettingStarted), "Getting started")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .gettingStarted), "Getting started")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .gettingStarted), "You're getting started with this habit")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .building), "Building momentum")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .building), "Building momentum")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .building), "This habit is building momentum")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .steady), "Staying consistent")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .steady), "Staying consistent")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .steady), "This habit is staying consistent")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .strong), "Strong rhythm")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .strong), "Strong rhythm")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .strong), "This habit has a strong rhythm")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .slipping), "Losing momentum")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .slipping), "Losing momentum")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .slipping), "This habit is losing momentum")

        XCTAssertEqual(CadenceLanguage.shortLabel(for: .rebuilding), "Getting back on track")
        XCTAssertEqual(CadenceLanguage.identityLine(for: .rebuilding), "Getting back on track")
        XCTAssertEqual(CadenceLanguage.insightLine(for: .rebuilding), "This habit is getting back on track")

        XCTAssertEqual(CadenceLanguage.stateTitle(.rebuilding), "Getting back on track")
    }

    func testBehaviourLineFormattingAndFallback() {
        XCTAssertEqual(
            CadenceLanguage.behaviourLine(completions: 3, window: 7),
            "Shown up 3 of the last 7 days"
        )
        XCTAssertEqual(
            CadenceLanguage.behaviourLine(completions: nil, window: nil),
            "Shown up 0 of the last 7 days"
        )
    }

    func testIdentityCopyHelpers() {
        XCTAssertEqual(CadenceLanguage.identityTitle(), "Identity")
        XCTAssertEqual(CadenceLanguage.identityEmptyPrompt(), "Shape this into part of who you are")
        XCTAssertEqual(CadenceLanguage.identityHelper(), "This helps turn habits into part of who you are")
        XCTAssertEqual(CadenceLanguage.identityPlaceholder(), "e.g. Someone who moves daily")
        XCTAssertEqual(CadenceLanguage.identityStat(days: 4, window: 7), "Shown up 4 of the last 7 days")
    }
}
