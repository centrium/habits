import Foundation

struct PaceInsight {
    let status: HabitInsightsPaceStatus
    let projectedTotal: Double
    let message: String
}

enum PaceCalculator {
    static func calculate(
        mode: HabitInsightMode,
        cadence: GoalPeriod,
        periodStart: Date,
        periodEnd: Date,
        progressSoFar: Double,
        now: Date
    ) -> PaceInsight? {
        let target: Double? = {
            switch mode {
            case .openEnded:
                return nil
            case .frequency(let target, _):
                return target
            case .cumulative(let target, _):
                return target
            }
        }()

        guard let target else { return nil }

        let elapsed = max(now.timeIntervalSince(periodStart), 0)
        let periodLength = max(periodEnd.timeIntervalSince(periodStart), 1)
        let projectedTotal: Double = {
            guard elapsed > 0 else { return progressSoFar }
            return (progressSoFar / elapsed) * periodLength
        }()

        if progressSoFar >= target {
            return PaceInsight(
                status: .completed,
                projectedTotal: projectedTotal,
                message: "You hit your goal this \(cadence.unit)."
            )
        }

        if projectedTotal >= target {
            return PaceInsight(
                status: .likelyToHitTarget,
                projectedTotal: projectedTotal,
                message: "At this pace you'll exceed your goal."
            )
        }

        return PaceInsight(
            status: .likelyShort,
            projectedTotal: projectedTotal,
            message: "You may fall short of your target."
        )
    }
}
