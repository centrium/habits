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
        calendar: Calendar
    ) -> PatternSignals? {
        guard logs.count >= 5 else { return nil }

        let weekdayCounts = weekdayFrequency(logs: logs, calendar: calendar)
        let timeWindowCounts = timeWindowFrequency(logs: logs, calendar: calendar)

        let strongestWeekday = topWeekday(from: weekdayCounts, calendar: calendar)
        let weakestWeekday = weakestActiveWeekday(from: weekdayCounts, calendar: calendar)
        let commonLogWindow = topWindow(from: timeWindowCounts)

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
        calendar: Calendar
    ) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for log in logs {
            let weekday = calendar.component(.weekday, from: log.date)
            counts[weekday, default: 0] += 1
        }
        return counts
    }

    private static func timeWindowFrequency(
        logs: [InsightLog],
        calendar: Calendar
    ) -> [TimeOfDayBucket: Int] {
        var counts: [TimeOfDayBucket: Int] = [:]
        for log in logs {
            let hour = calendar.component(.hour, from: log.date)
            let bucket: TimeOfDayBucket
            switch hour {
            case 5..<11:
                bucket = .morning
            case 11..<17:
                bucket = .afternoon
            case 17..<23:
                bucket = .evening
            default:
                bucket = .night
            }
            counts[bucket, default: 0] += 1
        }
        return counts
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

    private static func topWindow(from counts: [TimeOfDayBucket: Int]) -> String? {
        guard let bucket = counts.max(by: { lhs, rhs in
            if lhs.value == rhs.value { return rank(lhs.key) > rank(rhs.key) }
            return lhs.value < rhs.value
        })?.key else {
            return nil
        }

        switch bucket {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        }
    }

    private static func rank(_ bucket: TimeOfDayBucket) -> Int {
        switch bucket {
        case .morning:
            return 0
        case .afternoon:
            return 1
        case .evening:
            return 2
        case .night:
            return 3
        }
    }
}
