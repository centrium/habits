import Foundation

struct HeatmapMetricsCacheKey: Hashable {
    let habitID: UUID
    let revision: Int
    let calendarIdentifier: Calendar.Identifier
    let timeZoneIdentifier: String
    let firstWeekday: Int
    let earliestVisibleDate: Date?
}

final class HeatmapMetricsCache {

    struct Entry {
        let dayMetrics: [Date: HabitDayMetrics]
        let intensityMap: [Date: Double]
        let days: [Date]
    }

    private var cache: [HeatmapMetricsCacheKey: Entry] = [:]

    func entry(
        key: HeatmapMetricsCacheKey,
        build: () -> Entry
    ) -> Entry {
        if let existing = cache[key] {
            return existing
        }

        let newEntry = build()
        cache[key] = newEntry
        return newEntry
    }

    func invalidateAll() {
        cache.removeAll()
    }
}
