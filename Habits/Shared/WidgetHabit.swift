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
        colorHex: String?
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
