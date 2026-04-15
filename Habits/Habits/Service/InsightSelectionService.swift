import Foundation

enum CoachingInsightType: String, CaseIterable {
    case streakOpportunity
    case timingPattern
    case riskState
    case strongestDay
    case momentumState
    case consistency
    case fallback
}

struct TodayCoachingInsight: Equatable {
    let type: CoachingInsightType
    let message: String
    let primaryHighlight: String?
    let secondaryHighlight: String?
}

@MainActor
final class InsightSelectionService {
    static let shared = InsightSelectionService()

    private enum Keys {
        static let currentDay = "today.coachingInsight.currentDay"
        static let currentType = "today.coachingInsight.currentType"
        static let lastType = "today.coachingInsight.lastType"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func selectInsight(
        from snapshot: GlobalInsightsSnapshot,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TodayCoachingInsight {
        let candidates = buildCandidates(from: snapshot)
        guard !candidates.isEmpty else {
            return fallbackInsight()
        }

        let dayKey = Self.dayKey(for: now, calendar: calendar)
        if defaults.string(forKey: Keys.currentDay) == dayKey,
           let storedTypeRaw = defaults.string(forKey: Keys.currentType),
           let storedType = CoachingInsightType(rawValue: storedTypeRaw),
           let existing = candidates.first(where: { $0.type == storedType })?.insight {
            return existing
        }

        let previousType = defaults.string(forKey: Keys.currentType)
            .flatMap(CoachingInsightType.init(rawValue:))
            ?? defaults.string(forKey: Keys.lastType).flatMap(CoachingInsightType.init(rawValue:))

        let selected = selectCandidate(
            from: candidates,
            previousType: previousType,
            daySeed: Self.daySeed(for: now, calendar: calendar)
        )

        if let currentTypeRaw = defaults.string(forKey: Keys.currentType) {
            defaults.set(currentTypeRaw, forKey: Keys.lastType)
        }
        defaults.set(dayKey, forKey: Keys.currentDay)
        defaults.set(selected.type.rawValue, forKey: Keys.currentType)

        return selected.insight
    }
}

private extension InsightSelectionService {
    struct Candidate {
        let insight: TodayCoachingInsight
        let priority: Int

        var type: CoachingInsightType { insight.type }
    }

    func buildCandidates(from snapshot: GlobalInsightsSnapshot) -> [Candidate] {
        var candidates: [Candidate] = []

        let peakTime = snapshot.introSummary.typicalLoggingTime
        let stateTitle = CadenceLanguage.stateTitle(snapshot.hero.dominantState).lowercased()
        let bestDay = snapshot.metrics.bestDayOfWeek
        let streak = snapshot.metrics.bestCurrentStreak
        let consistency = snapshot.hero.consistency
        let atRiskCount = snapshot.metrics.atRiskCount
        let consistencyText = meaningfulConsistencyText(consistency)

        if streak >= 2 {
            candidates.append(
                Candidate(
                    insight: TodayCoachingInsight(
                        type: .streakOpportunity,
                        message: "Your routines have a \(streak)-day streak behind them, and checking in at \(peakTime) helps keep it going.",
                        primaryHighlight: "\(streak)-day streak",
                        secondaryHighlight: nil
                    ),
                    priority: 0
                )
            )
        }

        let timingMessage: String
        if let consistencyText {
            timingMessage = "You tend to log habits most at \(peakTime), and your consistency (\(consistencyText)) is strongest when you check in then."
        } else {
            timingMessage = "You tend to log habits most at \(peakTime), and showing up then helps maintain your rhythm."
        }
        candidates.append(
            Candidate(
                insight: TodayCoachingInsight(
                    type: .timingPattern,
                    message: timingMessage,
                    primaryHighlight: peakTime,
                    secondaryHighlight: consistencyText
                ),
                priority: 0
            )
        )

        if atRiskCount > 0 {
            let countText = atRiskCount == 1 ? "1 habit" : "\(atRiskCount) habits"
            candidates.append(
                Candidate(
                    insight: TodayCoachingInsight(
                        type: .riskState,
                        message: "\(countText) look easier to miss right now, and a check-in at \(peakTime) helps steady the routine.",
                        primaryHighlight: countText,
                        secondaryHighlight: nil
                    ),
                    priority: 0
                )
            )
        }

        if !bestDay.isEmpty {
            candidates.append(
                Candidate(
                    insight: TodayCoachingInsight(
                        type: .strongestDay,
                        message: "\(bestDay) tends to be your strongest day, and keeping today's rhythm close to that standard helps the week stay on track.",
                        primaryHighlight: bestDay,
                        secondaryHighlight: nil
                    ),
                    priority: 1
                )
            )
        }

        let momentumMessage: String
        if let consistencyText {
            momentumMessage = "Your habits are \(stateTitle), and your consistency (\(consistencyText)) is strongest when you check in at \(peakTime)."
        } else {
            momentumMessage = "Your habits are \(stateTitle), and checking in at \(peakTime) helps keep that going."
        }
        if !stateTitle.isEmpty {
            candidates.append(
                Candidate(
                    insight: TodayCoachingInsight(
                        type: .momentumState,
                        message: momentumMessage,
                        primaryHighlight: stateTitle,
                        secondaryHighlight: consistencyText
                    ),
                    priority: 2
                )
            )
        }

        if consistency > 0 {
            candidates.append(
                Candidate(
                    insight: TodayCoachingInsight(
                        type: .consistency,
                        message: "Your overall consistency is \(consistency)%, and a quick check-in at \(peakTime) helps maintain it.",
                        primaryHighlight: "\(consistency)%",
                        secondaryHighlight: nil
                    ),
                    priority: 2
                )
            )
        }

        candidates.append(
            Candidate(
                insight: fallbackInsight(),
                priority: 3
            )
        )

        return candidates
    }

    func selectCandidate(
        from candidates: [Candidate],
        previousType: CoachingInsightType?,
        daySeed: Int
    ) -> Candidate {
        let grouped = Dictionary(grouping: candidates, by: \.priority)
        let priorities = grouped.keys.sorted()

        for priority in priorities {
            guard let group = grouped[priority], !group.isEmpty else { continue }
            let ordered = rotated(group, offset: daySeed % group.count)

            if let preferred = ordered.first(where: { $0.type != previousType }) {
                return preferred
            }
        }

        return candidates.first ?? Candidate(insight: fallbackInsight(), priority: 3)
    }

    func rotated(_ values: [Candidate], offset: Int) -> [Candidate] {
        guard !values.isEmpty else { return values }
        let safeOffset = max(0, offset % values.count)
        return Array(values[safeOffset...]) + Array(values[..<safeOffset])
    }

    func fallbackInsight() -> TodayCoachingInsight {
        TodayCoachingInsight(
            type: .fallback,
            message: "You're building a steady rhythm, and a quick check-in keeps things moving.",
            primaryHighlight: "steady rhythm",
            secondaryHighlight: nil
        )
    }

    func meaningfulConsistencyText(_ consistency: Int) -> String? {
        guard consistency >= 15, consistency <= 95 else { return nil }
        return "\(consistency)%"
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    static func daySeed(for date: Date, calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }
}
