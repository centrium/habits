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
        XCTAssertTrue(values.allSatisfy { $0.value >= 0.05 && $0.value <= 1.0 })
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
}
