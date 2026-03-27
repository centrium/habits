import Foundation

struct GlobalInsightsSnapshot: Equatable {
    let hero: GlobalInsightsHero
    let metrics: GlobalInsightsMetrics
    let topHabits: [GlobalInsightHabitRow]
    let greig: GlobalInsightsGreig
    let stripSummary: PremiumInsightsStripSummary
}

struct GlobalInsightsHero: Equatable {
    let momentum: Int
    let consistency: Int
    let statusText: String
}

struct GlobalInsightsMetrics: Equatable {
    let bestCurrentStreak: Int
    let bestDayOfWeek: String
    let atRiskCount: Int
}

struct GlobalInsightHabitRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let statusLabel: String
}

struct GlobalInsightsGreig: Equatable {
    let trajectoryText: String
    let suggestionText: String
    let outcomeText: String
}

struct PremiumInsightsStripSummary: Equatable {
    let primaryLabel: String
    let primaryValue: String
    let secondaryLabel: String
    let secondaryValue: String
    let secondarySuffix: String?
}

struct GlobalInsightsService {
    private let calendar: Calendar
    private let weekStartPreference: WeekStartPreference

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) {
        self.calendar = calendar
        self.weekStartPreference = weekStartPreference
    }

    func snapshot(
        for habits: [Habit],
        now: Date = .now
    ) -> GlobalInsightsSnapshot? {
        guard !habits.isEmpty else { return nil }

        let metricsByHabit = habits.map { habit in
            habitMetrics(for: habit, now: now)
        }

        let momentum = roundedAverage(metricsByHabit.map(\.momentum))
        let consistency = roundedAverage(metricsByHabit.map(\.consistency))
        let atRiskCount = metricsByHabit.filter { $0.riskScore >= 0.5 }.count

        let hero = GlobalInsightsHero(
            momentum: momentum,
            consistency: consistency,
            statusText: statusText(
                momentum: momentum,
                consistency: consistency,
                atRiskCount: atRiskCount
            )
        )

        let metrics = GlobalInsightsMetrics(
            bestCurrentStreak: metricsByHabit.map(\.currentStreak).max() ?? 0,
            bestDayOfWeek: bestDayOfWeek(from: metricsByHabit, fallbackDate: now),
            atRiskCount: atRiskCount
        )

        let rankedHabits = rankedHabitRows(from: metricsByHabit)
        let greig = greigSummary(from: metricsByHabit, now: now)
        let stripSummary = PremiumInsightsStripSummary(
            primaryLabel: "Momentum ",
            primaryValue: "\(momentum)%",
            secondaryLabel: "Consistency ",
            secondaryValue: "\(consistency)%",
            secondarySuffix: stripSuffix(for: atRiskCount)
        )

        return GlobalInsightsSnapshot(
            hero: hero,
            metrics: metrics,
            topHabits: rankedHabits,
            greig: greig,
            stripSummary: stripSummary
        )
    }
}

private extension GlobalInsightsService {
    struct HabitMetrics {
        let habit: Habit
        let momentum: Int
        let consistency: Int
        let riskScore: Double
        let progressRatio: Double?
        let currentStreak: Int
        let completedDays: Set<Date>
    }

    struct MonthSessionSummary {
        let completedSessions: Int
        let elapsedDays: Int
        let totalDays: Int
        let remainingDays: Int
    }

    func habitMetrics(
        for habit: Habit,
        now: Date
    ) -> HabitMetrics {
        let momentumService = MomentumScoreService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let insightsService = HabitInsightsService(calendar: calendar)
        let streakService = StreakService(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        return HabitMetrics(
            habit: habit,
            momentum: momentumService.score(for: habit, now: now),
            consistency: insightsService.snapshot(for: habit, now: now).consistency,
            riskScore: PerformanceSignalsCalculator.habitRiskScore(
                for: habit,
                calendar: calendar,
                now: now
            ),
            progressRatio: habit.progress(
                for: now,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            ),
            currentStreak: streakService.currentStreak(for: habit, referenceDate: now),
            completedDays: completedDays(for: habit, now: now)
        )
    }

    func roundedAverage(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return Int((Double(total) / Double(values.count)).rounded())
    }

    func statusText(
        momentum: Int,
        consistency: Int,
        atRiskCount: Int
    ) -> String {
        switch atRiskCount {
        case 0 where momentum >= 75 && consistency >= 75:
            return "Your routine looks steady right now."
        case 0:
            return "You're keeping a solid baseline."
        case 1:
            return "Most habits are steady; 1 needs attention."
        default:
            return "Most habits are steady, with \(atRiskCount) needing attention."
        }
    }

    func bestDayOfWeek(
        from metrics: [HabitMetrics],
        fallbackDate: Date
    ) -> String {
        var counts: [Int: Int] = [:]

        for day in metrics.flatMap(\.completedDays) {
            let weekday = calendar.component(.weekday, from: day)
            counts[weekday, default: 0] += 1
        }

        guard let bestWeekday = counts.max(by: { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value < rhs.value
            }
            return weekdayTieBreakRank(lhs.key) > weekdayTieBreakRank(rhs.key)
        })?.key else {
            return weekdayName(for: calendar.component(.weekday, from: fallbackDate))
        }

        return weekdayName(for: bestWeekday)
    }

    func rankedHabitRows(
        from metrics: [HabitMetrics]
    ) -> [GlobalInsightHabitRow] {
        let sorted = metrics.sorted { lhs, rhs in
            if riskBucket(for: lhs) != riskBucket(for: rhs) {
                return riskBucket(for: lhs) > riskBucket(for: rhs)
            }
            if riskBucket(for: lhs) == 1,
               abs(lhs.riskScore - rhs.riskScore) > 0.0001 {
                return lhs.riskScore > rhs.riskScore
            }

            if progressBucket(for: lhs) != progressBucket(for: rhs) {
                return progressBucket(for: lhs) > progressBucket(for: rhs)
            }
            if progressBucket(for: lhs) == 1 {
                let lhsProgress = lhs.progressRatio ?? 0
                let rhsProgress = rhs.progressRatio ?? 0
                if abs(lhsProgress - rhsProgress) > 0.0001 {
                    return lhsProgress > rhsProgress
                }
            }

            if lhs.consistency != rhs.consistency {
                return lhs.consistency > rhs.consistency
            }
            if lhs.momentum != rhs.momentum {
                return lhs.momentum > rhs.momentum
            }
            if lhs.habit.orderIndex != rhs.habit.orderIndex {
                return lhs.habit.orderIndex < rhs.habit.orderIndex
            }
            return lhs.habit.name.localizedCaseInsensitiveCompare(rhs.habit.name) == .orderedAscending
        }

        return Array(sorted.prefix(3)).map { metric in
            GlobalInsightHabitRow(
                id: metric.habit.id,
                name: metric.habit.name,
                statusLabel: statusLabel(for: metric)
            )
        }
    }

    func statusLabel(for metric: HabitMetrics) -> String {
        if metric.riskScore >= 0.5 {
            return "Needs attention"
        }
        if metric.consistency >= 80 {
            return "Strong"
        }
        return "On track"
    }

    func riskBucket(for metric: HabitMetrics) -> Int {
        metric.riskScore >= 0.5 ? 1 : 0
    }

    func progressBucket(for metric: HabitMetrics) -> Int {
        guard metric.riskScore < 0.5, metric.progressRatio != nil else {
            return 0
        }
        return 1
    }

    func greigSummary(
        from metrics: [HabitMetrics],
        now: Date
    ) -> GlobalInsightsGreig {
        let summary = monthSessionSummary(from: metrics, now: now)
        let projectedTotal = projectedMonthlySessions(summary: summary)
        let remainingWeeklyOpportunities = weeklyImprovementOpportunities(remainingDays: summary.remainingDays)
        let improvedTotal = projectedTotal + remainingWeeklyOpportunities

        let trajectoryText: String
        if summary.completedSessions == 0 {
            trajectoryText = "Early pace points to ~0 sessions this month."
        } else if summary.elapsedDays <= 5 {
            trajectoryText = "Early pace points to ~\(projectedTotal) sessions this month."
        } else {
            trajectoryText = "At this pace, you'll complete ~\(projectedTotal) sessions this month."
        }

        let suggestionText: String
        let outcomeText: String
        if remainingWeeklyOpportunities > 0 {
            suggestionText = "One extra session a week gets you to"
            outcomeText = "~\(improvedTotal) sessions this month."
        } else {
            suggestionText = "Keep this pace and you'll land at"
            outcomeText = "~\(projectedTotal) sessions this month."
        }

        return GlobalInsightsGreig(
            trajectoryText: trajectoryText,
            suggestionText: suggestionText,
            outcomeText: outcomeText
        )
    }

    func monthSessionSummary(
        from metrics: [HabitMetrics],
        now: Date
    ) -> MonthSessionSummary {
        let today = calendar.startOfDay(for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now) ?? fallbackMonthInterval(for: now)
        let completedSessions = metrics.reduce(into: 0) { total, metric in
            total += metric.completedDays.filter { day in
                day >= monthInterval.start && day < monthInterval.end
            }.count
        }
        let elapsedDays = max(
            1,
            (calendar.dateComponents([.day], from: monthInterval.start, to: today).day ?? 0) + 1
        )
        let totalDays = max(
            1,
            calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? elapsedDays
        )
        let remainingDays = max(totalDays - elapsedDays, 0)

        return MonthSessionSummary(
            completedSessions: completedSessions,
            elapsedDays: elapsedDays,
            totalDays: totalDays,
            remainingDays: remainingDays
        )
    }

    func projectedMonthlySessions(summary: MonthSessionSummary) -> Int {
        guard summary.completedSessions > 0 else { return 0 }
        let pace = Double(summary.completedSessions) / Double(summary.elapsedDays)
        return Int((pace * Double(summary.totalDays)).rounded())
    }

    func weeklyImprovementOpportunities(remainingDays: Int) -> Int {
        guard remainingDays > 0 else { return 0 }
        return Int(ceil(Double(remainingDays) / 7.0))
    }

    func stripSuffix(for atRiskCount: Int) -> String? {
        switch atRiskCount {
        case 0:
            return "Steady today"
        case 1:
            return "1 needs attention"
        default:
            return "\(atRiskCount) need attention"
        }
    }

    func completedDays(
        for habit: Habit,
        now: Date
    ) -> Set<Date> {
        let today = calendar.startOfDay(for: now)
        let candidateDays = Set(
            habit.logs.compactMap { log -> Date? in
                let day = calendar.startOfDay(for: log.effectiveTimestamp)
                guard day <= today else { return nil }
                return day
            }
        )

        return Set(
            candidateDays.filter { day in
                StreakService(
                    calendar: calendar,
                    weekStartPreference: weekStartPreference
                ).isDayComplete(goal: habit, on: day)
            }
        )
    }

    func weekdayName(for weekday: Int) -> String {
        let symbols = calendar.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
    }

    func weekdayTieBreakRank(_ weekday: Int) -> Int {
        let normalized = ((weekday - calendar.firstWeekday) + 7) % 7
        return 6 - normalized
    }

    func fallbackMonthInterval(for date: Date) -> DateInterval {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}
