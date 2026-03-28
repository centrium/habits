import Foundation

struct ProgressAsOfSnapshot: Equatable {
    let current: Double
    let target: Double
    let progressFraction: Double
    let headlineText: String
    let contextText: String
    let overflowText: String?
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

    func snapshot(
        for habit: Habit,
        visibleMonth: Date,
        selectedDate: Date,
        dayMetrics: [Date: HabitDayMetrics] = [:]
    ) -> ProgressAsOfSnapshot? {

        guard let target = habit.effectiveTargetValue, target > 0 else { return nil }

        let today = now()

        // Decide which period we are evaluating
        let anchor = anchorDate(
            selectedDate: selectedDate,
            today: today,
            goalPeriod: habit.goalPeriod
        )

        let periodInterval = habit.goalPeriod.periodRange(
            for: anchor,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )
        let progress = periodProgress(
            for: habit,
            in: periodInterval,
            dayMetrics: dayMetrics
        )
        let displayProgress = min(progress, target)
        let ratio = clamp(displayProgress / target)
        let surplus = max(progress - target, 0)

        let details = HabitProgressDetails(
            current: progress,
            target: target,
            currentText: habit.formatProgressValue(displayProgress),
            targetText: habit.formatProgressValue(target),
            unitText: MetricKindResolver.resolve(habit) == .genericValue
                ? habit.trimmedUnit
                : nil,
            goalType: habit.goalType
        )

        return ProgressAsOfSnapshot(
            current: progress,
            target: target,
            progressFraction: ratio,
            headlineText: detailProgressText(from: details),
            contextText: timelineContext.periodContextLabel(
                for: habit.goalPeriod,
                selectedDate: selectedDate,
                today: today,
                weekStartPreference: weekStartPreference
            ),
            overflowText: overflowText(
                for: habit,
                surplus: surplus
            ),
            isComplete: progress >= target,
            visibleMonthText: visibleMonthText(
                for: habit,
                visibleMonth: visibleMonth,
                dayMetrics: dayMetrics
            )
        )
    }

    func metricDays(
        for habit: Habit,
        visibleMonth: Date,
        selectedDate: Date
    ) -> [Date] {
        guard habit.effectiveTargetValue != nil else { return [] }

        let today = now()
        let anchor = anchorDate(
            selectedDate: selectedDate,
            today: today,
            goalPeriod: habit.goalPeriod
        )
        let periodInterval = habit.goalPeriod.periodRange(
            for: anchor,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        var daySet = Set(days(in: periodInterval))
        if habit.goalType == .cumulative,
           let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) {
            daySet.formUnion(days(in: monthInterval))
        }

        return Array(daySet)
    }

    // MARK: Anchor Logic

    private func anchorDate(
        selectedDate: Date,
        today: Date,
        goalPeriod: GoalPeriod
    ) -> Date {

        guard let interval = calendar.dateInterval(
            of: goalPeriod.calendarComponent,
            for: selectedDate
        ) else {
            return today
        }

        // Current period → anchor to today
        if interval.contains(today) {
            return today
        }

        // Past period → anchor to end of that period
        if interval.end < today {
            return interval.end.addingTimeInterval(-1)
        }

        // Future period → anchor to today
        return today
    }

    // MARK: Visible Month

    private func visibleMonthText(
        for habit: Habit,
        visibleMonth: Date,
        dayMetrics: [Date: HabitDayMetrics]
    ) -> String? {

        guard habit.goalType == .cumulative else { return nil }

        let interval = calendar.dateInterval(of: .month, for: visibleMonth)

        guard let interval else { return nil }

        let total = monthTotal(
            for: habit,
            in: interval,
            dayMetrics: dayMetrics
        )

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

        let totalText = habit.formatProgressValue(total)
        let unitSuffix: String = {
            guard MetricKindResolver.resolve(habit) == .genericValue, let unit = habit.trimmedUnit else {
                return ""
            }
            return " \(unit)"
        }()

        return "\(formatter.string(from: visibleMonth)): \(totalText)\(unitSuffix)"
    }

    // MARK: Formatting

    private func detailProgressText(
        from details: HabitProgressDetails
    ) -> String {

        switch details.goalType {
        case .frequency:
            return "\(details.currentText) of \(details.targetText)"

        case .cumulative:
            let unitSuffix = details.unitText.map { " \($0)" } ?? ""
            return "\(details.currentText) of \(details.targetText)\(unitSuffix)"
        }
    }

    private func overflowText(
        for habit: Habit,
        surplus: Double
    ) -> String? {

        guard surplus > 0 else { return nil }

        if habit.goalType == .frequency {
            return "+\(Int(surplus.rounded())) extra"
        }

        return "+\(habit.formatProgressValue(surplus)) extra"
    }

    private func periodProgress(
        for habit: Habit,
        in interval: DateInterval,
        dayMetrics: [Date: HabitDayMetrics]
    ) -> Double {
        if !dayMetrics.isEmpty {
            return days(in: interval).reduce(0) { partial, day in
                let metrics = dayMetrics[day] ?? .zero
                switch habit.goalType {
                case .frequency:
                    return partial + Double(metrics.count)
                case .cumulative:
                    return partial + metrics.value
                }
            }
        }

        return habit.logs.reduce(0) { partial, log in
            let ts = log.effectiveTimestamp
            guard ts >= interval.start, ts < interval.end else { return partial }

            switch habit.goalType {
            case .frequency:
                return partial + Double(log.frequencyContribution)
            case .cumulative:
                return partial + log.numericValue
            }
        }
    }

    private func monthTotal(
        for habit: Habit,
        in interval: DateInterval,
        dayMetrics: [Date: HabitDayMetrics]
    ) -> Double {
        if !dayMetrics.isEmpty {
            return days(in: interval).reduce(0) { partial, day in
                partial + (dayMetrics[day]?.value ?? 0)
            }
        }

        return habit.logs.reduce(0) { partial, log in
            let ts = log.effectiveTimestamp
            guard ts >= interval.start, ts < interval.end else { return partial }
            return partial + log.numericValue
        }
    }

    private func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var day = calendar.startOfDay(for: interval.start)

        while day < interval.end {
            result.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }

        return result
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
