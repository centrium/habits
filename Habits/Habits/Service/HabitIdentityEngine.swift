import Foundation

struct HabitIdentityOutput {
    let identityLine: String
    let behaviourLine: String
    let emotionalLine: String?
}

struct HabitIdentityEngine {
    static func narrative(
        identity: String?,
        completionRate: Double?,
        recentCompletions: Int?,
        window: Int?
    ) -> HabitIdentityOutput? {
        guard let rawIdentity = identity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawIdentity.isEmpty else {
            return nil
        }

        guard let completionRate,
              let recentCompletions,
              let window,
              window > 0 else {
            return HabitIdentityOutput(
                identityLine: rawIdentity,
                behaviourLine: "This is where the habit begins to take shape",
                emotionalLine: nil
            )
        }

        let behaviourLine = "You’ve shown up \(recentCompletions) of the last \(window) days"

        if completionRate >= 0.7 {
            return HabitIdentityOutput(
                identityLine: rawIdentity,
                behaviourLine: behaviourLine,
                emotionalLine: "This is becoming part of who you are"
            )
        }

        if completionRate >= 0.4 {
            return HabitIdentityOutput(
                identityLine: rawIdentity,
                behaviourLine: behaviourLine,
                emotionalLine: "You’re building this identity — keep going"
            )
        }

        return HabitIdentityOutput(
            identityLine: rawIdentity,
            behaviourLine: behaviourLine,
            emotionalLine: "This habit supports the person you want to be"
        )
    }
}
