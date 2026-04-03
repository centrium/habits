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
            let state = HabitIdentityStateResolver.state(
                from: nil,
                hasRecentData: false
            )
            return HabitIdentityOutput(
                identityLine: rawIdentity,
                behaviourLine: "You’ve shown up 0 of the last 7 days",
                emotionalLine: HabitIdentityStateFormatter.detailLine(state)
            )
        }

        let state = HabitIdentityStateResolver.state(
            from: completionRate,
            hasRecentData: recentCompletions > 0
        )
        let behaviourLine = "You’ve shown up \(recentCompletions) of the last \(window) days"

        return HabitIdentityOutput(
            identityLine: rawIdentity,
            behaviourLine: behaviourLine,
            emotionalLine: HabitIdentityStateFormatter.detailLine(state)
        )
    }
}
