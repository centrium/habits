import Foundation

struct GoalProgress {
    let actual: Int
    let goal: Int

    /// Progress shown in UI (clamped to goal)
    var clamped: Int {
        min(actual, goal)
    }

    /// Surplus beyond goal
    var extra: Int {
        max(actual - goal, 0)
    }

    /// Fraction used by progress rings
    var fraction: Double {
        guard goal > 0 else { return 0 }
        return Double(clamped) / Double(goal)
    }

    /// True when the goal has been reached
    var isComplete: Bool {
        actual >= goal
    }
}
