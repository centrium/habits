import Foundation

struct IdentityOutput: Codable {
    let title: String
    let line1: String?
    let line2: String?
}

enum HabitIdentityState: Equatable {
    case gettingStarted
    case building
    case steady
    case strong
    case slipping
    case rebuilding
}

typealias HabitState = HabitIdentityState

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

    static func shortLabel(for state: HabitIdentityState) -> String {
        stateTitle(state)
    }

    static func stateTitle(_ state: HabitIdentityState) -> String {
        CadenceCopyCatalog.shortLabel(for: state.cadenceStateKey)
    }

    static func identityLine(for state: HabitIdentityState) -> String {
        CadenceCopyCatalog.identityLine(for: state.cadenceStateKey)
    }

    static func insightLine(for state: HabitIdentityState) -> String {
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
            return .gettingStarted
        case .building:
            return .building
        case .steady:
            return .steady
        case .strong:
            return .strong
        case .slipping:
            return .slipping
        case .rebuilding:
            return .rebuilding
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

        // Guard early-stage habits so day-one activity never looks like recovery work.
        if safeTotalLogCount <= 2 {
            return .gettingStarted
        }

        if safeRecentCompletedDays >= min(6, safeWindowDays) {
            return .strong
        }

        if safeRecentCompletedDays >= min(4, safeWindowDays) {
            return .steady
        }

        if safeRecentCompletedDays >= 2 {
            return .building
        }

        if safeRecentCompletedDays == 0 && safeTotalLogCount > 0 {
            guard let lastActivityDay else { return .slipping }
            let today = calendar.startOfDay(for: now)
            let lastDay = calendar.startOfDay(for: lastActivityDay)
            let daysSinceLastActivity = max(
                calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0,
                0
            )
            return daysSinceLastActivity >= safeWindowDays ? .rebuilding : .slipping
        }

        if safeRecentCompletedDays <= 2 && safeTotalLogCount > 5 {
            return .rebuilding
        }

        return .building
    }

    @available(*, deprecated, message: "Use resolve(recentCompletedDays:windowDays:totalLogCount:lastActivityDay:now:calendar:)")
    static func resolve(
        completionRate: Double?,
        hasRecentData: Bool
    ) -> HabitIdentityState {
        guard let rate = completionRate else {
            return .gettingStarted
        }

        switch rate {
        case 0.85...:
            return .strong
        case 0.55..<0.85:
            return .steady
        case 0.3..<0.55:
            return .building
        case 0.15..<0.3:
            return .rebuilding
        case 0.01..<0.15:
            return .slipping
        default:
            return hasRecentData ? .slipping : .gettingStarted
        }
    }

    static func resolve(
        for habit: Habit,
        calendar: Calendar,
        now: Date = .now,
        windowDays: Int = 7
    ) -> HabitIdentityState {
        recentSnapshot(
            for: habit,
            calendar: calendar,
            now: now,
            windowDays: windowDays
        ).state
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
        let resolvedState = resolve(
            recentCompletedDays: recentCompletedDayCount,
            windowDays: normalizedWindow,
            totalLogCount: totalLogCount,
            lastActivityDay: lastActivityDay,
            now: now,
            calendar: calendar
        )

        return HabitIdentityStateSnapshot(
            state: resolvedState,
            completionRate: completionRate,
            activeDays: recentCompletedDayCount,
            windowDays: normalizedWindow,
            hasRecentData: hasRecentData
        )
    }
}
