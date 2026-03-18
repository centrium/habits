import Foundation

enum HeatmapIntensityCalculator {
    static func intensity(
        for day: Date,
        habit: Habit,
        logs: [HabitLog],
        calendar: Calendar
    ) -> Double {
        let dayLogs = logs.filter { log in
            calendar.isDate(log.effectiveTimestamp, inSameDayAs: day)
        }

        guard !dayLogs.isEmpty else { return 0 }

        if !habit.hasStreakGoal {
            let hasCompletion = dayLogs.contains { log in
                log.frequencyContribution > 0 || log.numericValue > 0
            }
            return hasCompletion ? 1 : 0
        }

        guard let target = habit.effectiveTargetValue, target > 0 else {
            return 0
        }

        let value: Double
        switch habit.goalType {
        case .frequency:
            value = Double(dayLogs.reduce(0) { partialResult, log in
                partialResult + max(0, log.frequencyContribution)
            })
        case .cumulative:
            value = dayLogs.reduce(0) { partialResult, log in
                partialResult + max(0, log.numericValue)
            }
        }

        return clamp(value / target)
    }

    static func level(for intensity: Double) -> Double {
        let clamped = clamp(intensity)
        guard clamped > 0 else { return 0 }

        switch clamped {
        case ..<0.25:
            return 0.25
        case ..<0.5:
            return 0.5
        case ..<0.75:
            return 0.75
        default:
            return 1
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
