import Foundation

struct HourValue: Identifiable, Equatable {
    let hour: Int
    let value: Double

    var id: Int { hour }
}

struct HabitRhythm: Equatable, Sendable {
    let peakHour: Int
    let dipStart: Int
    let dipEnd: Int
    let consistencyScore: Double
    let lastUpdated: Date
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

enum BestTimeTimeframe: Equatable {
    case today
    case tomorrow
}

struct BestTimeRecommendation: Equatable {
    let hour: Int
    let timeframe: BestTimeTimeframe
}

nonisolated private func bestHourValue(from data: [HourValue]) -> HourValue? {
    data.max { lhs, rhs in
        if lhs.value == rhs.value {
            return lhs.hour > rhs.hour
        }
        return lhs.value < rhs.value
    }
}

nonisolated func peakHour(from data: [HourValue]) -> Int {
    bestHourValue(from: data)?.hour ?? 12
}

nonisolated func bestTimeRecommendation(
    from data: [HourValue],
    currentHour: Int,
    minimumFutureStrengthRatio: Double = 0.7
) -> BestTimeRecommendation {
    let normalizedHour = ((currentHour % 24) + 24) % 24
    guard let bestOverall = bestHourValue(from: data) else {
        return BestTimeRecommendation(hour: 12, timeframe: .tomorrow)
    }

    let futureHours = data.filter { $0.hour >= normalizedHour }
    guard let bestFuture = bestHourValue(from: futureHours) else {
        return BestTimeRecommendation(hour: bestOverall.hour, timeframe: .tomorrow)
    }

    let clampedRatio = min(max(minimumFutureStrengthRatio, 0), 1)
    let futureIsStrongEnough = bestFuture.value >= (bestOverall.value * clampedRatio)

    if futureIsStrongEnough {
        return BestTimeRecommendation(hour: bestFuture.hour, timeframe: .today)
    }

    return BestTimeRecommendation(hour: bestOverall.hour, timeframe: .tomorrow)
}

nonisolated func generateRhythmInsight(data: [HourValue]) -> RhythmInsight {
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

nonisolated func humanTime(for hour: Int) -> String {
    let normalized = ((hour % 24) + 24) % 24
    switch normalized {
    case 0: return "Midnight"
    case 12: return "Noon"
    case 1..<12: return "\(normalized)AM"
    default: return "\(normalized - 12)PM"
    }
}

nonisolated private func lowestSustainedRange(from data: [HourValue]) -> (Int, Int) {
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
        let rhythm: HabitRhythm
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

    func cachedRhythm(for habit: Habit, isPremium: Bool) -> HabitRhythm? {
        cachedRhythm(for: habit.id, days: isPremium ? 21 : 3)
    }

    func cachedLastCompletedDate(for habit: Habit, isPremium: Bool) -> Date? {
        let key = CacheKey(habitID: habit.id, days: isPremium ? 21 : 3)
        return cache[key]?.newestTimestamp
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
        let rhythm = Self.buildRhythm(from: values, lastUpdated: now)

        cache[key] = CacheEntry(
            logCount: logCount,
            newestTimestamp: newestTimestamp,
            values: values,
            rhythm: rhythm
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

    private func cachedRhythm(for habitID: UUID, days: Int) -> HabitRhythm? {
        let key = CacheKey(habitID: habitID, days: max(1, days))
        return cache[key]?.rhythm
    }

    private nonisolated static func buildRhythm(from values: [HourValue], lastUpdated: Date) -> HabitRhythm {
        let insight = rhythmInsight(from: values)
        return HabitRhythm(
            peakHour: insight.peakHour,
            dipStart: insight.lowRange.0,
            dipEnd: insight.lowRange.1,
            consistencyScore: consistencyScore(from: values, peakHour: insight.peakHour),
            lastUpdated: lastUpdated
        )
    }

    private nonisolated static func rhythmInsight(from values: [HourValue]) -> RhythmInsight {
        guard !values.isEmpty else {
            return RhythmInsight(
                peakHour: 12,
                lowRange: (15, 17),
                summary: "You're strongest around midday. Momentum dips in the afternoon."
            )
        }

        let sortedData = values.sorted { $0.hour < $1.hour }
        let peak = sortedData.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.hour > rhs.hour
            }
            return lhs.value < rhs.value
        }?.hour ?? 12
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

    private nonisolated static func consistencyScore(from values: [HourValue], peakHour: Int) -> Double {
        guard !values.isEmpty else { return 0 }

        let sorted = values.sorted { $0.value > $1.value }
        let primary = sorted.first?.value ?? 0
        let secondary = sorted.dropFirst().first?.value ?? 0
        let separation = max(0, primary - secondary)
        let concentration = neighborhoodAverage(around: peakHour, values: values)
        let score = (separation * 0.6) + (concentration * 0.4)
        return min(1, max(0, score))
    }

    private nonisolated static func neighborhoodAverage(around hour: Int, values: [HourValue]) -> Double {
        let lookup = Dictionary(uniqueKeysWithValues: values.map { ($0.hour, $0.value) })
        let previous = lookup[(hour + 23) % 24] ?? 0
        let current = lookup[hour] ?? 0
        let next = lookup[(hour + 1) % 24] ?? 0
        return (previous + current + next) / 3.0
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
