import Foundation

struct InsightLog {
    let date: Date
    let dayStart: Date
    let frequencyValue: Int
    let cumulativeValue: Double
}

enum HabitInsightMode {
    case openEnded
    case frequency(target: Double, cadence: GoalPeriod)
    case cumulative(target: Double, cadence: GoalPeriod)
}

struct InsightPeriodBucket {
    let start: Date
    let end: Date
    let frequencyTotal: Int
    let cumulativeTotal: Double
    let activeDays: Int
}

struct AchievementMetric {
    let progress: Double
    let target: Double?
    let progressClamped: Double
    let surplus: Double
    let completionRatio: Double?
    let isComplete: Bool
}

struct ConsistencyMetric {
    let activeDayRatio: Double
    let averageActiveDaysPerWeek: Double
}

struct TrendMonth {
    let monthStart: Date
    let label: String
    let total: Double
    let target: Double?
    let completionRatio: Double?
}

struct TrendMetric {
    let months: [TrendMonth]
}

struct HabitInsightSnapshot {
    let mode: HabitInsightMode
    let achievement: AchievementMetric
    let consistency: ConsistencyMetric
    let trend: TrendMetric
    let pace: PaceInsight?
    let activitySummary: ActivitySummaryInsight?
    let patternSignals: PatternSignals?
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
}

enum InsightLogNormalizer {
    static func normalize(
        logs: [HabitLog],
        calendar: Calendar
    ) -> [InsightLog] {
        logs.map { log in
            let date = log.effectiveTimestamp
            return InsightLog(
                date: date,
                dayStart: calendar.startOfDay(for: date),
                frequencyValue: max(1, log.frequencyContribution),
                cumulativeValue: max(0, log.numericValue)
            )
        }
    }
}

enum HabitInsightModeResolver {
    static func resolve(for habit: Habit) -> HabitInsightMode {
        guard habit.hasGoal, let target = habit.effectiveTargetValue else {
            return .openEnded
        }

        switch habit.goalType {
        case .frequency:
            return .frequency(target: target, cadence: habit.goalPeriod)
        case .cumulative:
            return .cumulative(target: target, cadence: habit.goalPeriod)
        }
    }
}

enum InsightBucketBuilder {
    static func goalPeriodBuckets(
        logs: [InsightLog],
        cadence: GoalPeriod,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> [Date: InsightPeriodBucket] {

        var grouped: [Date: (frequency: Int, cumulative: Double, activeDays: Set<Date>, end: Date)] = [:]

        for log in logs {
            let start = cadence.periodStart(
                for: log.date,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
            let end = cadence.nextPeriodStart(
                after: start,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )

            var aggregate = grouped[start] ?? (0, 0, Set<Date>(), end)
            aggregate.frequency += log.frequencyValue
            aggregate.cumulative += log.cumulativeValue
            aggregate.activeDays.insert(log.dayStart)
            aggregate.end = end
            grouped[start] = aggregate
        }

        var result: [Date: InsightPeriodBucket] = [:]
        for (start, aggregate) in grouped {
            result[start] = InsightPeriodBucket(
                start: start,
                end: aggregate.end,
                frequencyTotal: aggregate.frequency,
                cumulativeTotal: aggregate.cumulative,
                activeDays: aggregate.activeDays.count
            )
        }
        return result
    }

    static func monthlyBuckets(
        logs: [InsightLog],
        calendar: Calendar,
        anchorDate: Date,
        months: Int = 6
    ) -> [InsightPeriodBucket] {

        let anchorMonthStart = calendar.dateInterval(of: .month, for: anchorDate)?.start
            ?? calendar.startOfDay(for: anchorDate)

        let firstMonthStart = calendar.date(byAdding: .month, value: -(months - 1), to: anchorMonthStart)
            ?? anchorMonthStart

        var grouped: [Date: (frequency: Int, cumulative: Double, activeDays: Set<Date>)] = [:]
        for log in logs {
            let monthStart = calendar.dateInterval(of: .month, for: log.date)?.start
                ?? calendar.startOfDay(for: log.date)
            guard monthStart >= firstMonthStart, monthStart <= anchorMonthStart else {
                continue
            }

            var aggregate = grouped[monthStart] ?? (0, 0, Set<Date>())
            aggregate.frequency += log.frequencyValue
            aggregate.cumulative += log.cumulativeValue
            aggregate.activeDays.insert(log.dayStart)
            grouped[monthStart] = aggregate
        }

        var buckets: [InsightPeriodBucket] = []
        buckets.reserveCapacity(months)

        for monthOffset in 0..<months {
            guard let start = calendar.date(byAdding: .month, value: monthOffset, to: firstMonthStart) else {
                continue
            }
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            let aggregate = grouped[start] ?? (0, 0, Set<Date>())
            buckets.append(
                InsightPeriodBucket(
                    start: start,
                    end: end,
                    frequencyTotal: aggregate.frequency,
                    cumulativeTotal: aggregate.cumulative,
                    activeDays: aggregate.activeDays.count
                )
            )
        }

        return buckets
    }
}

enum AchievementCalculator {
    static func calculate(
        mode: HabitInsightMode,
        bucket: InsightPeriodBucket
    ) -> AchievementMetric {
        switch mode {
        case .openEnded:
            let progress = Double(bucket.frequencyTotal)
            return AchievementMetric(
                progress: progress,
                target: nil,
                progressClamped: progress,
                surplus: 0,
                completionRatio: nil,
                isComplete: progress > 0
            )
        case .frequency(let target, _):
            return goalBasedMetric(progress: Double(bucket.frequencyTotal), target: target)
        case .cumulative(let target, _):
            return goalBasedMetric(progress: bucket.cumulativeTotal, target: target)
        }
    }

    private static func goalBasedMetric(progress: Double, target: Double) -> AchievementMetric {
        let clamped = min(progress, target)
        let surplus = max(progress - target, 0)
        let ratio = target > 0 ? (clamped / target) : 0
        return AchievementMetric(
            progress: progress,
            target: target,
            progressClamped: clamped,
            surplus: surplus,
            completionRatio: ratio,
            isComplete: progress >= target
        )
    }
}

enum ConsistencyCalculator {
    static func calculate(
        logs: [InsightLog],
        trackingStart: Date,
        now: Date,
        calendar: Calendar
    ) -> ConsistencyMetric {
        _ = trackingStart

        let windowDays = 30.0
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        let activeDays = Set(
            logs
                .filter { $0.date >= windowStart && $0.date <= now }
                .map(\.dayStart)
        ).count

        let rawRatio = Double(activeDays) / windowDays
        let ratio = min(max(rawRatio, 0), 1)
        let averageDaysPerWeek = min(max(Double(activeDays) / 4.3, 0), 7)

        return ConsistencyMetric(
            activeDayRatio: ratio,
            averageActiveDaysPerWeek: averageDaysPerWeek
        )
    }
}

enum TrendCalculator {
    static func calculate(
        monthlyBuckets: [InsightPeriodBucket],
        mode: HabitInsightMode,
        calendar: Calendar
    ) -> TrendMetric {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        let months = monthlyBuckets.map { bucket in
            switch mode {
            case .openEnded:
                let total = Double(bucket.frequencyTotal)
                return TrendMonth(
                    monthStart: bucket.start,
                    label: formatter.string(from: bucket.start),
                    total: total,
                    target: nil,
                    completionRatio: nil
                )

            case .frequency(let target, _):
                let total = Double(bucket.frequencyTotal)
                let ratio = target > 0 ? (total / target) : nil
                return TrendMonth(
                    monthStart: bucket.start,
                    label: formatter.string(from: bucket.start),
                    total: total,
                    target: target,
                    completionRatio: ratio
                )

            case .cumulative(let target, _):
                let total = bucket.cumulativeTotal
                let ratio = target > 0 ? (total / target) : nil
                return TrendMonth(
                    monthStart: bucket.start,
                    label: formatter.string(from: bucket.start),
                    total: total,
                    target: target,
                    completionRatio: ratio
                )
            }
        }

        return TrendMetric(months: months)
    }
}

extension HabitInsightsEngine {
    struct Snapshot {

        struct Period {
            let start: Date
            let end: Date
            let progress: Double
            let progressClamped: Double
            let target: Double?
            let completionRatio: Double?
            let surplus: Double
            let isCompleted: Bool?
        }

        struct Streak {
            let current: Int
            let longest: Int
        }

        let currentPeriod: Period
        let streak: Streak
    }

    static func snapshot(
        for habit: Habit,
        anchorDate: Date,
        respectCreatedAtBoundary: Bool = true,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        now: Date = .now
    ) -> Snapshot {

        let foundation = habitInsightSnapshot(
            for: habit,
            anchorDate: anchorDate,
            globalLogs: [],
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            now: now
        )

        let period = Snapshot.Period(
            start: foundation.currentPeriodStart,
            end: foundation.currentPeriodEnd,
            progress: foundation.achievement.progress,
            progressClamped: foundation.achievement.progressClamped,
            target: foundation.achievement.target,
            completionRatio: foundation.achievement.completionRatio,
            surplus: foundation.achievement.surplus,
            isCompleted: foundation.mode.goalTarget.map { foundation.achievement.progress >= $0 }
        )

        let streak = StreakService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).streak(
            for: habit,
            referenceDate: anchorDate
        )

        return Snapshot(
            currentPeriod: period,
            streak: Snapshot.Streak(current: streak.current, longest: streak.best)
        )
    }

    static func habitInsightSnapshot(
        for habit: Habit,
        anchorDate: Date,
        globalLogs: [HabitLog] = [],
        calendar: Calendar,
        weekStartPreference: WeekStartPreference,
        now: Date
    ) -> HabitInsightSnapshot {
        let logs = InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar)
        let mode = HabitInsightModeResolver.resolve(for: habit)
        let cadence = habit.goalPeriod

        let currentPeriodStart = cadence.periodStart(
            for: anchorDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let currentPeriodEnd = cadence.nextPeriodStart(
            after: currentPeriodStart,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let periodBuckets = InsightBucketBuilder.goalPeriodBuckets(
            logs: logs,
            cadence: cadence,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let currentPeriodBucket = periodBuckets[currentPeriodStart] ?? InsightPeriodBucket(
            start: currentPeriodStart,
            end: currentPeriodEnd,
            frequencyTotal: 0,
            cumulativeTotal: 0,
            activeDays: 0
        )

        let monthlyBuckets = InsightBucketBuilder.monthlyBuckets(
            logs: logs,
            calendar: calendar,
            anchorDate: now
        )

        let achievement = AchievementCalculator.calculate(
            mode: mode,
            bucket: currentPeriodBucket
        )

        let consistency = ConsistencyCalculator.calculate(
            logs: logs,
            trackingStart: habit.createdAt,
            now: now,
            calendar: calendar
        )

        let trend = TrendCalculator.calculate(
            monthlyBuckets: monthlyBuckets,
            mode: mode,
            calendar: calendar
        )

        let progressSoFar = periodProgressSoFar(
            mode: mode,
            logs: logs,
            periodStart: currentPeriodStart,
            now: now
        )

        let pace = PaceCalculator.calculate(
            mode: mode,
            cadence: cadence,
            periodStart: currentPeriodStart,
            periodEnd: currentPeriodEnd,
            progressSoFar: progressSoFar,
            now: now
        )

        let activitySummary: ActivitySummaryInsight? = {
            guard case .openEnded = mode else { return nil }
            return ActivitySummaryCalculator.calculate(
                logs: logs,
                now: now,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
        }()

        let rawHabitLogs = habit.logs.filter { $0.kind == .entry && $0.timestamp != nil }
        let rawGlobalLogs = globalLogs.filter { $0.kind == .entry && $0.timestamp != nil }
        let resolvedGlobalLogs = rawGlobalLogs.isEmpty ? rawHabitLogs : rawGlobalLogs
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1" {
            print("[TimeInsight ROUTING]")
            print("habitType: \(habitTypeLabel(for: habit))")
            print("inputCount: \(rawHabitLogs.count)")
            print("engineUsed: true")
        }
        #endif
        let timingInsight = TimeInsightEngine.compute(
            logs: rawHabitLogs,
            globalLogs: resolvedGlobalLogs,
            debugLabel: habit.name,
            now: now,
            calendar: calendar
        )
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1" {
            let consumerHour = timingInsight.peakHour
            let match = consumerHour == timingInsight.peakHour
            print("[TimeInsight CONSISTENCY CHECK]")
            print("surface: Detail")
            print("enginePeak: \(timingInsight.peakHour)")
            print("consumerHour: \(consumerHour)")
            print("match: \(match)")
        }
        #endif
        let patternSignals = PatternCalculator.calculate(
            logs: logs,
            calendar: calendar,
            now: now,
            timeInsight: timingInsight
        )

        return HabitInsightSnapshot(
            mode: mode,
            achievement: achievement,
            consistency: consistency,
            trend: trend,
            pace: pace,
            activitySummary: activitySummary,
            patternSignals: patternSignals,
            currentPeriodStart: currentPeriodStart,
            currentPeriodEnd: currentPeriodEnd
        )
    }
}

private extension HabitInsightsEngine {
    static func habitTypeLabel(for habit: Habit) -> String {
        if habit.goalType == .cumulative { return "cumulative" }
        if habit.hasGoal { return "frequency" }
        return "open"
    }
}

private extension HabitInsightsEngine {
    static func periodProgressSoFar(
        mode: HabitInsightMode,
        logs: [InsightLog],
        periodStart: Date,
        now: Date
    ) -> Double {
        let inRange = logs.filter { $0.date >= periodStart && $0.date < now }
        switch mode {
        case .openEnded:
            return Double(inRange.reduce(0) { $0 + $1.frequencyValue })
        case .frequency:
            return Double(inRange.reduce(0) { $0 + $1.frequencyValue })
        case .cumulative:
            return inRange.reduce(0) { $0 + $1.cumulativeValue }
        }
    }
}

private extension HabitInsightMode {
    var goalTarget: Double? {
        switch self {
        case .openEnded:
            return nil
        case .frequency(let target, _):
            return target
        case .cumulative(let target, _):
            return target
        }
    }
}
