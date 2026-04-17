import XCTest
@testable import Habits

final class TimeOfDayPerformanceServiceTests: XCTestCase {
    @MainActor
    func testNormalisedHourlyValuesIncludesAllHoursWithFloor() {
        let values = TimeOfDayPerformanceService.shared.normalisedHourlyValues(
            counts: [6: 3, 12: 6, 18: 2]
        )

        XCTAssertEqual(values.count, 24)
        XCTAssertEqual(values.first?.hour, 0)
        XCTAssertEqual(values.last?.hour, 23)
        XCTAssertTrue(values.allSatisfy { $0.value >= 0.0 && $0.value <= 1.0 })
    }

    func testPeakHourChoosesHighestValue() {
        let data = [
            HourValue(hour: 8, value: 0.35),
            HourValue(hour: 12, value: 0.9),
            HourValue(hour: 17, value: 0.5)
        ]

        XCTAssertEqual(peakHour(from: data), 12)
    }

    func testGenerateRhythmInsightIncludesPeakAndDipRange() {
        let data = [
            HourValue(hour: 8, value: 0.2),
            HourValue(hour: 9, value: 0.25),
            HourValue(hour: 12, value: 0.92),
            HourValue(hour: 15, value: 0.12),
            HourValue(hour: 16, value: 0.1),
            HourValue(hour: 17, value: 0.14)
        ]

        let insight = generateRhythmInsight(data: data)

        XCTAssertEqual(insight.peakHour, 12)
        XCTAssertEqual(insight.lowRange.0, 15)
        XCTAssertEqual(insight.lowRange.1, 16)
        XCTAssertTrue(insight.summary.contains("strongest"))
    }

    func testHumanTimeFormatting() {
        XCTAssertEqual(humanTime(for: 0), "Midnight")
        XCTAssertEqual(humanTime(for: 13), "1PM")
        XCTAssertEqual(humanTime(for: 9), "9AM")
    }

    func testBestTimeRecommendationUsesTodayWhenFutureSlotIsStrong() {
        let data = [
            HourValue(hour: 9, value: 0.4),
            HourValue(hour: 11, value: 1.0),
            HourValue(hour: 18, value: 0.8)
        ]

        let recommendation = bestTimeRecommendation(from: data, currentHour: 10)

        XCTAssertEqual(recommendation, BestTimeRecommendation(hour: 11, timeframe: .today))
    }

    func testBestTimeRecommendationFallsBackToTomorrowWhenAllFutureHoursPassed() {
        let data = [
            HourValue(hour: 8, value: 0.7),
            HourValue(hour: 11, value: 1.0),
            HourValue(hour: 14, value: 0.6)
        ]

        let recommendation = bestTimeRecommendation(from: data, currentHour: 20)

        XCTAssertEqual(recommendation, BestTimeRecommendation(hour: 11, timeframe: .tomorrow))
    }

    func testBestTimeRecommendationFallsBackToTomorrowWhenFutureSignalIsWeak() {
        let data = [
            HourValue(hour: 11, value: 1.0),
            HourValue(hour: 17, value: 0.65),
            HourValue(hour: 19, value: 0.6)
        ]

        let recommendation = bestTimeRecommendation(from: data, currentHour: 15)

        XCTAssertEqual(recommendation, BestTimeRecommendation(hour: 11, timeframe: .tomorrow))
    }

    @MainActor
    func testHourlyValuesDeduplicatesEventsWithinSameMinute() async {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 22, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            name: "Reading",
            createdAt: TestDateFactory.date(2026, 4, 1, calendar: calendar),
            entries: [],
            calendar: calendar
        )

        let baseMinute = TestDateFactory.date(2026, 4, 16, hour: 13, minute: 5, calendar: calendar)
        habit.logs.append(TestHabitFactory.entryLog(on: baseMinute, value: 1, calendar: calendar))
        habit.logs.append(TestHabitFactory.entryLog(on: baseMinute.addingTimeInterval(30), value: 1, calendar: calendar))
        habit.logs.append(TestHabitFactory.entryLog(
            on: TestDateFactory.date(2026, 4, 16, hour: 21, minute: 0, calendar: calendar),
            value: 1,
            calendar: calendar
        ))

        _ = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: habit,
            globalLogs: habit.logs,
            days: 21,
            now: now,
            calendar: calendar
        )

        let rhythm = TimeOfDayPerformanceService.shared.cachedRhythm(for: habit, isPremium: true)
        XCTAssertEqual(rhythm?.uniqueEventCount, 2)
        XCTAssertEqual(rhythm?.confidence, 0.1)
    }

    @MainActor
    func testHourlyValuesBlendsTowardGlobalPatternWhenConfidenceIsLow() async {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 22, calendar: calendar)
        let habit = TestHabitFactory.frequency(
            name: "Stretch",
            createdAt: TestDateFactory.date(2026, 4, 1, calendar: calendar),
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 4, 14, hour: 13, minute: 0, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 4, 15, hour: 13, minute: 10, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 4, 16, hour: 13, minute: 20, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 4, 17, hour: 13, minute: 30, calendar: calendar), value: 1)
            ],
            calendar: calendar
        )

        let globalHabit = TestHabitFactory.frequency(
            name: "Global",
            createdAt: TestDateFactory.date(2026, 4, 1, calendar: calendar),
            entries: (0..<24).map { dayOffset in
                let date = TestDateFactory.addingDays(
                    dayOffset,
                    to: TestDateFactory.date(2026, 3, 24, hour: 21, minute: 0, calendar: calendar),
                    calendar: calendar
                )
                .init(
                    timestamp: calendar.date(
                        bySettingHour: 21,
                        minute: dayOffset % 60,
                        second: 0,
                        of: date
                    ) ?? date,
                    value: 1
                )
            },
            calendar: calendar
        )

        _ = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: habit,
            globalLogs: habit.logs + globalHabit.logs,
            days: 21,
            now: now,
            calendar: calendar
        )

        let rhythm = TimeOfDayPerformanceService.shared.cachedRhythm(for: habit, isPremium: true)
        XCTAssertEqual(rhythm?.peakHour, 21)
        XCTAssertEqual(rhythm?.uniqueEventCount, 4)
        XCTAssertEqual(rhythm?.confidence, 0.2)
    }

    func testPeakTimingSummaryForProvidedReadLogsPrefersLateEvening() {
        let calendar = TestDateFactory.utcCalendar
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 22, minute: 29, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 0, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 30, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar)
        ]

        let summary = TimeOfDayPerformanceService.peakTimingSummary(
            habitLogs: logs,
            globalLogs: logs,
            now: TestDateFactory.date(2026, 4, 17, hour: 12, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(summary?.peakHour, 21)
        XCTAssertEqual(summary?.uniqueEventCount, 5)
        XCTAssertEqual(summary?.confidence, 0.25)
    }
}
