import SwiftData
import XCTest
@testable import Habits

final class SwiftDataPersistenceTests: BaseTestCase {
    func testHabitDefaultsToGeneralCategoryAndNilIdentity() {
        let habit = TestHabitFactory.frequency(name: "Read")

        XCTAssertNil(habit.identity)
        XCTAssertEqual(habit.category, .general)
        XCTAssertEqual(habit.categoryRaw, HabitCategory.general.rawValue)
    }

    func testHabitCategoryGetterFallsBackToGeneralForUnknownRawValue() {
        let habit = TestHabitFactory.frequency(name: "Read")
        habit.categoryRaw = "Unknown"

        XCTAssertEqual(habit.category, .general)
    }

    func testHabitCategorySetterKeepsRawValueInSync() {
        let habit = TestHabitFactory.frequency(name: "Read")

        habit.category = .learning

        XCTAssertEqual(habit.categoryRaw, HabitCategory.learning.rawValue)
    }

    func testInMemoryContainerPersistsDataWithinItsOwnContext() throws {
        // Given
        let persistence = try TestPersistence()
        let habit = TestHabitFactory.frequency(name: "Read")
        persistence.insert(habit)

        // When
        try persistence.save()
        let fetched = try persistence.context.fetch(FetchDescriptor<Habit>())

        // Then
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Read")
    }

    func testSavingHabitPersistsIdentityAndCategory() throws {
        let persistence = try TestPersistence()
        let habit = TestHabitFactory.frequency(name: "Read")
        habit.identity = "Someone who keeps learning"
        habit.category = .learning
        persistence.insert(habit)

        try persistence.save()

        let fetched = try persistence.context.fetch(FetchDescriptor<Habit>())
        let stored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(stored.identity, "Someone who keeps learning")
        XCTAssertEqual(stored.category, .learning)
        XCTAssertEqual(stored.categoryRaw, HabitCategory.learning.rawValue)
    }

    func testSavingHabitPersistsTriggerHabitID() throws {
        let persistence = try TestPersistence()
        let parent = TestHabitFactory.frequency(name: "Parent")
        let child = TestHabitFactory.frequency(name: "Child")
        child.triggerHabitID = parent.id
        persistence.insert(parent)
        persistence.insert(child)

        try persistence.save()

        let fetched = try persistence.context.fetch(
            FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.orderIndex)])
        )
        let storedChild = try XCTUnwrap(fetched.first(where: { $0.name == "Child" }))
        XCTAssertEqual(storedChild.triggerHabitID, parent.id)
    }

    func testSeparateInMemoryContainersAreFullyIsolated() throws {
        // Given
        let firstPersistence = try TestPersistence()
        let secondPersistence = try TestPersistence()
        firstPersistence.insert(TestHabitFactory.frequency(name: "Only In First"))
        try firstPersistence.save()

        // When
        let firstFetched = try firstPersistence.context.fetch(FetchDescriptor<Habit>())
        let secondFetched = try secondPersistence.context.fetch(FetchDescriptor<Habit>())

        // Then
        XCTAssertEqual(firstFetched.count, 1)
        XCTAssertEqual(secondFetched.count, 0)
    }

    func testSavingHabitAlsoPersistsItsLogs() throws {
        // Given
        let persistence = try TestPersistence()
        let day = TestDateFactory.date(2026, 3, 11, calendar: TestDateFactory.utcCalendar)
        let habit = TestHabitFactory.frequency(calendar: TestDateFactory.utcCalendar)
        habit.logs = [TestHabitFactory.entryLog(on: day, value: 1, calendar: TestDateFactory.utcCalendar)]
        persistence.insert(habit)

        // When
        try persistence.save()
        let fetchedLogs = try persistence.context.fetch(FetchDescriptor<HabitLog>())
        let numericValue = try XCTUnwrap(fetchedLogs.first?.numericValue)

        // Then
        XCTAssertEqual(fetchedLogs.count, 1)
        XCTAssertEqual(numericValue, 1, accuracy: 0.0001)
    }

    func testSavingHabitAlsoPersistsItsReminder() throws {
        // Given
        let persistence = try TestPersistence()
        let habit = TestHabitFactory.frequency(name: "Read")
        habit.reminders = [HabitReminder(hour: 20, minute: 0)]
        persistence.insert(habit)

        // When
        try persistence.save()
        let fetched = try persistence.context.fetch(FetchDescriptor<Habit>())

        // Then
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.reminders.count, 1)
        XCTAssertEqual(fetched.first?.reminders.first?.hour, 20)
        XCTAssertEqual(fetched.first?.reminders.first?.minute, 0)
        XCTAssertTrue(fetched.first?.reminders.first?.isEnabled == true)
    }

    func testDeletingHabitCascadesAndRemovesRelatedLogs() throws {
        // Given
        let persistence = try TestPersistence()
        let day = TestDateFactory.date(2026, 3, 11, calendar: TestDateFactory.utcCalendar)
        let habit = TestHabitFactory.frequency(calendar: TestDateFactory.utcCalendar)
        habit.logs = [TestHabitFactory.entryLog(on: day, value: 1, calendar: TestDateFactory.utcCalendar)]
        habit.reminders = [HabitReminder(hour: 20, minute: 0)]
        persistence.insert(habit)
        try persistence.save()

        // When
        persistence.context.delete(habit)
        try persistence.save()
        let remainingHabits = try persistence.context.fetch(FetchDescriptor<Habit>())
        let remainingLogs = try persistence.context.fetch(FetchDescriptor<HabitLog>())
        let remainingReminders = try persistence.context.fetch(FetchDescriptor<HabitReminder>())

        // Then
        XCTAssertEqual(remainingHabits.count, 0)
        XCTAssertEqual(remainingLogs.count, 0)
        XCTAssertEqual(remainingReminders.count, 0)
    }

    func testHabitSupportsAddingReminder() {
        let habit = TestHabitFactory.frequency(name: "Read")
        habit.reminders = []

        habit.reminders.append(HabitReminder(hour: 8, minute: 0))

        XCTAssertEqual(habit.reminders.count, 1)
    }

    func testReminderCanBeDisabled() {
        let reminder = HabitReminder(hour: 8, minute: 0, isEnabled: true)

        reminder.isEnabled = false

        XCTAssertFalse(reminder.isEnabled)
    }

    func testRemindersMaintainIndependentTimes() {
        let reminder1 = HabitReminder(hour: 20, minute: 0)
        let reminder2 = HabitReminder(hour: 13, minute: 0)

        XCTAssertEqual(reminder1.hour, 20)
        XCTAssertEqual(reminder1.minute, 0)
        XCTAssertEqual(reminder2.hour, 13)
        XCTAssertEqual(reminder2.minute, 0)
    }

    func testEditingOneReminderDraftDoesNotAffectAnother() {
        var reminders = [
            HabitReminderDraft.makeDefault(hour: 20, minute: 0),
            HabitReminderDraft.makeDefault(hour: 13, minute: 0)
        ]

        reminders[0].setTime(hour: 21, minute: 0)

        XCTAssertEqual(reminders[0].hour, 21)
        XCTAssertEqual(reminders[0].minute, 0)
        XCTAssertEqual(reminders[1].hour, 13)
        XCTAssertEqual(reminders[1].minute, 0)
    }

    func testQuickPickTimeUpdateAffectsOnlySelectedReminderDraft() {
        var reminders = [
            HabitReminderDraft.makeDefault(hour: 20, minute: 0),
            HabitReminderDraft.makeDefault(hour: 13, minute: 0)
        ]

        reminders[1].setTime(hour: 8, minute: 0)

        XCTAssertEqual(reminders[0].hour, 20)
        XCTAssertEqual(reminders[0].minute, 0)
        XCTAssertEqual(reminders[1].hour, 8)
        XCTAssertEqual(reminders[1].minute, 0)
    }

    func testQuickPickSetsCorrectTime() {
        var reminder = HabitReminderDraft.makeDefault(hour: 0, minute: 0)

        reminder.setTime(hour: 8, minute: 0)

        XCTAssertEqual(reminder.hour, 8)
        XCTAssertEqual(reminder.minute, 0)
    }

    func testDuplicateReminderIsDetectedOnAdd() {
        let existingReminder = HabitReminderDraft.makeDefault(hour: 8, minute: 0)
        let newReminder = HabitReminderDraft.makeDefault(hour: 8, minute: 0)
        let reminders = [existingReminder, newReminder]

        XCTAssertTrue(
            reminders.containsReminderTime(
                newReminder.hour,
                minute: newReminder.minute,
                excluding: newReminder.id
            )
        )
    }

    func testEditingReminderToDuplicateTimeLeavesOriginalTimeUnchanged() {
        var reminders = [
            HabitReminderDraft.makeDefault(hour: 8, minute: 0),
            HabitReminderDraft.makeDefault(hour: 20, minute: 0)
        ]

        let originalTime = (hour: reminders[1].hour, minute: reminders[1].minute)
        let duplicateDetected = reminders.containsReminderTime(8, minute: 0, excluding: reminders[1].id)

        if !duplicateDetected {
            reminders[1].setTime(hour: 8, minute: 0)
        }

        XCTAssertTrue(duplicateDetected)
        XCTAssertEqual(reminders[1].hour, originalTime.hour)
        XCTAssertEqual(reminders[1].minute, originalTime.minute)
    }

    func testDefaultReminderDraftsUseDistinctIdentity() {
        let reminder1 = HabitReminderDraft.makeDefault()
        let reminder2 = HabitReminderDraft.makeDefault()

        XCTAssertNotEqual(reminder1.id, reminder2.id)
    }
}
