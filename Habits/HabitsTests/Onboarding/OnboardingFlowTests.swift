import SwiftData
import XCTest
@testable import Habits

@MainActor
final class OnboardingFlowTests: BaseTestCase {
    func testOnboardingCompletionPersists() {
        let settings = CompletionStateSpy()
        let flow = OnboardingFlowController(notificationPermissionRequester: NotificationPermissionSpy())

        flow.completeOnboarding(userSettings: settings)

        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.persistedValues, [true])
    }

    func testRootViewRouting() {
        XCTAssertEqual(
            RootViewRouter.destination(hasCompletedOnboarding: false),
            .onboarding
        )

        XCTAssertEqual(
            RootViewRouter.destination(hasCompletedOnboarding: true),
            .habitsList
        )
    }
}

private final class NotificationPermissionSpy: OnboardingNotificationPermissionRequesting {
    private(set) var requestCount = 0

    func requestPermission() async -> Bool {
        requestCount += 1
        return true
    }
}

private final class CompletionStateSpy: OnboardingCompletionStateStore {
    private(set) var persistedValues: [Bool] = []

    var hasCompletedOnboarding = false {
        didSet {
            persistedValues.append(hasCompletedOnboarding)
        }
    }
}
