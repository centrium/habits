//
//  HeatmapNormalizer.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import Foundation

struct HeatmapNormalizationContext {
    let goalType: GoalType
    let hasTarget: Bool
    let targetValue: Double?
    let metricKind: MetricKind
    let dailyValue: Double
    let recentDailyValues: [Double]
}

enum HeatmapNormalizer {
    private enum Constants {
        static let smallSampleCount = 10
        static let smallDatasetCapPercentile = 0.95
        static let largeDatasetCapPercentile = 0.97
    }

    static func tier(for context: HeatmapNormalizationContext) -> Int {
        let normalizedDailyValue = normalizedDailyValue(for: context)
        guard normalizedDailyValue > 0 else { return 0 }

        if context.goalType == .frequency,
           context.hasTarget,
           let target = context.targetValue,
           target > 0,
           target <= 3 {
            return smallTargetFrequencyTier(for: normalizedDailyValue, target: target)
        }

        let positiveValues = normalizedRecentValues(for: context)
            .filter { $0 > 0 }
            .sorted()

        guard !positiveValues.isEmpty else { return 4 }

        let distribution = heatmapDistribution(
            for: positiveValues,
            goalType: context.goalType,
            hasTarget: context.hasTarget,
            targetValue: context.targetValue
        )

        if distribution.positiveValues.count < Constants.smallSampleCount {
            return fallbackTier(for: normalizedDailyValue, positiveValues: distribution.positiveValues)
        }

        let clippedValue = min(normalizedDailyValue, distribution.cap)
        let lessCount = distribution.clippedValues.filter { $0 < clippedValue }.count
        let equalCount = distribution.clippedValues.filter { $0 == clippedValue }.count
        let rank = (Double(lessCount) + (Double(equalCount) * 0.5)) / Double(distribution.clippedValues.count)

        switch rank {
        case ...0.50:
            return 1
        case ...0.75:
            return 2
        case ...0.90:
            return 3
        default:
            return 4
        }
    }

    static func intensity(forTier tier: Int) -> Double {
        switch tier {
        case 0:
            return 0
        case 1:
            return 0.24
        case 2:
            return 0.40
        case 3:
            return 0.56
        default:
            return 0.86
        }
    }

    private struct Distribution {
        let positiveValues: [Double]
        let clippedValues: [Double]
        let cap: Double
    }

    private static func normalizedDailyValue(for context: HeatmapNormalizationContext) -> Double {
        guard context.goalType == .frequency,
              context.hasTarget,
              let target = context.targetValue,
              target > 0 else {
            return max(0, context.dailyValue)
        }

        return min(max(0, context.dailyValue), target)
    }

    private static func normalizedRecentValues(for context: HeatmapNormalizationContext) -> [Double] {
        guard context.goalType == .frequency,
              context.hasTarget,
              let target = context.targetValue,
              target > 0 else {
            return context.recentDailyValues.map { max(0, $0) }
        }

        return context.recentDailyValues.map { min(max(0, $0), target) }
    }

    private static func heatmapDistribution(
        for positiveValues: [Double],
        goalType: GoalType,
        hasTarget: Bool,
        targetValue: Double?
    ) -> Distribution {
        if goalType == .frequency,
           hasTarget,
           let targetValue,
           targetValue > 3 {
            return Distribution(
                positiveValues: positiveValues,
                clippedValues: positiveValues,
                cap: targetValue
            )
        }

        let capPercentile = positiveValues.count < 20
            ? Constants.smallDatasetCapPercentile
            : Constants.largeDatasetCapPercentile
        let cap = percentileValue(in: positiveValues, percentile: capPercentile)
        let clippedValues = positiveValues
            .map { min($0, cap) }
            .sorted()

        return Distribution(
            positiveValues: positiveValues,
            clippedValues: clippedValues,
            cap: cap
        )
    }

    private static func smallTargetFrequencyTier(for value: Double, target: Double) -> Int {
        let cappedValue = min(value, target)

        switch Int(target.rounded()) {
        case ...1:
            return 4
        case 2:
            return cappedValue >= 2 ? 4 : 2
        default:
            if cappedValue >= 3 {
                return 4
            }
            if cappedValue >= 2 {
                return 3
            }
            return 1
        }
    }

    private static func fallbackTier(for value: Double, positiveValues: [Double]) -> Int {
        guard let largest = positiveValues.last else { return 0 }

        let cap = positiveValues.count >= 2
            ? positiveValues[positiveValues.count - 2]
            : largest
        let clippedValue = min(value, cap)
        let tier1 = cap * 0.50
        let tier2 = cap * 0.75
        let tier3 = cap * 0.90

        switch clippedValue {
        case ...0:
            return 0
        case ...tier1:
            return 1
        case ...tier2:
            return 2
        case ...tier3:
            return 3
        default:
            return 4
        }
    }

    private static func percentileValue(in sortedValues: [Double], percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        if sortedValues.count == 1 { return sortedValues[0] }

        let clampedPercentile = min(max(percentile, 0), 1)
        let index = min(
            sortedValues.count - 1,
            Int(Double(sortedValues.count - 1) * clampedPercentile)
        )
        return sortedValues[index]
    }
}
