//
//  HabitLogService.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import Foundation
import SwiftData
import QuartzCore

final class HabitLogService {
    private let modelContext: ModelContext
    private let calendar: Calendar
    private var lastHapticTime: TimeInterval = 0
    private let hapticCooldown: TimeInterval = 0.1 // 100ms

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday-first
        self.calendar = cal
    }
    
    private func playHaptic(for habit: Habit, newCount: Int) {

        let now = CACurrentMediaTime()
        guard now - lastHapticTime > hapticCooldown else {
            return
        }

        lastHapticTime = now

        if habit.hasStreakGoal && newCount == habit.streakTarget {
            Haptics.success()
        } else {
            Haptics.impactLight()
        }
    }
}

extension HabitLogService {
    func daysForMonth(_ month: Date) -> [Date] {
        CalendarGridHelper.daysForMonth(month, calendar: calendar) as! [Date]
    }
}

extension HabitLogService {

    func count(for habit: Habit, on date: Date) -> Int {
        let day = calendar.startOfDay(for: date)
        return habit.logs.first { calendar.isDate($0.day, inSameDayAs: day) }?.count ?? 0
    }
}

extension HabitLogService {

    func intensity(for habit: Habit, on date: Date) -> Double {

        let dayCount = count(for: habit, on: date)

        if dayCount == 0 {
            return 0.10
        }

        if habit.hasStreakGoal {

            let period = habit.periodRange(for: date)
            let totalInPeriod = habit.totalCount(in: period)
            let target = max(1, habit.streakTarget)

            // How much of the goal has been completed so far
            _ = min(Double(totalInPeriod) / Double(target), 1.0)

            // Daily contribution weighting
            let dailyContribution = Double(dayCount) / Double(target)

            // Blend contribution + overall state
            let intensity = min(dailyContribution, 1.0)

            return 0.20 + (0.80 * intensity)

        } else {

            let scaled = min(Double(dayCount) / 10.0, 1.0)
            return 0.20 + (0.80 * scaled)
        }
    }
}

extension HabitLogService {

    @discardableResult
    func increment(for habit: Habit, on day: Date) -> Int {
        let d = calendar.startOfDay(for: day)

        let newCount: Int
        if let log = habit.logs.first(where: { calendar.isDate($0.day, inSameDayAs: d) }) {
            log.count += 1
            newCount = log.count
        } else {
            habit.logs.append(HabitLog(day: d, count: 1))
            newCount = 1
        }

        try? modelContext.save()

        DispatchQueue.main.async {
            self.playHaptic(for: habit, newCount: newCount)
        }

        return newCount
    }
    
    @discardableResult
    func decrement(for habit: Habit, on day: Date) -> Int {
        let d = calendar.startOfDay(for: day)

        guard let log = habit.logs.first(where: { calendar.isDate($0.day, inSameDayAs: d) }) else {
            return 0
        }

        log.count = max(0, log.count - 1)

        // Optional: remove log entirely if count hits 0
        if log.count == 0 {
            habit.logs.removeAll { $0.id == log.id }
        }

        try? modelContext.save()
        return log.count
    }
    
    @discardableResult
    func setCount(for habit: Habit, on day: Date, to newValue: Int) -> Int {
        let d = calendar.startOfDay(for: day)
        let value = max(0, newValue)

        if let log = habit.logs.first(where: { calendar.isDate($0.day, inSameDayAs: d) }) {
            if value == 0 {
                habit.logs.removeAll { $0.id == log.id }
            } else {
                log.count = value
            }
        } else if value > 0 {
            habit.logs.append(HabitLog(day: d, count: value))
        }

        try? modelContext.save()
        return value
    }
}
