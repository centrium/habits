//
//  HabitInsightsEngine+Snapshot.swift
//  Habits
//
//  Created by Matt Adams on 06/03/2026.
//

import SwiftUI

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

        let cadence = habit.goalPeriod
        let target = habit.effectiveTargetValue

        // ---- NORMALISE LOGS ----

        struct Log {
            let date: Date
            let value: Double
        }

        let logs: [Log] = habit.logs.map {
            Log(
                date: $0.effectiveTimestamp,
                value: max(Double($0.frequencyContribution), max(1, $0.numericValue))
            )
        }

        // ---- GROUP BY PERIOD ----

        var buckets: [Date: Double] = [:]

        for log in logs {

            let start = cadence.periodStart(
                for: log.date,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )

            buckets[start, default: 0] += log.value
        }

        // ---- CURRENT PERIOD ----

        let start = cadence.periodStart(
            for: anchorDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let end = cadence.nextPeriodStart(
            after: start,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        let progress = buckets[start] ?? 0

        let clamped = target != nil ? min(progress, target!) : progress
        let surplus = target != nil ? max(progress - target!, 0) : 0
        let ratio = target != nil ? clamped / target! : nil

        let period = Snapshot.Period(
            start: start,
            end: end,
            progress: progress,
            progressClamped: clamped,
            target: target,
            completionRatio: ratio,
            surplus: surplus,
            isCompleted: target != nil ? progress >= target! : nil
        )

        // ---- STREAK ----

        let sortedPeriods = buckets.keys.sorted()

        var running = 0
        var longest = 0
        var current = 0

        for date in sortedPeriods {

            let value = buckets[date] ?? 0
            let completed = target != nil ? value >= target! : value > 0

            if completed {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }

            if date == start {
                current = running
            }
        }

        let streak = Snapshot.Streak(
            current: current,
            longest: longest
        )

        return Snapshot(
            currentPeriod: period,
            streak: streak
        )
    }
}
