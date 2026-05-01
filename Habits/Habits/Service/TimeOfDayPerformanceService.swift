import Foundation

struct HourValue: Identifiable, Equatable {
    let hour: Int
    let value: Double

    var id: Int { hour }
}

struct HabitRhythm: Equatable, Sendable {
    let timeInsight: TimeInsightResult
    let dipStart: Int
    let dipEnd: Int
    let consistencyScore: Double
    let uniqueEventCount: Int
    let uniqueActiveDays: Int
    let lastUpdated: Date

    var peakHour: Int { timeInsight.peakHour }
    var confidence: Double { timeInsight.confidence }
    var distributionShape: ShapeType { timeInsight.distributionShape }
    var hourlyScores: [Double] { timeInsight.hourlyScores }

    init(
        timeInsight: TimeInsightResult,
        dipStart: Int,
        dipEnd: Int,
        consistencyScore: Double,
        uniqueEventCount: Int,
        uniqueActiveDays: Int,
        lastUpdated: Date
    ) {
        self.timeInsight = timeInsight
        self.dipStart = dipStart
        self.dipEnd = dipEnd
        self.consistencyScore = consistencyScore
        self.uniqueEventCount = uniqueEventCount
        self.uniqueActiveDays = uniqueActiveDays
        self.lastUpdated = lastUpdated
    }

    init(
        peakHour: Int,
        dipStart: Int,
        dipEnd: Int,
        consistencyScore: Double,
        confidence: Double,
        uniqueEventCount: Int,
        lastUpdated: Date
    ) {
        var scores = Array(repeating: 0.0, count: 24)
        scores[((peakHour % 24) + 24) % 24] = 1
        self.timeInsight = TimeInsightResult(
            hourlyScores: scores,
            peakHour: ((peakHour % 24) + 24) % 24,
            confidence: min(max(confidence, 0), 1),
            distributionShape: .singlePeak
        )
        self.dipStart = dipStart
        self.dipEnd = dipEnd
        self.consistencyScore = consistencyScore
        self.uniqueEventCount = uniqueEventCount
        self.uniqueActiveDays = Int((confidence * 14).rounded())
        self.lastUpdated = lastUpdated
    }
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
    let uniqueActiveDays: Int
}

nonisolated func bestTimeRecommendation(
    from insight: TimeInsightResult,
    currentHour: Int,
    minimumFutureStrengthRatio: Double = 0.7
) -> BestTimeRecommendation {
    let normalizedHour = ((currentHour % 24) + 24) % 24
    let scores = insight.hourlyScores
    guard scores.count == 24 else {
        return BestTimeRecommendation(hour: insight.peakHour, timeframe: .tomorrow)
    }

    let bestOverallHour = insight.peakHour
    let bestOverallScore = scores[bestOverallHour]

    let futureRange = normalizedHour..<24
    guard let bestFuture = futureRange.max(by: { lhs, rhs in
        let lhsScore = scores[lhs]
        let rhsScore = scores[rhs]
        if lhsScore == rhsScore {
            return lhs > rhs
        }
        return lhsScore < rhsScore
    }) else {
        return BestTimeRecommendation(hour: bestOverallHour, timeframe: .tomorrow)
    }

    let futureScore = scores[bestFuture]
    let clampedRatio = min(max(minimumFutureStrengthRatio, 0), 1)
    let futureIsStrongEnough = futureScore >= (bestOverallScore * clampedRatio)

    if futureIsStrongEnough {
        return BestTimeRecommendation(hour: bestFuture, timeframe: .today)
    }

    return BestTimeRecommendation(hour: bestOverallHour, timeframe: .tomorrow)
}

nonisolated func generateRhythmInsight(from insight: TimeInsightResult) -> RhythmInsight {
    guard insight.hourlyScores.count == 24 else {
        return RhythmInsight(
            peakHour: ((insight.peakHour % 24) + 24) % 24,
            lowRange: (15, 17),
            summary: "Your strongest window is still forming. Momentum dips in the afternoon."
        )
    }

    let dip = lowestSustainedRange(from: insight.hourlyScores)
    let peakLabel = timeWindowLabel(for: insight.peakHour)
    let dipStart = humanTime(for: dip.0)
    let dipEnd = humanTime(for: dip.1)

    return RhythmInsight(
        peakHour: insight.peakHour,
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

nonisolated func timeWindowLabel(for hour: Int) -> String {
    let normalized = ((hour % 24) + 24) % 24
    switch normalized {
    case 5..<11:
        return "morning"
    case 11..<15:
        return "midday"
    case 15..<19:
        return "afternoon"
    case 19..<23:
        return "evening"
    default:
        return "night"
    }
}

nonisolated private func lowestSustainedRange(from hourlyScores: [Double]) -> (Int, Int) {
    guard hourlyScores.count == 24 else { return (15, 17) }

    var bestStart = 15
    var bestLength = 2
    var bestAverage = Double.greatestFiniteMagnitude

    for length in 2...3 {
        for start in 0..<24 {
            var total = 0.0
            for offset in 0..<length {
                total += hourlyScores[(start + offset) % 24]
            }
            let average = total / Double(length)
            if average < bestAverage {
                bestAverage = average
                bestStart = start
                bestLength = length
            }
        }
    }

    let end = (bestStart + bestLength - 1) % 24
    return (bestStart, end)
}

final class TimeOfDayPerformanceService {
    private struct DetachedLogsBatch: @unchecked Sendable {
        let logs: [HabitLog]
    }

    private static let defaultShared = TimeOfDayPerformanceService()
    static var shared: TimeOfDayPerformanceService {
        TestIsolationRegistry.timeOfDayPerformanceService ?? defaultShared
    }

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
        let timeInsight: TimeInsightResult
    }

    private var cache: [CacheKey: CacheEntry] = [:]
    private var requestSequenceByKey: [CacheKey: UInt64] = [:]
    private let lock = NSLock()

    init() {}

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

    func cachedTimeInsight(for habit: Habit, isPremium: Bool) -> TimeInsightResult? {
        cachedTimeInsight(for: habit.id, days: isPremium ? 21 : 3)
    }

    func cachedLastCompletedDate(for habit: Habit, isPremium: Bool) -> Date? {
        let key = CacheKey(habitID: habit.id, days: isPremium ? 21 : 3)
        return withLock { cache[key]?.newestTimestamp }
    }

    func resetForTesting() {
        withLock {
            cache.removeAll()
            requestSequenceByKey.removeAll()
        }
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

        if let cached = withLock({ cache[key] }),
           cached.logCount == logCount,
           cached.newestTimestamp == newestTimestamp,
           cached.globalLogCount == globalLogCount,
           cached.newestGlobalTimestamp == newestGlobalTimestamp {
            return cached.values
        }

        let rawHabitLogs = rawTimestampLogs(from: habit.logs)
        let rawGlobalLogs = rawTimestampLogs(from: globalLogs)
        let resolvedGlobalLogs = rawGlobalLogs.isEmpty ? rawHabitLogs : rawGlobalLogs
        let detachedHabitLogs = detachedLogsCopy(from: rawHabitLogs, calendar: calendar)
        let detachedGlobalLogs = detachedLogsCopy(from: resolvedGlobalLogs, calendar: calendar)
        let requestSequence = withLock { () -> UInt64 in
            let next = (requestSequenceByKey[key] ?? 0) + 1
            requestSequenceByKey[key] = next
            return next
        }
        let debugLabel = "\(habit.name) | id=\(habit.id.uuidString) | goalType=\(habit.goalType.rawValue)"
        let computation = await computeTimingOffMain(
            habitTypeLabel: Self.habitTypeLabel(for: habit),
            habitLogCount: detachedHabitLogs.count,
            debugLabel: debugLabel,
            habitLogs: detachedHabitLogs,
            globalLogs: detachedGlobalLogs,
            now: now,
            calendar: calendar
        )
        guard !Task.isCancelled else {
            return withLock({ cache[key]?.values ?? [] })
        }

        let values = hourlyValues(from: computation.result)
        let rhythm = Self.buildRhythm(
            from: computation.result,
            diagnostics: computation.diagnostics,
            lastUpdated: now
        )

        return withLock {
            guard requestSequenceByKey[key] == requestSequence else {
                return cache[key]?.values ?? values
            }

            cache[key] = CacheEntry(
                logCount: logCount,
                newestTimestamp: newestTimestamp,
                globalLogCount: globalLogCount,
                newestGlobalTimestamp: newestGlobalTimestamp,
                values: values,
                rhythm: rhythm,
                timeInsight: computation.result
            )
            return values
        }
    }

    func clearCache(for habitID: UUID? = nil) {
        guard let habitID else {
            withLock {
                cache.removeAll()
                requestSequenceByKey.removeAll()
            }
            return
        }

        withLock {
            cache = cache.filter { $0.key.habitID != habitID }
            requestSequenceByKey = requestSequenceByKey.filter { $0.key.habitID != habitID }
        }
    }

    static func peakTimingSummary(
        habitLogs: [HabitLog],
        globalLogs: [HabitLog],
        habitName: String? = nil,
        habitType: GoalType? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PeakTimingSummary? {
        let rawHabitLogs = rawTimestampLogs(from: habitLogs)
        guard !rawHabitLogs.isEmpty else {
            return nil
        }
        let rawGlobalLogs = rawTimestampLogs(from: globalLogs)
        let resolvedGlobalLogs = rawGlobalLogs.isEmpty ? rawHabitLogs : rawGlobalLogs
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1" {
            print("[TimeInsight ROUTING]")
            print("habitType: \(habitTypeLabel(for: habitType))")
            print("inputCount: \(rawHabitLogs.count)")
            print("engineUsed: true")
        }
        #endif

        let computation = TimeInsightEngine.computeDetails(
            logs: rawHabitLogs,
            globalLogs: resolvedGlobalLogs,
            allowGlobalBlending: false,
            debugLabel: "\(habitName ?? "unknown") | goalType=\(habitTypeLabel(for: habitType))",
            now: now,
            calendar: calendar
        )
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1" {
            let consumerHour = computation.result.peakHour
            print("[TimeInsight CONSISTENCY CHECK]")
            print("surface: Today")
            print("enginePeak: \(computation.result.peakHour)")
            print("consumerHour: \(consumerHour)")
            print("match: \(consumerHour == computation.result.peakHour)")
        }
        #endif

        return PeakTimingSummary(
            peakHour: computation.result.peakHour,
            confidence: computation.result.confidence,
            uniqueEventCount: computation.diagnostics.uniqueEventCount,
            uniqueActiveDays: computation.diagnostics.uniqueActiveDays
        )
    }

    private func cachedRhythm(for habitID: UUID, days: Int) -> HabitRhythm? {
        let key = CacheKey(habitID: habitID, days: max(1, days))
        return withLock { cache[key]?.rhythm }
    }

    private func cachedTimeInsight(for habitID: UUID, days: Int) -> TimeInsightResult? {
        let key = CacheKey(habitID: habitID, days: max(1, days))
        return withLock { cache[key]?.timeInsight }
    }

    private static func rawTimestampLogs(from logs: [HabitLog]) -> [HabitLog] {
        logs.filter { log in
            log.kind == .entry && log.timestamp != nil
        }
    }

    private func rawTimestampLogs(from logs: [HabitLog]) -> [HabitLog] {
        Self.rawTimestampLogs(from: logs)
    }

    private static func habitTypeLabel(for habit: Habit) -> String {
        if habit.goalType == .cumulative { return "cumulative" }
        if habit.hasGoal { return "frequency" }
        return "open"
    }

    private static func habitTypeLabel(for goalType: GoalType?) -> String {
        guard let goalType else { return "unknown" }
        switch goalType {
        case .frequency: return "frequency"
        case .cumulative: return "cumulative"
        }
    }

    private static func buildRhythm(
        from insight: TimeInsightResult,
        diagnostics: TimeInsightDiagnostics,
        lastUpdated: Date
    ) -> HabitRhythm {
        let rhythmInsight = generateRhythmInsight(from: insight)
        return HabitRhythm(
            timeInsight: insight,
            dipStart: rhythmInsight.lowRange.0,
            dipEnd: rhythmInsight.lowRange.1,
            consistencyScore: consistencyScore(from: insight.hourlyScores, peakHour: insight.peakHour),
            uniqueEventCount: diagnostics.uniqueEventCount,
            uniqueActiveDays: diagnostics.uniqueActiveDays,
            lastUpdated: lastUpdated
        )
    }

    private static func consistencyScore(from hourlyScores: [Double], peakHour: Int) -> Double {
        guard !hourlyScores.isEmpty else { return 0 }

        let sorted = hourlyScores.sorted(by: >)
        let primary = sorted.first ?? 0
        let secondary = sorted.dropFirst().first ?? 0
        let separation = max(0, primary - secondary)
        let concentration = neighborhoodAverage(around: peakHour, scores: hourlyScores)
        let score = (separation * 0.6) + (concentration * 0.4)
        return min(1, max(0, score))
    }

    private static func neighborhoodAverage(around hour: Int, scores: [Double]) -> Double {
        guard scores.count == 24 else { return 0 }
        let previous = scores[(hour + 23) % 24]
        let current = scores[hour]
        let next = scores[(hour + 1) % 24]
        return (previous + current + next) / 3.0
    }

    private func hourlyValues(from insight: TimeInsightResult) -> [HourValue] {
        guard insight.hourlyScores.count == 24 else { return [] }
        return (0..<24).map { hour in
            HourValue(hour: hour, value: insight.hourlyScores[hour])
        }
    }

    private func computeTimingOffMain(
        habitTypeLabel: String,
        habitLogCount: Int,
        debugLabel: String,
        habitLogs: [HabitLog],
        globalLogs: [HabitLog],
        now: Date,
        calendar: Calendar
    ) async -> TimeInsightComputation {
        let detachedHabitLogs = DetachedLogsBatch(logs: habitLogs)
        let detachedGlobalLogs = DetachedLogsBatch(logs: globalLogs)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                LoggingPerformanceMonitor.assertHeavyPathOffMainThread(#function)
                #if DEBUG
                if ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1" {
                    print("[TimeInsight ROUTING]")
                    print("habitType: \(habitTypeLabel)")
                    print("inputCount: \(habitLogCount)")
                    print("engineUsed: true")
                }
                #endif

                let computation = TimeInsightEngine.computeDetails(
                    logs: detachedHabitLogs.logs,
                    globalLogs: detachedGlobalLogs.logs,
                    allowGlobalBlending: false,
                    debugLabel: debugLabel,
                    now: now,
                    calendar: calendar
                )

                #if DEBUG
                if ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1" {
                    let consumerHour = computation.result.peakHour
                    print("[TimeInsight CONSISTENCY CHECK]")
                    print("surface: Momentum")
                    print("enginePeak: \(computation.result.peakHour)")
                    print("consumerHour: \(consumerHour)")
                    print("match: \(consumerHour == computation.result.peakHour)")
                }
                #endif
                continuation.resume(returning: computation)
            }
        }
    }

    private func detachedLogsCopy(from logs: [HabitLog], calendar: Calendar) -> [HabitLog] {
        logs.map { log in
            let copy: HabitLog
            switch log.kind {
            case .entry:
                copy = HabitLog(
                    timestamp: log.effectiveTimestamp,
                    value: log.numericValue,
                    createdAt: log.createdAt,
                    calendar: calendar
                )
            case .legacyDailyTotal:
                copy = HabitLog(
                    day: log.day,
                    count: log.count,
                    createdAt: log.createdAt,
                    calendar: calendar
                )
            }

            copy.id = log.id
            copy.day = log.day
            copy.count = log.count
            copy.timestamp = log.timestamp
            copy.value = log.value
            copy.logKindRaw = log.logKindRaw
            copy.createdAt = log.createdAt
            return copy
        }
    }

    private func withLock<T>(_ operation: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}
