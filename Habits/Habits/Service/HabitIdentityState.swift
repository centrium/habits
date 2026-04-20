import Foundation

struct IdentityOutput: Codable {
    let title: String
    let line1: String?
    let line2: String?
}

enum HabitState: String, Equatable, Codable {
    case start
    case build
    case steady
    case strong
    case slip
    case rebuild
}

enum TimingConfidence: String, Equatable, Codable {
    case low
    case medium
    case high
}

struct HabitStateModel: Equatable {
    let state: HabitState
    let strongestTime: String?
    let timingConfidence: TimingConfidence
    let habitStrength: Double
    let risk: Double
    let consistency: Int
    let streakState: String
}

enum HabitIdentityState: Equatable {
    case gettingStarted
    case building
    case steady
    case strong
    case slipping
    case rebuilding
}

struct CadenceLanguage {
    // MARK: - Identity

    static func identityTitle() -> String {
        CadenceCopyCatalog.identityTitle()
    }

    static func identityEmptyPrompt() -> String {
        CadenceCopyCatalog.identityEmptyPrompt()
    }

    static func identityHelper() -> String {
        CadenceCopyCatalog.identityHelper()
    }

    static func identityPlaceholder() -> String {
        CadenceCopyCatalog.identityPlaceholder()
    }

    static func identityStat(days: Int, window: Int) -> String {
        CadenceCopyCatalog.identityStat(days: days, window: window)
    }

    static func identityReinforcement() -> String {
        CadenceCopyCatalog.identityReinforcement()
    }

    static func shortLabel(for state: HabitIdentityState) -> String {
        stateTitle(state)
    }

    static func shortLabel(for state: HabitState) -> String {
        CadenceCopyCatalog.shortLabel(for: state.cadenceStateKey)
    }

    static func stateTitle(_ state: HabitIdentityState) -> String {
        CadenceCopyCatalog.shortLabel(for: state.cadenceStateKey)
    }

    static func stateTitle(_ state: HabitState) -> String {
        CadenceCopyCatalog.shortLabel(for: state.cadenceStateKey)
    }

    static func identityLine(for state: HabitIdentityState) -> String {
        CadenceCopyCatalog.identityLine(for: state.cadenceStateKey)
    }

    static func identityLine(for state: HabitState) -> String {
        CadenceCopyCatalog.identityLine(for: state.cadenceStateKey)
    }

    static func insightLine(for state: HabitIdentityState) -> String {
        CadenceCopyCatalog.insightLine(for: state.cadenceStateKey)
    }

    static func insightLine(for state: HabitState) -> String {
        CadenceCopyCatalog.insightLine(for: state.cadenceStateKey)
    }

    static func riskEarlyStage() -> String {
        CadenceCopyCatalog.riskEarlyStage()
    }

    static func behaviourLine(
        completions: Int?,
        window: Int?
    ) -> String {
        identityStat(days: completions ?? 0, window: window ?? 7)
    }

    static func identityOutput(
        for habit: Habit,
        date: Date,
        calendar: Calendar = .current
    ) -> IdentityOutput {
        let snapshot = HabitIdentityStateResolver.recentSnapshot(
            for: habit,
            calendar: calendar,
            now: date,
            windowDays: 7
        )
        let metrics = HabitIdentityMetrics.from(snapshot: snapshot)
        let identityNarrative = HabitIdentityEngine.build(habit: habit, metrics: metrics)

        let title = identityNarrative?.identityLine ?? identityEmptyPrompt()
        let line1 = behaviourLine(
            completions: snapshot.activeDays,
            window: snapshot.windowDays
        )
        let line2: String? = nil

        return IdentityOutput(
            title: title,
            line1: line1,
            line2: line2
        )
    }
}

private extension HabitIdentityState {
    var cadenceStateKey: CadenceStateKey {
        switch self {
        case .gettingStarted:
            return .start
        case .building:
            return .build
        case .steady:
            return .steady
        case .strong:
            return .strong
        case .slipping:
            return .slip
        case .rebuilding:
            return .rebuild
        }
    }
}

private extension HabitState {
    var cadenceStateKey: CadenceStateKey {
        switch self {
        case .start:
            return .start
        case .build:
            return .build
        case .steady:
            return .steady
        case .strong:
            return .strong
        case .slip:
            return .slip
        case .rebuild:
            return .rebuild
        }
    }
}

extension HabitState {
    var identityState: HabitIdentityState {
        switch self {
        case .start:
            return .gettingStarted
        case .build:
            return .building
        case .steady:
            return .steady
        case .strong:
            return .strong
        case .slip:
            return .slipping
        case .rebuild:
            return .rebuilding
        }
    }
}

extension HabitIdentityState {
    var habitState: HabitState {
        switch self {
        case .gettingStarted:
            return .start
        case .building:
            return .build
        case .steady:
            return .steady
        case .strong:
            return .strong
        case .slipping:
            return .slip
        case .rebuilding:
            return .rebuild
        }
    }
}

enum HabitStateResolver {
    static func deriveState(
        consistency: Int,
        habitStrength: Double,
        risk: Double,
        streakState: String
    ) -> HabitState {
        // Identity state is the source of truth.
        // Timing, momentum, and AI must never override this state.
        _ = habitStrength
        _ = streakState

        if risk > 0.7 {
            return .slip
        }

        if risk > 0.4 {
            return .rebuild
        }

        if consistency < 30 {
            return .start
        }

        if consistency < 60 {
            return .build
        }

        if consistency < 80 {
            return .steady
        }

        return .strong
    }

    static func resolve(
        for habit: Habit,
        globalLogs: [HabitLog] = [],
        calendar: Calendar,
        weekStartPreference: WeekStartPreference = .system,
        now: Date = .now
    ) -> HabitStateModel {
        let normalizedLogs = InsightLogNormalizer.normalize(logs: habit.logs, calendar: calendar)
        let consistency = HabitInsightsService(calendar: calendar).snapshot(
            for: habit,
            now: now
        ).consistency
        let habitStrength = PerformanceSignalsCalculator.habitStrengthScore(
            for: habit,
            logs: normalizedLogs,
            calendar: calendar,
            now: now
        )
        let risk = PerformanceSignalsCalculator.habitRiskScore(
            for: habit,
            logs: normalizedLogs,
            calendar: calendar,
            now: now
        )
        let streak = StreakStateEngine(
            calendar: calendar,
            weekStartPreference: weekStartPreference
        ).streakState(for: habit, referenceDate: now)
        let streakState = streakLabel(for: streak)
        let timingSummary = TimeOfDayPerformanceService.peakTimingSummary(
            habitLogs: habit.logs,
            globalLogs: globalLogs.isEmpty ? habit.logs : globalLogs,
            habitName: habit.name,
            habitType: habit.goalType,
            now: now,
            calendar: calendar
        )
        let timingConfidence = timingConfidence(
            from: timingSummary?.confidence ?? 0,
            hasSummary: timingSummary != nil,
            uniqueEventCount: timingSummary?.uniqueEventCount ?? 0,
            uniqueActiveDays: timingSummary?.uniqueActiveDays ?? 0
        )
        let strongestTime = timingSummary.map { humanTime(for: $0.peakHour) }
        let state = deriveState(
            consistency: consistency,
            habitStrength: habitStrength,
            risk: risk,
            streakState: streakState
        )

        return HabitStateModel(
            state: state,
            strongestTime: strongestTime,
            timingConfidence: timingConfidence,
            habitStrength: habitStrength,
            risk: risk,
            consistency: consistency,
            streakState: streakState
        )
    }

    private static func timingConfidence(
        from confidence: Double,
        hasSummary: Bool,
        uniqueEventCount: Int,
        uniqueActiveDays: Int
    ) -> TimingConfidence {
        guard hasSummary else { return .low }

        // Mature habits with broad but real timing data should not fall back to "forming"
        // unless confidence is effectively absent.
        let hasMatureTimingVolume = uniqueEventCount >= 24 && uniqueActiveDays >= 10
        if hasMatureTimingVolume, confidence >= 0.18 {
            if confidence < 0.55 {
                return .medium
            }
        }

        switch confidence {
        case ..<0.35:
            return .low
        case ..<0.75:
            return .medium
        default:
            return .high
        }
    }

    private static func streakLabel(for streak: StreakState) -> String {
        guard streak.currentStreak > 0 else { return "forming" }
        switch streak.status {
        case .safe:
            return "\(streak.currentStreak)-period streak"
        case .atRisk:
            return "\(streak.currentStreak)-period streak at risk"
        case .broken:
            return "streak broken"
        }
    }
}

struct HabitIdentityStateSnapshot: Equatable {
    let state: HabitIdentityState
    let completionRate: Double?
    let activeDays: Int
    let windowDays: Int
    let hasRecentData: Bool
}

enum HabitIdentityStateResolver {
    static func resolve(
        recentCompletedDays: Int,
        windowDays: Int,
        totalLogCount: Int,
        lastActivityDay: Date?,
        now: Date,
        calendar: Calendar
    ) -> HabitIdentityState {
        let safeRecentCompletedDays = max(recentCompletedDays, 0)
        let safeTotalLogCount = max(totalLogCount, 0)
        let safeWindowDays = max(windowDays, 1)
        let consistency = Int(
            (
                Double(safeRecentCompletedDays) /
                Double(safeWindowDays)
            ) * 100
        )
        let habitStrength = min(max(Double(safeRecentCompletedDays) / Double(safeWindowDays), 0), 1)
        let risk: Double = {
            guard safeTotalLogCount > 2 else { return 0.2 }
            guard safeRecentCompletedDays == 0 else {
                if safeRecentCompletedDays <= 1 { return 0.45 }
                return 0.2
            }

            let inactivityDays: Int = {
                guard let lastActivityDay else { return safeWindowDays }
                let today = calendar.startOfDay(for: now)
                let lastDay = calendar.startOfDay(for: lastActivityDay)
                return max(calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0, 0)
            }()
            return inactivityDays >= safeWindowDays ? 0.8 : 0.6
        }()
        let state = HabitStateResolver.deriveState(
            consistency: consistency,
            habitStrength: habitStrength,
            risk: risk,
            streakState: "derived"
        )

        return state.identityState
    }

    @available(*, deprecated, message: "Use resolve(recentCompletedDays:windowDays:totalLogCount:lastActivityDay:now:calendar:)")
    static func resolve(
        completionRate: Double?,
        hasRecentData: Bool
    ) -> HabitIdentityState {
        let normalizedRate = min(max(completionRate ?? 0, 0), 1)
        let consistency = Int((normalizedRate * 100).rounded())
        let risk = hasRecentData ? (normalizedRate <= 0.05 ? 0.75 : 0.45) : 0.2
        return HabitStateResolver.deriveState(
            consistency: consistency,
            habitStrength: normalizedRate,
            risk: risk,
            streakState: "derived"
        ).identityState
    }

    static func resolve(
        for habit: Habit,
        calendar: Calendar,
        now: Date = .now,
        windowDays: Int = 7
    ) -> HabitIdentityState {
        _ = windowDays
        return HabitStateResolver.resolve(
            for: habit,
            calendar: calendar,
            now: now
        ).state.identityState
    }

    static func recentSnapshot(
        for habit: Habit,
        calendar: Calendar,
        now: Date = .now,
        windowDays: Int = 7
    ) -> HabitIdentityStateSnapshot {
        let normalizedWindow = max(1, windowDays)
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .day, value: -(normalizedWindow - 1), to: today) ?? today
        let qualifyingLogDays = habit.logs.compactMap { log -> Date? in
            guard log.frequencyContribution > 0 else { return nil }
            let day = calendar.startOfDay(for: log.effectiveTimestamp)
            guard day <= today else { return nil }
            return day
        }
        let recentCompletedDayCount = Set(
            qualifyingLogDays.filter { $0 >= earliest && $0 <= today }
        ).count
        let totalLogCount = qualifyingLogDays.count
        let lastActivityDay = qualifyingLogDays.max()
        let hasRecentData = recentCompletedDayCount > 0
        let completionRate = Double(recentCompletedDayCount) / Double(normalizedWindow)
        _ = totalLogCount
        _ = lastActivityDay
        let resolvedState = HabitStateResolver.resolve(
            for: habit,
            calendar: calendar,
            now: now
        ).state.identityState

        return HabitIdentityStateSnapshot(
            state: resolvedState,
            completionRate: completionRate,
            activeDays: recentCompletedDayCount,
            windowDays: normalizedWindow,
            hasRecentData: hasRecentData
        )
    }
}
