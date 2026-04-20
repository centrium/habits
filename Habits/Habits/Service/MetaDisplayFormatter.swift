import Foundation

enum HabitDisplayState {
    case start
    case build
    case strong
}

struct MetaLine: Equatable {
    let text: String
}

enum MetaDisplayFormatter {
    static func format(
        habit: Habit,
        streakState: StreakState,
        weeklyActiveDays: Int,
        isGoalMet: Bool
    ) -> [MetaLine] {
        let streak = max(0, streakState.currentStreak)
        let activeDays = max(0, weeklyActiveDays)
        let state = displayState(
            streak: streak,
            weeklyActiveDays: activeDays,
            isGoalMet: isGoalMet,
            goalType: habit.goalType
        )

        switch state {
        case .strong:
            return [MetaLine(text: "\(streak) days strong")]
        case .build:
            let streakText = streakLabel(streak)
            let behaviourText = BehaviourCopyFormatter.weeklySummary(days: activeDays)
            guard activeDays > 0 else {
                return [MetaLine(text: streakText)]
            }
            return [MetaLine(text: "\(streakText) • \(behaviourText)")]
        case .start:
            if streak == 0 {
                return [
                    MetaLine(text: BehaviourCopyFormatter.weeklySummary(days: activeDays))
                ]
            }
            return [
                MetaLine(text: streakLabel(streak)),
                MetaLine(text: BehaviourCopyFormatter.weeklySummary(days: activeDays))
            ]
        }
    }

    static func displayState(
        streak: Int,
        weeklyActiveDays: Int,
        isGoalMet: Bool,
        goalType: GoalType
    ) -> HabitDisplayState {
        let hasHighConsistency = weeklyActiveDays >= 5 || isGoalMet
        let hasModerateConsistency = weeklyActiveDays >= 3
        _ = goalType

        if streak >= 7 && hasHighConsistency {
            return .strong
        }

        if streak <= 1 || weeklyActiveDays <= 1 {
            return .start
        }

        if (2...6).contains(streak) || hasModerateConsistency {
            return .build
        }

        return .start
    }

    private static func streakLabel(_ streak: Int) -> String {
        "\(streak) day streak"
    }
}
