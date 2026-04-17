import Foundation

enum TodayInsightType {
    case strongestWindow
    case nearPeakWindow
    case dipRisk
    case reinforcement
    case fallback
}

struct TodayInsight {
    let habit: Habit
    let type: TodayInsightType
    let message: String
}

struct TodayInsightCandidate {
    let habit: Habit
    let rhythm: HabitRhythm?
    let isCompletedToday: Bool
    let lastCompletedDate: Date?
    let streak: Int
}

@MainActor
final class TodayInsightSelectionService {
    static let shared = TodayInsightSelectionService()

    private struct SelectionState {
        let habitID: UUID
        let score: Double
        let hour: Int
    }

    private struct ScoredCandidate {
        let candidate: TodayInsightCandidate
        let score: Double
        let consistency: Double
        let streak: Int
    }

    private let switchThreshold: Double = 0.15
    private let recentCompletionWindow: TimeInterval = 2 * 60 * 60
    private var previousSelection: SelectionState?

    private init() {}

    func reset() {
        previousSelection = nil
    }

    func selectInsight(
        from candidates: [TodayInsightCandidate],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayInsight? {
        guard !candidates.isEmpty else {
            previousSelection = nil
            return nil
        }

        let currentHour = calendar.component(.hour, from: now)
        let allCompleted = candidates.allSatisfy(\.isCompletedToday)

        if allCompleted {
            let selected = selectForAllCompleted(candidates)
            let message = "All set for today. \(selected.candidate.habit.name) has strong consistency."
            previousSelection = SelectionState(habitID: selected.candidate.habit.id, score: selected.score, hour: currentHour)
            return TodayInsight(habit: selected.candidate.habit, type: .reinforcement, message: message)
        }

        let scored = candidates.map { candidate in
            score(candidate: candidate, currentHour: currentHour, now: now)
        }

        let best = scored.max(by: compareScored)
        let fallback = fallbackCandidate(from: candidates)

        guard let bestCandidate = best ?? fallback else { return nil }

        let resolved = resolveStability(
            best: bestCandidate,
            allScored: scored,
            currentHour: currentHour
        )

        previousSelection = SelectionState(
            habitID: resolved.candidate.habit.id,
            score: resolved.score,
            hour: currentHour
        )

        let message = message(
            for: resolved.candidate,
            currentHour: currentHour
        )

        return TodayInsight(
            habit: resolved.candidate.habit,
            type: insightType(for: resolved.candidate, currentHour: currentHour),
            message: message
        )
    }

    private func selectForAllCompleted(_ candidates: [TodayInsightCandidate]) -> ScoredCandidate {
        let scored = candidates.map { candidate in
            ScoredCandidate(
                candidate: candidate,
                score: candidate.rhythm?.consistencyScore ?? 0,
                consistency: candidate.rhythm?.consistencyScore ?? 0,
                streak: candidate.streak
            )
        }

        return scored.max(by: compareScored)
            ?? ScoredCandidate(candidate: candidates[0], score: 0, consistency: 0, streak: candidates[0].streak)
    }

    private func score(
        candidate: TodayInsightCandidate,
        currentHour: Int,
        now: Date
    ) -> ScoredCandidate {
        guard let rhythm = candidate.rhythm else {
            let completionScore = candidate.isCompletedToday ? 0.0 : 0.5
            let recentPenalty = recentCompletionPenalty(lastCompletedDate: candidate.lastCompletedDate, now: now)
            let total = completionScore + recentPenalty
            return ScoredCandidate(
                candidate: candidate,
                score: total,
                consistency: 0,
                streak: candidate.streak
            )
        }

        let peakDistance = abs(currentHour - rhythm.peakHour)
        let peakScore = max(0, 1 - (Double(peakDistance) / 12.0))
        let dipScore = isHour(currentHour, inRange: rhythm.dipStart...rhythm.dipEnd) ? 1.0 : 0.0
        let completionScore = candidate.isCompletedToday ? 0.0 : 0.5
        let consistencyWeight = rhythm.consistencyScore * 0.3
        let recentPenalty = recentCompletionPenalty(lastCompletedDate: candidate.lastCompletedDate, now: now)

        let totalScore =
            (peakScore * 0.5) +
            (dipScore * 0.3) +
            completionScore +
            consistencyWeight +
            recentPenalty

        return ScoredCandidate(
            candidate: candidate,
            score: totalScore,
            consistency: rhythm.consistencyScore,
            streak: candidate.streak
        )
    }

    private func recentCompletionPenalty(lastCompletedDate: Date?, now: Date) -> Double {
        guard let lastCompletedDate else { return 0 }
        return now.timeIntervalSince(lastCompletedDate) <= recentCompletionWindow ? -0.5 : 0
    }

    private func resolveStability(
        best: ScoredCandidate,
        allScored: [ScoredCandidate],
        currentHour: Int
    ) -> ScoredCandidate {
        guard let previousSelection,
              previousSelection.hour == currentHour,
              best.candidate.habit.id != previousSelection.habitID,
              let previousCandidate = allScored.first(where: { $0.candidate.habit.id == previousSelection.habitID }) else {
            return best
        }

        if best.score < previousCandidate.score + switchThreshold {
            return previousCandidate
        }

        return best
    }

    private func fallbackCandidate(from candidates: [TodayInsightCandidate]) -> ScoredCandidate? {
        let recent = candidates.max { lhs, rhs in
            let lhsDate = lhs.lastCompletedDate ?? .distantPast
            let rhsDate = rhs.lastCompletedDate ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.habit.orderIndex > rhs.habit.orderIndex
            }
            return lhsDate < rhsDate
        }

        guard let recent else { return nil }
        return ScoredCandidate(candidate: recent, score: 0, consistency: 0, streak: recent.streak)
    }

    private func compareScored(_ lhs: ScoredCandidate, _ rhs: ScoredCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        if lhs.consistency != rhs.consistency {
            return lhs.consistency < rhs.consistency
        }
        if lhs.streak != rhs.streak {
            return lhs.streak < rhs.streak
        }
        return lhs.candidate.habit.orderIndex > rhs.candidate.habit.orderIndex
    }

    private func insightType(for candidate: TodayInsightCandidate, currentHour: Int) -> TodayInsightType {
        guard let rhythm = candidate.rhythm else { return .fallback }
        if isHour(currentHour, inRange: rhythm.dipStart...rhythm.dipEnd) {
            return .dipRisk
        }
        if abs(currentHour - rhythm.peakHour) <= 1 {
            return .nearPeakWindow
        }
        return .strongestWindow
    }

    private func message(for candidate: TodayInsightCandidate, currentHour: Int) -> String {
        guard let rhythm = candidate.rhythm else {
            return "Keep momentum going with \(candidate.habit.name)"
        }

        let isLowConfidence = rhythm.confidence < 0.5

        if isHour(currentHour, inRange: rhythm.dipStart...rhythm.dipEnd) {
            return "Momentum tends to drop for \(candidate.habit.name) around \(humanTime(for: rhythm.dipStart))–\(humanTime(for: rhythm.dipEnd))"
        }

        if isLowConfidence {
            return "Usually \(softWindowPhrase(for: rhythm.peakHour)) for \(candidate.habit.name)"
        }

        if abs(currentHour - rhythm.peakHour) <= 1 {
            return "You're near your peak window for \(candidate.habit.name)"
        }

        if currentHour <= rhythm.peakHour {
            return "Strongest window for \(candidate.habit.name): \(humanTime(for: rhythm.peakHour))"
        }

        return "Strongest window tomorrow for \(candidate.habit.name): \(humanTime(for: rhythm.peakHour))"
    }

    private func isHour(_ hour: Int, inRange range: ClosedRange<Int>) -> Bool {
        if range.lowerBound <= range.upperBound {
            return range.contains(hour)
        }
        return hour >= range.lowerBound || hour <= range.upperBound
    }

    private func softWindowPhrase(for hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        switch normalized {
        case 0..<5:
            return "later at night"
        case 5..<11:
            return "earlier in the morning"
        case 11..<15:
            return "around midday"
        case 15..<18:
            return "later in the afternoon"
        case 18..<22:
            return "later in the evening"
        default:
            return "at night"
        }
    }
}
