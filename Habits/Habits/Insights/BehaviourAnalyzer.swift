import Foundation

struct HabitBehaviourSnapshot {
    let paceStatus: HabitInsightsPaceStatus?
    let projectedTotal: Double?
    let strongestWeekday: String?
    let weakestWeekday: String?
    let commonLogWindow: String?
    let activitySummary: ActivitySummaryInsight?
    let momentumMessage: String
    let patternItems: [String]
    let retentionItems: [String]
}

enum BehaviourAnalyzer {
    static func analyze(
        metrics: HabitMetricsSnapshot,
        foundation: HabitInsightSnapshot
    ) -> HabitBehaviourSnapshot {
        _ = metrics
        let paceStatus = foundation.pace?.status
        let projectedTotal = foundation.pace?.projectedTotal
        let activitySummary = foundation.activitySummary
        let patternSignals = foundation.patternSignals

        let momentumMessage: String = {
            if let paceMessage = foundation.pace?.message {
                return paceMessage
            }
            if let summary = activitySummary?.summaryText {
                return summary
            }
            return "In progress."
        }()

        return HabitBehaviourSnapshot(
            paceStatus: paceStatus,
            projectedTotal: projectedTotal,
            strongestWeekday: patternSignals?.strongestWeekday,
            weakestWeekday: patternSignals?.weakestWeekday,
            commonLogWindow: patternSignals?.commonLogWindow,
            activitySummary: activitySummary,
            momentumMessage: momentumMessage,
            patternItems: patternSignals?.patternItems ?? [],
            retentionItems: patternSignals?.retentionItems ?? []
        )
    }
}
