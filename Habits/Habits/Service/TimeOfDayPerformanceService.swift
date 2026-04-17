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
    let confidence: Double
    let uniqueEventCount: Int
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

struct PeakTimingSummary: Equatable {
    let peakHour: Int
    let confidence: Double
    let uniqueEventCount: Int
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
        let globalLogCount: Int
        let newestGlobalTimestamp: Date?
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
        globalLogs: [HabitLog] = [],
        isPremium: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> [HourValue] {
        let days = isPremium ? 21 : 3
        return await hourlyValues(
            for: habit,
            globalLogs: globalLogs,
            days: days,
            now: now,
            calendar: calendar
        )
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
        globalLogs: [HabitLog] = [],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> [HourValue] {
        let clampedDays = max(1, days)
        let key = CacheKey(habitID: habit.id, days: clampedDays)
        let logCount = habit.logs.count
        let newestTimestamp = habit.logs.map(\.effectiveTimestamp).max()
        let globalLogCount = globalLogs.count
        let newestGlobalTimestamp = globalLogs.map(\.effectiveTimestamp).max()

        if let cached = cache[key],
           cached.logCount == logCount,
           cached.newestTimestamp == newestTimestamp,
           cached.globalLogCount == globalLogCount,
           cached.newestGlobalTimestamp == newestGlobalTimestamp {
            return cached.values
        }

        let windowedLogs = logsForWindow(logs: habit.logs, days: clampedDays, now: now, calendar: calendar)
        let habitSnapshots = windowedLogs
            .filter { ($0.frequencyContribution > 0 || $0.numericValue > 0) && $0.effectiveTimestamp <= now }
            .map { LogSnapshot(timestamp: $0.effectiveTimestamp) }
        let globalSnapshots = (globalLogs.isEmpty ? windowedLogs : globalLogs)
            .filter { ($0.frequencyContribution > 0 || $0.numericValue > 0) && $0.effectiveTimestamp <= now }
            .map { LogSnapshot(timestamp: $0.effectiveTimestamp) }
        let floorValue = self.floorValue

        let blendedResult = await Task.detached(priority: .utility) {
            Self.buildBlendedValues(
                habitLogs: habitSnapshots,
                globalLogs: globalSnapshots,
                now: now,
                calendar: calendar,
                floorValue: floorValue
            )
        }.value
        let rhythm = Self.buildRhythm(
            from: blendedResult.values,
            confidence: blendedResult.confidence,
            uniqueEventCount: blendedResult.uniqueEventCount,
            lastUpdated: now
        )

        cache[key] = CacheEntry(
            logCount: logCount,
            newestTimestamp: newestTimestamp,
            globalLogCount: globalLogCount,
            newestGlobalTimestamp: newestGlobalTimestamp,
            values: blendedResult.values,
            rhythm: rhythm
        )

        return blendedResult.values
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

    nonisolated static func peakTimingSummary(
        habitLogs: [HabitLog],
        globalLogs: [HabitLog],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PeakTimingSummary? {
        let filteredHabitLogs = habitLogs.filter {
            ($0.frequencyContribution > 0 || $0.numericValue > 0) && $0.effectiveTimestamp <= now
        }
        guard !filteredHabitLogs.isEmpty else {
            return nil
        }

        let filteredGlobalLogs = (globalLogs.isEmpty ? filteredHabitLogs : globalLogs).filter {
            ($0.frequencyContribution > 0 || $0.numericValue > 0) && $0.effectiveTimestamp <= now
        }

        let result = buildBlendedValues(
            habitLogs: filteredHabitLogs.map { LogSnapshot(timestamp: $0.effectiveTimestamp) },
            globalLogs: filteredGlobalLogs.map { LogSnapshot(timestamp: $0.effectiveTimestamp) },
            now: now,
            calendar: calendar,
            floorValue: 0.05
        )
        guard let peakHour = bestHourValue(from: result.values)?.hour else {
            return nil
        }
        return PeakTimingSummary(
            peakHour: peakHour,
            confidence: result.confidence,
            uniqueEventCount: result.uniqueEventCount
        )
    }

    nonisolated static func deduplicatedHourlyCounts(
        from logs: [HabitLog],
        calendar: Calendar,
        now: Date
    ) -> (counts: [Int: Int], uniqueEventCount: Int) {
        let snapshots = logs.map { LogSnapshot(timestamp: $0.effectiveTimestamp) }
        return deduplicatedHourlyCounts(from: snapshots, calendar: calendar, now: now)
    }

    private nonisolated static func deduplicatedHourlyCounts(
        from logs: [LogSnapshot],
        calendar: Calendar,
        now: Date
    ) -> (counts: [Int: Int], uniqueEventCount: Int) {
        var seenMinuteStarts = Set<Date>()
        seenMinuteStarts.reserveCapacity(logs.count)

        var counts: [Int: Int] = [:]
        counts.reserveCapacity(24)

        for log in logs {
            guard log.timestamp <= now else { continue }
            guard let minuteStart = calendar.dateInterval(of: .minute, for: log.timestamp)?.start else {
                continue
            }
            guard seenMinuteStarts.insert(minuteStart).inserted else {
                continue
            }
            let hour = calendar.component(.hour, from: minuteStart)
            counts[hour, default: 0] += 1
        }

        return (counts, seenMinuteStarts.count)
    }

    private nonisolated static func buildBlendedValues(
        habitLogs: [LogSnapshot],
        globalLogs: [LogSnapshot],
        now: Date,
        calendar: Calendar,
        floorValue: Double
    ) -> (values: [HourValue], confidence: Double, uniqueEventCount: Int) {
        let habitCounts = deduplicatedHourlyCounts(from: habitLogs, calendar: calendar, now: now)
        let habitValues = normalisedHourlyValues(counts: habitCounts.counts, floorValue: floorValue)

        let globalCounts = deduplicatedHourlyCounts(from: globalLogs, calendar: calendar, now: now)
        let globalValues = normalisedHourlyValues(counts: globalCounts.counts, floorValue: floorValue)

        let confidence = min(1.0, Double(habitCounts.uniqueEventCount) / 20.0)
        let blendedValues = (0..<24).map { hour in
            let habitScore = habitValues[hour].value
            let globalScore = globalValues[hour].value
            return HourValue(
                hour: hour,
                value: (habitScore * confidence) + (globalScore * (1.0 - confidence))
            )
        }

        return (blendedValues, confidence, habitCounts.uniqueEventCount)
    }

    nonisolated static func normalisedHourlyValues(counts: [Int: Int], floorValue _: Double) -> [HourValue] {
        let maxCount = max(counts.values.max() ?? 0, 1)
        return (0..<24).map { hour in
            let raw = Double(counts[hour] ?? 0) / Double(maxCount)
            return HourValue(hour: hour, value: min(1, max(0, raw)))
        }
    }

    private func cachedRhythm(for habitID: UUID, days: Int) -> HabitRhythm? {
        let key = CacheKey(habitID: habitID, days: max(1, days))
        return cache[key]?.rhythm
    }

    private nonisolated static func buildRhythm(
        from values: [HourValue],
        confidence: Double,
        uniqueEventCount: Int,
        lastUpdated: Date
    ) -> HabitRhythm {
        let insight = rhythmInsight(from: values)
        return HabitRhythm(
            peakHour: insight.peakHour,
            dipStart: insight.lowRange.0,
            dipEnd: insight.lowRange.1,
            consistencyScore: consistencyScore(from: values, peakHour: insight.peakHour),
            confidence: confidence,
            uniqueEventCount: uniqueEventCount,
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

    // Intentionally no gap interpolation: bucket scores come from observed hourly events only.
}
