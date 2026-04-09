import Foundation

enum HeatmapRenderIntensity {
    static func value(for metrics: HabitDayMetrics, habit: Habit) -> Double {
        let base = clamp(metrics.intensity)
        guard base > 0 else { return 0 }

        // Preserve normal progression below peak; only differentiate within saturated days.
        guard base >= 0.999 else { return base }

        let overflowBoost: Double
        if habit.hasStreakGoal, let target = habit.effectiveTargetValue, target > 0 {
            switch habit.goalType {
            case .frequency:
                let over = max(0, Double(metrics.count) - target)
                overflowBoost = min(over / max(target * 4, 1), 0.55)
            case .cumulative:
                let over = max(0, metrics.value - target)
                overflowBoost = min(over / max(target * 4, 1), 0.55)
            }
        } else {
            let extraEntries = max(0, metrics.count - 1)
            let scaled = log1p(Double(extraEntries)) / log(6)
            overflowBoost = min(max(0, scaled) * 0.4, 0.4)
        }

        return 1 + overflowBoost
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
