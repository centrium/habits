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
        allowGlobalBlending: Bool = true,
        debugMode: Bool = false,
        debugLabel: String? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInsightResult {
        computeDetails(
            logs: logs,
            globalLogs: globalLogs,
            allowGlobalBlending: allowGlobalBlending,
            debugMode: debugMode,
            debugLabel: debugLabel,
            now: now,
            calendar: calendar
        ).result
    }

    static func computeDetails(
        logs: [HabitLog],
        globalLogs: [HabitLog],
        allowGlobalBlending: Bool = true,
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

        let eventCoverage = min(1.0, Double(habitEvents.count) / 24.0)
        let dayCoverage = min(1.0, Double(habitSignal.activeDays) / 14.0)
        let baseConfidence = (eventCoverage * 0.75) + (dayCoverage * 0.25)
        let historicalPeak = argmax(historicalHabitSignal.normalized)
        let recentPeak = argmax(habitSignal.normalized)
        let blendingConfidence = blendingConfidence(
            habitSignal: habitSignal,
            globalSignal: globalSignal,
            baseConfidence: baseConfidence
        )
        let isInsufficientSignal = habitEvents.count < minimumEventCountForSignal

        let blended = (0..<24).map { hour in
            if !allowGlobalBlending {
                return habitSignal.normalized[hour]
            }
            let habitScore = habitSignal.normalized[hour]
            let globalScore = globalSignal.normalized[hour]
            return (habitScore * blendingConfidence) + (globalScore * (1.0 - blendingConfidence))
        }

        let smoothed = isInsufficientSignal
            ? Array(repeating: 0.0, count: 24)
            : safelySmoothed(blended)
        let peakHour = isInsufficientSignal ? recentPeak : argmax(smoothed)
        let shape: ShapeType = isInsufficientSignal
            ? .flat
            : detectShape(scores: smoothed, peakHour: peakHour)
        let confidenceBase = isInsufficientSignal
            ? 0
            : confidenceFromDistribution(
                scores: smoothed,
                activeDays: habitSignal.activeDays,
                eventCount: habitEvents.count
            )
        let confidence = isInsufficientSignal
            ? 0
            : confidenceAdjustedForShift(
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
            print(
                debugReport(
                    logs: logs,
                    label: debugLabel ?? "unknown",
                    now: now,
                    calendar: calendar,
                    habitEvents: habitEvents,
                    globalEvents: globalEvents,
                    isInsufficientSignal: isInsufficientSignal,
                    allowGlobalBlending: allowGlobalBlending,
                    blendingConfidence: blendingConfidence,
                    habitSignal: habitSignal,
                    globalSignal: globalSignal,
                    blended: blended,
                    smoothed: smoothed,
                    peakHour: peakHour,
                    confidence: confidence
                )
            )
        }

        return TimeInsightComputation(result: result, diagnostics: diagnostics)
    }

    static func debugDumpAllLogs(
        for habit: Habit,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
#if DEBUG
        print(
            debugAllLogsReport(
                for: habit,
                now: now,
                calendar: calendar
            )
        )
#else
        _ = habit
        _ = now
        _ = calendar
#endif
    }
}

private extension TimeInsightEngine {
    static let minimumEventCountForSignal: Int = 3

    struct DeduplicatedEvent {
        let logID: UUID
        let logicalDay: Date
        let timestamp: Date
        let createdAt: Date
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
        var events: [DeduplicatedEvent] = []
        events.reserveCapacity(logs.count)

        for log in logs {
            guard log.kind == .entry,
                  let timestamp = log.timestamp,
                  timestamp <= now,
                  let minuteStart = calendar.dateInterval(of: .minute, for: timestamp)?.start else {
                continue
            }

            events.append(
                DeduplicatedEvent(
                    logID: log.id,
                    logicalDay: log.day,
                    timestamp: timestamp,
                    createdAt: log.createdAt,
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
            let eventWeight: Double
            if useRecencyWeighting {
                let timestampRecencyWeight = recencyWeight(
                    for: event.minuteStart,
                    now: now,
                    decayFactorDays: recencyDecayFactorDays
                )
                let trust = timingTrustFactor(
                    timestamp: event.timestamp,
                    createdAt: event.createdAt
                )
                eventWeight = timestampRecencyWeight * trust
            } else {
                eventWeight = 1.0
            }
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

    static func timingTrustFactor(timestamp: Date, createdAt: Date) -> Double {
        let deltaSeconds = abs(timestamp.timeIntervalSince(createdAt))
        let deltaHours = deltaSeconds / 3_600.0

        switch deltaHours {
        case ...2:
            return 1.0
        case ...24:
            return 0.75
        case ...72:
            return 0.4
        default:
            return 0.1
        }
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
        activeDays: Int,
        eventCount: Int
    ) -> Double {
        let topScores = scores.sorted(by: >).prefix(3)
        guard let peakScore = topScores.first else { return 0 }

        let topSum = max(topScores.reduce(0, +), 0.0001)
        var confidence = peakScore / topSum
        confidence *= dataQualityFactor(activeDays: activeDays, eventCount: eventCount)

        let secondHighest = topScores.dropFirst().first ?? 0
        if secondHighest >= (peakScore * 0.85) {
            confidence *= 0.7
        } else if secondHighest >= (peakScore * 0.7) {
            confidence *= 0.85
        }

        return min(max(confidence, 0), 0.97)
    }

    static func dataQualityFactor(activeDays: Int, eventCount: Int) -> Double {
        let events = max(0, eventCount)
        let eventFactor: Double = {
            switch events {
            case ..<5:
                let progress = Double(events) / 4.0
                return 0.35 + (0.25 * progress)
            case 5...12:
                let progress = Double(events - 5) / 7.0
                return 0.6 + (0.2 * progress)
            default:
                let progress = min(Double(events - 12) / 12.0, 1.0)
                return 0.8 + (0.2 * progress)
            }
        }()

        let days = max(0, activeDays)
        let dayFactor: Double = {
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
        }()

        return min(1, max(0, (eventFactor * 0.75) + (dayFactor * 0.25)))
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

    static func debugReport(
        logs: [HabitLog],
        label: String,
        now: Date,
        calendar: Calendar,
        habitEvents: [DeduplicatedEvent],
        globalEvents: [DeduplicatedEvent],
        isInsufficientSignal: Bool,
        allowGlobalBlending: Bool,
        blendingConfidence: Double,
        habitSignal: HourlySignal,
        globalSignal: HourlySignal,
        blended: [Double],
        smoothed: [Double],
        peakHour: Int,
        confidence: Double
    ) -> String {
        let includedRows = debugIncludedRows(logs: logs, now: now, calendar: calendar)
        let uniqueActiveDays = Set(includedRows.map(\.dayStart)).count
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = calendar.timeZone

        var rawCountByHour = Array(repeating: 0, count: 24)
        var rawWeightedByHour = Array(repeating: 0.0, count: 24)
        for row in includedRows {
            rawCountByHour[row.hour] += 1
            rawWeightedByHour[row.hour] += row.adjustedWeight
        }

        let ranked = smoothed.enumerated().sorted { lhs, rhs in
            if lhs.element == rhs.element {
                return lhs.offset < rhs.offset
            }
            return lhs.element > rhs.element
        }
        let winner = ranked.first ?? (offset: 0, element: 0.0)
        let runnerUp = ranked.dropFirst().first ?? (offset: 0, element: 0.0)
        let exclusions = debugExclusionSummary(logs: logs, now: now, calendar: calendar)
        let confidenceBand: String = {
            switch confidence {
            case ..<0.35: return "low"
            case ..<0.75: return "medium"
            default: return "high"
            }
        }()

        var lines: [String] = []
        lines.append("---- Timing Signal Debug (\(label)) ----")
        lines.append("A. Input summary")
        lines.append("[input] now=\(formatter.string(from: now)) timezone=\(calendar.timeZone.identifier)")
        lines.append("[input] logsIncluded=\(habitEvents.count) uniqueActiveDays=\(uniqueActiveDays) globalEvents=\(globalEvents.count)")
        lines.append("[input] logsExcluded nonEntry=\(exclusions.nonEntry) missingTimestamp=\(exclusions.missingTimestamp) future=\(exclusions.futureTimestamp)")
        lines.append("[input] insufficientData=\(isInsufficientSignal) minEvents=\(minimumEventCountForSignal)")
        lines.append("[input] placementSource=timestamp weightingSource=timestamp recencyDecayDays=\(String(format: "%.1f", recencyDecayFactorDays))")

        lines.append("B. Per-log trace")
        if includedRows.isEmpty {
            lines.append("[log] none")
        } else {
            for row in includedRows {
                lines.append(
                    "[log] id=\(row.logID.uuidString) date=\(formatter.string(from: row.logicalDay)) createdAt=\(formatter.string(from: row.createdAt)) localTOD=\(row.localTOD) bin=\(row.hour) placementSource=timestamp weightingSource=timestamp ageDays=\(String(format: "%.2f", row.ageDays)) weight(timestamp)=\(String(format: "%.4f", row.timestampWeight)) weight(createdAt)=\(String(format: "%.4f", row.createdAtWeight)) [trust] deltaHours=\(String(format: "%.2f", row.trustDeltaHours)) trust=\(String(format: "%.2f", row.trust)) adjustedWeight=\(String(format: "%.4f", row.adjustedWeight))"
                )
            }
        }

        lines.append("C. Bin summary before smoothing")
        let nonZeroRawHours = (0..<24).filter { rawCountByHour[$0] > 0 || rawWeightedByHour[$0] > 0.0001 }
        if nonZeroRawHours.isEmpty {
            lines.append("[bin raw] none")
        } else {
            for hour in nonZeroRawHours {
                lines.append(
                    "[bin raw] \(hourLabel(hour)) count=\(rawCountByHour[hour]) weighted=\(String(format: "%.4f", rawWeightedByHour[hour]))"
                )
            }
        }

        lines.append("D. Smoothing summary")
        let smoothingEnabled = !isInsufficientSignal
        lines.append("[smooth] enabled=\(smoothingEnabled ? "yes" : "no") mode=tri-neighbor-circular-kernel(0.2,0.6,0.2)-peak-preserving")
        lines.append("[smooth] blending=\(allowGlobalBlending ? "enabled" : "disabled") blendingConfidence=\(String(format: "%.4f", blendingConfidence))")
        if smoothingEnabled {
            let nonZeroSmoothedHours = (0..<24).filter { smoothed[$0] > 0.0001 }
            for hour in nonZeroSmoothedHours.prefix(10) {
                lines.append("[bin smooth] \(hourLabel(hour)) score=\(String(format: "%.4f", smoothed[hour]))")
            }
        } else {
            lines.append("[smooth] suppressedDueToInsufficientData=true")
        }

        lines.append("E. Peak selection summary")
        lines.append("[peak] mode=argmax(smoothedNormalizedScores)")
        lines.append("[peak] winner=\(hourLabel(winner.offset)) score=\(String(format: "%.4f", winner.element))")
        lines.append("[peak] runnerUp=\(hourLabel(runnerUp.offset)) score=\(String(format: "%.4f", runnerUp.element))")
        lines.append("[peak] strongestWindowLabel=\(windowBucketLabel(for: peakHour) ?? "nil") peakTime=\(hourLabel(peakHour))")

        lines.append("F. Confidence summary")
        lines.append("[confidence] score=\(String(format: "%.4f", confidence)) band=\(confidenceBand) activeDays=\(habitSignal.activeDays) events=\(habitEvents.count)")
        lines.append("[confidence] suppressedStrongestWindow=\(isInsufficientSignal ? "yes" : "no")")

        let resultLine: String
        if isInsufficientSignal {
            resultLine = "[result] strongestWindow=nil confidence=low reason=Insufficient signal; only \(habitEvents.count) logs across \(habitSignal.activeDays) active day(s), so peak is intentionally suppressed"
        } else {
            resultLine = "[result] strongestWindow=\(hourLabel(peakHour)) confidence=\(confidenceBand) reason=Selected dominant weighted bin \(hourLabel(winner.offset)) score=\(String(format: "%.4f", winner.element)) vs runner-up \(hourLabel(runnerUp.offset)) score=\(String(format: "%.4f", runnerUp.element))"
        }
        lines.append("G. Final explanation line")
        lines.append(resultLine)

        // Keep compact numerical context for cross-checking.
        lines.append("[trace] habitTopHours=\(topHours(from: habitSignal.normalized)) globalTopHours=\(topHours(from: globalSignal.normalized)) blendedTopHours=\(topHours(from: blended))")
        return lines.joined(separator: "\n")
    }

    struct DebugIncludedRow {
        let logID: UUID
        let logicalDay: Date
        let createdAt: Date
        let dayStart: Date
        let hour: Int
        let localTOD: String
        let trustDeltaHours: Double
        let trust: Double
        let ageDays: Double
        let timestampWeight: Double
        let createdAtWeight: Double
        let adjustedWeight: Double
    }

    struct DebugExclusionSummary {
        let nonEntry: Int
        let missingTimestamp: Int
        let futureTimestamp: Int
    }

    static func debugExclusionSummary(
        logs: [HabitLog],
        now: Date,
        calendar: Calendar
    ) -> DebugExclusionSummary {
        var nonEntry = 0
        var missingTimestamp = 0
        var futureTimestamp = 0

        for log in logs {
            guard log.kind == .entry else {
                nonEntry += 1
                continue
            }
            guard let timestamp = log.timestamp else {
                missingTimestamp += 1
                continue
            }
            guard timestamp <= now else {
                futureTimestamp += 1
                continue
            }
            guard calendar.dateInterval(of: .minute, for: timestamp)?.start != nil else {
                missingTimestamp += 1
                continue
            }
        }

        return DebugExclusionSummary(
            nonEntry: nonEntry,
            missingTimestamp: missingTimestamp,
            futureTimestamp: futureTimestamp
        )
    }

    static func debugIncludedRows(
        logs: [HabitLog],
        now: Date,
        calendar: Calendar
    ) -> [DebugIncludedRow] {
        var rows: [DebugIncludedRow] = []

        for log in logs {
            guard log.kind == .entry,
                  let timestamp = log.timestamp,
                  timestamp <= now,
                  let minuteStart = calendar.dateInterval(of: .minute, for: timestamp)?.start else {
                continue
            }
            let hour = calendar.component(.hour, from: minuteStart)
            let minute = calendar.component(.minute, from: minuteStart)
            let ageDays = max(0, now.timeIntervalSince(minuteStart) / 86_400.0)
            let timestampWeight = recencyWeight(
                for: minuteStart,
                now: now,
                decayFactorDays: recencyDecayFactorDays
            )
            let createdAtWeight = recencyWeight(
                for: log.createdAt,
                now: now,
                decayFactorDays: recencyDecayFactorDays
            )
            let trustDeltaHours = abs(timestamp.timeIntervalSince(log.createdAt)) / 3_600.0
            let trust = timingTrustFactor(timestamp: timestamp, createdAt: log.createdAt)
            let adjustedWeight = timestampWeight * trust
            let localTOD = String(format: "%02d:%02d", hour, minute)
            rows.append(
                DebugIncludedRow(
                    logID: log.id,
                    logicalDay: log.day,
                    createdAt: log.createdAt,
                    dayStart: calendar.startOfDay(for: minuteStart),
                    hour: hour,
                    localTOD: localTOD,
                    trustDeltaHours: trustDeltaHours,
                    trust: trust,
                    ageDays: ageDays,
                    timestampWeight: timestampWeight,
                    createdAtWeight: createdAtWeight,
                    adjustedWeight: adjustedWeight
                )
            )
        }

        return rows.sorted { lhs, rhs in
            if lhs.logicalDay == rhs.logicalDay {
                return lhs.localTOD < rhs.localTOD
            }
            return lhs.logicalDay < rhs.logicalDay
        }
    }

    static func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", ((hour % 24) + 24) % 24)
    }

    static func windowBucketLabel(for peakHour: Int) -> String? {
        switch peakHour {
        case 5..<11:
            return "Morning"
        case 11..<17:
            return "Afternoon"
        case 17..<23:
            return "Evening"
        case 23, 0..<5:
            return "Night"
        default:
            return nil
        }
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

    struct LogDumpRow {
        let logID: UUID
        let kind: HabitLogKind
        let logicalDay: Date
        let timestamp: Date?
        let effectiveTimestamp: Date
        let createdAt: Date
        let count: Int
        let value: Double?
        let numericValue: Double
        let frequencyContribution: Int
        let localTOD: String
        let bin: Int?
        let minuteStart: Date?
        let ageDaysByTimestamp: Double?
        let ageDaysByCreatedAt: Double
        let recencyWeightByTimestamp: Double?
        let recencyWeightByCreatedAt: Double
        let trustDeltaHours: Double?
        let trust: Double?
        let adjustedWeight: Double?
        let includedInTiming: Bool
        let exclusionReason: String?
    }

    static func debugAllLogsReport(
        for habit: Habit,
        now: Date,
        calendar: Calendar
    ) -> String {
        let rows = buildLogDumpRows(
            logs: habit.logs,
            now: now,
            calendar: calendar
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = calendar.timeZone

        let total = rows.count
        let entryCount = rows.filter { $0.kind == .entry }.count
        let legacyCount = rows.filter { $0.kind == .legacyDailyTotal }.count
        let includedCount = rows.filter(\.includedInTiming).count
        let uniqueDays = Set(rows.map { calendar.startOfDay(for: $0.effectiveTimestamp) }).count

        var lines: [String] = []
        lines.append("---- Habit Log Full Dump (\(habit.name)) ----")
        lines.append("[habit] id=\(habit.id.uuidString) goalType=\(habit.goalType.rawValue) hasGoal=\(habit.hasGoal) createdAt=\(formatter.string(from: habit.createdAt))")
        lines.append("[context] now=\(formatter.string(from: now)) timezone=\(calendar.timeZone.identifier)")
        lines.append("[counts] total=\(total) entry=\(entryCount) legacy=\(legacyCount) uniqueDays=\(uniqueDays)")
        lines.append("[timing-input] eligible=\(includedCount) excluded=\(total - includedCount)")
        lines.append("[timing-config] placementSource=timestamp weightingSource=timestamp recencyDecayDays=\(String(format: "%.1f", recencyDecayFactorDays))")

        if rows.isEmpty {
            lines.append("[log] none")
        } else {
            for row in rows {
                let timestampText = row.timestamp.map { formatter.string(from: $0) } ?? "nil"
                let minuteStartText = row.minuteStart.map { formatter.string(from: $0) } ?? "nil"
                let ageByTimestampText = row.ageDaysByTimestamp.map { String(format: "%.2f", $0) } ?? "nil"
                let weightByTimestampText = row.recencyWeightByTimestamp.map { String(format: "%.4f", $0) } ?? "nil"
                let trustDeltaHoursText = row.trustDeltaHours.map { String(format: "%.2f", $0) } ?? "nil"
                let trustText = row.trust.map { String(format: "%.2f", $0) } ?? "nil"
                let adjustedWeightText = row.adjustedWeight.map { String(format: "%.4f", $0) } ?? "nil"
                let binText = row.bin.map(String.init) ?? "nil"
                let excludedText = row.exclusionReason ?? "none"
                lines.append(
                    "[log] id=\(row.logID.uuidString) kind=\(row.kind.rawValue) day=\(formatter.string(from: row.logicalDay)) timestamp=\(timestampText) effective=\(formatter.string(from: row.effectiveTimestamp)) createdAt=\(formatter.string(from: row.createdAt)) localTOD=\(row.localTOD) minuteStart=\(minuteStartText) bin=\(binText) count=\(row.count) value=\(row.value.map { String(format: "%.4f", $0) } ?? "nil") numeric=\(String(format: "%.4f", row.numericValue)) freqContribution=\(row.frequencyContribution) timingEligible=\(row.includedInTiming) exclusion=\(excludedText) ageDays(timestamp)=\(ageByTimestampText) ageDays(createdAt)=\(String(format: "%.2f", row.ageDaysByCreatedAt)) weight(timestamp)=\(weightByTimestampText) weight(createdAt)=\(String(format: "%.4f", row.recencyWeightByCreatedAt)) [trust] deltaHours=\(trustDeltaHoursText) trust=\(trustText) adjustedWeight=\(adjustedWeightText)"
                )
            }
        }

        lines.append("---- End Habit Log Full Dump ----")
        return lines.joined(separator: "\n")
    }

    static func buildLogDumpRows(
        logs: [HabitLog],
        now: Date,
        calendar: Calendar
    ) -> [LogDumpRow] {
        let sorted = logs.sorted { lhs, rhs in
            if lhs.effectiveTimestamp == rhs.effectiveTimestamp {
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.effectiveTimestamp < rhs.effectiveTimestamp
        }

        var rows: [LogDumpRow] = []
        rows.reserveCapacity(sorted.count)

        for log in sorted {
            let timestamp = log.timestamp
            let minuteStart = timestamp.flatMap { calendar.dateInterval(of: .minute, for: $0)?.start }

            let exclusionReason: String? = {
                guard log.kind == .entry else { return "nonEntry(kind=\(log.kind.rawValue))" }
                guard let timestamp else { return "missingTimestamp" }
                guard timestamp <= now else { return "futureTimestamp" }
                guard minuteStart != nil else { return "invalidMinuteStart" }
                return nil
            }()
            let includedInTiming = exclusionReason == nil

            let hour = minuteStart.map { calendar.component(.hour, from: $0) }
            let minute = minuteStart.map { calendar.component(.minute, from: $0) }
            let localTOD = {
                guard let hour, let minute else { return "n/a" }
                return String(format: "%02d:%02d", hour, minute)
            }()

            let ageDaysByTimestamp = minuteStart.map { max(0, now.timeIntervalSince($0) / 86_400.0) }
            let recencyWeightByTimestamp = minuteStart.map {
                recencyWeight(for: $0, now: now, decayFactorDays: recencyDecayFactorDays)
            }
            let ageDaysByCreatedAt = max(0, now.timeIntervalSince(log.createdAt) / 86_400.0)
            let recencyWeightByCreatedAt = recencyWeight(
                for: log.createdAt,
                now: now,
                decayFactorDays: recencyDecayFactorDays
            )
            let trustDeltaHours = timestamp.map { abs($0.timeIntervalSince(log.createdAt)) / 3_600.0 }
            let trust = timestamp.map {
                timingTrustFactor(timestamp: $0, createdAt: log.createdAt)
            }
            let adjustedWeight = recencyWeightByTimestamp.flatMap { timestampWeight in
                trust.map { timestampWeight * $0 }
            }

            rows.append(
                LogDumpRow(
                    logID: log.id,
                    kind: log.kind,
                    logicalDay: log.day,
                    timestamp: timestamp,
                    effectiveTimestamp: log.effectiveTimestamp,
                    createdAt: log.createdAt,
                    count: log.count,
                    value: log.value,
                    numericValue: log.numericValue,
                    frequencyContribution: log.frequencyContribution,
                    localTOD: localTOD,
                    bin: hour,
                    minuteStart: minuteStart,
                    ageDaysByTimestamp: ageDaysByTimestamp,
                    ageDaysByCreatedAt: ageDaysByCreatedAt,
                    recencyWeightByTimestamp: recencyWeightByTimestamp,
                    recencyWeightByCreatedAt: recencyWeightByCreatedAt,
                    trustDeltaHours: trustDeltaHours,
                    trust: trust,
                    adjustedWeight: adjustedWeight,
                    includedInTiming: includedInTiming,
                    exclusionReason: exclusionReason
                )
            )
        }

        return rows
    }
}
