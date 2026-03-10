import XCTest
@testable import Habits

final class HeatmapNormalizerTests: XCTestCase {
    func testOpenHabitTierUsesLogCountBands() {
        XCTAssertEqual(
            HeatmapNormalizer.tier(
                for: HeatmapNormalizationContext(
                    goalType: .frequency,
                    hasGoal: false,
                    targetValue: nil,
                    dailyLogCount: 0,
                    dailyLogValue: 0,
                    maxDailyValueInWindow: 0
                )
            ),
            0
        )
        XCTAssertEqual(
            HeatmapNormalizer.tier(
                for: HeatmapNormalizationContext(
                    goalType: .frequency,
                    hasGoal: false,
                    targetValue: nil,
                    dailyLogCount: 1,
                    dailyLogValue: 1,
                    maxDailyValueInWindow: 0
                )
            ),
            1
        )
        XCTAssertEqual(
            HeatmapNormalizer.tier(
                for: HeatmapNormalizationContext(
                    goalType: .frequency,
                    hasGoal: false,
                    targetValue: nil,
                    dailyLogCount: 2,
                    dailyLogValue: 2,
                    maxDailyValueInWindow: 0
                )
            ),
            2
        )
        XCTAssertEqual(
            HeatmapNormalizer.tier(
                for: HeatmapNormalizationContext(
                    goalType: .frequency,
                    hasGoal: false,
                    targetValue: nil,
                    dailyLogCount: 3,
                    dailyLogValue: 3,
                    maxDailyValueInWindow: 0
                )
            ),
            3
        )
    }

    func testFrequencyGoalTierUsesProgressBandsAndCapsAtMax() {
        let lowTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .frequency,
                hasGoal: true,
                targetValue: 10,
                dailyLogCount: 2,
                dailyLogValue: 2,
                maxDailyValueInWindow: 0
            )
        )
        let mediumTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .frequency,
                hasGoal: true,
                targetValue: 10,
                dailyLogCount: 7,
                dailyLogValue: 7,
                maxDailyValueInWindow: 0
            )
        )
        let maxTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .frequency,
                hasGoal: true,
                targetValue: 10,
                dailyLogCount: 10,
                dailyLogValue: 10,
                maxDailyValueInWindow: 0
            )
        )
        let overGoalTier = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .frequency,
                hasGoal: true,
                targetValue: 10,
                dailyLogCount: 18,
                dailyLogValue: 18,
                maxDailyValueInWindow: 0
            )
        )

        XCTAssertEqual(lowTier, 1)
        XCTAssertEqual(mediumTier, 2)
        XCTAssertEqual(maxTier, 3)
        XCTAssertEqual(overGoalTier, 3)
    }

    func testCumulativeGoalTierUsesRelativeDailyEffortInWindow() {
        let level1 = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .cumulative,
                hasGoal: true,
                targetValue: 200,
                dailyLogCount: 1,
                dailyLogValue: 30,
                maxDailyValueInWindow: 120
            )
        )
        let level2 = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .cumulative,
                hasGoal: true,
                targetValue: 200,
                dailyLogCount: 1,
                dailyLogValue: 70,
                maxDailyValueInWindow: 120
            )
        )
        let level3 = HeatmapNormalizer.tier(
            for: HeatmapNormalizationContext(
                goalType: .cumulative,
                hasGoal: true,
                targetValue: 200,
                dailyLogCount: 1,
                dailyLogValue: 120,
                maxDailyValueInWindow: 120
            )
        )

        XCTAssertEqual(level1, 1)
        XCTAssertEqual(level2, 2)
        XCTAssertEqual(level3, 3)
    }
}
