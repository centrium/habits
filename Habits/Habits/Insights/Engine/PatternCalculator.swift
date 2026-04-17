import Foundation

struct PatternSignals {
    let strongestWeekday: String?
    let weakestWeekday: String?
    let commonLogWindow: String?
    let patternItems: [String]
    let retentionItems: [String]
}

enum PatternCalculator {
    static func calculate(
        logs: [InsightLog],
        calendar: Calendar,
        now: Date,
        timeInsight: TimeInsightResult?
    ) -> PatternSignals? {
        guard logs.count >= 5 else { return nil }

        let weekdayCounts = weekdayFrequency(
            logs: logs,
            calendar: calendar,
            now: now
        )

        let strongestWeekday = topWeekday(from: weekdayCounts, calendar: calendar)
        let weakestWeekday = weakestActiveWeekday(from: weekdayCounts, calendar: calendar)
        let commonLogWindow = topWindow(from: timeInsight)

        var patternItems: [String] = []
        if let strongestWeekday {
            patternItems.append("Strongest day: \(strongestWeekday)")
        }
        if let weakestWeekday {
            patternItems.append("Weakest day: \(weakestWeekday)")
        }
        if let commonLogWindow {
            patternItems.append("Most common log time: \(commonLogWindow)")
        }

        guard !patternItems.isEmpty else { return nil }

        var retentionItems: [String] = []
        if let strongestWeekday {
            retentionItems.append("You show up best on \(strongestWeekday).")
        }
        if let commonLogWindow {
            retentionItems.append("\(commonLogWindow) is your most consistent logging window.")
        }
        if let weakestWeekday {
            retentionItems.append("Consider adding one small check-in on \(weakestWeekday).")
        }

        return PatternSignals(
            strongestWeekday: strongestWeekday,
            weakestWeekday: weakestWeekday,
            commonLogWindow: commonLogWindow,
            patternItems: Array(patternItems.prefix(3)),
            retentionItems: Array(retentionItems.prefix(3))
        )
    }

    private static func weekdayFrequency(
        logs: [InsightLog],
        calendar: Calendar,
        now: Date
    ) -> [Int: Int] {
        let anchorDay = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -83, to: anchorDay) ?? anchorDay

        var uniqueDaysByWeekday: [Int: Set<Date>] = [:]
        for log in logs {
            let dayStart = calendar.startOfDay(for: log.dayStart)
            guard dayStart >= windowStart && dayStart <= anchorDay else { continue }
            let weekday = calendar.component(.weekday, from: dayStart)
            uniqueDaysByWeekday[weekday, default: []].insert(dayStart)
        }

        return uniqueDaysByWeekday.reduce(into: [Int: Int]()) { result, element in
            result[element.key] = element.value.count
        }
    }

    private static func topWeekday(
        from counts: [Int: Int],
        calendar: Calendar
    ) -> String? {
        guard let day = counts.max(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        })?.key else {
            return nil
        }
        return weekdayName(for: day, calendar: calendar)
    }

    private static func weakestActiveWeekday(
        from counts: [Int: Int],
        calendar: Calendar
    ) -> String? {
        let nonZero = counts.filter { $0.value > 0 }
        guard let day = nonZero.min(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        })?.key else {
            return nil
        }
        return weekdayName(for: day, calendar: calendar)
    }

    private static func weekdayName(
        for weekday: Int,
        calendar: Calendar
    ) -> String {
        let symbols = calendar.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
    }

    private static func topWindow(from insight: TimeInsightResult?) -> String? {
        guard let insight else {
            return nil
        }
        guard insight.confidence >= 0.15 else { return nil }

        if insight.distributionShape == .flat {
            return nil
        }

        switch insight.peakHour {
        case 5..<11:
            return "Morning"
        case 11..<17:
            return "Afternoon"
        case 17..<23:
            return "Evening"
        default:
            return "Night"
        }
    }
}
