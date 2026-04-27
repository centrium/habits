import XCTest
@testable import Habits

final class TimeOfDayPerformanceServiceTests: BaseTestCase {
    @MainActor
    func testTimeInsightInputAuditByHabitTypeUsesRawTimestampsOnly() async throws {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 23, calendar: calendar)

        let frequency = TestHabitFactory.frequency(
            name: "Read",
            hasGoal: true,
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 6, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1)
            ],
            calendar: calendar
        )
        frequency.logs.append(
            TestHabitFactory.legacyLog(
                on: TestDateFactory.date(2026, 4, 14, hour: 0, minute: 0, calendar: calendar),
                count: 3,
                calendar: calendar
            )
        )

        let open = TestHabitFactory.openEnded(
            name: "Start Cycling",
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 4, 12, hour: 21, minute: 6, calendar: calendar), value: 1),
                .init(timestamp: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 42, calendar: calendar), value: 1)
            ],
            calendar: calendar
        )
        open.logs.append(
            TestHabitFactory.legacyLog(
                on: TestDateFactory.date(2026, 4, 10, hour: 0, minute: 0, calendar: calendar),
                count: 2,
                calendar: calendar
            )
        )

        let cumulative = TestHabitFactory.cumulative(
            name: "Hydration",
            entries: [
                .init(timestamp: TestDateFactory.date(2026, 4, 12, hour: 20, minute: 45, calendar: calendar), value: 250),
                .init(timestamp: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 15, calendar: calendar), value: 300)
            ],
            calendar: calendar
        )
        cumulative.logs.append(
            TestHabitFactory.legacyLog(
                on: TestDateFactory.date(2026, 4, 9, hour: 0, minute: 0, calendar: calendar),
                count: 1,
                calendar: calendar
            )
        )

        let frequencyValues = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: frequency,
            globalLogs: frequency.logs,
            days: 21,
            now: now,
            calendar: calendar
        )
        let openValues = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: open,
            globalLogs: open.logs,
            days: 21,
            now: now,
            calendar: calendar
        )
        let cumulativeValues = await TimeOfDayPerformanceService.shared.hourlyValues(
            for: cumulative,
            globalLogs: cumulative.logs,
            days: 21,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(frequencyValues.count, 24)
        XCTAssertEqual(openValues.count, 24)
        XCTAssertEqual(cumulativeValues.count, 24)

        let frequencyRawTimestampCount = frequency.logs.filter { $0.kind == .entry && $0.timestamp != nil }.count
        let openRawTimestampCount = open.logs.filter { $0.kind == .entry && $0.timestamp != nil }.count
        let cumulativeRawTimestampCount = cumulative.logs.filter { $0.kind == .entry && $0.timestamp != nil }.count

        let frequencyRhythm = try XCTUnwrap(TimeOfDayPerformanceService.shared.cachedRhythm(for: frequency, isPremium: true))
        let openRhythm = try XCTUnwrap(TimeOfDayPerformanceService.shared.cachedRhythm(for: open, isPremium: true))
        let cumulativeRhythm = try XCTUnwrap(TimeOfDayPerformanceService.shared.cachedRhythm(for: cumulative, isPremium: true))

        XCTAssertEqual(frequencyRhythm.uniqueEventCount, frequencyRawTimestampCount)
        XCTAssertEqual(openRhythm.uniqueEventCount, openRawTimestampCount)
        XCTAssertEqual(cumulativeRhythm.uniqueEventCount, cumulativeRawTimestampCount)
    }

    func testCurrentDatasetOpenAndFrequencyPeakAt21() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 23, calendar: calendar)

        let startCyclingLogs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 10, hour: 12, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 10, hour: 12, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 12, hour: 21, minute: 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 12, hour: 21, minute: 7, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 12, hour: 22, minute: 3, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 19, minute: 14, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 8, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 20, minute: 59, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 41, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 42, calendar: calendar), value: 1, calendar: calendar)
        ]

        let readLogs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 6, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 22, minute: 29, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 0, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 0, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 0, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 0, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 30, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 31, calendar: calendar), value: 1, calendar: calendar)
        ]

        let startCyclingInsight = TimeInsightEngine.compute(
            logs: startCyclingLogs,
            globalLogs: startCyclingLogs + readLogs,
            now: now,
            calendar: calendar
        )
        let readInsight = TimeInsightEngine.compute(
            logs: readLogs,
            globalLogs: startCyclingLogs + readLogs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(startCyclingInsight.peakHour, 21)
        XCTAssertEqual(readInsight.peakHour, 21)
    }

    @MainActor
    func testTimeInsightEngineProduces24HourlyScores() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 23, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 16, hour: 6, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 16, hour: 12, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 16, hour: 18, minute: 0, calendar: calendar), value: 1, calendar: calendar)
        ]

        let result = TimeInsightEngine.compute(
            logs: logs,
            globalLogs: logs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.hourlyScores.count, 24)
        XCTAssertTrue(result.hourlyScores.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    func testGenerateRhythmInsightUsesProvidedPeak() {
        let insight = TimeInsightResult(
            hourlyScores: makeScores(peakHour: 12, peakValue: 1.0, baseline: 0.1),
            peakHour: 12,
            confidence: 0.8,
            distributionShape: .singlePeak
        )

        let rhythmInsight = generateRhythmInsight(from: insight)

        XCTAssertEqual(rhythmInsight.peakHour, 12)
        XCTAssertTrue(rhythmInsight.summary.contains("strongest"))
    }

    func testHumanTimeFormatting() {
        XCTAssertEqual(humanTime(for: 0), "Midnight")
        XCTAssertEqual(humanTime(for: 13), "1PM")
        XCTAssertEqual(humanTime(for: 9), "9AM")
    }

    func testBestTimeRecommendationUsesTodayWhenFutureSlotIsStrong() {
        var scores = Array(repeating: 0.1, count: 24)
        scores[11] = 1.0
        scores[18] = 0.8
        let insight = TimeInsightResult(
            hourlyScores: scores,
            peakHour: 11,
            confidence: 0.8,
            distributionShape: .singlePeak
        )

        let recommendation = bestTimeRecommendation(from: insight, currentHour: 10)

        XCTAssertEqual(recommendation, BestTimeRecommendation(hour: 11, timeframe: .today))
    }

    func testBestTimeRecommendationFallsBackToTomorrowWhenFutureHoursPassed() {
        var scores = Array(repeating: 0.1, count: 24)
        scores[11] = 1.0
        scores[14] = 0.6
        let insight = TimeInsightResult(
            hourlyScores: scores,
            peakHour: 11,
            confidence: 0.8,
            distributionShape: .singlePeak
        )

        let recommendation = bestTimeRecommendation(from: insight, currentHour: 20)

        XCTAssertEqual(recommendation, BestTimeRecommendation(hour: 11, timeframe: .tomorrow))
    }
  
    func testPeakTimingSummaryPrefersLateEveningAndUsesActiveDayConfidence() {
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
        XCTAssertEqual(summary?.uniqueEventCount, 7)
        XCTAssertGreaterThan(summary?.confidence ?? 0, 0)
        XCTAssertLessThanOrEqual(summary?.confidence ?? 0, 1)
    }

    func testTimeInsightEngineSuppressesSingleDayNoonSpike() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 23, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 12, hour: 21, minute: 5, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 21, minute: 15, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 21, minute: 25, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 15, hour: 21, minute: 35, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 16, hour: 21, minute: 45, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 16, hour: 12, minute: 0, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 16, hour: 12, minute: 0, calendar: calendar), value: 1, calendar: calendar),
        ]

        let computation = TimeInsightEngine.computeDetails(
            logs: logs,
            globalLogs: logs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(computation.result.peakHour, 21)
        XCTAssertLessThan(computation.result.confidence, 0.5)
        XCTAssertGreaterThan(computation.result.hourlyScores[21], computation.result.hourlyScores[12])
    }

    func testTimeInsightEngineSmoothingKeepsPeakStable() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 23, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 10, hour: 21, minute: 5, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 11, hour: 21, minute: 5, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 12, hour: 21, minute: 5, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 13, hour: 20, minute: 5, calendar: calendar), value: 1, calendar: calendar),
            TestHabitFactory.entryLog(on: TestDateFactory.date(2026, 4, 14, hour: 22, minute: 5, calendar: calendar), value: 1, calendar: calendar)
        ]

        let result = TimeInsightEngine.compute(
            logs: logs,
            globalLogs: logs,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.peakHour, 21)
    }

    func testTimeInsightEngineSuppressesInsufficientSignalForSingleEvent() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 17, hour: 12, calendar: calendar)
        let logs: [HabitLog] = [
            TestHabitFactory.entryLog(
                on: TestDateFactory.date(2026, 4, 17, hour: 8, minute: 40, calendar: calendar),
                value: 1,
                calendar: calendar
            )
        ]

        let result = TimeInsightEngine.compute(
            logs: logs,
            globalLogs: logs,
            allowGlobalBlending: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.confidence, 0, accuracy: 0.0001)
        XCTAssertEqual(result.distributionShape, .flat)
        XCTAssertTrue(result.hourlyScores.allSatisfy { abs($0) < 0.0001 })
    }

    func testTimeInsightEnginePrefersRecentEveningClusterOverOlderNoonHistory() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 18, hour: 23, calendar: calendar)

        let oldNoonLogs = (0..<10).map { offset in
            TestHabitFactory.entryLog(
                on: TestDateFactory.addingDays(-20 - offset, to: now, calendar: calendar),
                value: 1,
                calendar: calendar
            )
        }.map { log in
            log.timestamp = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: log.effectiveTimestamp)
            return log
        }

        let recentEveningLogs = (0..<3).map { offset in
            TestHabitFactory.entryLog(
                on: TestDateFactory.addingDays(-offset, to: now, calendar: calendar),
                value: 1,
                calendar: calendar
            )
        }.map { log in
            log.timestamp = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: log.effectiveTimestamp)
            return log
        }

        let logs = oldNoonLogs + recentEveningLogs
        let result = TimeInsightEngine.compute(
            logs: logs,
            globalLogs: logs,
            allowGlobalBlending: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.peakHour, 22)
        XCTAssertGreaterThan(result.hourlyScores[22], result.hourlyScores[12])
    }

    func testTimeInsightEngineRecencyWeightingUsesTimestampNotCreatedAt() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 18, hour: 23, calendar: calendar)
        let oldEveningTimestamp = TestDateFactory.date(2026, 3, 1, hour: 22, minute: 0, calendar: calendar)
        let recentNoonTimestamp = TestDateFactory.date(2026, 4, 18, hour: 12, minute: 0, calendar: calendar)

        let logsCreatedNow: [HabitLog] = [
            TestHabitFactory.entryLog(
                on: oldEveningTimestamp,
                value: 1,
                createdAt: now,
                calendar: calendar
            ),
            TestHabitFactory.entryLog(
                on: recentNoonTimestamp,
                value: 1,
                createdAt: TestDateFactory.date(2026, 3, 1, hour: 9, minute: 0, calendar: calendar),
                calendar: calendar
            )
        ]

        let logsCreatedHistorical: [HabitLog] = [
            TestHabitFactory.entryLog(
                on: oldEveningTimestamp,
                value: 1,
                createdAt: TestDateFactory.date(2026, 3, 1, hour: 9, minute: 0, calendar: calendar),
                calendar: calendar
            ),
            TestHabitFactory.entryLog(
                on: recentNoonTimestamp,
                value: 1,
                createdAt: now,
                calendar: calendar
            )
        ]

        let resultCreatedNow = TimeInsightEngine.compute(
            logs: logsCreatedNow,
            globalLogs: logsCreatedNow,
            allowGlobalBlending: false,
            now: now,
            calendar: calendar
        )
        let resultCreatedHistorical = TimeInsightEngine.compute(
            logs: logsCreatedHistorical,
            globalLogs: logsCreatedHistorical,
            allowGlobalBlending: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(resultCreatedNow.peakHour, 12)
        XCTAssertEqual(resultCreatedNow.peakHour, resultCreatedHistorical.peakHour)
        XCTAssertEqual(resultCreatedNow.hourlyScores, resultCreatedHistorical.hourlyScores)
    }

    func testTimeInsightEngineSeparatedClustersChooseStrongerClusterNotMidpoint() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 18, hour: 23, calendar: calendar)
        let noonDates = [14, 12, 10].map { days in
            TestDateFactory.addingDays(-days, to: now, calendar: calendar)
        }
        let eveningDates = [7, 6, 5, 4, 3].map { days in
            TestDateFactory.addingDays(-days, to: now, calendar: calendar)
        }

        let noonLogs = noonDates.map { date in
            TestHabitFactory.entryLog(
                on: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date,
                value: 1,
                calendar: calendar
            )
        }
        let eveningLogs = eveningDates.map { date in
            TestHabitFactory.entryLog(
                on: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date) ?? date,
                value: 1,
                calendar: calendar
            )
        }
        let logs = noonLogs + eveningLogs

        let result = TimeInsightEngine.compute(
            logs: logs,
            globalLogs: logs,
            allowGlobalBlending: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.peakHour, 22)
        XCTAssertNotEqual(result.peakHour, 17)
    }

    func testTimeInsightEngineDownweightsSyntheticTimestampsUsingCreatedAtDelta() {
        let calendar = TestDateFactory.utcCalendar
        let now = TestDateFactory.date(2026, 4, 18, hour: 23, calendar: calendar)
        var logs: [HabitLog] = []

        for dayOffset in 0..<4 {
            let day = TestDateFactory.addingDays(-dayOffset, to: now, calendar: calendar)
            let noonTimestamp = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            let eveningTimestamp = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day) ?? day

            // Synthetic/backfilled: timestamp far from createdAt -> low trust.
            logs.append(
                TestHabitFactory.entryLog(
                    on: noonTimestamp,
                    value: 1,
                    createdAt: now,
                    calendar: calendar
                )
            )

            // Real-time log: timestamp close to createdAt -> high trust.
            logs.append(
                TestHabitFactory.entryLog(
                    on: eveningTimestamp,
                    value: 1,
                    createdAt: eveningTimestamp.addingTimeInterval(60),
                    calendar: calendar
                )
            )
        }

        let result = TimeInsightEngine.compute(
            logs: logs,
            globalLogs: logs,
            allowGlobalBlending: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.peakHour, 22)
        XCTAssertGreaterThan(result.hourlyScores[22], result.hourlyScores[12])
    }

    private func makeScores(peakHour: Int, peakValue: Double, baseline: Double) -> [Double] {
        var scores = Array(repeating: baseline, count: 24)
        scores[((peakHour % 24) + 24) % 24] = peakValue
        return scores
    }
}
