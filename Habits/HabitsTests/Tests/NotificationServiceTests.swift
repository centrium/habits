import XCTest
import SwiftData
import UserNotifications
@testable import Habits

final class NotificationServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var mockNotificationCenter: MockNotificationCenter!
    private var service: NotificationService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try TestHabitFactory.makeInMemoryContainer()
        context = ModelContext(container)
        mockNotificationCenter = MockNotificationCenter()
        service = NotificationService(
            notificationCenter: mockNotificationCenter,
            modelContainerProvider: { [unowned self] in self.container }
        )
    }

    override func tearDownWithError() throws {
        service = nil
        mockNotificationCenter = nil
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testScheduleHabitReminderCreatesExpectedRequest() async throws {
        // Arrange
        let habit = TestHabitFactory.createHabit(reminderEnabled: true, reminderHour: 7, reminderMinute: 45)

        // Act
        await service.scheduleHabitReminder(for: habit)

        // Assert
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 1)

        guard let request = mockNotificationCenter.scheduledRequests.first else {
            XCTFail("Expected one scheduled request")
            return
        }

        XCTAssertEqual(request.identifier, service.habitReminderIdentifier(for: habit.id))
        XCTAssertEqual(request.content.categoryIdentifier, NotificationCategoryID.habitReminder)
        XCTAssertEqual(request.content.userInfo["habitID"] as? String, habit.id.uuidString)

        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 7)
        XCTAssertEqual(trigger.dateComponents.minute, 45)
    }

    func testSyncHabitReminderWhenDisabledDoesNotSchedule() async {
        // Arrange
        let habit = TestHabitFactory.createHabit(reminderEnabled: false)
        mockNotificationCenter.authorizationStatus = .authorized

        // Act
        await service.syncHabitReminder(for: habit)

        // Assert
        XCTAssertTrue(mockNotificationCenter.scheduledRequests.isEmpty)
    }

    func testSyncHabitReminderWhenEnabledSchedulesNotification() async throws {
        // Arrange
        let habit = TestHabitFactory.createHabit(reminderEnabled: true, reminderHour: 21, reminderMinute: 10)
        context.insert(habit)
        try context.save()
        mockNotificationCenter.authorizationStatus = .authorized

        // Act
        await service.syncHabitReminder(for: habit)

        // Assert
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 1)
        XCTAssertEqual(
            mockNotificationCenter.scheduledRequests.first?.identifier,
            service.habitReminderIdentifier(for: habit.id)
        )
    }

    func testSyncHabitReminderWhenHabitCompletedTodayDoesNotSchedule() async throws {
        // Arrange
        let habit = TestHabitFactory.createCompletedHabit(completionDate: Date())
        context.insert(habit)
        try context.save()
        mockNotificationCenter.authorizationStatus = .authorized

        // Act
        await service.syncHabitReminder(for: habit)

        // Assert
        XCTAssertTrue(mockNotificationCenter.scheduledRequests.isEmpty)
    }

    func testSyncHabitReminderRemovesExistingReminderBeforeRescheduling() async throws {
        // Arrange
        let habit = TestHabitFactory.createHabit(reminderEnabled: true)
        context.insert(habit)
        try context.save()
        mockNotificationCenter.authorizationStatus = .authorized

        // Act
        await service.syncHabitReminder(for: habit)

        // Assert
        let identifier = service.habitReminderIdentifier(for: habit.id)
        XCTAssertEqual(mockNotificationCenter.removedPendingIdentifiers.first, [identifier])
        XCTAssertEqual(mockNotificationCenter.calls.first, .removePending([identifier]))
        XCTAssertEqual(mockNotificationCenter.calls.dropFirst().first, .removePending([identifier]))
        XCTAssertEqual(mockNotificationCenter.calls.last, .add(identifier))
    }

    func testRemoveHabitReminderRemovesCorrectIdentifier() {
        // Arrange
        let habitID = UUID()

        // Act
        service.removeHabitReminder(habitID: habitID)

        // Assert
        XCTAssertEqual(
            mockNotificationCenter.removedPendingIdentifiers,
            [[service.habitReminderIdentifier(for: habitID)]]
        )
    }

    func testReminderCancellationWhenCompletedTodayDoesNotSchedule() async throws {
        // Arrange
        let habit = TestHabitFactory.createCompletedHabit(completionDate: Date())
        context.insert(habit)
        try context.save()
        mockNotificationCenter.authorizationStatus = .authorized

        // Act
        await service.syncHabitReminder(for: habit)

        // Assert
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 0)
    }
}
