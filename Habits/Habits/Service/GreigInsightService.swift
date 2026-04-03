import Foundation

struct GreigInsight: Equatable {
    let title: String
    let body: String?
    let confidence: ConfidenceLevel
    let status: InsightStatus
}

enum ConfidenceLevel: Equatable {
    case low
    case medium
    case high
}

enum InsightStatus: Equatable {
    case ahead
    case onTrack
    case atRisk
    case neutral
}

enum GreigCopyGoalType: String {
    case open
    case frequency
    case cumulative
}

struct GreigInsightGoal {
    enum Kind {
        case open
        case frequency(target: Double)
        case cumulative(target: Double)
    }

    let kind: Kind
    let period: GoalPeriod
}

struct GreigInsightProgress {
    let currentTotal: Double
    let periodStart: Date
    let periodEnd: Date
    let now: Date
    let logs: [HabitLog]
    let unit: String
    let formatValue: (Double) -> String

    init(
        currentTotal: Double,
        periodStart: Date,
        periodEnd: Date,
        now: Date,
        logs: [HabitLog],
        unit: String = "",
        formatValue: @escaping (Double) -> String = { value in
            if value.rounded() == value {
                return String(Int(value))
            }
            return value.formatted(.number.precision(.fractionLength(1)))
        }
    ) {
        self.currentTotal = currentTotal
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.now = now
        self.logs = logs
        self.unit = unit
        self.formatValue = formatValue
    }
}

struct GreigInsightService {
    private let projectionService: GreigProjectionService

    init(
        calendar: Calendar = .current,
        projectionService: GreigProjectionService? = nil
    ) {
        self.projectionService = projectionService ?? GreigProjectionService(calendar: calendar)
    }

    func generateInsight(
        for goal: GreigInsightGoal,
        progress: GreigInsightProgress
    ) -> GreigInsight? {
        guard let projection = projectionService.projection(for: goal, progress: progress) else {
            return nil
        }

        switch goal.kind {
        case .open:
            return generateOpenInsight(
                goal: goal,
                projection: projection
            )
        case .frequency(let target):
            guard target > 0 else { return nil }
            return generateFrequencyInsight(
                goal: goal,
                target: target,
                progress: progress,
                projection: projection
            )
        case .cumulative(let target):
            guard target > 0 else { return nil }
            return generateCumulativeInsight(
                goal: goal,
                target: target,
                progress: progress,
                projection: projection
            )
        }
    }
}

private extension GreigInsightService {
    enum BehaviourState {
        case strongConsistency
        case buildingConsistency
        case inconsistent
    }

    func generateCumulativeInsight(
        goal: GreigInsightGoal,
        target: Double,
        progress: GreigInsightProgress,
        projection: GreigProjectionResult
    ) -> GreigInsight {
        let status = goalStatus(
            target: target,
            projection: projection,
            tolerance: max(target * 0.05, 1)
        )

        guard let projectedTotal = projection.projectedTotal,
              let dailyAverage = projection.dailyAverage else {
            let title = "Projection needs more data for \(goal.period.relativeLabel)"
            let body = "You've completed \(projection.behaviourCompletedDays) of the last \(projection.behaviourWindowDays) days, so there's not enough behaviour to project yet."
            return GreigInsight(
                title: title,
                body: body,
                confidence: .low,
                status: .neutral
            )
        }

        let projectedText = progress.formatValue(projectedTotal)
        let averageText = "~\(progress.formatValue(dailyAverage))/day"
        let title = cumulativeHeadline(
            projectedText: projectedText,
            periodLabel: goal.period.relativeLabel,
            confidence: projection.confidence
        )
        let body = cumulativeBody(
            confidence: projection.confidence,
            completedDays: projection.behaviourCompletedDays,
            windowDays: projection.behaviourWindowDays,
            recentStreak: projection.recentStreak,
            averageText: averageText,
            deltaFromGoal: projection.deltaFromGoal,
            target: target,
            progress: progress,
            loggedToday: projection.loggedToday
        )

        return GreigInsight(
            title: title,
            body: body,
            confidence: projection.confidence,
            status: status
        )
    }

    func generateFrequencyInsight(
        goal: GreigInsightGoal,
        target: Double,
        progress: GreigInsightProgress,
        projection: GreigProjectionResult
    ) -> GreigInsight {
        let status = goalStatus(
            target: target,
            projection: projection,
            tolerance: 1
        )

        guard let projectedTotal = projection.projectedTotal,
              let dailyAverage = projection.dailyAverage else {
            let title = "Projection needs more data for \(goal.period.relativeLabel)"
            let body = "You've completed \(projection.behaviourCompletedDays) of the last \(projection.behaviourWindowDays) days, so there's not enough behaviour to project yet."
            return GreigInsight(
                title: title,
                body: body,
                confidence: .low,
                status: .neutral
            )
        }

        let projectedText = formattedCount(projectedTotal)
        let averageText = "~\(formattedRate(dailyAverage))/day"
        let title = frequencyHeadline(
            projectedText: projectedText,
            periodLabel: goal.period.relativeLabel,
            confidence: projection.confidence
        )
        let body = frequencyBody(
            confidence: projection.confidence,
            completedDays: projection.behaviourCompletedDays,
            windowDays: projection.behaviourWindowDays,
            recentStreak: projection.recentStreak,
            averageText: averageText,
            deltaFromGoal: projection.deltaFromGoal,
            target: target,
            loggedToday: projection.loggedToday
        )

        return GreigInsight(
            title: title,
            body: body,
            confidence: projection.confidence,
            status: status
        )
    }

    func generateOpenInsight(
        goal _: GreigInsightGoal,
        projection: GreigProjectionResult
    ) -> GreigInsight {
        let state = behaviourState(for: projection.behaviourCompletionRate)
        let status = status(for: state)
        let confidence = confidence(for: state)
        let streak = max(projection.currentStreak, projection.recentStreak)

        let title: String = {
            switch state {
            case .strongConsistency:
                return "You've been consistent recently"
            case .buildingConsistency:
                return "You're building a solid routine"
            case .inconsistent:
                return "Let's get started"
            }
        }()

        let evidence: String = {
            switch state {
            case .strongConsistency:
                return "You've completed \(projection.behaviourCompletedDays) of the last \(projection.behaviourWindowDays) days, including a \(max(streak, 1))-day streak."
            case .buildingConsistency:
                if streak > 1 {
                    return "You've completed \(projection.behaviourCompletedDays) of the last \(projection.behaviourWindowDays) days, including a \(streak)-day streak."
                }
                return "You've completed \(projection.behaviourCompletedDays) of the last \(projection.behaviourWindowDays) days."
            case .inconsistent:
                if projection.loggedToday {
                    return "Keep showing up to build consistency."
                }
                return "A quick check-in today will help build consistency."
            }
        }()
        let body = joinedSentences(
            evidence,
            openConsistencyNudge(
                state: state,
                loggedToday: projection.loggedToday
            )
        )

        return GreigInsight(
            title: title,
            body: body,
            confidence: confidence,
            status: status
        )
    }

    func behaviourState(for completionRate: Double) -> BehaviourState {
        if completionRate >= 0.7 {
            return .strongConsistency
        }
        if completionRate >= 0.4 {
            return .buildingConsistency
        }
        return .inconsistent
    }

    func status(for state: BehaviourState) -> InsightStatus {
        switch state {
        case .strongConsistency:
            return .ahead
        case .buildingConsistency:
            return .onTrack
        case .inconsistent:
            return .atRisk
        }
    }

    func confidence(for state: BehaviourState) -> ConfidenceLevel {
        switch state {
        case .strongConsistency:
            return .high
        case .buildingConsistency:
            return .medium
        case .inconsistent:
            return .low
        }
    }

    func goalStatus(
        target: Double,
        projection: GreigProjectionResult,
        tolerance: Double
    ) -> InsightStatus {
        guard projection.confidence != .low,
              let delta = projection.deltaFromGoal else {
            return .neutral
        }

        if delta > tolerance {
            return .ahead
        }
        if delta < -tolerance {
            return .atRisk
        }
        return .onTrack
    }

    func cumulativeHeadline(
        projectedText: String,
        periodLabel: String,
        confidence: ConfidenceLevel
    ) -> String {
        switch confidence {
        case .low:
            return "You could reach around \(projectedText) \(periodLabel)"
        case .medium:
            return "You're on track for about \(projectedText) \(periodLabel)"
        case .high:
            return "You're on track for \(projectedText) \(periodLabel)"
        }
    }

    func frequencyHeadline(
        projectedText: String,
        periodLabel: String,
        confidence: ConfidenceLevel
    ) -> String {
        switch confidence {
        case .low:
            return "You could reach around \(projectedText) sessions \(periodLabel)"
        case .medium:
            return "You're on track for about \(projectedText) sessions \(periodLabel)"
        case .high:
            return "You're on track for \(projectedText) sessions \(periodLabel)"
        }
    }

    func cumulativeBody(
        confidence: ConfidenceLevel,
        completedDays: Int,
        windowDays: Int,
        recentStreak: Int,
        averageText: String,
        deltaFromGoal: Double?,
        target: Double,
        progress: GreigInsightProgress,
        loggedToday: Bool
    ) -> String {
        let goalLine = cumulativeGoalLine(
            deltaFromGoal: deltaFromGoal,
            target: target,
            progress: progress,
            confident: confidence == .high
        )
        let evidence: String
        let streak = max(recentStreak, 1)

        switch confidence {
        case .low:
            evidence = "Based on your recent activity (\(averageText) across \(completedDays) of the last \(windowDays) days), this is an early estimate."
        case .medium:
            evidence = "You've completed \(completedDays) of the last \(windowDays) days (\(averageText)), \(goalLine)."
        case .high:
            evidence = "You've completed \(completedDays) of the last \(windowDays) days, including a \(streak)-day streak (\(averageText)), \(goalLine)."
        }

        return joinedSentences(
            evidence,
            genericNudge(loggedToday: loggedToday)
        ) ?? evidence
    }

    func cumulativeGoalLine(
        deltaFromGoal: Double?,
        target: Double,
        progress: GreigInsightProgress,
        confident: Bool
    ) -> String {
        guard let deltaFromGoal else {
            return "keeping you aligned with your goal"
        }

        let tolerance = max(target * 0.05, 1)
        if abs(deltaFromGoal) <= tolerance {
            return "keeping you aligned with your goal"
        }

        let deltaText = progress.formatValue(abs(deltaFromGoal))
        if deltaFromGoal > 0 {
            return confident
                ? "already \(deltaText) ahead of your goal"
                : "putting you \(deltaText) ahead of your goal"
        }

        return confident
            ? "still \(deltaText) behind your goal"
            : "putting you \(deltaText) behind your goal"
    }

    func frequencyBody(
        confidence: ConfidenceLevel,
        completedDays: Int,
        windowDays: Int,
        recentStreak: Int,
        averageText: String,
        deltaFromGoal: Double?,
        target: Double,
        loggedToday: Bool
    ) -> String {
        let goalLine = frequencyGoalLine(
            deltaFromGoal: deltaFromGoal,
            target: target,
            confident: confidence == .high
        )
        let evidence: String
        let streak = max(recentStreak, 1)

        switch confidence {
        case .low:
            evidence = "Based on your recent activity (\(averageText) across \(completedDays) of the last \(windowDays) days), this is an early estimate."
        case .medium:
            evidence = "You've completed \(completedDays) of the last \(windowDays) days (\(averageText)), \(goalLine)."
        case .high:
            evidence = "You've completed \(completedDays) of the last \(windowDays) days, including a \(streak)-day streak (\(averageText)), \(goalLine)."
        }

        return joinedSentences(
            evidence,
            genericNudge(loggedToday: loggedToday)
        ) ?? evidence
    }

    func frequencyGoalLine(
        deltaFromGoal: Double?,
        target: Double,
        confident: Bool
    ) -> String {
        guard let deltaFromGoal else {
            return "keeping you aligned with your goal"
        }

        let tolerance = 1.0
        if abs(deltaFromGoal) <= tolerance {
            return "keeping you aligned with your goal"
        }

        let deltaText = formattedCount(abs(deltaFromGoal))
        if deltaFromGoal > 0 {
            return confident
                ? "already \(deltaText) sessions ahead of your goal"
                : "putting you \(deltaText) sessions ahead of your goal"
        }

        return confident
            ? "still \(deltaText) sessions behind your goal"
            : "putting you \(deltaText) sessions behind your goal"
    }

    func formattedCount(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    func formattedRate(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    func genericNudge(loggedToday: Bool) -> String? {
        guard !loggedToday else { return nil }
        return "Log today to keep this routine steady."
    }

    func openConsistencyNudge(
        state: BehaviourState,
        loggedToday: Bool
    ) -> String? {
        guard !loggedToday else { return nil }
        switch state {
        case .strongConsistency:
            return "Log today to keep this routine steady."
        case .buildingConsistency:
            return "Log today to reinforce this routine."
        case .inconsistent:
            return nil
        }
    }

    func joinedSentences(
        _ first: String?,
        _ second: String?
    ) -> String? {
        let parts = [first, second].compactMap { value -> String? in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }
}
