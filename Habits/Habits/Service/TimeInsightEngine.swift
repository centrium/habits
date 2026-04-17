import Foundation

enum ShapeType: String, Equatable, Sendable {
    case flat
    case singlePeak
    case multiPeak
}

struct TimeInsightResult: Equatable, Sendable {
    let hourlyScores: [Double]
    let peakHour: Int
    let confidence: Double
    let distributionShape: ShapeType
}

struct TimeInsightDiagnostics: Equatable, Sendable {
    let uniqueEventCount: Int
    let uniqueActiveDays: Int
}

struct TimeInsightComputation: Equatable, Sendable {
    let result: TimeInsightResult
    let diagnostics: TimeInsightDiagnostics
}

enum TimeInsightEngine {
    static func compute(
        logs: [HabitLog],
        globalLogs: [HabitLog],
        debugMode: Bool = false,
        debugLabel: String? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInsightResult {
        computeDetails(
            logs: logs,
            globalLogs: globalLogs,
            debugMode: debugMode,
            debugLabel: debugLabel,
            now: now,
            calendar: calendar
        ).result
    }

    static func computeDetails(
        logs: [HabitLog],
        globalLogs: [HabitLog],
        debugMode: Bool = false,
        debugLabel: String? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInsightComputation {
        let debugEnabled = debugMode || isDebugEnvironmentEnabled()
        validateRawTimestampInput(logs: logs, label: debugLabel, sectionName: "HABIT")
        let habitEvents = deduplicatedEvents(from: logs, now: now, calendar: calendar)
        let resolvedGlobalLogs = globalLogs.isEmpty ? logs : globalLogs
        validateRawTimestampInput(logs: resolvedGlobalLogs, label: debugLabel, sectionName: "GLOBAL")
        let globalEvents = deduplicatedEvents(from: resolvedGlobalLogs, now: now, calendar: calendar)

        guard !habitEvents.isEmpty else {
            let fallback = TimeInsightResult(
                hourlyScores: Array(repeating: 0, count: 24),
                peakHour: 12,
                confidence: 0,
                distributionShape: .flat
            )
            return TimeInsightComputation(
                result: fallback,
                diagnostics: TimeInsightDiagnostics(uniqueEventCount: 0, uniqueActiveDays: 0)
            )
        }

        let historicalHabitSignal = hourlySignal(
            from: habitEvents,
            now: now,
            useRecencyWeighting: false
        )
        let habitSignal = hourlySignal(
            from: habitEvents,
            now: now,
            useRecencyWeighting: true
        )
        let globalSignal = hourlySignal(
            from: globalEvents.isEmpty ? habitEvents : globalEvents,
            now: now,
            useRecencyWeighting: true
        )

        let baseConfidence = min(1.0, Double(habitSignal.activeDays) / 14.0)
        let historicalPeak = argmax(historicalHabitSignal.normalized)
        let recentPeak = argmax(habitSignal.normalized)
        let blendingConfidence = blendingConfidence(
            habitSignal: habitSignal,
            globalSignal: globalSignal,
            baseConfidence: baseConfidence
        )
        let blended = (0..<24).map { hour in
            let habitScore = habitSignal.normalized[hour]
            let globalScore = globalSignal.normalized[hour]
            return (habitScore * blendingConfidence) + (globalScore * (1.0 - blendingConfidence))
        }

        let smoothed = safelySmoothed(blended)
        let peakHour = argmax(smoothed)
        let shape = detectShape(scores: smoothed, peakHour: peakHour)
        let confidenceBase = confidenceFromDistribution(
            scores: smoothed,
            activeDays: habitSignal.activeDays
        )
        let confidence = confidenceAdjustedForShift(
            baseConfidence: confidenceBase,
            recentPeak: recentPeak,
            historicalPeak: historicalPeak
        )

        let result = TimeInsightResult(
            hourlyScores: smoothed,
            peakHour: peakHour,
            confidence: confidence,
            distributionShape: shape
        )
        let diagnostics = TimeInsightDiagnostics(
            uniqueEventCount: habitEvents.count,
            uniqueActiveDays: habitSignal.activeDays
        )

        if debugEnabled {
            let label = debugLabel ?? "unknown"
            print("[TimeInsightEngine INPUT]")
            print("habit: \(label)")
            print("dedupedCount: \(habitEvents.count)")
            print("[TimeInsightEngine OUTPUT]")
            print("peakHour: \(peakHour)")
            print(String(format: "confidence: %.4f", confidence))
            print("top 3 hours: \(topHours(from: smoothed))")
            if peakHour == 12 {
                print(
                    peakCompetitionExplanation(
                        selectedPeakHour: peakHour,
                        blended: blended,
                        smoothed: smoothed
                    )
                )
            }
        }

        return TimeInsightComputation(result: result, diagnostics: diagnostics)
    }
}

private extension TimeInsightEngine {
    struct DeduplicatedEvent {
        let minuteStart: Date
        let hour: Int
        let dayStart: Date
    }

    struct HourlySignal {
        let normalized: [Double]
        let rawBuckets: [Double]
        let adjustedBuckets: [Double]
        let coverage: [Double]
        let activeDays: Int
        let coverageUsedInPeakScoring: Bool
        let isRecencyWeighted: Bool
    }

    static func deduplicatedEvents(
        from logs: [HabitLog],
        now: Date,
        calendar: Calendar
    ) -> [DeduplicatedEvent] {
        var seen = Set<Date>()
        seen.reserveCapacity(logs.count)

        var events: [DeduplicatedEvent] = []
        events.reserveCapacity(logs.count)

        for log in logs {
            guard log.kind == .entry,
                  let timestamp = log.timestamp,
                  timestamp <= now,
                  let minuteStart = calendar.dateInterval(of: .minute, for: timestamp)?.start else {
                continue
            }
            guard seen.insert(minuteStart).inserted else {
                continue
            }

            events.append(
                DeduplicatedEvent(
                    minuteStart: minuteStart,
                    hour: calendar.component(.hour, from: minuteStart),
                    dayStart: calendar.startOfDay(for: minuteStart)
                )
            )
        }

        return events
    }

    static func validateRawTimestampInput(
        logs: [HabitLog],
        label: String?,
        sectionName: String
    ) {
        let invalidLogs = logs.filter { log in
            !(log.kind == .entry && log.timestamp != nil)
        }
        assert(
            invalidLogs.isEmpty,
            "TimeInsightEngine must receive raw timestamps only"
        )
        guard !invalidLogs.isEmpty else { return }

        let prefix = label.map { "[\($0)] " } ?? ""
        print("ERROR: \(prefix)Invalid input: TimeInsightEngine requires raw timestamps (\(sectionName), invalidLogs=\(invalidLogs.count), totalLogs=\(logs.count))")
    }

    static func hourlySignal(
        from events: [DeduplicatedEvent],
        now: Date,
        useRecencyWeighting: Bool
    ) -> HourlySignal {
        guard !events.isEmpty else {
            return HourlySignal(
                normalized: Array(repeating: 0, count: 24),
                rawBuckets: Array(repeating: 0, count: 24),
                adjustedBuckets: Array(repeating: 0, count: 24),
                coverage: Array(repeating: 0, count: 24),
                activeDays: 0,
                coverageUsedInPeakScoring: false,
                isRecencyWeighted: useRecencyWeighting
            )
        }

        var bucketCounts = Array(repeating: 0.0, count: 24)
        var uniqueDaysByHour = Array(repeating: Set<Date>(), count: 24)
        var activeDays = Set<Date>()

        for event in events {
            let eventWeight = useRecencyWeighting
                ? recencyWeight(for: event.minuteStart, now: now, decayFactorDays: recencyDecayFactorDays)
                : 1.0
            bucketCounts[event.hour] += eventWeight
            uniqueDaysByHour[event.hour].insert(event.dayStart)
            activeDays.insert(event.dayStart)
        }

        let totalActiveDays = max(activeDays.count, 1)
        let rawBuckets = bucketCounts
        var coverageByHour = Array(repeating: 0.0, count: 24)
        let coverageUsedInPeakScoring = !useRecencyWeighting
        for hour in 0..<24 {
            let coverage = Double(uniqueDaysByHour[hour].count) / Double(totalActiveDays)
            coverageByHour[hour] = coverage
            if coverageUsedInPeakScoring, coverage <= 0.2 {
                bucketCounts[hour] *= 0.3
            }
        }
        let adjustedBuckets = bucketCounts

        let maxBucket = max(bucketCounts.max() ?? 0, 1)
        let normalized = bucketCounts.map { value in
            min(1, max(0, value / maxBucket))
        }

        return HourlySignal(
            normalized: normalized,
            rawBuckets: rawBuckets,
            adjustedBuckets: adjustedBuckets,
            coverage: coverageByHour,
            activeDays: activeDays.count,
            coverageUsedInPeakScoring: coverageUsedInPeakScoring,
            isRecencyWeighted: useRecencyWeighting
        )
    }

    static func safelySmoothed(_ values: [Double]) -> [Double] {
        guard values.count == 24 else { return values }

        let originalPeak = argmax(values)
        let smoothedCandidate = (0..<24).map { hour in
            let previous = values[(hour + 23) % 24]
            let current = values[hour]
            let next = values[(hour + 1) % 24]
            let rawSmoothed = (previous * 0.2) + (current * 0.6) + (next * 0.2)
            let localCeiling = max(previous, current, next)
            return min(max(rawSmoothed, 0), localCeiling)
        }

        let smoothedPeak = argmax(smoothedCandidate)
        if smoothedPeak != originalPeak {
            return values
        }

        return smoothedCandidate
    }

    static func argmax(_ values: [Double]) -> Int {
        guard !values.isEmpty else { return 12 }

        var bestIndex = 0
        var bestValue = values[0]
        for index in 1..<values.count {
            let candidate = values[index]
            if candidate > bestValue {
                bestValue = candidate
                bestIndex = index
            }
        }
        return bestIndex
    }

    static func detectShape(scores: [Double], peakHour: Int) -> ShapeType {
        guard scores.count == 24 else { return .flat }

        let minScore = scores.min() ?? 0
        let maxScore = scores.max() ?? 0
        let spread = maxScore - minScore
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.reduce(0) { partial, score in
            let delta = score - mean
            return partial + (delta * delta)
        } / Double(scores.count)
        let standardDeviation = sqrt(variance)

        if maxScore < 0.18 || spread < 0.12 || standardDeviation < 0.06 {
            return .flat
        }

        let ranked = scores.enumerated().sorted { lhs, rhs in
            if lhs.element == rhs.element {
                return lhs.offset < rhs.offset
            }
            return lhs.element > rhs.element
        }

        guard ranked.count > 1 else { return .singlePeak }
        let secondHour = ranked[1].offset
        let secondValue = ranked[1].element
        let hourDistance = wrappedHourDistance(peakHour, secondHour)

        if secondValue >= (maxScore * 0.9), hourDistance >= 3 {
            return .multiPeak
        }

        return .singlePeak
    }

    static func wrappedHourDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let raw = abs(lhs - rhs)
        return min(raw, 24 - raw)
    }

    static func recencyWeight(for timestamp: Date, now: Date, decayFactorDays: Double) -> Double {
        let secondsPerDay = 86_400.0
        let daysAgo = max(0, now.timeIntervalSince(timestamp) / secondsPerDay)
        let decayFactor = max(1.0, decayFactorDays)
        return exp(-daysAgo / decayFactor)
    }

    static func confidenceAdjustedForShift(
        baseConfidence: Double,
        recentPeak: Int,
        historicalPeak: Int
    ) -> Double {
        guard recentPeak != historicalPeak else { return baseConfidence }
        return max(0, min(1, baseConfidence - 0.08))
    }

    static func confidenceFromDistribution(
        scores: [Double],
        activeDays: Int
    ) -> Double {
        let topScores = scores.sorted(by: >).prefix(3)
        guard let peakScore = topScores.first else { return 0 }

        let topSum = max(topScores.reduce(0, +), 0.0001)
        var confidence = peakScore / topSum
        confidence *= dataQualityFactor(activeDays: activeDays)

        let secondHighest = topScores.dropFirst().first ?? 0
        if secondHighest >= (peakScore * 0.85) {
            confidence *= 0.7
        } else if secondHighest >= (peakScore * 0.7) {
            confidence *= 0.85
        }

        return min(max(confidence, 0), 0.97)
    }

    static func dataQualityFactor(activeDays: Int) -> Double {
        let days = max(0, activeDays)
        switch days {
        case ..<5:
            let progress = Double(days) / 4.0
            return 0.4 + (0.2 * progress)
        case 5...10:
            let progress = Double(days - 5) / 5.0
            return 0.6 + (0.2 * progress)
        default:
            let progress = min(Double(days - 10) / 10.0, 1.0)
            return 0.8 + (0.2 * progress)
        }
    }

    static let recencyDecayFactorDays: Double = 14.0

    static func blendingConfidence(
        habitSignal: HourlySignal,
        globalSignal: HourlySignal,
        baseConfidence: Double
    ) -> Double {
        guard habitSignal.normalized.count == 24, globalSignal.normalized.count == 24 else {
            return baseConfidence
        }

        let habitPeak = argmax(habitSignal.normalized)
        let globalPeak = argmax(globalSignal.normalized)
        guard habitPeak != globalPeak else { return baseConfidence }

        let habitPeakValue = habitSignal.normalized[habitPeak]
        let globalAtHabitPeak = globalSignal.normalized[habitPeak]
        let localLead = habitPeakValue - globalAtHabitPeak
        let hasStrongLocalPattern = habitSignal.activeDays >= 3 && habitPeakValue >= 0.65 && localLead >= 0.25

        if hasStrongLocalPattern {
            // Prevent low-confidence blending from overriding a clear local timing signal.
            return max(baseConfidence, 0.65)
        }

        return baseConfidence
    }

    static func isDebugEnvironmentEnabled() -> Bool {
        let value = ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() ?? ""
        return value == "1" || value == "true" || value == "yes"
    }

    static func peakCompetitionExplanation(
        selectedPeakHour: Int,
        blended: [Double],
        smoothed: [Double]
    ) -> String {
        guard blended.count == 24, smoothed.count == 24 else {
            return "peak explanation: insufficient score data"
        }

        let noonBlended = blended[12]
        let eveningBlended = blended[21]
        let noonSmoothed = smoothed[12]
        let eveningSmoothed = smoothed[21]

        return String(
            format: "peak explanation: selected=%02d, blended(12)=%.4f vs blended(21)=%.4f, smoothed(12)=%.4f vs smoothed(21)=%.4f",
            selectedPeakHour,
            noonBlended,
            eveningBlended,
            noonSmoothed,
            eveningSmoothed
        )
    }

    static func topHours(from values: [Double], count: Int = 3) -> String {
        values.enumerated()
            .sorted { lhs, rhs in
                if lhs.element == rhs.element {
                    return lhs.offset < rhs.offset
                }
                return lhs.element > rhs.element
            }
            .prefix(count)
            .map { String(format: "%02d=%.4f", $0.offset, $0.element) }
            .joined(separator: ", ")
    }
}
