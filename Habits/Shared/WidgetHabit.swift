//
//  WidgetHabit.swift
//  Habits
//
//  Created by Matt Adams on 20/03/2026.
//

import Foundation
import OSLog

enum WidgetGoalType: String, Codable {
    case binary
    case goal
    case openEnded
}

enum WidgetHeatmapAggregationKind: String, Codable {
    case completion
    case count
    case value
}

struct WidgetActivitySample: Codable, Equatable {
    let date: Date
    let value: Double
}

struct WidgetHabit: Codable, Identifiable {
    let id: UUID
    let name: String
    let isCompleteToday: Bool
    let streak: Int
    let goalType: WidgetGoalType
    let progress: Double?
    let hasActivityToday: Bool
    let iconName: String?
    let colorHex: String?
    let momentumScore: Int
    let heatmapAggregationKind: WidgetHeatmapAggregationKind
    let recentActivity: [WidgetActivitySample]

    var goalProgress: Double {
        guard goalType == .goal else { return 0 }
        return Self.clampedGoalProgress(progress)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isCompleteToday
        case streak
        case goalType
        case progress
        case hasActivityToday
        case iconName
        case colorHex
        case momentumScore
        case heatmapAggregationKind
        case recentActivity

        // Legacy payload support
        case progressFraction
        case usesActivityIndicator
    }

    init(
        id: UUID,
        name: String,
        isCompleteToday: Bool,
        streak: Int,
        goalType: WidgetGoalType,
        progress: Double?,
        hasActivityToday: Bool,
        iconName: String?,
        colorHex: String?,
        momentumScore: Int = 0,
        heatmapAggregationKind: WidgetHeatmapAggregationKind = .completion,
        recentActivity: [WidgetActivitySample] = []
    ) {
        self.id = id
        self.name = name
        self.isCompleteToday = isCompleteToday
        self.streak = streak
        self.goalType = goalType
        self.progress = Self.normalizedProgress(for: goalType, progress: progress)
        self.hasActivityToday = hasActivityToday
        self.iconName = iconName
        self.colorHex = colorHex
        self.momentumScore = max(momentumScore, 0)
        self.heatmapAggregationKind = heatmapAggregationKind
        self.recentActivity = recentActivity

        WidgetHabitLogger.log(
            context: "initialized",
            habitName: name,
            goalType: goalType,
            progress: self.progress
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isCompleteToday = try container.decode(Bool.self, forKey: .isCompleteToday)
        streak = try container.decode(Int.self, forKey: .streak)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        if let decodedGoalType = try container.decodeIfPresent(WidgetGoalType.self, forKey: .goalType) {
            goalType = decodedGoalType
            let decodedProgress = try container.decodeIfPresent(Double.self, forKey: .progress)
            progress = Self.normalizedProgress(for: decodedGoalType, progress: decodedProgress)
            let decodedHasActivity = try container.decodeIfPresent(Bool.self, forKey: .hasActivityToday)
            hasActivityToday = Self.resolvedHasActivity(
                explicitHasActivity: decodedHasActivity,
                goalType: decodedGoalType,
                progress: progress,
                isCompleteToday: isCompleteToday
            )
            momentumScore = try container.decodeIfPresent(Int.self, forKey: .momentumScore) ?? 0
            heatmapAggregationKind = try container.decodeIfPresent(
                WidgetHeatmapAggregationKind.self,
                forKey: .heatmapAggregationKind
            ) ?? .completion
            recentActivity = try container.decodeIfPresent(
                [WidgetActivitySample].self,
                forKey: .recentActivity
            ) ?? []
            WidgetHabitLogger.log(
                context: "decoded",
                habitName: name,
                goalType: goalType,
                progress: progress
            )
            return
        }

        let legacyProgress = try container.decodeIfPresent(Double.self, forKey: .progressFraction)
        let legacyUsesActivity = try container.decodeIfPresent(Bool.self, forKey: .usesActivityIndicator) ?? false

        if legacyUsesActivity {
            goalType = .openEnded
            progress = nil
            hasActivityToday = false
        } else if let legacyProgress {
            goalType = .goal
            progress = Self.normalizedProgress(for: .goal, progress: legacyProgress)
            hasActivityToday = Self.clampedGoalProgress(progress) > 0
        } else {
            goalType = .binary
            progress = nil
            hasActivityToday = isCompleteToday
        }
        momentumScore = 0
        heatmapAggregationKind = .completion
        recentActivity = []

        WidgetHabitLogger.log(
            context: "decoded-legacy",
            habitName: name,
            goalType: goalType,
            progress: progress
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isCompleteToday, forKey: .isCompleteToday)
        try container.encode(streak, forKey: .streak)
        try container.encode(goalType, forKey: .goalType)
        if goalType == .goal {
            try container.encode(goalProgress, forKey: .progress)
        } else {
            try container.encodeIfPresent(progress, forKey: .progress)
        }
        try container.encode(hasActivityToday, forKey: .hasActivityToday)
        try container.encodeIfPresent(iconName, forKey: .iconName)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encode(momentumScore, forKey: .momentumScore)
        try container.encode(heatmapAggregationKind, forKey: .heatmapAggregationKind)
        try container.encode(recentActivity, forKey: .recentActivity)
    }

    private static func normalizedProgress(for goalType: WidgetGoalType, progress: Double?) -> Double? {
        if goalType == .goal {
            return clampedGoalProgress(progress)
        }

        guard let progress else { return nil }
        return progress.isFinite ? progress : nil
    }

    private static func clampedGoalProgress(_ progress: Double?) -> Double {
        guard let progress, progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    private static func resolvedHasActivity(
        explicitHasActivity: Bool?,
        goalType: WidgetGoalType,
        progress: Double?,
        isCompleteToday: Bool
    ) -> Bool {
        if let explicitHasActivity {
            return explicitHasActivity
        }

        switch goalType {
        case .goal:
            return clampedGoalProgress(progress) > 0
        case .binary:
            return isCompleteToday
        case .openEnded:
            return false
        }
    }
}

enum WidgetMomentumState: String, Equatable {
    case slipping = "Slipping"
    case steady = "Steady"
    case building = "Building"
}

enum WidgetMomentumDirection: Equatable {
    case improving(deltaPercent: Int)
    case stable
    case declining(deltaPercent: Int)
    case unavailable

    var summaryText: String {
        switch self {
        case .improving(let deltaPercent):
            return "↑ \(deltaPercent)% vs last 7 days"
        case .stable:
            return "No change vs last 7 days"
        case .declining(let deltaPercent):
            return "↓ \(deltaPercent)% vs last 7 days"
        case .unavailable:
            return "Need 14 days"
        }
    }
}

struct WidgetMomentumSummary: Equatable {
    let score: Int
    let state: WidgetMomentumState
    let direction: WidgetMomentumDirection
}

struct WidgetHeatmapDay: Equatable {
    let date: Date
    let intensity: Int
}

enum WidgetFocusState {
    case noHabits
    case allComplete(primaryHabit: WidgetHabit, completedCount: Int)
    case needsAttention(WidgetHabit)
}

struct WidgetConsistencySnapshot: Equatable {
    let days: [WidgetHeatmapDay]
    let activeDayCount: Int
    let lastActiveDayIndex: Int?

    var summaryText: String {
        "\(activeDayCount)/\(days.count) days"
    }

    var hasActivity: Bool {
        activeDayCount > 0
    }
}

func selectTopWidgetHabits(
    _ habits: [WidgetHabit],
    limit: Int = 3
) -> [WidgetHabit] {
    guard !habits.isEmpty, limit > 0 else { return [] }

    let partialGoalHabits = habits
        .filter(\.isPartiallyCompleteGoalHabit)
        .sorted { lhs, rhs in
            let lhsProgress = lhs.goalProgress
            let rhsProgress = rhs.goalProgress

            if lhsProgress != rhsProgress {
                return lhsProgress > rhsProgress
            }

            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    let pendingCompletionHabits = habits
        .filter(\.isPendingCompletionHabit)
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    let openEndedNeedsAttentionHabits = habits
        .filter(\.isOpenEndedHabitWithoutActivityToday)
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    let completedHabits = habits
        .filter(\.isAlreadyAddressedHabit)
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    return Array(
        (partialGoalHabits + pendingCompletionHabits + openEndedNeedsAttentionHabits + completedHabits)
            .prefix(limit)
    )
}

func selectFocusWidgetHabit(_ habits: [WidgetHabit]) -> WidgetHabit? {
    guard !habits.isEmpty else { return nil }

    let incompleteHabits = habits.filter { !$0.hasActivityToday }
    guard !incompleteHabits.isEmpty else { return nil }

    let streakProtectionHabits = incompleteHabits
        .filter { $0.streak > 0 }
        .sorted { lhs, rhs in
            if lhs.streak != rhs.streak {
                return lhs.streak > rhs.streak
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

    if let focusHabit = streakProtectionHabits.first {
        return focusHabit
    }

    return incompleteHabits.first
}

func resolveFocusWidgetState(_ habits: [WidgetHabit]) -> WidgetFocusState {
    guard !habits.isEmpty else { return .noHabits }

    if habits.allSatisfy(\.hasActivityToday), let primaryHabit = habits.first {
        return .allComplete(primaryHabit: primaryHabit, completedCount: habits.count)
    }

    if let focusHabit = selectFocusWidgetHabit(habits) {
        return .needsAttention(focusHabit)
    }

    if let primaryHabit = habits.first {
        return .allComplete(primaryHabit: primaryHabit, completedCount: habits.count)
    }

    return .noHabits
}

func makeWidgetConsistencySnapshot(
    from habits: [WidgetHabit],
    referenceDate: Date,
    calendar: Calendar = .current
) -> WidgetConsistencySnapshot {
    let today = calendar.startOfDay(for: referenceDate)
    let sourceDays = (0..<7).compactMap { offset -> (date: Date, total: Double)? in
        guard let date = calendar.date(byAdding: .day, value: -6 + offset, to: today) else {
            return nil
        }

        let total = habits.reduce(0.0) { partialResult, habit in
            partialResult + habit.widgetActivityValue(on: date, calendar: calendar)
        }

        return (date: date, total: max(total, 0))
    }

    let maximum = sourceDays.map(\.total).max() ?? 0
    let normalizedDays = sourceDays.map { day in
        WidgetHeatmapDay(
            date: day.date,
            intensity: normalizedConsistencyIntensity(for: day.total, maximum: maximum)
        )
    }
    let activeDayCount = normalizedDays.filter { $0.intensity > 0 }.count

    return WidgetConsistencySnapshot(
        days: normalizedDays,
        activeDayCount: activeDayCount,
        lastActiveDayIndex: normalizedDays.lastIndex(where: { $0.intensity > 0 })
    )
}

private extension WidgetHabit {
    var isPartiallyCompleteGoalHabit: Bool {
        goalType == .goal && goalProgress > 0 && goalProgress < 1
    }

    var isPendingCompletionHabit: Bool {
        switch goalType {
        case .binary:
            return !isCompleteToday
        case .goal:
            return goalProgress == 0
        case .openEnded:
            return false
        }
    }

    var isOpenEndedHabitWithoutActivityToday: Bool {
        goalType == .openEnded && !hasActivityToday
    }

    var isAlreadyAddressedHabit: Bool {
        switch goalType {
        case .binary:
            return isCompleteToday
        case .goal:
            return goalProgress >= 1
        case .openEnded:
            return hasActivityToday
        }
    }

    func widgetActivityValue(
        on date: Date,
        calendar: Calendar
    ) -> Double {
        let day = calendar.startOfDay(for: date)
        return recentActivity.first(where: {
            calendar.isDate($0.date, inSameDayAs: day)
        })?.value ?? 0
    }

}

extension WidgetHabit {
    var momentumSummary: WidgetMomentumSummary {
        let score = max(momentumScore, 0)
        let direction = momentumDirection
        return WidgetMomentumSummary(
            score: score,
            state: momentumState(for: score, direction: direction),
            direction: direction
        )
    }
}

private extension WidgetHabit {
    func momentumState(for score: Int, direction: WidgetMomentumDirection) -> WidgetMomentumState {
        switch direction {
        case .improving:
            return .building
        case .stable:
            return .steady
        case .declining:
            return .slipping
        case .unavailable:
            switch score {
            case 75...:
                return .building
            case 40...:
                return .steady
            default:
                return .slipping
            }
        }
    }

    var momentumDirection: WidgetMomentumDirection {
        let comparisonSamples = Array(recentActivity.sorted { $0.date < $1.date }.suffix(14))
        guard comparisonSamples.count >= 14 else { return .unavailable }

        let previousWeek = Array(comparisonSamples.prefix(7))
        let latestWeek = Array(comparisonSamples.suffix(7))

        let peakActivity = comparisonSamples.map { max(0, $0.value) }.max() ?? 0
        guard peakActivity > 0 else { return .stable }

        let previousAverage = normalizedAverageActivity(for: previousWeek, peakActivity: peakActivity)
        let latestAverage = normalizedAverageActivity(for: latestWeek, peakActivity: peakActivity)
        let deltaPercent = Int(((latestAverage - previousAverage) * 100).rounded())

        if deltaPercent >= 3 {
            return .improving(deltaPercent: deltaPercent)
        }

        if deltaPercent <= -3 {
            return .declining(deltaPercent: abs(deltaPercent))
        }

        return .stable
    }

    func normalizedAverageActivity(
        for samples: [WidgetActivitySample],
        peakActivity: Double
    ) -> Double {
        guard !samples.isEmpty, peakActivity > 0 else { return 0 }

        let total = samples.reduce(0.0) { partialResult, sample in
            partialResult + min(max(sample.value, 0), peakActivity)
        }

        return total / (Double(samples.count) * peakActivity)
    }
}

extension WidgetFocusState {
    var titleText: String {
        switch self {
        case .noHabits:
            return "No habits yet"
        case .allComplete:
            return "All done"
        case .needsAttention(let habit):
            return habit.name
        }
    }

    var subtitleText: String {
        switch self {
        case .noHabits:
            return "Add a habit"
        case .allComplete(_, let completedCount):
            return "\(completedCount) completed today"
        case .needsAttention(let habit):
            return habit.streak == 0 ? "Log today" : "Keep \(habit.streak)-day streak"
        }
    }
}

private func normalizedConsistencyIntensity(for total: Double, maximum: Double) -> Int {
    guard total > 0, maximum > 0 else { return 0 }
    return max(1, min(4, Int(ceil((total / maximum) * 4))))
}

enum WidgetHabitLogger {
    static let logger = Logger(subsystem: "ma.Habits", category: "WidgetHabit")

    static func log(
        context: StaticString,
        habitName: String,
        goalType: WidgetGoalType,
        progress: Double?
    ) {
        logger.debug(
            "\(context, privacy: .public) habit=\(habitName, privacy: .public) goalType=\(String(describing: goalType), privacy: .public) progress=\(String(describing: progress), privacy: .public)"
        )
    }

    static func logCompactSummary(
        habitName: String,
        goalType: WidgetGoalType,
        progress: Double?
    ) {
        let progressText = progress.map { String(format: "%.1f", $0) } ?? "nil"
        logger.debug(
            "\(habitName, privacy: .public) \(goalType.rawValue, privacy: .public) \(progressText, privacy: .public)"
        )
    }

    static func logValidationFailure(
        habitName: String,
        reason: String
    ) {
        logger.error(
            "Widget payload validation failure for \(habitName, privacy: .public): \(reason, privacy: .public)"
        )
    }

    static func logStorageFailure(
        context: StaticString,
        reason: String
    ) {
        logger.error(
            "Widget storage failure \(context, privacy: .public): \(reason, privacy: .public)"
        )
    }

    static func logWidgetWrite(count: Int) {
        logger.debug("WIDGET WRITE: \(count, privacy: .public) habits saved")
    }

    static func logWidgetRead(count: Int) {
        logger.debug("WIDGET READ: \(count, privacy: .public) habits loaded")
    }
}
