import Foundation

enum DetailGoalCopyFormatter {
    static func summaryText(
        currentText: String,
        targetText: String,
        goalPeriod: GoalPeriod
    ) -> String {
        "\(currentText) of \(targetText) \(goalPeriod.relativeLabel)"
    }

    static func remainingFrequencyText(
        baseSummary: String,
        remainingCount: Int,
        goalPeriod: GoalPeriod
    ) -> String {
        "\(baseSummary) • \(max(0, remainingCount)) more to hit \(goalPeriod.relativeLabel)"
    }

    static func remainingCumulativeText(
        baseSummary: String,
        remainingText: String
    ) -> String {
        "\(baseSummary) • \(remainingText) to go"
    }
}
