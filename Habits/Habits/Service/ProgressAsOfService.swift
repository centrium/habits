import Foundation

struct ProgressAsOfSnapshot {
    let current: Double
    let target: Double
    let progressFraction: Double
    let headlineText: String
    let contextText: String
    let overflowText: String?
    let streak: Int
    let isComplete: Bool
    let visibleMonthText: String?
}

struct ProgressAsOfService {
    private let calendar: Calendar
    private let timelineContext: TimelineContext
    private let weekStartPreference: WeekStartPreference
    private let now: () -> Date

    init(
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        now: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.timelineContext = TimelineContext(calendar: calendar)
        self.weekStartPreference = weekStartPreference
        self.now = now
    }

    func snapshot(for habit: Habit, visibleMonth: Date, selectedDate: Date) -> ProgressAsOfSnapshot? {
        guard let target = habit.effectiveTargetValue else { return nil }

        let today = now()
        let selectedPeriod = habit.periodRange(
            for: selectedDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let current = total(for: habit, in: selectedPeriod, asOf: selectedDate, today: today)
        let progressFraction = min(max(current / target, 0), 1)
        let details = HabitProgressDetails(
            current: current,
            target: target,
            currentText: habit.formatProgressValue(current),
            targetText: habit.formatProgressValue(target),
            unitText: MetricKindResolver.resolve(habit) == .genericValue ? habit.trimmedUnit : nil,
            goalType: habit.goalType
        )

        return ProgressAsOfSnapshot(
            current: current,
            target: target,
            progressFraction: progressFraction,
            headlineText: detailProgressText(from: details),
            contextText: timelineContext.periodContextLabel(
                for: habit.goalPeriod,
                selectedDate: selectedDate,
                today: today,
                weekStartPreference: weekStartPreference
            ),
            overflowText: overflowText(for: habit, current: current, target: target),
            streak: streak(for: habit, selectedDate: selectedDate, today: today),
            isComplete: progressFraction == 1.0,
            visibleMonthText: visibleMonthText(for: habit, visibleMonth: visibleMonth, selectedDate: selectedDate, today: today)
        )
    }

    func total(for habit: Habit, in interval: DateInterval, asOf selectedDate: Date, today: Date) -> Double {
        let upperBound = min(interval.end, timelineContext.asOfExclusiveUpperBound(for: selectedDate, today: today))
        return total(for: habit, in: interval, upperBound: upperBound)
    }

    func goalProgress(for habit: Habit, asOf selectedDate: Date) -> (current: Double, target: Double, percent: Double)? {
        guard let target = habit.effectiveTargetValue else { return nil }

        let today = now()
        let interval = habit.periodRange(
            for: selectedDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let current = total(for: habit, in: interval, asOf: selectedDate, today: today)
        let percent = min(max(current / target, 0), 1)

        return (current, target, percent)
    }

    private func total(for habit: Habit, in interval: DateInterval, upperBound: Date) -> Double {
        guard upperBound > interval.start else { return 0 }

        let matchingLogs = habit.logs.filter { log in
            let timestamp = log.effectiveTimestamp
            return timestamp >= interval.start && timestamp < upperBound
        }

        switch habit.goalType {
        case .frequency:
            return Double(matchingLogs.reduce(0) { $0 + $1.frequencyContribution })
        case .cumulative:
            return matchingLogs.reduce(0) { $0 + $1.numericValue }
        }
    }

    private func streak(for habit: Habit, selectedDate: Date, today: Date) -> Int {
        guard let target = habit.effectiveTargetValue else { return 0 }

        var streak = 0
        var interval = habit.periodRange(
            for: selectedDate,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        var upperBound = min(interval.end, timelineContext.asOfExclusiveUpperBound(for: selectedDate, today: today))

        while total(for: habit, in: interval, upperBound: upperBound) >= target {
            streak += 1

            let previousStart = habit.goalPeriod.previousPeriodStart(
                before: interval.start,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
            interval = habit.periodRange(
                for: previousStart,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
            upperBound = interval.end
        }

        return streak
    }

    private func visibleMonthText(for habit: Habit, visibleMonth: Date, selectedDate: Date, today: Date) -> String? {
        guard habit.goalType == .cumulative else { return nil }

        let interval = calendar.dateInterval(of: .month, for: visibleMonth) ?? DateInterval(start: visibleMonth, end: visibleMonth)
        let monthTotal: Double

        if calendar.isDate(selectedDate, equalTo: visibleMonth, toGranularity: .month) {
            monthTotal = total(for: habit, in: interval, asOf: selectedDate, today: today)
        } else {
            monthTotal = total(for: habit, in: interval, upperBound: interval.end)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

        let totalText = habit.formatProgressValue(monthTotal)
        let unitSuffix = monthUnitSuffix(for: habit)
        return "\(formatter.string(from: visibleMonth)): \(totalText)\(unitSuffix)"
    }

    private func monthUnitSuffix(for habit: Habit) -> String {
        let context = ValueFormattingContext(habit: habit)
        guard context.showsUnitSuffix, let unit = habit.trimmedUnit else { return "" }
        return " \(unit)"
    }

    private func detailProgressText(from details: HabitProgressDetails) -> String {
        switch details.goalType {
        case .frequency:
            return "\(details.currentText) of \(details.targetText)"
        case .cumulative:
            let unitSuffix = details.unitText.map { " \($0)" } ?? ""
            return "\(details.currentText) of \(details.targetText)\(unitSuffix)"
        }
    }

    private func overflowText(for habit: Habit, current: Double, target: Double) -> String? {
        let overflow = max(0, current - target)
        guard overflow > 0 else { return nil }
        return "+\(habit.formatProgressValue(overflow)) extra"
    }
}
