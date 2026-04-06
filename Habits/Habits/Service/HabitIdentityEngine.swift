import Foundation

struct HabitIdentityOutput {
    let identityLine: String
    let behaviourLine: String
    let emotionalLine: String?
}

struct HabitIdentityMetrics {
    let completionRate: Double?
    let recentCompletions: Int?
    let window: Int?

    static func from(snapshot: HabitIdentityStateSnapshot) -> HabitIdentityMetrics {
        HabitIdentityMetrics(
            completionRate: snapshot.completionRate,
            recentCompletions: snapshot.activeDays,
            window: snapshot.windowDays
        )
    }
}

struct HabitIdentityEngine {
    static func build(
        habit: Habit,
        metrics: HabitIdentityMetrics
    ) -> HabitIdentityOutput? {
        build(
            identity: habit.identity,
            metrics: metrics
        )
    }

    static func build(
        identity: String?,
        metrics: HabitIdentityMetrics
    ) -> HabitIdentityOutput? {
        guard let rawIdentity = identity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawIdentity.isEmpty else {
            return nil
        }

        return HabitIdentityOutput(
            identityLine: rawIdentity,
            behaviourLine: CadenceLanguage.behaviourLine(
                completions: metrics.recentCompletions,
                window: metrics.window
            ),
            emotionalLine: nil
        )
    }

    @available(*, deprecated, message: "Use build(habit:metrics:) or build(identity:metrics:)")
    static func narrative(
        identity: String?,
        completionRate: Double?,
        recentCompletions: Int?,
        window: Int?
    ) -> HabitIdentityOutput? {
        build(
            identity: identity,
            metrics: HabitIdentityMetrics(
                completionRate: completionRate,
                recentCompletions: recentCompletions,
                window: window
            )
        )
    }
}
