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

    func snapshot(
        for habit: Habit,
        visibleMonth: Date,
        selectedDate: Date
    ) -> ProgressAsOfSnapshot? {

        guard habit.effectiveTargetValue != nil else { return nil }

        let today = now()

        // Decide which period we are evaluating
        let anchor = anchorDate(
            selectedDate: selectedDate,
            today: today,
            goalPeriod: habit.goalPeriod
        )

        let canonical = HabitInsightsEngine.snapshot(
            for: habit,
            anchorDate: anchor,
            respectCreatedAtBoundary: false,
            calendar: calendar,
            weekStartPreference: weekStartPreference,
            now: today
        )

        guard let target = canonical.currentPeriod.target else { return nil }

        let progress = canonical.currentPeriod.progress
        let displayProgress = canonical.currentPeriod.progressClamped
        let ratio = canonical.currentPeriod.completionRatio ?? 0

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
                surplus: canonical.currentPeriod.surplus
            ),
            streak: canonical.streak.current,
            isComplete: canonical.currentPeriod.isCompleted ?? false,
            visibleMonthText: visibleMonthText(
                for: habit,
                visibleMonth: visibleMonth
            )
        )
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
        visibleMonth: Date
    ) -> String? {

        guard habit.goalType == .cumulative else { return nil }

        let interval = calendar.dateInterval(of: .month, for: visibleMonth)

        guard let interval else { return nil }

        let logs = habit.logs.filter {
            let ts = $0.effectiveTimestamp
            return ts >= interval.start && ts < interval.end
        }

        let total: Double = logs.reduce(0) { partial, log in
            partial + log.numericValue
        }

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
}
