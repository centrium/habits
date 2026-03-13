import SwiftData
import XCTest
@testable import Habits

final class HabitDeletionActionTests: XCTestCase {
    func testDeleteActionRemovesHabitAndLogsAndTriggersDismissCallbacks() throws {
        // Given
        let persistence = try TestPersistence()
        let day = TestDateFactory.date(2026, 3, 11, calendar: TestDateFactory.utcCalendar)
        let habit = TestHabitFactory.frequency(calendar: TestDateFactory.utcCalendar)
        habit.logs = [TestHabitFactory.entryLog(on: day, value: 1, calendar: TestDateFactory.utcCalendar)]
        persistence.insert(habit)
        try persistence.save()

        var editDismissCount = 0
        var deletedCallbackCount = 0

        // When
        HabitDeletionAction.perform(
            habit: habit,
            modelContext: persistence.context,
            dismissEditSheet: { editDismissCount += 1 },
            onDeleted: { deletedCallbackCount += 1 }
        )

        let remainingHabits = try persistence.context.fetch(FetchDescriptor<Habit>())
        let remainingLogs = try persistence.context.fetch(FetchDescriptor<HabitLog>())

        // Then
        XCTAssertEqual(editDismissCount, 1)
        XCTAssertEqual(deletedCallbackCount, 1)
        XCTAssertEqual(remainingHabits.count, 0)
        XCTAssertEqual(remainingLogs.count, 0)
    }

    func testDeleteActionWorksWithoutOnDeletedCallback() throws {
        // Given
        let persistence = try TestPersistence()
        let habit = TestHabitFactory.frequency(name: "Delete Me")
        persistence.insert(habit)
        try persistence.save()

        var editDismissCount = 0

        // When
        HabitDeletionAction.perform(
            habit: habit,
            modelContext: persistence.context,
            dismissEditSheet: { editDismissCount += 1 }
        )

        let remainingHabits = try persistence.context.fetch(FetchDescriptor<Habit>())

        // Then
        XCTAssertEqual(editDismissCount, 1)
        XCTAssertTrue(remainingHabits.isEmpty)
    }
}
