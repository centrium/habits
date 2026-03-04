//
//  HabitInsightsEngine.swift
//  Habits
//
//  Created by Matt Adams on 04/03/2026.
//

import SwiftUI

struct HabitInsightsEngine {

    static func insights(
        for habit: Habit,
        referenceDate: Date = .now,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> HabitInsights {

        // 1) series for the mini chart
        let progressSeries = progressSeries(
            habit: habit,
            days: 14,
            referenceDate: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        // 2) completion over a cadence-appropriate window
        let completionRate = completionRate(
            for: habit,
            referenceDate: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        // 3) momentum (compare recent vs previous)
        let momentumPct = momentumPercentage(
            for: habit,
            referenceDate: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        // 4) average per day (based on progress series; you can change to raw totals later)
        let avg = averagePerDay(from: progressSeries)

        // 5) streaks (you already have currentStreak; longest can be added later)
        let currentStreak = habit.currentStreak(
            referenceDate: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        return HabitInsights(
            completionRate: completionRate,
            completionWindowLabel: completionWindowLabel(for: habit),
            progressSeries: progressSeries,
            averagePerDay: avg,
            currentStreak: currentStreak,
            longestStreak: 0, // TODO: implement longest streak later
            momentumPercentage: momentumPct,
            reinforcementMessage: reinforcementMessage(for: completionRate)
        )
    }
}

// MARK: - Calculations

private extension HabitInsightsEngine {

    private static func progressSeries(
        habit: Habit,
        days: Int,
        referenceDate: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> [DailyProgress] {

        let endDay = calendar.startOfDay(for: referenceDate)
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) ?? endDay

        let createdStart = calendar.startOfDay(for: habit.createdAt)

        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }

            // For days before the habit existed, return 0 to pad the chart.
            if day < createdStart {
                return DailyProgress(date: day, progress: 0.0)
            }

            let p = habit.progressFraction(
                for: day,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            ) ?? 0.0

            return DailyProgress(date: day, progress: min(max(p, 0.0), 1.0))
        }
    }
    
    /// Completion rate over a "reasonable" window depending on cadence.
    /// - Daily: last 30 days
    /// - Weekly: last 8 weeks (56 days)
    /// - Monthly: last 6 months (approx by iterating months)
    /// - Yearly: last 3 years (iterate years)
    static func completionRate(
        for habit: Habit,
        referenceDate: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> Double {

        guard habit.hasGoal else { return 0 }

        switch habit.goalPeriod {
        case .daily:
            return completionRateByDays(
                habit: habit,
                days: 30,
                referenceDate: referenceDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )

        case .weekly:
            return completionRateByPeriods(
                habit: habit,
                periods: 8,
                referenceDate: referenceDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )

        case .monthly:
            return completionRateByPeriods(
                habit: habit,
                periods: 6,
                referenceDate: referenceDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )

        case .yearly:
            return completionRateByPeriods(
                habit: habit,
                periods: 3,
                referenceDate: referenceDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
        }
    }

    static func completionRateByDays(
        habit: Habit,
        days: Int,
        referenceDate: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> Double {

        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end

        // Don’t count days before habit existed
        let startLimit = calendar.startOfDay(for: habit.createdAt)
        let actualStart = max(start, startLimit)

        let totalDays = (calendar.dateComponents([.day], from: actualStart, to: end).day ?? 0) + 1
        guard totalDays > 0 else { return 0 }

        var completed = 0
        for offset in 0..<totalDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: actualStart) else { continue }
            if habit.isComplete(for: day, calendar: calendar, weekStartPreference: weekStartPreference) {
                completed += 1
            }
        }

        return Double(completed) / Double(totalDays)
    }
    
    static func mostActiveTimeOfDay(
        for habit: Habit
    ) -> String? {

        let logsWithTime = habit.logs.compactMap { $0.timestamp }

        guard !logsWithTime.isEmpty else { return nil }

        var buckets: [String: Int] = [
            "Morning": 0,
            "Afternoon": 0,
            "Evening": 0,
            "Night": 0
        ]

        let calendar = Calendar.current

        for timestamp in logsWithTime {

            let hour = calendar.component(.hour, from: timestamp)

            switch hour {
            case 5..<12:
                buckets["Morning", default: 0] += 1

            case 12..<18:
                buckets["Afternoon", default: 0] += 1

            case 18..<22:
                buckets["Evening", default: 0] += 1

            default:
                buckets["Night", default: 0] += 1
            }
        }

        return buckets.max(by: { $0.value < $1.value })?.key
    }
    
    static func projectedCompletion(
        for habit: Habit,
        referenceDate: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> Double {

        let interval = habit.periodRange(
            for: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let elapsed = referenceDate.timeIntervalSince(interval.start)
        let total = interval.end.timeIntervalSince(interval.start)

        guard elapsed > 0 else { return habit.progressTotal(in: interval) }

        let currentTotal = habit.progressTotal(in: interval)

        let pace = currentTotal / elapsed

        return pace * total
    }

    /// Period-based completion: counts how many periods in the last N periods hit target.
    static func completionRateByPeriods(
        habit: Habit,
        periods: Int,
        referenceDate: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> Double {

        var completed = 0
        var total = 0

        var interval = habit.periodRange(
            for: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        // Iterate backwards over periods
        for _ in 0..<periods {
            // Stop if period is entirely before habit creation
            if interval.end <= habit.createdAt { break }

            total += 1
            if habit.hasHitTarget(in: interval) { completed += 1 }

            // move back a period
            let prevStart = habit.goalPeriod.previousPeriodStart(
                before: interval.start,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
            interval = habit.periodRange(
                for: prevStart,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
        }

        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    /// Momentum compares a recent window vs previous window.
    /// Daily: 7d vs prior 7d
    /// Weekly: 1w vs prior 1w
    /// Monthly: 1m vs prior 1m
    /// Yearly: 1y vs prior 1y
    ///
    /// Returns percent change (-100...+∞), but you can clamp in UI.
    static func momentumPercentage(
        for habit: Habit,
        referenceDate: Date,
        calendar: Calendar,
        weekStartPreference: WeekStartPreference
    ) -> Double {

        // Define two consecutive windows in terms of periods
        let currentInterval = habit.periodRange(
            for: referenceDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let previousStart = habit.goalPeriod.previousPeriodStart(
            before: currentInterval.start,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let previousInterval = habit.periodRange(
            for: previousStart,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        // Use progressTotal so it works for frequency & cumulative
        let currentTotal = habit.progressTotal(in: currentInterval)
        let previousTotal = habit.progressTotal(in: previousInterval)

        // If previous was zero, define momentum sensibly
        if previousTotal <= 0 {
            return currentTotal > 0 ? 100.0 : 0.0
        }

        return ((currentTotal - previousTotal) / previousTotal) * 100.0
    }

    static func averagePerDay(from series: [DailyProgress]) -> Double {
        guard !series.isEmpty else { return 0 }
        // average progress fraction per day; if you prefer "average units/day", compute from daily totals instead
        let sum = series.reduce(0.0) { $0 + $1.progress }
        return sum / Double(series.count)
    }

    static func completionWindowLabel(for habit: Habit) -> String {
        switch habit.goalPeriod {
        case .daily:
            return "Completion (Last 30 Days)"
        case .weekly:
            return "Completion (Last 8 Weeks)"
        case .monthly:
            return "Completion (Last 6 Months)"
        case .yearly:
            return "Completion (Last 3 Years)"
        }
    }

    static func reinforcementMessage(for completionRate: Double) -> String {
        switch completionRate {
        case 0.80...:
            return "You're staying consistent."
        case 0.50..<0.80:
            return "You're building momentum."
        default:
            return "Consistency will strengthen this habit."
        }
    }
}

// MARK: - Small helper

private func max(_ a: Date, _ b: Date) -> Date { a > b ? a : b }
