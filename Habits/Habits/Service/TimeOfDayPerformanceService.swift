import Foundation

struct HourValue: Identifiable, Equatable {
    let hour: Int
    let value: Double

    var id: Int { hour }
}

struct RhythmInsight: Equatable {
    let peakHour: Int
    let lowRange: (Int, Int)
    let summary: String

    static func == (lhs: RhythmInsight, rhs: RhythmInsight) -> Bool {
        lhs.peakHour == rhs.peakHour &&
        lhs.lowRange.0 == rhs.lowRange.0 &&
        lhs.lowRange.1 == rhs.lowRange.1 &&
        lhs.summary == rhs.summary
    }
}

func peakHour(from data: [HourValue]) -> Int {
    data
        .max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.hour > rhs.hour
            }
            return lhs.value < rhs.value
        }?
        .hour ?? 12
}

func generateRhythmInsight(data: [HourValue]) -> RhythmInsight {
    guard !data.isEmpty else {
        return RhythmInsight(
            peakHour: 12,
            lowRange: (15, 17),
            summary: "You're strongest around midday. Momentum dips in the afternoon."
        )
    }

    let sortedData = data.sorted { $0.hour < $1.hour }
    let peak = peakHour(from: sortedData)
    let dip = lowestSustainedRange(from: sortedData)

    let peakLabel = humanTime(for: peak)
    let dipStart = humanTime(for: dip.0)
    let dipEnd = humanTime(for: dip.1)

    return RhythmInsight(
        peakHour: peak,
        lowRange: dip,
        summary: "You're strongest around \(peakLabel). Momentum dips between \(dipStart) and \(dipEnd)."
    )
}

func humanTime(for hour: Int) -> String {
    let normalized = ((hour % 24) + 24) % 24
    switch normalized {
    case 0: return "midnight"
    case 12: return "noon"
    case 1..<12: return "\(normalized)am"
    default: return "\(normalized - 12)pm"
    }
}

private func lowestSustainedRange(from data: [HourValue]) -> (Int, Int) {
    guard data.count >= 2 else {
        return (15, 17)
    }

    var bestStart = data[0].hour
    var bestEnd = data[min(2, data.count - 1)].hour
    var bestAverage = Double.greatestFiniteMagnitude

    for length in 2...3 {
        guard data.count >= length else { continue }

        for index in 0...(data.count - length) {
            let window = data[index..<(index + length)]
            let average = window.map(\.value).reduce(0, +) / Double(length)
            let start = data[index].hour
            let end = data[index + length - 1].hour

            if average < bestAverage {
                bestAverage = average
                bestStart = start
                bestEnd = end
            }
        }
    }

    return (bestStart, bestEnd)
}

@MainActor
final class TimeOfDayPerformanceService {
    static let shared = TimeOfDayPerformanceService()

    private struct CacheKey: Hashable {
        let habitID: UUID
        let days: Int
    }

    private struct CacheEntry {
        let logCount: Int
        let newestTimestamp: Date?
        let values: [HourValue]
    }

    private struct LogSnapshot: Sendable {
        let timestamp: Date
    }

    private let floorValue = 0.05
    private var cache: [CacheKey: CacheEntry] = [:]

    private init() {}

    func hourlyValues(
        for habit: Habit,
        isPremium: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> [HourValue] {
        let days = isPremium ? 21 : 3
        return await hourlyValues(for: habit, days: days, now: now, calendar: calendar)
    }

    func hourlyValues(
        for habit: Habit,
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> [HourValue] {
        let clampedDays = max(1, days)
        let key = CacheKey(habitID: habit.id, days: clampedDays)
        let logCount = habit.logs.count
        let newestTimestamp = habit.logs.map(\.effectiveTimestamp).max()

        if let cached = cache[key],
           cached.logCount == logCount,
           cached.newestTimestamp == newestTimestamp {
            return cached.values
        }

        let windowedLogs = logsForWindow(logs: habit.logs, days: clampedDays, now: now, calendar: calendar)
        let snapshots = windowedLogs.map { LogSnapshot(timestamp: $0.effectiveTimestamp) }
        let floorValue = self.floorValue

        let values = await Task.detached(priority: .utility) {
            Self.buildValues(from: snapshots, calendar: calendar, floorValue: floorValue)
        }.value

        cache[key] = CacheEntry(
            logCount: logCount,
            newestTimestamp: newestTimestamp,
            values: values
        )

        return values
    }

    func clearCache(for habitID: UUID? = nil) {
        guard let habitID else {
            cache.removeAll()
            return
        }

        cache = cache.filter { $0.key.habitID != habitID }
    }

    func bucketLogsByHour(logs: [HabitLog], calendar: Calendar = .current) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        counts.reserveCapacity(24)

        for log in logs {
            let hour = calendar.component(.hour, from: log.effectiveTimestamp)
            counts[hour, default: 0] += 1
        }

        return counts
    }

    func logsForWindow(
        logs: [HabitLog],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [HabitLog] {
        let clampedDays = max(1, days)
        guard let windowStart = calendar.date(
            byAdding: .day,
            value: -(clampedDays - 1),
            to: calendar.startOfDay(for: now)
        ) else {
            return logs
        }

        return logs.filter { log in
            let timestamp = log.effectiveTimestamp
            return timestamp >= windowStart && timestamp <= now
        }
    }

    func normalisedHourlyValues(counts: [Int: Int]) -> [HourValue] {
        Self.normalisedHourlyValues(counts: counts, floorValue: floorValue)
    }

    private nonisolated static func buildValues(
        from logs: [LogSnapshot],
        calendar: Calendar,
        floorValue: Double
    ) -> [HourValue] {
        var counts: [Int: Int] = [:]
        counts.reserveCapacity(24)

        for log in logs {
            let hour = calendar.component(.hour, from: log.timestamp)
            counts[hour, default: 0] += 1
        }

        return normalisedHourlyValues(counts: counts, floorValue: floorValue)
    }

    private nonisolated static func normalisedHourlyValues(counts: [Int: Int], floorValue: Double) -> [HourValue] {
        let filledCounts = fillHourlyGaps(counts)
        let maxCount = max(filledCounts.values.max() ?? 0, 1)

        let normalized: [Double] = (0..<24).map { hour in
            (filledCounts[hour] ?? 0) / maxCount
        }

        let smoothed: [Double] = (0..<24).map { hour in
            let previous = normalized[max(0, hour - 1)]
            let current = normalized[hour]
            let next = normalized[min(23, hour + 1)]
            return (previous + (current * 2.0) + next) / 4.0
        }

        return (0..<24).map { hour in
            let edgeDistance = min(hour, 23 - hour)
            let edgeWeight = min(Double(edgeDistance) / 4.0, 1.0)
            let ripple = (sin((Double(hour) / 24.0) * .pi * 2.0) + 1.0) / 2.0
            let dynamicFloor = floorValue + (ripple * 0.05)
            let tapered = smoothed[hour] * (0.9 + (0.1 * edgeWeight))
            let clamped = min(1, max(dynamicFloor, tapered))
            return HourValue(hour: hour, value: clamped)
        }
    }

    private nonisolated static func fillHourlyGaps(_ counts: [Int: Int]) -> [Int: Double] {
        var filled: [Int: Double] = [:]
        filled.reserveCapacity(24)

        for hour in 0..<24 {
            if let value = counts[hour] {
                filled[hour] = Double(value)
                continue
            }

            let previous = nearestKnownHour(before: hour, counts: counts)
            let next = nearestKnownHour(after: hour, counts: counts)

            if let previous, let next, previous != next {
                let previousValue = Double(counts[previous] ?? 0)
                let nextValue = Double(counts[next] ?? 0)
                let distance = Double(next - previous)
                let progress = Double(hour - previous) / distance
                filled[hour] = previousValue + ((nextValue - previousValue) * progress)
            } else {
                filled[hour] = 0
            }
        }

        return filled
    }

    private nonisolated static func nearestKnownHour(before hour: Int, counts: [Int: Int]) -> Int? {
        guard hour > 0 else { return nil }

        for candidate in stride(from: hour - 1, through: 0, by: -1) {
            if counts[candidate] != nil {
                return candidate
            }
        }

        return nil
    }

    private nonisolated static func nearestKnownHour(after hour: Int, counts: [Int: Int]) -> Int? {
        guard hour < 23 else { return nil }

        for candidate in (hour + 1)...23 {
            if counts[candidate] != nil {
                return candidate
            }
        }

        return nil
    }
}
