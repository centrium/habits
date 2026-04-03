import SwiftData
import XCTest
@testable import Habits

@MainActor
final class OnboardingFlowTests: XCTestCase {
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

    func testQuickHabitCreation() throws {
        let persistence = try TestPersistence()
        let settings = CompletionStateSpy()
        let flow = OnboardingFlowController(notificationPermissionRequester: NotificationPermissionSpy())
        let initialHabits = try persistence.context.fetch(FetchDescriptor<Habit>())

        let createdHabit = try flow.createQuickHabit(
            from: .walk,
            modelContext: persistence.context,
            userSettings: settings
        )
        let updatedHabits = try persistence.context.fetch(FetchDescriptor<Habit>())

        XCTAssertEqual(updatedHabits.count, initialHabits.count + 1)
        XCTAssertEqual(createdHabit.name, "Walk")
        XCTAssertNil(createdHabit.identity)
        XCTAssertEqual(createdHabit.category, .general)
        XCTAssertTrue(createdHabit.reminders.isEmpty)
        XCTAssertTrue(settings.hasCompletedOnboarding)
    }

    func testNotificationPermissionTriggeredOnlyOnStep3() async {
        let spy = NotificationPermissionSpy()
        let flow = OnboardingFlowController(notificationPermissionRequester: spy)
        var step = OnboardingStep.welcome

        step = await flow.handlePrimaryAction(from: step) // step 1 -> step 2
        XCTAssertEqual(spy.requestCount, 0)
        XCTAssertEqual(step, .benefits)

        step = await flow.handlePrimaryAction(from: step) // step 2 -> step 3
        XCTAssertEqual(spy.requestCount, 0)
        XCTAssertEqual(step, .notifications)

        step = await flow.handlePrimaryAction(from: step) // step 3 -> step 4
        XCTAssertEqual(spy.requestCount, 1)
        XCTAssertEqual(step, .firstHabit)

        step = await flow.handlePrimaryAction(from: step) // step 4 remains step 4
        XCTAssertEqual(spy.requestCount, 1)
        XCTAssertEqual(step, .firstHabit)
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
