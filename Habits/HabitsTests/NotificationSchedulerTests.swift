import XCTest
@testable import Habits

final class NotificationSchedulerTests: BaseTestCase {
    private var calendar: Calendar {
        TestDateFactory.utcCalendar
    }

    private var referenceDate: Date {
        TestDateFactory.date(2026, 1, 1, hour: 0, minute: 0, calendar: calendar)
    }

    private var scheduler: NotificationScheduler {
        NotificationScheduler(calendar: calendar)
    }

    func testBundlingSameReminderTimeProducesSingleNotification() throws {
        // Given
        let persistence = try TestPersistence()
        let habitA = makeReminderHabit(name: "Habit A", hour: 8, minute: 0)
        let habitB = makeReminderHabit(name: "Habit B", hour: 8, minute: 0)
        let habitC = makeReminderHabit(name: "Habit C", hour: 8, minute: 0)

        persistence.insert(habitA)
        persistence.insert(habitB)
        persistence.insert(habitC)
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertEqual(schedule.count, 1)
        let notification = try XCTUnwrap(schedule.first)
        XCTAssertEqual(notification.deliveryDate, dateAt(hour: 8, minute: 0))
        XCTAssertEqual(Set(notification.habitIDs), Set([habitA.id, habitB.id, habitC.id]))
    }

    func testNotificationSpacingIsAtLeastTenMinutes() throws {
        // Given
        let persistence = try TestPersistence()
        persistence.insert(makeReminderHabit(name: "Habit A", hour: 8, minute: 0))
        persistence.insert(makeReminderHabit(name: "Habit B", hour: 8, minute: 5))
        persistence.insert(makeReminderHabit(name: "Habit C", hour: 8, minute: 7))
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertEqual(schedule.count, 3)
        XCTAssertEqual(schedule[0].deliveryDate, dateAt(hour: 8, minute: 0))
        XCTAssertEqual(schedule[1].deliveryDate, dateAt(hour: 8, minute: 10))
        XCTAssertEqual(schedule[2].deliveryDate, dateAt(hour: 8, minute: 20))
        XCTAssertGreaterThanOrEqual(
            schedule[1].deliveryDate.timeIntervalSince(schedule[0].deliveryDate),
            NotificationScheduler.minimumNotificationSpacing
        )
        XCTAssertGreaterThanOrEqual(
            schedule[2].deliveryDate.timeIntervalSince(schedule[1].deliveryDate),
            NotificationScheduler.minimumNotificationSpacing
        )
    }

    func testMixedBundlingAndSpacingScenario() throws {
        // Given
        let persistence = try TestPersistence()
        let habitA = makeReminderHabit(name: "Habit A", hour: 8, minute: 0)
        let habitB = makeReminderHabit(name: "Habit B", hour: 8, minute: 0)
        let habitC = makeReminderHabit(name: "Habit C", hour: 8, minute: 5)
        let habitD = makeReminderHabit(name: "Habit D", hour: 8, minute: 10)

        persistence.insert(habitA)
        persistence.insert(habitB)
        persistence.insert(habitC)
        persistence.insert(habitD)
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertEqual(schedule.count, 3)
        XCTAssertEqual(schedule[0].deliveryDate, dateAt(hour: 8, minute: 0))
        XCTAssertEqual(Set(schedule[0].habitIDs), Set([habitA.id, habitB.id]))
        XCTAssertEqual(schedule[1].deliveryDate, dateAt(hour: 8, minute: 10))
        XCTAssertEqual(schedule[1].habitIDs, [habitC.id])
        XCTAssertEqual(schedule[2].deliveryDate, dateAt(hour: 8, minute: 20))
        XCTAssertEqual(schedule[2].habitIDs, [habitD.id])
    }

    func testCompletedHabitProducesNoNotification() throws {
        // Given
        let persistence = try TestPersistence()
        let completedEntry = TestHabitFactory.entry(
            on: TestDateFactory.date(2026, 1, 1, hour: 19, minute: 0, calendar: calendar),
            value: 1
        )
        let completedHabit = makeReminderHabit(
            name: "Habit A",
            hour: 20,
            minute: 0,
            entries: [completedEntry]
        )

        persistence.insert(completedHabit)
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertTrue(schedule.isEmpty)
    }

    func testDisabledReminderProducesNoNotification() throws {
        // Given
        let persistence = try TestPersistence()
        let habit = TestHabitFactory.frequency(
            name: "Habit A",
            createdAt: referenceDate,
            calendar: calendar
        )
        habit.reminders = [
            HabitReminder(hour: 20, minute: 0, isEnabled: false)
        ]

        persistence.insert(habit)
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertTrue(schedule.isEmpty)
    }

    func testBundleReductionAfterOneHabitCompletionUpdatesContent() throws {
        // Given
        let persistence = try TestPersistence()
        let completedEntry = TestHabitFactory.entry(
            on: TestDateFactory.date(2026, 1, 1, hour: 19, minute: 0, calendar: calendar),
            value: 1
        )
        let meditate = makeReminderHabit(
            name: "Meditate",
            hour: 20,
            minute: 0,
            entries: [completedEntry]
        )
        let stretch = makeReminderHabit(name: "Stretch", hour: 20, minute: 0)
        let journal = makeReminderHabit(name: "Journal", hour: 20, minute: 0)

        persistence.insert(meditate)
        persistence.insert(stretch)
        persistence.insert(journal)
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertEqual(schedule.count, 1)
        let notification = try XCTUnwrap(schedule.first)
        XCTAssertEqual(Set(notification.habitIDs), Set([stretch.id, journal.id]))
        XCTAssertTrue(notification.body.contains("2 habits"))
        XCTAssertTrue(notification.body.contains("Stretch"))
        XCTAssertTrue(notification.body.contains("Journal"))
        XCTAssertFalse(notification.body.contains("Meditate"))
    }

    func testNoTodayLogsAtSameTimeShowsTwoHabitsReadyEvenWithPriorPeriodProgress() throws {
        // Given
        let persistence = try TestPersistence()
        let priorWeekEntry = TestHabitFactory.entry(
            on: TestDateFactory.date(2025, 12, 31, hour: 9, minute: 0, calendar: calendar),
            value: 1
        )
        let habitA = makeReminderHabit(
            name: "Meditate Twice A Day",
            hour: 11,
            minute: 56,
            period: .weekly,
            target: 1,
            entries: [priorWeekEntry]
        )
        let habitB = makeReminderHabit(
            name: "Stretch",
            hour: 11,
            minute: 56
        )

        persistence.insert(habitA)
        persistence.insert(habitB)
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertEqual(schedule.count, 1)
        let notification = try XCTUnwrap(schedule.first)
        XCTAssertEqual(notification.deliveryDate, dateAt(hour: 11, minute: 56))
        XCTAssertEqual(Set(notification.habitIDs), Set([habitA.id, habitB.id]))
        XCTAssertTrue(notification.body.contains("2 habits ready"))
        XCTAssertFalse(notification.body.contains("remaining"))
    }

    func testSingleHabitNotificationUsesHumanCopy() throws {
        // Given / When
        let notification = try singleNotification(for: "Meditate Twice A Day")

        // Then
        XCTAssertEqual(notification.title, "Time for your habit")
        XCTAssertEqual(notification.body, "Your \"Meditate Twice A Day\" habit is waiting")
    }

    func testBundleBodyFormattingWithTwoHabitsShowsBothNames() throws {
        // Given / When
        let body = try bundledBody(
            for: [
                "Meditate Twice A Day",
                "Save 200 A Month"
            ]
        )

        // Then
        XCTAssertEqual(body, "2 habits ready: Meditate Twice A Day • Save 200 A Month")
    }

    func testBundleBodyFormattingWithThreeHabitsShowsTwoNamesAndMoreCount() throws {
        // Given / When
        let body = try bundledBody(
            for: [
                "Meditate Twice A Day",
                "Save 200 A Month",
                "Stretch"
            ]
        )

        // Then
        XCTAssertEqual(body, "3 habits ready: Meditate Twice A Day • Save 200 A Month +1 more")
    }

    func testBundleBodyFormattingWithFiveHabitsShowsTwoNamesAndMoreCount() throws {
        // Given / When
        let body = try bundledBody(
            for: [
                "Meditate Twice A Day",
                "Save 200 A Month",
                "Stretch",
                "Yoga",
                "Zzz"
            ]
        )

        // Then
        XCTAssertEqual(body, "5 habits ready: Meditate Twice A Day • Save 200 A Month +3 more")
    }

    func testSingleHabitWithMultipleRemindersProducesMultipleNotifications() throws {
        // Given
        let persistence = try TestPersistence()
        let habit = makeReminderHabit(name: "Read", hour: 8, minute: 0)
        habit.reminders.append(HabitReminder(hour: 20, minute: 0))
        persistence.insert(habit)
        try persistence.save()

        // When
        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertEqual(schedule.count, 2)
        XCTAssertEqual(schedule[0].deliveryDate, dateAt(hour: 8, minute: 0))
        XCTAssertEqual(schedule[1].deliveryDate, dateAt(hour: 20, minute: 0))
        XCTAssertEqual(schedule[0].body, "Your \"Read\" habit is waiting")
        XCTAssertEqual(schedule[1].body, "Your \"Read\" habit is waiting")
    }

    func testScheduleOrderingIsDeterministicAndSortedByDeliveryDate() throws {
        // Given
        let persistence = try TestPersistence()
        persistence.insert(makeReminderHabit(name: "Habit C", hour: 8, minute: 7))
        persistence.insert(makeReminderHabit(name: "Habit A", hour: 8, minute: 0))
        persistence.insert(makeReminderHabit(name: "Habit B", hour: 8, minute: 5))
        try persistence.save()

        // When
        let firstRun = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )
        let secondRun = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        // Then
        XCTAssertEqual(firstRun, secondRun)
        XCTAssertEqual(
            firstRun.map(\.deliveryDate),
            firstRun.map(\.deliveryDate).sorted()
        )
        XCTAssertEqual(Set(firstRun.map(\.id)).count, firstRun.count)
    }

    private func makeReminderHabit(
        name: String,
        hour: Int,
        minute: Int,
        period: GoalPeriod = .daily,
        target: Int = 1,
        hasGoal: Bool = true,
        entries: [TestHabitFactory.Entry] = []
    ) -> Habit {
        let habit = TestHabitFactory.frequency(
            name: name,
            period: period,
            target: target,
            hasGoal: hasGoal,
            createdAt: referenceDate,
            entries: entries,
            calendar: calendar
        )
        habit.reminders = [HabitReminder(hour: hour, minute: minute)]
        return habit
    }

    private func dateAt(hour: Int, minute: Int) -> Date {
        TestDateFactory.date(2026, 1, 1, hour: hour, minute: minute, calendar: calendar)
    }

    private func bundledBody(for names: [String]) throws -> String {
        let persistence = try TestPersistence()
        for name in names {
            persistence.insert(makeReminderHabit(name: name, hour: 11, minute: 56))
        }
        try persistence.save()

        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        XCTAssertEqual(schedule.count, 1)
        return try XCTUnwrap(schedule.first?.body)
    }

    private func singleNotification(for name: String) throws -> ScheduledNotification {
        let persistence = try TestPersistence()
        persistence.insert(makeReminderHabit(name: name, hour: 11, minute: 56))
        try persistence.save()

        let schedule = try scheduler.schedule(
            using: persistence.context,
            referenceDate: referenceDate
        )

        XCTAssertEqual(schedule.count, 1)
        return try XCTUnwrap(schedule.first)
    }
}
