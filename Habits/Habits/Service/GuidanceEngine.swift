import Foundation

struct HabitPattern: Equatable {
    let description: String
    let anchor: String?
}

struct GuidanceInput {
    let habit: Habit
    let now: Date
    let isCompletedToday: Bool
    let streakState: StreakState
    let completionHistory: [HabitLog]
    let globalHistory: [HabitLog]
    let pattern: HabitPattern?
    let goalType: GoalType

    init(
        habit: Habit,
        now: Date,
        isCompletedToday: Bool,
        streakState: StreakState,
        completionHistory: [HabitLog],
        globalHistory: [HabitLog] = [],
        pattern: HabitPattern?,
        goalType: GoalType
    ) {
        self.habit = habit
        self.now = now
        self.isCompletedToday = isCompletedToday
        self.streakState = streakState
        self.completionHistory = completionHistory
        self.globalHistory = globalHistory
        self.pattern = pattern
        self.goalType = goalType
    }
}

struct GuidanceOutput: Equatable {
    let id: String
    let title: String
    let action: String
    let supportingContext: String?
    let emphasisLabel: String?
    let type: GuidanceType
}

enum GuidanceType: String, Equatable, Codable {
    case momentum
    case atRisk
    case recovery
    case identity
}

enum GuidanceVisualVariant: String, Equatable {
    case focus
    case glow
    case pinnedMoment
}

enum TimeBucket: CaseIterable, Equatable {
    case earlyMorning
    case morning
    case midday
    case afternoon
    case evening
    case night
}

struct TimingComparison: Equatable {
    let behaviour: TimeBucket?
    let optimal: TimeBucket?
    let relationship: Relationship
}

enum Relationship: Equatable {
    case aligned
    case slightlyEarly
    case slightlyLate
    case farEarly
    case farLate
    case unknown
}

enum TimePosition: Equatable {
    case beforeOptimal
    case inOptimal
    case afterOptimal
    case unknown
}

enum ConsistencyStage: Equatable {
    case early
    case building
    case steady
}

enum GuidanceContentType: Equatable {
    case timePosition
    case behaviour
    case action
    case reinforcement
}

struct GuidanceSelectionContext: Equatable {
    let expectedHour: Int?
    let isWithinWindow: Bool
    let isNearPeak: Bool
    let windowPassed: Bool
    let timingConfidence: Double
    let behaviourBucket: TimeBucket?
    let optimalBucket: TimeBucket?
    let timePosition: TimePosition
    let cutoffHour: Int
    let activeDays: Int
    let windowDays: Int
    let pattern: HabitPattern?
}

private struct GuidanceTemplate: Equatable {
    let id: String
    let title: String
    let action: String
    let openingToken: String
}

struct GuidanceAssignment: Codable, Equatable {
    let templateID: String
    let type: GuidanceType
    let dayStamp: TimeInterval
}

struct GuidanceHistoryEntry: Codable, Equatable {
    let templateID: String
    let openingToken: String
    let usedAt: TimeInterval
}

struct GuidanceRotationSnapshot: Codable, Equatable {
    var currentAssignmentByHabitID: [String: GuidanceAssignment] = [:]
    var historyByHabitID: [String: [GuidanceHistoryEntry]] = [:]
}

protocol GuidanceRotationStoring {
    func snapshot() -> GuidanceRotationSnapshot
    func save(_ snapshot: GuidanceRotationSnapshot)
}

struct UserDefaultsGuidanceRotationStore: GuidanceRotationStoring {
    private let defaults: UserDefaults
    private let key = "guidance.rotation.snapshot.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func snapshot() -> GuidanceRotationSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(GuidanceRotationSnapshot.self, from: data) else {
            return GuidanceRotationSnapshot()
        }
        return snapshot
    }

    func save(_ snapshot: GuidanceRotationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}

enum GuidanceEngine {
    private static let forbiddenFragments = [
        "streak",
        "don't break",
        "protect your streak",
        "extend your streak",
        "reset"
    ]
    private static let identityFragments = [
        "who you are",
        "becoming",
        "identity",
        "part of you"
    ]

    private static let rotationLookback: TimeInterval = 48 * 60 * 60
    private static let permissionLines = [
        "Even now, it still counts",
        "It’s not too late to show up",
        "A later session still adds value",
        "Showing up now still matters",
        "You can still make this count",
        "Any progress now is a win",
        "This still moves things forward",
        "It all adds up, even now"
    ]
    private static let reinforcementLines = [
        "This keeps your progress intact",
        "Every check-in strengthens this",
        "You’re building something steady",
        "This helps lock it in",
        "You’re reinforcing the habit",
        "This is how consistency forms",
        "Small steps keep it moving",
        "This keeps your rhythm alive"
    ]
    private static let energisingLines = [
        "You’re right there - keep it going",
        "This is a great moment to act",
        "Lean into it while it’s there",
        "You’ve got momentum - use it",
        "This is a strong moment to move",
        "Stay with it - you’re on track",
        "You’re in a good place - continue",
        "Keep this going while it feels natural"
    ]
    private static let identityLines = [
        "This is what someone consistent does",
        "You’re becoming someone who shows up",
        "This is part of who you’re building",
        "You’re proving it to yourself",
        "This is how it becomes natural",
        "You’re shaping the habit right now",
        "This is what it looks like in practice",
        "You’re reinforcing who you want to be"
    ]

    static func build(
        input: GuidanceInput,
        calendar: Calendar = .current,
        identitySnapshot: HabitIdentityStateSnapshot? = nil,
        rotationStore: GuidanceRotationStoring = UserDefaultsGuidanceRotationStore()
    ) -> GuidanceOutput {
        let snapshot = identitySnapshot ?? HabitIdentityStateResolver.recentSnapshot(
            for: input.habit,
            calendar: calendar,
            now: input.now,
            windowDays: 7
        )
        let selectionContext = selectionContext(
            for: input,
            snapshot: snapshot,
            calendar: calendar
        )

        let chosenType: GuidanceType = {
            if input.isCompletedToday {
                return snapshot.activeDays >= 5 || snapshot.state == .strong ? .identity : .momentum
            }
            if shouldUseIdentityPush(snapshot: snapshot, streakState: input.streakState) {
                return .identity
            }
            if selectionContext.windowPassed {
                return .recovery
            }
            if calendar.component(.hour, from: input.now) >= selectionContext.cutoffHour {
                return .atRisk
            }
            return .momentum
        }()

        let candidates = templates(
            for: chosenType,
            input: input,
            context: selectionContext,
            identityState: snapshot.state
        )
        let template = selectTemplate(
            from: candidates,
            habitID: input.habit.id,
            state: chosenType,
            now: input.now,
            calendar: calendar,
            store: rotationStore
        )
        let title = guidanceTitle(
            for: selectionContext.timePosition,
            confidence: selectionContext.timingConfidence,
            optimalBucket: selectionContext.optimalBucket
        )
        let action = guidanceAction(
            for: selectionContext.timePosition,
            confidence: selectionContext.timingConfidence,
            optimalBucket: selectionContext.optimalBucket
        )

        return validated(
            GuidanceOutput(
                id: template.id,
                title: title,
                action: action,
                supportingContext: supportingContext(
                    for: chosenType,
                    input: input,
                    context: selectionContext,
                    calendar: calendar,
                    actionLine: action
                ),
                emphasisLabel: emphasisLabel(for: chosenType, context: selectionContext),
                type: chosenType
            )
        )
    }

    static func visualVariant(for output: GuidanceOutput) -> GuidanceVisualVariant {
        if output.type == .atRisk {
            return .pinnedMoment
        }
        if output.type == .identity || output.supportingContext?.localizedCaseInsensitiveContains("Peak:") == true {
            return .glow
        }
        return .focus
    }

    private static func selectTemplate(
        from templates: [GuidanceTemplate],
        habitID: UUID,
        state: GuidanceType,
        now: Date,
        calendar: Calendar,
        store: GuidanceRotationStoring
    ) -> GuidanceTemplate {
        guard !templates.isEmpty else {
            return GuidanceTemplate(
                id: "fallback-momentum-1",
                title: "Finding your rhythm",
                action: "A short session now keeps this on track",
                openingToken: "youre"
            )
        }

        let habitKey = habitID.uuidString
        var snapshot = store.snapshot()
        let dayStart = calendar.startOfDay(for: now).timeIntervalSince1970

        if let assignment = snapshot.currentAssignmentByHabitID[habitKey],
           assignment.type == state,
           assignment.dayStamp == dayStart,
           let existing = templates.first(where: { $0.id == assignment.templateID }) {
            return existing
        }

        let recentHistory = (snapshot.historyByHabitID[habitKey] ?? [])
            .filter { now.timeIntervalSince1970 - $0.usedAt < rotationLookback }
        let recentIDs = Set(recentHistory.map(\.templateID))
        let lastTwoOpenings = Array(recentHistory.suffix(2).map(\.openingToken))

        let available = templates.filter { !recentIDs.contains($0.id) }
        let pool = available.isEmpty ? templates : available
        let constrained = pool.filter { candidate in
            !(lastTwoOpenings.count == 2 && lastTwoOpenings.allSatisfy { $0 == candidate.openingToken })
        }
        let selected = (constrained.isEmpty ? pool : constrained)[0]

        snapshot.currentAssignmentByHabitID[habitKey] = GuidanceAssignment(
            templateID: selected.id,
            type: state,
            dayStamp: dayStart
        )

        var updatedHistory = snapshot.historyByHabitID[habitKey] ?? []
        updatedHistory.append(
            GuidanceHistoryEntry(
                templateID: selected.id,
                openingToken: selected.openingToken,
                usedAt: now.timeIntervalSince1970
            )
        )
        snapshot.historyByHabitID[habitKey] = Array(updatedHistory.suffix(8))
        store.save(snapshot)

        return selected
    }

    private static func templates(
        for type: GuidanceType,
        input: GuidanceInput,
        context: GuidanceSelectionContext,
        identityState: HabitIdentityState
    ) -> [GuidanceTemplate] {
        switch type {
        case .momentum:
            if let pattern = input.pattern {
                let triggerName = pattern.anchor ?? "your routine"
                return [
                    template("stacking-1", "Post-\(compactAnchor(triggerName)) window open", "Start now while it still feels natural"),
                    template("stacking-2", "Right after \(lowercaseDisplay(triggerName))", "This is a good moment to follow through"),
                    template("stacking-3", "Natural next step", "Act now while you’re in the flow"),
                    template("stacking-4", "In your usual sequence", momentumNudge(for: input))
                ]
            }

            if context.isNearPeak {
                return [
                    template("peak-1", "You’re right near your peak time", "Act now while it’s working for you"),
                    template("peak-2", "This is your strongest window", momentumNudge(for: input)),
                    template("peak-3", "You’re approaching your best time", "Now is a good time to follow through"),
                    template("peak-4", "This moment works for you", "Take advantage of it")
                ]
            }

            return [
                template("momentum-1", "You’re in a strong rhythm", momentumNudge(for: input)),
                template("momentum-2", "This is your strongest window", "Start now while it feels natural"),
                template("momentum-3", "Right moment to act", "This is a good moment to follow through"),
                template("momentum-4", "This moment works for you", "Take advantage of it"),
                template("momentum-5", "This is your window", "Now is the easiest time to act")
            ]

        case .recovery:
            if input.pattern != nil {
                return [
                    template("recovery-1", "You’ve missed your usual time", "A short session keeps things on track"),
                    template("recovery-2", "This is outside your normal window", recoveryNudge(for: input)),
                    template("recovery-3", "The usual moment has passed", "A quick version still counts"),
                    template("recovery-4", "Not your typical time", "A short session still keeps this moving")
                ]
            }

            if context.isNearPeak {
                return [
                    template("recovery-peak-1", "This is just past your strongest window", recoveryNudge(for: input)),
                    template("recovery-peak-2", "You’ve missed your usual time", "A short session keeps things on track"),
                    template("recovery-peak-3", "The usual moment has passed", "A quick version still counts")
                ]
            }

            return [
                template("recovery-5", "You’ve missed your usual time", "A short session keeps things on track"),
                template("recovery-6", "This is outside your normal window", recoveryNudge(for: input)),
                template("recovery-7", "The usual moment has passed", "A quick version still counts"),
                template("recovery-8", "Not your typical time", "A short session still keeps this moving")
            ]

        case .atRisk:
            return [
                template("risk-1", "You haven’t completed this today", atRiskNudge(for: input)),
                template("risk-2", "Today’s nearly gone", "A quick session today keeps your rhythm"),
                template("risk-3", "You’re running out of time today", "Keep it simple and get it done"),
                template("risk-4", "Even a small effort counts today", "A short check-in before the day ends keeps this moving")
            ]

        case .identity:
            switch identityState {
            case .gettingStarted:
                return [
                    template("identity-1", "You’re in a strong rhythm", momentumNudge(for: input)),
                    template("identity-2", "This is a good moment to show up", "Right now is a good time to follow through")
                ]
            case .building, .steady:
                return [
                    template("identity-3", "You’re in a strong rhythm", momentumNudge(for: input)),
                    template("identity-4", "This is a good moment to show up", "Right now is a good time to follow through"),
                    template("identity-5", "Keep your rhythm going", "A quick check-in today keeps momentum")
                ]
            case .strong:
                return [
                    template("identity-6", "Keep your rhythm going", "A quick check-in today keeps momentum"),
                    template("identity-7", "You’re in a strong rhythm", momentumNudge(for: input))
                ]
            case .slipping, .rebuilding:
                return [
                    template("identity-8", "You’re in a strong rhythm", recoveryNudge(for: input)),
                    template("identity-9", "This is a good moment to show up", "Right now is a good time to follow through")
                ]
            }
        }
    }

    private static func supportingContext(
        for _: GuidanceType,
        input _: GuidanceInput,
        context: GuidanceSelectionContext,
        calendar _: Calendar,
        actionLine: String
    ) -> String? {
        let comparison = timingComparison(
            behaviour: context.behaviourBucket,
            optimal: context.optimalBucket
        )
        let stage = consistencyStage(activeDays: context.activeDays, windowDays: context.windowDays)
        let lines = timingInsightLines(
            from: comparison,
            timePosition: context.timePosition,
            stage: stage,
            actionLine: actionLine
        )
        return lines.isEmpty ? nil : lines.joined(separator: " • ")
    }

    private static func emphasisLabel(
        for type: GuidanceType,
        context: GuidanceSelectionContext
    ) -> String? {
        if type == .atRisk || context.isNearPeak {
            return "Right now"
        }
        return nil
    }

    private static func selectionContext(
        for input: GuidanceInput,
        snapshot: HabitIdentityStateSnapshot,
        calendar: Calendar
    ) -> GuidanceSelectionContext {
        let timingPattern = inferTimingPattern(from: input.completionHistory, now: input.now, calendar: calendar)
        let timing = timingPattern.window
        let currentHour = calendar.component(.hour, from: input.now)
        let cutoffHour = cutoffHour(for: timing, currentHour: currentHour)
        let optimalSummary = TimeOfDayPerformanceService.peakTimingSummary(
            habitLogs: input.completionHistory,
            globalLogs: input.globalHistory,
            now: input.now,
            calendar: calendar
        )
        let optimalPeakHour = optimalSummary?.peakHour
        let timingConfidence = optimalSummary?.confidence ?? 0
        let optimalBucket = optimalPeakHour.map(bucket(for:))
        let currentTimePosition = timePosition(
            now: input.now,
            optimalPeakHour: optimalPeakHour,
            hasBehaviour: timingPattern.behaviourBucket != nil && timingConfidence >= 0.5,
            calendar: calendar
        )

        return GuidanceSelectionContext(
            expectedHour: timing?.expectedHour,
            isWithinWindow: timing.map { currentHour >= $0.windowStart && currentHour <= $0.windowEnd } ?? false,
            isNearPeak: timingConfidence >= 0.5 ? (timing.map { abs(currentHour - $0.expectedHour) <= 1 } ?? false) : false,
            windowPassed: timingConfidence >= 0.5 ? (timing.map { currentHour > $0.windowEnd } ?? false) : false,
            timingConfidence: timingConfidence,
            behaviourBucket: timingPattern.behaviourBucket,
            optimalBucket: optimalBucket,
            timePosition: currentTimePosition,
            cutoffHour: cutoffHour,
            activeDays: snapshot.activeDays,
            windowDays: snapshot.windowDays,
            pattern: input.pattern
        )
    }

    private static func shouldUseIdentityPush(
        snapshot: HabitIdentityStateSnapshot,
        streakState: StreakState
    ) -> Bool {
        snapshot.activeDays >= 5 || streakState.currentStreak >= 4
    }

    private static func validated(_ output: GuidanceOutput) -> GuidanceOutput {
        let lowercased = "\(output.title) \(output.action) \(output.supportingContext ?? "")".lowercased()
        guard forbiddenFragments.allSatisfy({ !lowercased.contains($0) }) &&
                identityFragments.allSatisfy({ !lowercased.contains($0) }) else {
            return GuidanceOutput(
                id: "fallback-safe",
                title: "Finding your rhythm",
                action: "A short session now keeps this on track",
                supportingContext: "Works well now",
                emphasisLabel: nil,
                type: .momentum
            )
        }
        return enforceNonDuplication(in: output)
    }

    private struct GuidanceLine {
        let type: GuidanceContentType
        let text: String
    }

    private static func enforceNonDuplication(in output: GuidanceOutput) -> GuidanceOutput {
        guard let supportingContext = output.supportingContext else {
            return output
        }

        var lines = supportingContext
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return output }
        if lines.count > 2 {
            lines = Array(lines.prefix(2))
        }

        var guidanceLines: [GuidanceLine] = []
        guidanceLines.append(GuidanceLine(type: .behaviour, text: lines[0]))
        if lines.count > 1 {
            guidanceLines.append(GuidanceLine(type: .reinforcement, text: lines[1]))
        }

        guard guidanceLines.count > 1 else {
            return GuidanceOutput(
                id: output.id,
                title: output.title,
                action: output.action,
                supportingContext: guidanceLines.map(\.text).joined(separator: " • "),
                emphasisLabel: output.emphasisLabel,
                type: output.type
            )
        }

        let titleHasTimePosition = containsTimePositionLanguage(output.title)
        let bullet1HasBehaviour = containsBehaviourTiming(guidanceLines[0].text)
        let bullet2 = guidanceLines[1].text
        let bullet2HasTimePosition = containsTimePositionLanguage(bullet2)
        let bullet2HasBehaviour = containsBehaviourTiming(bullet2)

        let shouldReplaceBullet2 =
            (titleHasTimePosition && bullet2HasTimePosition) ||
            (bullet1HasBehaviour && bullet2HasBehaviour) ||
            areSemanticallySimilar(guidanceLines[0].text, bullet2)

        if shouldReplaceBullet2 {
            guidanceLines[1] = GuidanceLine(
                type: .reinforcement,
                text: reinforcementLine(for: output.type, avoiding: [output.title, output.action, guidanceLines[0].text])
            )
        }

        return GuidanceOutput(
            id: output.id,
            title: output.title,
            action: output.action,
            supportingContext: guidanceLines.map(\.text).joined(separator: " • "),
            emphasisLabel: output.emphasisLabel,
            type: output.type
        )
    }

    private static func containsTimePositionLanguage(_ value: String) -> Bool {
        let normalized = value.lowercased()
        let keywords = [
            "strongest window",
            "earlier today",
            "coming up",
            "right now",
            "earlier",
            "later",
            "window",
            "best time",
            "peak",
            "now"
        ]
        return keywords.contains(where: { normalized.contains($0) })
    }

    private static func containsBehaviourTiming(_ value: String) -> Bool {
        let normalized = value.lowercased()
        let keywords = [
            "usually",
            "tend to",
            "around midday",
            "early morning",
            "morning",
            "afternoon",
            "evening",
            "night",
            "later at night",
            "in the day"
        ]
        return keywords.contains(where: { normalized.contains($0) })
    }

    private static func areSemanticallySimilar(_ lhs: String, _ rhs: String) -> Bool {
        let lhsTokens = Set(
            lhs.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count > 3 }
        )
        let rhsTokens = Set(
            rhs.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count > 3 }
        )
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return false }
        let overlap = lhsTokens.intersection(rhsTokens)
        return overlap.count >= 2
    }

    private static func reinforcementLine(for type: GuidanceType, avoiding lines: [String]) -> String {
        let basePool: [String]
        switch type {
        case .atRisk, .recovery:
            basePool = permissionLines + reinforcementLines
        case .momentum, .identity:
            basePool = reinforcementLines + identityLines
        }

        let filtered = basePool.filter { candidate in
            !containsBehaviourTiming(candidate) &&
            !containsTimePositionLanguage(candidate) &&
            !lines.contains(where: { existing in areSemanticallySimilar(existing, candidate) })
        }
        let pool = filtered.isEmpty ? reinforcementLines : filtered
        for candidate in pool {
            let clashes = lines.contains { existing in
                areSemanticallySimilar(existing, candidate)
            }
            if !clashes {
                return candidate
            }
        }
        return stablePick(from: reinforcementLines, using: "\(type)|\(lines.joined(separator: "|"))")
    }

    private static func cutoffHour(
        for timing: TimingWindow?,
        currentHour: Int
    ) -> Int {
        if let timing {
            return min(max(timing.expectedHour + 4, 18), 22)
        }
        return currentHour >= 18 ? currentHour : 18
    }

    private struct TimingWindow: Equatable {
        let expectedHour: Int
        let windowStart: Int
        let windowEnd: Int
    }

    private struct TimingPattern {
        let window: TimingWindow?
        let behaviourBucket: TimeBucket?
    }

    private static func inferTimingPattern(
        from logs: [HabitLog],
        now: Date,
        calendar: Calendar
    ) -> TimingPattern {
        let qualifyingLogs = logs
            .filter { ($0.frequencyContribution > 0 || $0.numericValue > 0) && $0.effectiveTimestamp <= now }
            .sorted { $0.effectiveTimestamp > $1.effectiveTimestamp }

        let recentHours = qualifyingLogs
            .prefix(28)
            .map { calendar.component(.hour, from: $0.effectiveTimestamp) }

        guard !recentHours.isEmpty else {
            return TimingPattern(window: nil, behaviourBucket: nil)
        }

        var counts: [TimeBucket: Int] = [:]
        for hour in recentHours {
            let bucket = bucket(for: hour)
            counts[bucket, default: 0] += 1
        }

        guard let primary = counts.max(by: { lhs, rhs in
            if lhs.value == rhs.value {
                return bucketOrder(lhs.key) > bucketOrder(rhs.key)
            }
            return lhs.value < rhs.value
        }) else {
            return TimingPattern(window: nil, behaviourBucket: nil)
        }

        let primaryBucket = primary.key
        let primaryCount = primary.value
        let totalCount = recentHours.count
        let primaryRatio = Double(primaryCount) / Double(max(1, totalCount))

        guard totalCount >= 3, primaryRatio >= 0.4 else {
            return TimingPattern(window: nil, behaviourBucket: nil)
        }

        let representativeHour = modeHour(
            in: recentHours,
            for: primaryBucket
        ) ?? bucketRepresentativeHour(primaryBucket)
        let bounds = windowBounds(for: primaryBucket, representativeHour: representativeHour)

        return TimingPattern(
            window: TimingWindow(
                expectedHour: representativeHour,
                windowStart: bounds.start,
                windowEnd: bounds.end
            ),
            behaviourBucket: primaryBucket
        )
    }

    private static func template(_ id: String, _ title: String, _ action: String) -> GuidanceTemplate {
        GuidanceTemplate(
            id: id,
            title: title,
            action: action,
            openingToken: openingToken(from: title)
        )
    }

    private static func openingToken(from title: String) -> String {
        let lowercased = title.lowercased()
        if lowercased.hasPrefix("you’re") || lowercased.hasPrefix("you're") { return "youre" }
        if lowercased.hasPrefix("this") { return "this" }
        if lowercased.hasPrefix("today") { return "today" }
        if lowercased.hasPrefix("even") { return "even" }
        if lowercased.hasPrefix("not") { return "not" }
        return lowercased.split(separator: " ").first.map(String.init) ?? "other"
    }

    private static func lowercaseDisplay(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private static func compactAnchor(_ value: String) -> String {
        let lowered = lowercaseDisplay(value)
        if lowered.hasSuffix("ing"), lowered.count > 5 {
            return String(lowered.dropLast(3))
        }
        return lowered
    }

    private static func bucket(for hour: Int) -> TimeBucket {
        switch hour {
        case 5..<8:
            return .earlyMorning
        case 8..<11:
            return .morning
        case 11..<14:
            return .midday
        case 14..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    private static func bucketOrder(_ bucket: TimeBucket) -> Int {
        switch bucket {
        case .earlyMorning: return 0
        case .morning: return 1
        case .midday: return 2
        case .afternoon: return 3
        case .evening: return 4
        case .night: return 5
        }
    }

    private static func timingComparison(
        behaviour: TimeBucket?,
        optimal: TimeBucket?
    ) -> TimingComparison {
        guard let behaviour, let optimal else {
            return TimingComparison(
                behaviour: behaviour,
                optimal: optimal,
                relationship: .unknown
            )
        }

        let difference = bucketOrder(optimal) - bucketOrder(behaviour)
        let relationship: Relationship
        switch difference {
        case -1:
            relationship = .slightlyLate
        case 1:
            relationship = .slightlyEarly
        case 0:
            relationship = .aligned
        case let x where x <= -2:
            relationship = .farLate
        case let x where x >= 2:
            relationship = .farEarly
        default:
            relationship = .unknown
        }

        return TimingComparison(
            behaviour: behaviour,
            optimal: optimal,
            relationship: relationship
        )
    }

    private static func timingInsightLines(
        from comparison: TimingComparison,
        timePosition: TimePosition,
        stage: ConsistencyStage,
        actionLine: String
    ) -> [String] {
        switch (comparison.behaviour, comparison.optimal) {
        case let (behaviour?, _?):
            var lines = [behaviourLine(for: behaviour)]
            if let reinforcement = bullet2Line(
                for: timePosition,
                stage: stage,
                actionLine: actionLine,
                firstBullet: lines[0]
            ) {
                lines.append(reinforcement)
            }
            return lines
        case let (behaviour?, nil):
            return [behaviourLine(for: behaviour)]
        case (nil, _?):
            return ["You’re still finding your rhythm"]
        case (nil, nil):
            return []
        }
    }

    private static func behaviourLine(for bucket: TimeBucket) -> String {
        "Usually \(bucketPhrase(for: bucket))"
    }

    private static func consistencyStage(activeDays: Int, windowDays: Int) -> ConsistencyStage {
        let safeWindow = max(1, windowDays)
        let ratio = Double(max(0, activeDays)) / Double(safeWindow)
        if activeDays <= 2 || ratio < 0.4 {
            return .early
        }
        if ratio < 0.75 {
            return .building
        }
        return .steady
    }

    private static func bullet2Pool(for position: TimePosition, stage: ConsistencyStage) -> [String] {
        switch position {
        case .afterOptimal:
            return permissionLines
        case .inOptimal:
            if stage == .early {
                return reinforcementLines
            }
            return energisingLines + reinforcementLines
        case .beforeOptimal:
            if stage == .early {
                return reinforcementLines
            }
            return energisingLines
        case .unknown:
            return stage == .steady ? (reinforcementLines + identityLines) : reinforcementLines
        }
    }

    private static func bullet2Line(
        for position: TimePosition,
        stage: ConsistencyStage,
        actionLine: String,
        firstBullet: String
    ) -> String? {
        let pool = bullet2Pool(for: position, stage: stage)
        guard !pool.isEmpty else { return nil }

        let forbidden = [
            "earlier", "later", "window", "best time", "peak",
            "morning", "midday", "afternoon", "evening", "night"
        ]

        let candidates = pool.filter { line in
            let normalized = line.lowercased()
            if forbidden.contains(where: { normalized.contains($0) }) {
                return false
            }
            if areSemanticallySimilar(line, actionLine) {
                return false
            }
            if areSemanticallySimilar(line, firstBullet) {
                return false
            }
            return true
        }

        let finalPool = candidates.isEmpty ? pool : candidates
        return stablePick(from: finalPool, using: "\(position)|\(stage)|\(actionLine)|\(firstBullet)")
    }

    private static func stablePick(from pool: [String], using seed: String) -> String {
        guard !pool.isEmpty else { return "This still helps build consistency" }
        let hash = seed.unicodeScalars.reduce(5381) { partial, scalar in
            ((partial << 5) &+ partial) &+ Int(scalar.value)
        }
        let index = abs(hash) % pool.count
        return pool[index]
    }

    private static func bucketPhrase(for bucket: TimeBucket) -> String {
        switch bucket {
        case .earlyMorning:
            return "in the early morning"
        case .morning:
            return "in the morning"
        case .midday:
            return "around midday"
        case .afternoon:
            return "in the afternoon"
        case .evening:
            return "in the evening"
        case .night:
            return "later at night"
        }
    }

    private static func guidanceTitle(
        for position: TimePosition,
        confidence: Double,
        optimalBucket: TimeBucket?
    ) -> String {
        if confidence < 0.5 {
            if let optimalBucket {
                return "You usually do this \(bucketPhrase(for: optimalBucket))"
            }
            return "Your usual window is still forming"
        }

        switch position {
        case .inOptimal:
            return "You’re in your strongest window"
        case .beforeOptimal:
            return "Your strongest window is coming up"
        case .afterOptimal:
            return "Your strongest window was earlier"
        case .unknown:
            return "Finding your rhythm"
        }
    }

    private static func guidanceAction(
        for position: TimePosition,
        confidence: Double,
        optimalBucket: TimeBucket?
    ) -> String {
        if confidence < 0.5 {
            if let optimalBucket {
                return "Usually \(bucketPhrase(for: optimalBucket)) works well"
            }
            return "A quick check-in keeps this consistent"
        }

        switch position {
        case .inOptimal:
            return "Doing this now helps lock it in"
        case .beforeOptimal, .afterOptimal:
            return "A short session now keeps this on track"
        case .unknown:
            return "A quick check-in keeps this consistent"
        }
    }

    private static func timePosition(
        now: Date,
        optimalPeakHour: Int?,
        hasBehaviour: Bool,
        calendar: Calendar
    ) -> TimePosition {
        guard hasBehaviour, let optimalPeakHour else { return .unknown }

        let windowStartHour = (optimalPeakHour + 23) % 24
        let windowEndHour = (optimalPeakHour + 1) % 24
        let todayStart = calendar.startOfDay(for: now)

        guard var start = calendar.date(byAdding: .hour, value: windowStartHour, to: todayStart),
              var end = calendar.date(byAdding: .hour, value: windowEndHour, to: todayStart) else {
            return .unknown
        }

        if windowStartHour > windowEndHour {
            let nowHour = calendar.component(.hour, from: now)
            if nowHour <= windowEndHour {
                start = calendar.date(byAdding: .day, value: -1, to: start) ?? start
            } else {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
        }

        if now >= start && now <= end {
            return .inOptimal
        } else if now < start {
            return .beforeOptimal
        } else if now > end {
            return .afterOptimal
        }
        return .unknown
    }

    private static func modeHour(in hours: [Int], for targetBucket: TimeBucket) -> Int? {
        let bucketHours = hours.filter { hour in
            bucket(for: hour) == targetBucket
        }
        guard !bucketHours.isEmpty else { return nil }

        var frequencies: [Int: Int] = [:]
        for hour in bucketHours {
            frequencies[hour, default: 0] += 1
        }

        let representative = frequencies.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }
            return lhs.value < rhs.value
        }?.key
        return representative
    }

    private static func bucketRepresentativeHour(_ bucket: TimeBucket) -> Int {
        switch bucket {
        case .earlyMorning: return 6
        case .morning: return 9
        case .midday: return 12
        case .afternoon: return 15
        case .evening: return 18
        case .night: return 22
        }
    }

    private static func windowBounds(
        for bucket: TimeBucket,
        representativeHour: Int
    ) -> (start: Int, end: Int) {
        switch bucket {
        case .earlyMorning:
            return (5, 7)
        case .morning:
            return (8, 10)
        case .midday:
            return (11, 13)
        case .afternoon:
            return (14, 16)
        case .evening:
            return (17, 20)
        case .night:
            return representativeHour >= 21 ? (21, 23) : (0, 4)
        }
    }

    private static func momentumNudge(for input: GuidanceInput) -> String {
        if isLearningHabit(input.habit) {
            return "A short session now keeps this on track"
        }
        if isFinanceHabit(input.habit) {
            return "A quick check-in keeps this consistent"
        }
        if isFitnessHabit(input.habit) {
            return "A short session now keeps this on track"
        }
        return "A short session now keeps this on track"
    }

    private static func recoveryNudge(for input: GuidanceInput) -> String {
        if isLearningHabit(input.habit) {
            return "A few minutes now keeps this on track"
        }
        if isFinanceHabit(input.habit) {
            return "Putting something aside now keeps this on track"
        }
        if isFitnessHabit(input.habit) {
            return "A short walk now keeps things on track"
        }
        return "A short session now keeps this on track"
    }

    private static func atRiskNudge(for input: GuidanceInput) -> String {
        if isLearningHabit(input.habit) {
            return "A short session now keeps this on track"
        }
        if isFinanceHabit(input.habit) {
            return "A quick check-in keeps this consistent"
        }
        if isFitnessHabit(input.habit) {
            return "A short session now keeps this on track"
        }
        return "A short session now keeps this on track"
    }

    private static func isFitnessHabit(_ habit: Habit) -> Bool {
        if habit.category == .health || habit.category == .wellbeing {
            return true
        }
        let name = habit.name.lowercased()
        return name.contains("walk") ||
            name.contains("run") ||
            name.contains("gym") ||
            name.contains("workout") ||
            name.contains("exercise")
    }

    private static func isLearningHabit(_ habit: Habit) -> Bool {
        if habit.category == .learning {
            return true
        }
        let name = habit.name.lowercased()
        return name.contains("read") ||
            name.contains("study") ||
            name.contains("learn") ||
            name.contains("practice")
    }

    private static func isFinanceHabit(_ habit: Habit) -> Bool {
        let name = habit.name.lowercased()
        return name.contains("save") ||
            name.contains("budget") ||
            name.contains("invest") ||
            name.contains("money") ||
            name.contains("finance")
    }
}
