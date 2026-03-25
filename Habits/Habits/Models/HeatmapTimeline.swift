import Foundation

struct HeatmapTimeline {
    let weeks: [Week]
    let startDate: Date
    let endDate: Date
}

extension HeatmapTimeline {
    func dateRange(calendar: Calendar) -> DateInterval {
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        return DateInterval(start: startDate, end: endExclusive)
    }
}
