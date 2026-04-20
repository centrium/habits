import Foundation

struct ActivitySummaryInsight {
    let entriesThisWeek: Int
    let entriesThisMonth: Int
    let averageEntriesPerWeek: Double
    let summaryText: String
}

enum ActivitySummaryCalculator {
    static func calculate(
        logs: [InsightLog],
        now: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> ActivitySummaryInsight {
        let weekInterval = WeekBoundaryCalculator.weekInterval(
            containing: now,
            calendar: calendar,
            weekStart: weekStartPreference
        )
        let monthInterval = calendar.dateInterval(of: .month, for: now)
            ?? DateInterval(start: calendar.startOfDay(for: now), duration: 0)
        let rollingWindowStart = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now))
            ?? calendar.startOfDay(for: now)

        let entriesThisWeek = logs.filter { weekInterval.contains($0.dayStart) }.count
        let entriesThisMonth = logs.filter { monthInterval.contains($0.dayStart) }.count
        let entriesInRollingWindow = logs.filter {
            $0.dayStart >= rollingWindowStart && $0.dayStart <= calendar.startOfDay(for: now)
        }.count
        let averagePerWeek = Double(entriesInRollingWindow) / 4.3

        let summaryText: String = {
            if entriesThisWeek > 0 {
                return BehaviourCopyFormatter.activityCount(
                    entriesThisWeek,
                    timeframe: .weekly
                )
            }
            if entriesThisMonth > 0 {
                return BehaviourCopyFormatter.activityCount(
                    entriesThisMonth,
                    timeframe: .monthly
                )
            }
            return "Around \(averagePerWeek.formatted(.number.precision(.fractionLength(1)))) times per week recently."
        }()

        return ActivitySummaryInsight(
            entriesThisWeek: entriesThisWeek,
            entriesThisMonth: entriesThisMonth,
            averageEntriesPerWeek: averagePerWeek,
            summaryText: summaryText
        )
    }
}
