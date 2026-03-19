import Foundation

struct GreigCopy {
    let title: String
    let body: String?
}

struct GreigContext {
    let projectedValue: Double?
    let nudgedProjection: Double?
    let deltaFromTarget: Double?
    let suggestedIncrement: Double?
    let requiredRate: Double?
    let currentRate: Double?
    let unit: String
    let targetValue: Double?
    let currentValue: Double?
    let remainingActions: Int?
    let streakLength: Int?
    let recentCompletedDays: Int?
    let recentWindowDays: Int?
    let periodLabel: String?

    init(
        projectedValue: Double? = nil,
        nudgedProjection: Double? = nil,
        deltaFromTarget: Double? = nil,
        suggestedIncrement: Double? = nil,
        requiredRate: Double? = nil,
        currentRate: Double? = nil,
        unit: String = "",
        targetValue: Double? = nil,
        currentValue: Double? = nil,
        remainingActions: Int? = nil,
        streakLength: Int? = nil,
        recentCompletedDays: Int? = nil,
        recentWindowDays: Int? = nil,
        periodLabel: String? = nil
    ) {
        self.projectedValue = projectedValue
        self.nudgedProjection = nudgedProjection
        self.deltaFromTarget = deltaFromTarget
        self.suggestedIncrement = suggestedIncrement
        self.requiredRate = requiredRate
        self.currentRate = currentRate
        self.unit = unit
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.remainingActions = remainingActions
        self.streakLength = streakLength
        self.recentCompletedDays = recentCompletedDays
        self.recentWindowDays = recentWindowDays
        self.periodLabel = periodLabel
    }
}

enum GreigCopyGoalType: String {
    case open
    case frequency
    case cumulative
}

struct GreigCopyProvider {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func copy(
        for goalType: GreigCopyGoalType,
        status: InsightStatus,
        confidence: ConfidenceLevel,
        date: Date,
        context: GreigContext? = nil,
        fallbackBody: String? = nil
    ) -> GreigCopy {
        let scenario = scenarioFor(goalType: goalType, status: status, confidence: confidence)
        let titleVariants = titles(for: scenario)
        let bodyVariants = bodies(for: scenario)

        let titleIndex = rotatingIndex(
            salt: "title|\(scenario.rawValue)|\(goalType.rawValue)|\(status)|\(confidence)",
            dayDate: date,
            count: titleVariants.count
        )
        let bodyIndex = rotatingIndex(
            salt: "body|\(scenario.rawValue)|\(goalType.rawValue)|\(status)|\(confidence)",
            dayDate: date,
            count: max(bodyVariants.count, 1)
        )

        let title = titleVariants[titleIndex]
        let body = bodyVariants.isEmpty ? fallbackBody : bodyVariants[bodyIndex]
        let baseCopy = GreigCopy(title: title, body: body ?? fallbackBody)

        guard confidence != .low, let context else {
            return baseCopy
        }

        switch goalType {
        case .cumulative:
            return metricCopyForCumulative(
                baseCopy: baseCopy,
                status: status,
                context: context
            )
        case .frequency:
            return metricCopyForFrequency(
                baseCopy: baseCopy,
                status: status,
                context: context
            )
        case .open:
            return metricCopyForOpen(
                baseCopy: baseCopy,
                status: status,
                context: context
            )
        }
    }

    func scenarioName(
        for goalType: GreigCopyGoalType,
        status: InsightStatus,
        confidence: ConfidenceLevel
    ) -> String {
        scenarioFor(goalType: goalType, status: status, confidence: confidence).rawValue
    }
}

private extension GreigCopyProvider {
    enum Scenario: String {
        case aheadHigh
        case aheadLow
        case onTrack
        case onTrackLow
        case atRisk
        case atRiskLow
        case openConsistency
    }

    func scenarioFor(
        goalType: GreigCopyGoalType,
        status: InsightStatus,
        confidence: ConfidenceLevel
    ) -> Scenario {
        if goalType == .open {
            switch status {
            case .ahead, .onTrack:
                return .openConsistency
            case .atRisk, .neutral:
                return confidence == .low ? .atRiskLow : .atRisk
            }
        }

        switch status {
        case .ahead:
            return confidence == .low ? .aheadLow : .aheadHigh
        case .onTrack:
            return confidence == .low ? .onTrackLow : .onTrack
        case .atRisk:
            return confidence == .low ? .atRiskLow : .atRisk
        case .neutral:
            return .atRiskLow
        }
    }

    func titles(for scenario: Scenario) -> [String] {
        switch scenario {
        case .aheadHigh:
            return [
                "You're operating above your target pace",
                "You're on track to exceed your goal",
                "Your current pace puts you ahead",
                "You've moved beyond your expected rhythm",
                "You're progressing faster than required",
                "Your pace is stronger than your target demands",
                "You're trending comfortably ahead",
                "You've built momentum beyond your goal",
                "Your recent consistency is outperforming your target",
                "You're exceeding your expected trajectory",
                "You're advancing at a higher pace than planned",
                "Your behaviour is outpacing your goal",
                "You've shifted into a higher-performing rhythm",
                "You're ahead of where you need to be",
                "Your current pattern leads beyond your target",
                "You're moving faster than your goal requires",
                "You've established a pace that exceeds expectations",
                "You're consistently above your target rate",
            ]
        case .aheadLow:
            return [
                "You're starting above your target pace",
                "Early signs suggest a stronger pace",
                "You've opened ahead of your target",
                "Your initial pace is higher than expected",
                "You're trending above your target early on",
                "A strong start is forming",
                "Your early rhythm exceeds your target",
                "You've begun at a higher pace",
                "You're showing early signs of exceeding your goal",
                "Your pace is currently ahead of expectation",
                "You've started stronger than required",
                "Early activity suggests upward momentum",
                "You're setting a higher initial pace",
                "You're moving ahead early",
                "Your starting rhythm is above target",
            ]
        case .onTrack:
            return [
                "You're aligned with your target pace",
                "Your progress matches your goal",
                "You're tracking steadily toward your target",
                "Your current pace is right on target",
                "You're maintaining the required rhythm",
                "Your consistency is keeping you on track",
                "You're progressing as expected",
                "You're matching your goal's demands",
                "Your behaviour aligns with your target",
                "You're maintaining a stable pace",
                "Your current pattern supports your goal",
                "You're operating within your target range",
                "You're sustaining the right level of progress",
                "Your pace is balanced and consistent",
                "You're keeping in line with expectations",
            ]
        case .onTrackLow:
            return [
                "Your pace is still taking shape",
                "Early activity suggests you're near target pace",
                "Your trajectory is still forming",
                "It's early, but your pace looks aligned",
                "Your pattern is developing around target pace",
                "You are close to the required rhythm so far",
                "Your early progress is roughly on track",
                "This pace is promising but still early",
                "Your current direction looks close to target",
                "Your pattern is building toward a stable pace",
            ]
        case .atRisk:
            return [
                "You're slightly below your target pace",
                "Your current pace is behind your goal",
                "You're drifting below your expected progress",
                "You're just under where you need to be",
                "Your pace is falling short of target",
                "You're not quite meeting your goal's rhythm",
                "You're tracking slightly behind",
                "Your progress is under target pace",
                "You're below your expected trajectory",
                "Your current pattern won't reach your goal",
                "You're moving slower than required",
                "Your pace needs a small lift",
                "You're under your target threshold",
                "You're slightly off track",
                "Your current rate is below expectation",
            ]
        case .atRiskLow:
            return [
                "Not enough data yet to establish your pace",
                "It's still early to determine your trajectory",
                "Your pattern isn't clear yet",
                "Activity is too limited to assess direction",
                "Your pace is still forming",
                "Not enough progress to evaluate yet",
                "Your trend is still developing",
                "It's too early to judge your progress",
                "Your current pattern is incomplete",
                "There isn't a clear rhythm yet",
            ]
        case .openConsistency:
            return [
                "You're building a consistent pattern",
                "Your habit is becoming more regular",
                "You're reinforcing this behaviour",
                "Your consistency is strengthening",
                "You're showing up reliably",
                "Your habit is taking shape",
                "You're creating a stable rhythm",
                "This behaviour is becoming routine",
                "Your consistency is improving",
                "You're forming a repeatable pattern",
                "You're strengthening this habit loop",
                "Your engagement is becoming steady",
                "You're building reliability in this habit",
                "This is becoming part of your routine",
                "Your pattern is stabilising",
            ]
        }
    }

    func bodies(for scenario: Scenario) -> [String] {
        switch scenario {
        case .aheadHigh:
            return [
                "This pace would carry you beyond your goal.",
                "You're building a meaningful buffer.",
                "If sustained, this will outperform your target.",
                "You're ahead of expected progress.",
                "This pattern is stronger than required.",
            ]
        case .aheadLow:
            return [
                "Too early to confirm, but this is promising.",
                "If maintained, this will put you ahead.",
                "Keep this going to build a clearer pattern.",
                "This could develop into a strong period.",
            ]
        case .onTrack:
            return [
                "Maintain this to reach your goal.",
                "This level of consistency is enough.",
                "You're exactly where you need to be.",
                "Stay steady to complete your target.",
            ]
        case .onTrackLow:
            return [
                "Keep going to build a clearer pattern.",
                "A few more entries will sharpen this signal.",
                "Your direction will become clearer soon.",
                "Maintain this rhythm to confirm your trajectory.",
            ]
        case .atRisk:
            return [
                "A small increase will bring you back on track.",
                "There's still time to recover.",
                "A couple of actions will close the gap.",
                "You can still reach your goal with a push.",
            ]
        case .atRiskLow:
            return [
                "Add a few more entries to build a clearer picture.",
                "Your direction will become clearer soon.",
                "Keep logging to establish your pace.",
            ]
        case .openConsistency:
            return [
                "Keep this up to solidify the habit.",
                "Consistency is doing the work here.",
                "This is how habits stick.",
            ]
        }
    }

    func rotatingIndex(
        salt: String,
        dayDate: Date,
        count: Int
    ) -> Int {
        guard count > 1 else { return 0 }
        let dayKey = dayNumber(for: dayDate)
        var index = stableDailyIndex(salt: salt, dayNumber: dayKey, count: count)

        let disallowed = Set((1...3).map { offset in
            stableDailyIndex(salt: salt, dayNumber: dayKey - offset, count: count)
        })

        if disallowed.contains(index) {
            for candidateOffset in 1..<count {
                let candidate = (index + candidateOffset) % count
                if !disallowed.contains(candidate) {
                    index = candidate
                    break
                }
            }
        }

        return index
    }

    func stableDailyIndex(
        salt: String,
        dayNumber: Int,
        count: Int
    ) -> Int {
        let key = "\(salt)|\(dayNumber)"
        let hash = fnv1a64(key)
        return Int(hash % UInt64(count))
    }

    func dayNumber(for date: Date) -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let referenceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.dateComponents([.day], from: referenceDay, to: dayStart).day ?? 0
    }

    func fnv1a64(_ input: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }

    func metricCopyForCumulative(
        baseCopy: GreigCopy,
        status: InsightStatus,
        context: GreigContext
    ) -> GreigCopy {
        let periodText = context.periodLabel ?? "this period"
        let projectedText = context.projectedValue.map {
            formatValue($0, unit: context.unit)
        }
        let nudgedText = context.nudgedProjection.map {
            formatValue($0, unit: context.unit)
        }
        let incrementText = context.suggestedIncrement.map {
            formatRate($0, unit: context.unit)
        }

        switch status {
        case .ahead:
            let title = projectedText.map { "You're on track for \($0) \(periodText)" } ?? baseCopy.title
            let body: String? = {
                if let nudgedText, let incrementText {
                    return "A small top-up of \(incrementText)/day could lift this to \(nudgedText) \(periodText)."
                }
                if let delta = context.deltaFromTarget {
                    return "About \(formatValue(abs(delta), unit: context.unit)) ahead of your goal."
                }
                return baseCopy.body
            }()
            return GreigCopy(title: title, body: body)
        case .onTrack:
            let title = projectedText.map { "You're on track for \($0) \(periodText)" } ?? baseCopy.title
            let body: String? = {
                if let nudgedText, let incrementText {
                    if let target = context.targetValue, let nudgedProjection = context.nudgedProjection, nudgedProjection > target {
                        return "A small boost of \(incrementText)/day could take this above your goal."
                    }
                    return "A small boost of \(incrementText)/day could lift this to \(nudgedText) \(periodText)."
                }
                if let target = context.targetValue {
                    return "Right in line with your \(formatValue(target, unit: context.unit)) goal."
                }
                return "Right in line with your goal."
            }()
            return GreigCopy(title: title, body: body)
        case .atRisk:
            let body: String? = {
                if let requiredRate = context.requiredRate {
                    return "Adding \(formatRate(requiredRate, unit: context.unit))/day would bring you back on track."
                }
                return baseCopy.body
            }()
            return GreigCopy(title: baseCopy.title, body: body)
        case .neutral:
            return baseCopy
        }
    }

    func metricCopyForFrequency(
        baseCopy: GreigCopy,
        status: InsightStatus,
        context: GreigContext
    ) -> GreigCopy {
        let suggestedActions = context.suggestedIncrement.map { max(1, Int($0.rounded())) }

        switch status {
        case .ahead:
            if let current = context.currentValue, let target = context.targetValue {
                let currentText = formatCount(current)
                let targetText = formatCount(target)
                let nudgeSentence: String = {
                    guard suggestedActions != nil else { return "" }
                    return " Another session could strengthen your lead."
                }()
                return GreigCopy(
                    title: baseCopy.title,
                    body: "You've already completed \(currentText) of \(targetText) planned sessions.\(nudgeSentence)"
                )
            }
            return baseCopy
        case .onTrack:
            if let remaining = context.remainingActions, remaining > 0 {
                let noun = remaining == 1 ? "session" : "sessions"
                let nudgeSentence: String = {
                    guard suggestedActions != nil else { return "" }
                    return " One extra session could put you comfortably ahead."
                }()
                return GreigCopy(
                    title: baseCopy.title,
                    body: "\(remaining) more \(noun) will hit your target.\(nudgeSentence)"
                )
            }
            if let remaining = context.remainingActions, remaining == 0 {
                let nudgeSentence: String = {
                    guard suggestedActions != nil else { return "" }
                    return " One extra session would put you comfortably ahead."
                }()
                return GreigCopy(
                    title: baseCopy.title,
                    body: "You've already hit your target.\(nudgeSentence)"
                )
            }
            return baseCopy
        case .atRisk:
            if let remaining = context.remainingActions, remaining > 0 {
                let nudgeCount = max(remaining, suggestedActions ?? 0)
                let noun = nudgeCount == 1 ? "check-in" : "check-ins"
                return GreigCopy(
                    title: baseCopy.title,
                    body: "\(nudgeCount) more \(noun) would bring you back on track."
                )
            }
            return baseCopy
        case .neutral:
            return baseCopy
        }
    }

    func metricCopyForOpen(
        baseCopy: GreigCopy,
        status: InsightStatus,
        context: GreigContext
    ) -> GreigCopy {
        let hasNudge = (context.suggestedIncrement ?? 0) > 0

        if status == .ahead, let streak = context.streakLength, streak > 1 {
            return GreigCopy(
                title: "You've built a \(streak)-day streak",
                body: hasNudge ? "Showing up today could keep this momentum intact." : "Consistency is strengthening."
            )
        }

        if status == .onTrack {
            return GreigCopy(
                title: baseCopy.title,
                body: hasNudge ? "Showing up today could reinforce this rhythm." : baseCopy.body
            )
        }

        if (status == .neutral || status == .atRisk),
           let completed = context.recentCompletedDays,
           let window = context.recentWindowDays {
            return GreigCopy(
                title: "You've completed \(completed) of the last \(window) days",
                body: hasNudge ? "Logging today would help reset your rhythm." : "Your rhythm is rebuilding."
            )
        }

        return baseCopy
    }

    func formatValue(
        _ value: Double,
        unit: String
    ) -> String {
        let rounded = Int(value.rounded())
        let currencyDetection = CurrencyDetection.detect(unit: unit)
        if currencyDetection.isCurrency {
            let symbol = currencyDetection.currencySymbol ?? unit
            return "\(symbol)\(rounded)"
        }

        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "\(rounded)"
        }
        return "\(rounded) \(trimmed)"
    }

    func formatRate(
        _ value: Double,
        unit: String
    ) -> String {
        "~\(formatValue(value, unit: unit))"
    }

    func formatCount(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}
