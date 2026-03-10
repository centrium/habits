import XCTest
import SwiftData
import UserNotifications
@testable import Habits

final class NotificationActionHandlerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var notificationCenter: MockNotificationCenter!
    private var mockNotificationService: MockNotificationService!
    private var deepLinkManager: MockDeepLinkManager!
    private var habitLogServiceBuilder: MockHabitLogServiceBuilder!
    private var actionHandler: NotificationActionHandler!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try TestHabitFactory.makeInMemoryContainer()
        context = ModelContext(container)
        notificationCenter = MockNotificationCenter()
        mockNotificationService = MockNotificationService()
        deepLinkManager = MockDeepLinkManager()
        habitLogServiceBuilder = MockHabitLogServiceBuilder()

        actionHandler = NotificationActionHandler(
            notificationService: mockNotificationService,
            notificationCenter: notificationCenter,
            deepLinkManager: deepLinkManager,
            habitLogServiceBuilder: habitLogServiceBuilder
        )
        actionHandler.modelContainer = container
    }

    override func tearDownWithError() throws {
        actionHandler = nil
        habitLogServiceBuilder = nil
        deepLinkManager = nil
        mockNotificationService = nil
        notificationCenter = nil
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testLogHabitActionQuickLogsAndRemovesNotification() async throws {
        // Arrange
        let habit = TestHabitFactory.createHabit(reminderEnabled: true)
        context.insert(habit)
        try context.save()

        // Act
        await actionHandler.handleAction(
            actionIdentifier: NotificationActionID.logHabit,
            userInfo: ["habitID": habit.id.uuidString]
        )

        // Assert
        XCTAssertEqual(habitLogServiceBuilder.quickLogCallCount, 1)
        XCTAssertEqual(mockNotificationService.syncedHabitIDs, [habit.id])
        XCTAssertEqual(
            notificationCenter.removedDeliveredIdentifiers,
            [[mockNotificationService.habitReminderIdentifier(for: habit.id)]]
        )

        let habitID = habit.id
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        let storedHabit = try XCTUnwrap(context.fetch(descriptor).first)
        XCTAssertEqual(storedHabit.logs.count, 1)
    }

    func testOpenHabitActionUpdatesDeepLinkManager() async throws {
        // Arrange
        let habit = TestHabitFactory.createHabit()

        // Act
        await actionHandler.handleAction(
            actionIdentifier: NotificationActionID.openHabit,
            userInfo: ["habitID": habit.id.uuidString]
        )

        // Assert
        XCTAssertEqual(deepLinkManager.openedHabitID, habit.id)
    }

    func testDefaultNotificationTapUpdatesDeepLinkManager() async throws {
        // Arrange
        let habit = TestHabitFactory.createHabit()

        // Act
        await actionHandler.handleAction(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: ["habitID": habit.id.uuidString]
        )

        // Assert
        XCTAssertEqual(deepLinkManager.openedHabitID, habit.id)
    }
}

private final class MockNotificationService: NotificationReminderSyncing {
    var syncedHabitIDs: [UUID] = []

    func syncHabitReminder(for habit: Habit) async {
        syncedHabitIDs.append(habit.id)
    }

    func habitReminderIdentifier(for habitID: UUID) -> String {
        "habit-reminder-\(habitID.uuidString)"
    }
}

private final class MockDeepLinkManager: DeepLinkManaging {
    var openedHabitID: UUID?

    @MainActor
    func openHabit(_ id: UUID) {
        openedHabitID = id
    }
}

private final class MockHabitLogServiceBuilder: HabitLogServiceBuilding {
    private(set) var quickLogCallCount = 0

    func make(modelContext: ModelContext) -> HabitLogServiceProtocol {
        MockHabitLogService { [weak self] habit, day in
            self?.quickLogCallCount += 1
            let service = HabitLogService(modelContext: modelContext)
            return service.quickLog(for: habit, on: day)
        }
    }
}

private struct MockHabitLogService: HabitLogServiceProtocol {
    let onQuickLog: (Habit, Date) -> Double

    @discardableResult
    func quickLog(for habit: Habit, on day: Date) -> Double {
        onQuickLog(habit, day)
    }
}
