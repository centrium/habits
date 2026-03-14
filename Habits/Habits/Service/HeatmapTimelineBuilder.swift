import Foundation

enum HeatmapTimelineBuilder {
    private static let dayCount = 365

    static func yearTimeline(calendar: Calendar) -> HeatmapTimeline {
        yearTimeline(endingAt: Date(), calendar: calendar)
    }

    static func yearTimeline(endingAt endDate: Date, calendar: Calendar) -> HeatmapTimeline {
        let normalizedEndDate = calendar.startOfDay(for: endDate)
        let startDate = calendar.date(
            byAdding: .day,
            value: -(dayCount - 1),
            to: normalizedEndDate
        ) ?? normalizedEndDate

        let leadingPlaceholders = leadingPlaceholderCount(for: startDate, calendar: calendar)
        let firstWeekStart = calendar.date(byAdding: .day, value: -leadingPlaceholders, to: startDate) ?? startDate

        var paddedDays = Array<Date?>(repeating: nil, count: leadingPlaceholders)
        paddedDays.reserveCapacity(leadingPlaceholders + dayCount + 6)

        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            paddedDays.append(calendar.startOfDay(for: date))
        }

        let trailingPlaceholders = (7 - (paddedDays.count % 7)) % 7
        if trailingPlaceholders > 0 {
            paddedDays.append(contentsOf: Array(repeating: nil, count: trailingPlaceholders))
        }

        var weeks: [Week] = []
        weeks.reserveCapacity(paddedDays.count / 7)

        for startIndex in stride(from: 0, to: paddedDays.count, by: 7) {
            let weekDays = Array(paddedDays[startIndex..<(startIndex + 7)])
            let weekStart = calendar.date(byAdding: .day, value: startIndex, to: firstWeekStart) ?? firstWeekStart
            let month = calendar.component(.month, from: weekStart)
            weeks.append(
                Week(
                    id: calendar.startOfDay(for: weekStart),
                    days: weekDays,
                    month: month
                )
            )
        }

        return HeatmapTimeline(
            weeks: weeks,
            startDate: calendar.startOfDay(for: startDate),
            endDate: normalizedEndDate
        )
    }

    private static func leadingPlaceholderCount(for startDate: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: startDate)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}
