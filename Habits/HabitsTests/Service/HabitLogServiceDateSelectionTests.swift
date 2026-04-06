import Foundation
import XCTest
@testable import Habits

@MainActor
final class HabitLogServiceDateSelectionTests: XCTestCase {
    func testAddLogStoresEntryOnSelectedDay() throws {
        let calendar = makeCalendar(timeZoneID: "Europe/London")
        let selectedDate = date(2026, 3, 30, hour: 14, minute: 20, calendar: calendar)
        let habit = TestHabitFactory.frequency(calendar: calendar)
        habit.logValue(on: selectedDate, value: 1, calendar: calendar)

        XCTAssertEqual(habit.logs.count, 1)
        XCTAssertEqual(habit.logs.first?.day, calendar.startOfDay(for: selectedDate))
    }

    func testAddLogNearMidnightDoesNotDriftToPreviousDay() throws {
        let calendar = makeCalendar(timeZoneID: "America/Los_Angeles")
        let selectedDate = date(2026, 4, 1, hour: 0, minute: 5, calendar: calendar)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let habit = TestHabitFactory.frequency(calendar: calendar)
        habit.logValue(on: selectedDate, value: 1, calendar: calendar)

        let storedDay = try XCTUnwrap(habit.logs.first?.day)
        XCTAssertEqual(storedDay, calendar.startOfDay(for: selectedDate))
        XCTAssertNotEqual(storedDay, calendar.startOfDay(for: previousDay))
    }

    func testAddLogUsesCalendarTimeZoneForDayBucketing() throws {
        let calendar = makeCalendar(timeZoneID: "Pacific/Kiritimati")
        let selectedDate = date(2026, 3, 30, hour: 0, minute: 30, calendar: calendar)
        let habit = TestHabitFactory.frequency(calendar: calendar)
        habit.logValue(on: selectedDate, value: 1, calendar: calendar)

        let storedDay = try XCTUnwrap(habit.logs.first?.day)
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: storedDay)
        XCTAssertEqual(dayComponents.year, 2026)
        XCTAssertEqual(dayComponents.month, 3)
        XCTAssertEqual(dayComponents.day, 30)
    }

    private func makeCalendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        guard let resolved = calendar.date(from: components) else {
            fatalError("Unable to create deterministic test date")
        }
        return resolved
    }
}

@MainActor
final class CueInsightServiceTests: XCTestCase {
    func testDetectCueReturnsDominantSourceWhenThresholdsMet() throws {
        let calendar = TestDateFactory.utcCalendar
        let persistence = try TestPersistence()
        let sourceHabit = TestHabitFactory.frequency(name: "A", calendar: calendar)
        let targetHabit = TestHabitFactory.frequency(name: "B", calendar: calendar)
        let otherTargetHabit = TestHabitFactory.frequency(name: "C", calendar: calendar)

        for dayOffset in 0..<4 {
            let targetTime = makeDate(2026, 4, 1 + dayOffset, 12, 0, calendar: calendar)
            let sourceTime = targetTime.addingTimeInterval(-(3 * 60 * 60))
            sourceHabit.logs.append(TestHabitFactory.entryLog(on: sourceTime, value: 1, calendar: calendar))
            targetHabit.logs.append(TestHabitFactory.entryLog(on: targetTime, value: 1, calendar: calendar))
        }

        let cTargetTime = makeDate(2026, 4, 10, 12, 0, calendar: calendar)
        let cSourceTime = cTargetTime.addingTimeInterval(-(3 * 60 * 60))
        sourceHabit.logs.append(TestHabitFactory.entryLog(on: cSourceTime, value: 1, calendar: calendar))
        otherTargetHabit.logs.append(TestHabitFactory.entryLog(on: cTargetTime, value: 1, calendar: calendar))

        persistence.insert(sourceHabit)
        persistence.insert(targetHabit)
        persistence.insert(otherTargetHabit)
        try persistence.save()

        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: HabitUIStateStore()
        )

        let insight = await service.detectCue(for: targetHabit.id)
        XCTAssertEqual(insight?.sourceHabitId, sourceHabit.id)
        XCTAssertEqual(insight?.occurrenceCount, 4)
        XCTAssertEqual(insight?.confidence ?? 0, 1.0, accuracy: 0.0001)
    }

    func testDetectCueReturnsNilWithoutDominantPattern() throws {
        let calendar = TestDateFactory.utcCalendar
        let persistence = try TestPersistence()
        let sourceA = TestHabitFactory.frequency(name: "A", calendar: calendar)
        let sourceC = TestHabitFactory.frequency(name: "C", calendar: calendar)
        let targetHabit = TestHabitFactory.frequency(name: "B", calendar: calendar)

        for dayOffset in 0..<4 {
            let targetTime = makeDate(2026, 5, 1 + dayOffset, 12, 0, calendar: calendar)
            let sourceTime = targetTime.addingTimeInterval(-(3 * 60 * 60))

            if dayOffset.isMultiple(of: 2) {
                sourceA.logs.append(TestHabitFactory.entryLog(on: sourceTime, value: 1, calendar: calendar))
            } else {
                sourceC.logs.append(TestHabitFactory.entryLog(on: sourceTime, value: 1, calendar: calendar))
            }

            targetHabit.logs.append(TestHabitFactory.entryLog(on: targetTime, value: 1, calendar: calendar))
        }

        persistence.insert(sourceA)
        persistence.insert(sourceC)
        persistence.insert(targetHabit)
        try persistence.save()

        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: HabitUIStateStore()
        )

        let insight = await service.detectCue(for: targetHabit.id)
        XCTAssertNil(insight)
    }

    func testDetectCueReturnsNilWhenOccurrencesBelowMinimum() throws {
        let calendar = TestDateFactory.utcCalendar
        let persistence = try TestPersistence()
        let sourceHabit = TestHabitFactory.frequency(name: "A", calendar: calendar)
        let targetHabit = TestHabitFactory.frequency(name: "B", calendar: calendar)

        for dayOffset in 0..<2 {
            let targetTime = makeDate(2026, 6, 1 + dayOffset, 12, 0, calendar: calendar)
            let sourceTime = targetTime.addingTimeInterval(-(3 * 60 * 60))
            sourceHabit.logs.append(TestHabitFactory.entryLog(on: sourceTime, value: 1, calendar: calendar))
            targetHabit.logs.append(TestHabitFactory.entryLog(on: targetTime, value: 1, calendar: calendar))
        }

        persistence.insert(sourceHabit)
        persistence.insert(targetHabit)
        try persistence.save()

        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: HabitUIStateStore()
        )

        let insight = await service.detectCue(for: targetHabit.id)
        XCTAssertNil(insight)
    }

    func testDetectCueIgnoresReversedOrder() throws {
        let calendar = TestDateFactory.utcCalendar
        let persistence = try TestPersistence()
        let sourceHabit = TestHabitFactory.frequency(name: "A", calendar: calendar)
        let targetHabit = TestHabitFactory.frequency(name: "B", calendar: calendar)

        for dayOffset in 0..<4 {
            let sourceTime = makeDate(2026, 7, 1 + dayOffset, 9, 0, calendar: calendar)
            let targetTime = sourceTime.addingTimeInterval(-(3 * 60 * 60))
            sourceHabit.logs.append(TestHabitFactory.entryLog(on: sourceTime, value: 1, calendar: calendar))
            targetHabit.logs.append(TestHabitFactory.entryLog(on: targetTime, value: 1, calendar: calendar))
        }

        persistence.insert(sourceHabit)
        persistence.insert(targetHabit)
        try persistence.save()

        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: HabitUIStateStore()
        )

        let insight = await service.detectCue(for: targetHabit.id)
        XCTAssertNil(insight)
    }

    func testDetectCueIgnoresEventsOutsideTimeWindow() throws {
        let calendar = TestDateFactory.utcCalendar
        let persistence = try TestPersistence()
        let sourceHabit = TestHabitFactory.frequency(name: "A", calendar: calendar)
        let targetHabit = TestHabitFactory.frequency(name: "B", calendar: calendar)

        for dayOffset in 0..<4 {
            let targetTime = makeDate(2026, 8, 1 + dayOffset, 12, 0, calendar: calendar)
            let sourceTime = targetTime.addingTimeInterval(-(5 * 60 * 60))
            sourceHabit.logs.append(TestHabitFactory.entryLog(on: sourceTime, value: 1, calendar: calendar))
            targetHabit.logs.append(TestHabitFactory.entryLog(on: targetTime, value: 1, calendar: calendar))
        }

        persistence.insert(sourceHabit)
        persistence.insert(targetHabit)
        try persistence.save()

        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: HabitUIStateStore()
        )

        let insight = await service.detectCue(for: targetHabit.id)
        XCTAssertNil(insight)
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )

        guard let resolved = calendar.date(from: components) else {
            fatalError("Unable to create deterministic test date")
        }

        return resolved
    }
}
