//
//  HeatmapNormalizer.swift
//  Habits
//
//  Created by Codex on 02/03/2026.
//

import Foundation

struct HeatmapNormalizationContext {
    let goalType: GoalType
    let hasGoal: Bool
    let targetValue: Double?
    let dailyLogCount: Int
    let dailyLogValue: Double
    let maxDailyValueInWindow: Double
}

enum HeatmapNormalizer {
    static func tier(for context: HeatmapNormalizationContext) -> Int {
        guard context.hasGoal else {
            return openHabitLogCountTier(for: context.dailyLogCount)
        }

        switch context.goalType {
        case .frequency:
            guard let target = context.targetValue, target > 0 else { return 0 }
            let progress = Double(max(0, context.dailyLogCount)) / target
            return goalProgressTier(for: progress)
        case .cumulative:
            guard context.maxDailyValueInWindow > 0 else { return 0 }
            let ratio = max(0, context.dailyLogValue) / context.maxDailyValueInWindow
            return cumulativeEffortTier(for: ratio)
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
        default:
            return 0.56
        }
    }

    private static func openHabitLogCountTier(for dailyLogCount: Int) -> Int {
        switch dailyLogCount {
        case ...0:
            return 0
        case 1:
            return 1
        case 2:
            return 2
        default:
            return 3
        }
    }

    private static func goalProgressTier(for progress: Double) -> Int {
        switch progress {
        case ...0:
            return 0
        case ..<0.5:
            return 1
        case ..<1:
            return 2
        default:
            return 3
        }
    }

    private static func cumulativeEffortTier(for ratio: Double) -> Int {
        switch ratio {
        case ...0:
            return 0
        case ...0.33:
            return 1
        case ...0.66:
            return 2
        default:
            return 3
        }
    }
}
