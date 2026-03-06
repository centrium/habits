import Foundation

enum InsightType {
    case streak
    case pace
    case activity
    case pattern
}

struct HabitInsight {
    let priority: Int
    let message: String
    let type: InsightType
}

enum InsightGenerator {
    static func generate(
        metrics: HabitMetricsSnapshot,
        behaviour: HabitBehaviourSnapshot
    ) -> [HabitInsight] {
        var candidates: [HabitInsight] = []

        if metrics.currentStreak > 0 {
            candidates.append(
                HabitInsight(
                    priority: 100,
                    message: "You're on a \(metrics.currentStreak) \(metrics.currentStreak == 1 ? "period" : "periods") streak.",
                    type: .streak
                )
            )
        }

        if let paceStatus = behaviour.paceStatus {
            let message: String
            switch paceStatus {
            case .completed:
                message = "You're ahead of pace this period."
            case .likelyToHitTarget:
                message = "You're on track to hit your goal."
            case .likelyShort:
                message = "You may fall short of your target."
            case .paceOnly:
                message = "Your pace trend is stabilizing."
            }
            candidates.append(
                HabitInsight(
                    priority: 80,
                    message: message,
                    type: .pace
                )
            )
        }

        if let summary = behaviour.activitySummary?.summaryText {
            candidates.append(
                HabitInsight(
                    priority: 60,
                    message: summary,
                    type: .activity
                )
            )
        }

        if let strongest = behaviour.strongestWeekday {
            candidates.append(
                HabitInsight(
                    priority: 40,
                    message: "Your strongest day is \(strongest).",
                    type: .pattern
                )
            )
        }

        return candidates.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.message < rhs.message
            }
            return lhs.priority > rhs.priority
        }
    }
}
