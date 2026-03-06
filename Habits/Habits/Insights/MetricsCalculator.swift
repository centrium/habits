import Foundation

struct TrendBucket {
    let periodStart: Date
    let label: String
    let total: Double
    let target: Double?
    let completionRatio: Double?
}

struct HabitMetricsSnapshot {
    let progress: Double
    let target: Double?
    let completionRatio: Double?
    let currentStreak: Int
    let longestStreak: Int
    let consistencyScore: Double?
    let averageDaysPerWeek: Double?
    let trendBuckets: [TrendBucket]
}

enum MetricsCalculator {
    static func calculate(
        foundation: HabitInsightSnapshot,
        streak: HabitInsightsEngine.Snapshot.Streak
    ) -> HabitMetricsSnapshot {
        HabitMetricsSnapshot(
            progress: foundation.achievement.progress,
            target: foundation.achievement.target,
            completionRatio: foundation.achievement.completionRatio,
            currentStreak: streak.current,
            longestStreak: streak.longest,
            consistencyScore: foundation.consistency.activeDayRatio,
            averageDaysPerWeek: foundation.consistency.averageActiveDaysPerWeek,
            trendBuckets: foundation.trend.months.map {
                TrendBucket(
                    periodStart: $0.monthStart,
                    label: $0.label,
                    total: $0.total,
                    target: $0.target,
                    completionRatio: $0.completionRatio
                )
            }
        )
    }
}
