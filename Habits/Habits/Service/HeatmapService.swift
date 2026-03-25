import Foundation

struct HabitGoal: Equatable {
    enum Kind: Equatable {
        case open
        case frequency
        case cumulative
    }

    let kind: Kind
    let target: Double?

    static func open() -> HabitGoal {
        HabitGoal(kind: .open, target: nil)
    }

    static func frequency(target: Double?) -> HabitGoal {
        HabitGoal(kind: .frequency, target: target)
    }

    static func cumulative(target: Double?) -> HabitGoal {
        HabitGoal(kind: .cumulative, target: target)
    }

    static func from(habit: Habit) -> HabitGoal {
        guard habit.hasStreakGoal else {
            return .open()
        }

        switch habit.goalType {
        case .frequency:
            return .frequency(target: habit.effectiveTargetValue)
        case .cumulative:
            return .cumulative(target: habit.effectiveTargetValue)
        }
    }
}

struct HeatmapCell: Equatable {
    let date: Date
    let value: Double
    let normalizedIntensity: Int // 0...5
    let isCompleted: Bool
    let isToday: Bool
    let isLocked: Bool
}

struct HeatmapService {
    private struct DailyAggregate {
        var frequencyCount: Int = 0
        var cumulativeValue: Double = 0
        var hasCompletion: Bool = false
    }

    let calendar: Calendar
    let premiumStatus: PremiumStatus
    let now: () -> Date

    init(
        calendar: Calendar = .current,
        premiumStatus: PremiumStatus = .unknown,
        now: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.premiumStatus = premiumStatus
        self.now = now
    }

    func generateCells(
        habit: Habit,
        logs: [HabitLog],
        dateRange: DateInterval,
        goal: HabitGoal
    ) -> [HeatmapCell] {
        _ = habit

        guard let normalizedRange = normalizedRange(for: dateRange) else {
            return []
        }

        let nowDate = now()
        let today = calendar.startOfDay(for: nowDate)
        let gate = PremiumHistoryGate.Context(
            calendar: calendar,
            premiumStatus: premiumStatus,
            now: nowDate
        )

        var aggregateByDay: [Date: DailyAggregate] = [:]
        aggregateByDay.reserveCapacity(64)

        for log in logs {
            let day = calendar.startOfDay(for: log.effectiveTimestamp)
            guard day >= normalizedRange.start, day < normalizedRange.endExclusive else {
                continue
            }

            var aggregate = aggregateByDay[day, default: DailyAggregate()]
            let frequencyContribution = max(0, log.frequencyContribution)
            let cumulativeContribution = max(0, log.numericValue)
            aggregate.frequencyCount += frequencyContribution
            aggregate.cumulativeValue += cumulativeContribution
            aggregate.hasCompletion = aggregate.hasCompletion || frequencyContribution > 0 || cumulativeContribution > 0
            aggregateByDay[day] = aggregate
        }

        let maxObservedFrequency = aggregateByDay.values.map { Double($0.frequencyCount) }.max() ?? 0
        let maxObservedCumulative = aggregateByDay.values.map(\.cumulativeValue).max() ?? 0

        var cells: [HeatmapCell] = []
        cells.reserveCapacity(dayCount(in: normalizedRange))

        var day = normalizedRange.start
        while day < normalizedRange.endExclusive {
            let aggregate = aggregateByDay[day, default: DailyAggregate()]

            let rawValue: Double
            let completed: Bool

            switch goal.kind {
            case .open:
                rawValue = aggregate.hasCompletion ? 1 : 0
                completed = aggregate.hasCompletion

            case .frequency:
                let observed = Double(aggregate.frequencyCount)
                let reference = intensityReference(
                    target: goal.target,
                    observedMaximum: maxObservedFrequency
                )
                rawValue = intensity(observed: observed, reference: reference)
                completed = completionState(
                    observed: observed,
                    target: goal.target
                )

            case .cumulative:
                let observed = aggregate.cumulativeValue
                let reference = intensityReference(
                    target: goal.target,
                    observedMaximum: maxObservedCumulative
                )
                rawValue = intensity(observed: observed, reference: reference)
                completed = completionState(
                    observed: observed,
                    target: goal.target
                )
            }

            let isLocked = gate.isLocked(date: day)
            let visibleValue = isLocked ? 0 : rawValue
            let normalizedIntensity = normalizedIntensity(for: visibleValue)

            cells.append(
                HeatmapCell(
                    date: day,
                    value: visibleValue,
                    normalizedIntensity: normalizedIntensity,
                    isCompleted: completed,
                    isToday: day == today,
                    isLocked: isLocked
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return cells
    }

    private func normalizedRange(for dateRange: DateInterval) -> (start: Date, endExclusive: Date)? {
        let start = calendar.startOfDay(for: dateRange.start)
        let endDay = calendar.startOfDay(for: dateRange.end)

        let endExclusive: Date
        if dateRange.end > endDay {
            endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        } else {
            endExclusive = endDay
        }

        guard endExclusive > start else {
            return nil
        }

        return (start, endExclusive)
    }

    private func dayCount(in range: (start: Date, endExclusive: Date)) -> Int {
        max(0, calendar.dateComponents([.day], from: range.start, to: range.endExclusive).day ?? 0)
    }

    private func intensityReference(target: Double?, observedMaximum: Double) -> Double? {
        if let target, target > 0 {
            return target
        }

        guard observedMaximum > 0 else {
            return nil
        }

        return observedMaximum
    }

    private func intensity(observed: Double, reference: Double?) -> Double {
        guard observed > 0, let reference, reference > 0 else {
            return 0
        }

        return clamp(observed / reference)
    }

    private func completionState(observed: Double, target: Double?) -> Bool {
        if let target, target > 0 {
            return observed >= target
        }

        return observed > 0
    }

    private func normalizedIntensity(for value: Double) -> Int {
        let clamped = clamp(value)
        guard clamped > 0 else { return 0 }
        return max(1, min(5, Int(ceil(clamped * 5))))
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
