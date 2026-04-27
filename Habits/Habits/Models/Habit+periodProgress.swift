import Foundation

enum GoalProgressState: Equatable {
    case onTrack
    case atRisk
    case offTrack
}

protocol PeriodTrackable {
    var required: Double { get }
    var completed: Double { get }
}

struct FrequencyTrackable: PeriodTrackable {
    let required: Double
    let completed: Double
}

struct CumulativeTrackable: PeriodTrackable {
    let required: Double
    let completed: Double
}

struct PeriodProgress: Equatable {
    let completed: Double
    let required: Double
    let remaining: Double
    let expectedByNow: Double
    let state: GoalProgressState
}

func computeProgress(
    trackable: PeriodTrackable,
    periodStart: Date,
    periodEnd: Date,
    now: Date
) -> PeriodProgress {
    let elapsed = now.timeIntervalSince(periodStart)
    let total = periodEnd.timeIntervalSince(periodStart)
    let elapsedRatio = total > 0 ? max(0, min(1, elapsed / total)) : 1
    let expectedByNow = trackable.required * elapsedRatio

    let state: GoalProgressState
    if trackable.completed >= trackable.required {
        state = .onTrack
    } else if trackable.completed >= expectedByNow * 0.8 {
        state = .onTrack
    } else if expectedByNow < 1 {
        // Avoid classifying a fresh period as off-track before meaningful expected progress accrues.
        state = .atRisk
    } else if trackable.completed >= expectedByNow * 0.4 {
        state = .atRisk
    } else {
        state = .offTrack
    }

    return PeriodProgress(
        completed: trackable.completed,
        required: trackable.required,
        remaining: max(0, trackable.required - trackable.completed),
        expectedByNow: expectedByNow,
        state: state
    )
}

extension Habit {
    func periodProgress(
        now: Date = .now,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system
    ) -> PeriodProgress? {
        guard hasStreakGoal else { return nil }

        let interval = periodRange(for: now, calendar: calendar, weekStartPreference: weekStartPreference)

        let trackable: PeriodTrackable
        switch goalType {
        case .frequency:
            let required = Double(max(1, streakTarget))
            let completed = Double(max(0, totalCount(in: interval)))
            trackable = FrequencyTrackable(required: required, completed: completed)
        case .cumulative:
            guard let required = targetValue, required > 0 else { return nil }
            let completed = max(0, totalValue(in: interval))
            trackable = CumulativeTrackable(required: required, completed: completed)
        }

        guard trackable.required > 0 else { return nil }

        return computeProgress(
            trackable: trackable,
            periodStart: interval.start,
            periodEnd: interval.end,
            now: now
        )
    }
}
