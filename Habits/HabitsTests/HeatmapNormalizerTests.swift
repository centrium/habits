import XCTest
@testable import Habits

final class HeatmapNormalizerTests: XCTestCase {
    func testOutlierSpikeDoesNotCollapseRemainingDistribution() {
        let recentValues = Array(repeating: 1.0, count: 16) +
            Array(repeating: 2.0, count: 12) +
            Array(repeating: 3.0, count: 8) +
            [40, 60, 120, 250]

        let mediumTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .cumulative,
                hasTarget: false,
                targetValue: nil,
                metricKind: .currency,
                dailyValue: 3,
                recentDailyValues: recentValues
            )
        )

        XCTAssertGreaterThanOrEqual(mediumTier, 2)
        XCTAssertLessThan(mediumTier, 4)
    }

    func testTopTierRemainsReachableForLargeCurrencyValues() {
        let recentValues = Array(repeating: 25.0, count: 16) +
            Array(repeating: 50.0, count: 18) +
            Array(repeating: 100.0, count: 12) +
            Array(repeating: 150.0, count: 4) +
            [300, 400]

        let brightTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .cumulative,
                hasTarget: true,
                targetValue: 500,
                metricKind: .currency,
                dailyValue: 300,
                recentDailyValues: recentValues
            )
        )

        XCTAssertEqual(brightTier, 4)
    }

    func testSmallValuesStillShowVariation() {
        let recentValues = [0, 1, 1, 2, 2, 3, 3, 4, 5, 6]

        let lowTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .cumulative,
                hasTarget: false,
                targetValue: nil,
                metricKind: .genericValue,
                dailyValue: 1,
                recentDailyValues: recentValues
            )
        )
        let higherTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .cumulative,
                hasTarget: false,
                targetValue: nil,
                metricKind: .genericValue,
                dailyValue: 5,
                recentDailyValues: recentValues
            )
        )

        XCTAssertLessThan(lowTier, higherTier)
    }
}
