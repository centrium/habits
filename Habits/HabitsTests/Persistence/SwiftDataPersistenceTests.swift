import SwiftData
import XCTest
@testable import Habits

final class SwiftDataPersistenceTests: XCTestCase {
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

    func testDeletingHabitCascadesAndRemovesRelatedLogs() throws {
        // Given
        let persistence = try TestPersistence()
        let day = TestDateFactory.date(2026, 3, 11, calendar: TestDateFactory.utcCalendar)
        let habit = TestHabitFactory.frequency(calendar: TestDateFactory.utcCalendar)
        habit.logs = [TestHabitFactory.entryLog(on: day, value: 1, calendar: TestDateFactory.utcCalendar)]
        persistence.insert(habit)
        try persistence.save()

        // When
        persistence.context.delete(habit)
        try persistence.save()
        let remainingHabits = try persistence.context.fetch(FetchDescriptor<Habit>())
        let remainingLogs = try persistence.context.fetch(FetchDescriptor<HabitLog>())

        // Then
        XCTAssertEqual(remainingHabits.count, 0)
        XCTAssertEqual(remainingLogs.count, 0)
    }
}
