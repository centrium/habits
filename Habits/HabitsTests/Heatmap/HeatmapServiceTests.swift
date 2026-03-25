import XCTest
@testable import Habits

final class HeatmapServiceTests: XCTestCase {
    private var calendar: Calendar {
        TestDateFactory.utcCalendar
    }

    func testListAndDetailPipelinesProduceIdenticalCells() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, hour: 10, minute: 0, calendar: calendar)
        let dayA = TestDateFactory.date(2026, 3, 14, hour: 9, minute: 0, calendar: calendar)
        let dayB = TestDateFactory.date(2026, 3, 15, hour: 18, minute: 0, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            target: 2,
            entries: [
                .init(timestamp: dayA, value: 1),
                .init(timestamp: dayA, value: 1),
                .init(timestamp: dayB, value: 1)
            ],
            calendar: calendar
        )
        let range = dateRange(
            start: TestDateFactory.date(2026, 3, 10, calendar: calendar),
            endInclusive: TestDateFactory.date(2026, 3, 16, calendar: calendar)
        )
        let goal = HabitGoal.from(habit: habit)

        // WHEN
        let listCells = HeatmapService(
            calendar: calendar,
            premiumStatus: .free,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: goal
        )
        let detailCells = HeatmapService(
            calendar: calendar,
            premiumStatus: .free,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: goal
        )

        // THEN
        XCTAssertEqual(listCells, detailCells)
    }

    func testOpenGoalWithMultipleLogsUsesBinaryIntensity() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, hour: 12, minute: 0, calendar: calendar)
        let loggedDay = TestDateFactory.date(2026, 3, 15, hour: 8, minute: 0, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [
                .init(timestamp: loggedDay, value: 1),
                .init(timestamp: TestDateFactory.date(2026, 3, 15, hour: 20, minute: 0, calendar: calendar), value: 3)
            ],
            calendar: calendar
        )
        let range = dateRange(
            start: TestDateFactory.date(2026, 3, 14, calendar: calendar),
            endInclusive: TestDateFactory.date(2026, 3, 16, calendar: calendar)
        )

        // WHEN
        let cells = HeatmapService(
            calendar: calendar,
            premiumStatus: .premium,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: .open()
        )

        // THEN
        guard let loggedCell = cell(on: loggedDay, in: cells) else {
            XCTFail("Expected a heatmap cell for logged day")
            return
        }
        XCTAssertEqual(loggedCell.value, 1, accuracy: 0.0001)
        XCTAssertEqual(loggedCell.normalizedIntensity, 5)
        XCTAssertEqual(loggedCell.isCompleted, true)
    }

    func testCumulativeGoalScalesIntensityByMaxObservedWhenNoTargetExists() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, hour: 12, minute: 0, calendar: calendar)
        let firstDay = TestDateFactory.date(2026, 3, 14, hour: 9, minute: 0, calendar: calendar)
        let secondDay = TestDateFactory.date(2026, 3, 15, hour: 9, minute: 0, calendar: calendar)
        let habit = Habit(
            name: "Cumulative No Target",
            colorHex: "#0EA5A5",
            hasStreakGoal: true,
            goalPeriod: .daily,
            goalType: .cumulative,
            streakTarget: 1,
            targetValue: nil,
            unit: "ml",
            allowsDecimals: true,
            createdAt: now
        )
        habit.logs = [
            HabitLog(timestamp: firstDay, value: 20, calendar: calendar),
            HabitLog(timestamp: secondDay, value: 80, calendar: calendar)
        ]
        let range = dateRange(
            start: TestDateFactory.date(2026, 3, 14, calendar: calendar),
            endInclusive: TestDateFactory.date(2026, 3, 16, calendar: calendar)
        )

        // WHEN
        let cells = HeatmapService(
            calendar: calendar,
            premiumStatus: .premium,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: .cumulative(target: nil)
        )

        // THEN
        guard let firstCell = cell(on: firstDay, in: cells) else {
            XCTFail("Expected a heatmap cell for first day")
            return
        }
        guard let secondCell = cell(on: secondDay, in: cells) else {
            XCTFail("Expected a heatmap cell for second day")
            return
        }
        XCTAssertEqual(firstCell.value, 0.25, accuracy: 0.0001)
        XCTAssertEqual(secondCell.value, 1, accuracy: 0.0001)
        XCTAssertEqual(secondCell.normalizedIntensity, 5)
    }

    func testCumulativeGoalScalesIntensityByTargetWhenTargetExists() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, hour: 12, minute: 0, calendar: calendar)
        let loggedDay = TestDateFactory.date(2026, 3, 15, hour: 9, minute: 0, calendar: calendar)
        let habit = TestHabitFactory.cumulative(
            target: 100,
            entries: [.init(timestamp: loggedDay, value: 25)],
            calendar: calendar
        )
        let range = dateRange(
            start: TestDateFactory.date(2026, 3, 14, calendar: calendar),
            endInclusive: TestDateFactory.date(2026, 3, 16, calendar: calendar)
        )

        // WHEN
        let cells = HeatmapService(
            calendar: calendar,
            premiumStatus: .premium,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: HabitGoal.from(habit: habit)
        )

        // THEN
        guard let loggedCell = cell(on: loggedDay, in: cells) else {
            XCTFail("Expected a heatmap cell for logged day")
            return
        }
        XCTAssertEqual(loggedCell.value, 0.25, accuracy: 0.0001)
    }

    func testFreeUserLocksCellsOlderThanNinetyDays() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, hour: 12, minute: 0, calendar: calendar)
        let lockedDay = TestDateFactory.addingDays(-91, to: now, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: lockedDay, value: 1)],
            calendar: calendar
        )
        let range = dateRange(
            start: TestDateFactory.addingDays(-100, to: now, calendar: calendar),
            endInclusive: now
        )

        // WHEN
        let cells = HeatmapService(
            calendar: calendar,
            premiumStatus: .free,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: .open()
        )

        // THEN
        let lockedCell = cell(on: lockedDay, in: cells)
        XCTAssertEqual(lockedCell?.isLocked, true)
    }

    func testTodayCompletionIsConsistentAcrossListAndDetail() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, hour: 17, minute: 20, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: now, value: 1)],
            calendar: calendar
        )
        let range = dateRange(
            start: TestDateFactory.addingDays(-3, to: now, calendar: calendar),
            endInclusive: now
        )
        let goal = HabitGoal.from(habit: habit)
        let listService = HeatmapService(calendar: calendar, premiumStatus: .premium, now: { now })
        let detailService = HeatmapService(calendar: calendar, premiumStatus: .premium, now: { now })

        // WHEN
        let listCells = listService.generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: goal
        )
        let detailCells = detailService.generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: range,
            goal: goal
        )

        // THEN
        let listToday = cell(on: today, in: listCells)
        let detailToday = cell(on: today, in: detailCells)
        XCTAssertEqual(listToday?.isCompleted, true)
        XCTAssertEqual(listToday, detailToday)
    }

    func testTimelineDateRangeIncludesTimelineEndDate() {
        // GIVEN
        let now = TestDateFactory.date(2026, 3, 16, hour: 17, minute: 20, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let timeline = HeatmapTimelineBuilder.yearTimeline(endingAt: now, calendar: calendar)
        let habit = TestHabitFactory.openEnded(
            entries: [.init(timestamp: now, value: 1)],
            calendar: calendar
        )

        // WHEN
        let cells = HeatmapService(
            calendar: calendar,
            premiumStatus: .premium,
            now: { now }
        ).generateCells(
            habit: habit,
            logs: habit.logs,
            dateRange: timeline.dateRange(calendar: calendar),
            goal: .open()
        )

        // THEN
        XCTAssertEqual(cells.count, 365)
        XCTAssertEqual(cells.last?.date, today)
        XCTAssertEqual(cells.last?.isToday, true)
        XCTAssertEqual(cells.last?.isCompleted, true)
    }

    private func dateRange(start: Date, endInclusive: Date) -> DateInterval {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: endInclusive)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: normalizedEnd) ?? normalizedEnd
        return DateInterval(start: normalizedStart, end: endExclusive)
    }

    private func cell(on day: Date, in cells: [HeatmapCell]) -> HeatmapCell? {
        let targetDay = calendar.startOfDay(for: day)
        return cells.first(where: { $0.date == targetDay })
    }
}
