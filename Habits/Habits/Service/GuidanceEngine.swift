import Foundation

enum CoachingDepth: String, Sendable, Equatable {
    case basic
    case premium
}

enum CoachPresentationMode: Sendable, Equatable {
    case aiCoach
    case guidanceFallback
}

enum CoachingSignalID: String, CaseIterable, Sendable, Equatable, Hashable {
    case identityState
    case streakState
    case consistency
    case timeOfDayInsights
    case recentBehaviourSummary
    case todayStatus
}

struct SelectedCoachingSignals: Sendable, Equatable {
    let primary: CoachingSignalID
    let secondary: CoachingSignalID?

    var all: Set<CoachingSignalID> {
        if let secondary {
            return [primary, secondary]
        }
        return [primary]
    }
}

struct CoachingTimeOfDayInsights: Sendable, Equatable {
    let strongestWindow: String?
    let confidence: TimingConfidence
}

private func coachingStableHash64(_ input: String) -> UInt64 {
    let prime: UInt64 = 1099511628211
    var hash: UInt64 = 1469598103934665603
    for byte in input.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* prime
    }
    return hash
}

private func coachingStableHashHex(_ input: String) -> String {
    String(format: "%016llx", coachingStableHash64(input))
}

struct CoachingInput: Sendable, Equatable {
    let version: Int
    let identityState: HabitState
    let streakState: String
    let consistency: Int
    let timeOfDayInsights: CoachingTimeOfDayInsights
    let recentBehaviourSummary: String
    let todayStatus: String
    let windowDays: Int
    let dayBucket: Int64
    let dayOrdinal: Int

    init(
        version: Int = 1,
        identityState: HabitState,
        streakState: String,
        consistency: Int,
        timeOfDayInsights: CoachingTimeOfDayInsights,
        recentBehaviourSummary: String,
        todayStatus: String,
        windowDays: Int,
        dayBucket: Int64,
        dayOrdinal: Int
    ) {
        self.version = version
        self.identityState = identityState
        self.streakState = streakState
        self.consistency = consistency
        self.timeOfDayInsights = timeOfDayInsights
        self.recentBehaviourSummary = recentBehaviourSummary
        self.todayStatus = todayStatus
        self.windowDays = windowDays
        self.dayBucket = dayBucket
        self.dayOrdinal = dayOrdinal
    }

    func coreMeaningFingerprint(selectedSignals: SelectedCoachingSignals) -> String {
        coachingStableHashHex([
            "v\(version)",
            identityState.rawValue,
            streakState,
            "\(consistency)",
            timeOfDayInsights.strongestWindow ?? "none",
            timeOfDayInsights.confidence.rawValue,
            recentBehaviourSummary,
            todayStatus,
            "\(windowDays)",
            selectedSignals.all.map(\.rawValue).sorted().joined(separator: ",")
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .joined(separator: "|"))
    }

    func aiFingerprint(depth: CoachingDepth, selectedSignals: SelectedCoachingSignals) -> String {
        coachingStableHashHex("\(coreMeaningFingerprint(selectedSignals: selectedSignals))|\(depth.rawValue)|v\(version)")
    }

    func stableAIFingerprint(depth: CoachingDepth, selectedSignals: SelectedCoachingSignals) -> String {
        let consistencyBucket = max(0, min(100, Int((Double(consistency) / 5.0).rounded()) * 5))
        let windowDaysBucket = max(1, min(90, windowDays))
        return coachingStableHashHex([
            "v\(version)",
            "depth:\(depth.rawValue)",
            "day:\(dayOrdinal)",
            identityState.rawValue,
            streakState,
            "consistency:\(consistencyBucket)",
            timeOfDayInsights.strongestWindow ?? "none",
            timeOfDayInsights.confidence.rawValue,
            recentBehaviourSummary,
            todayStatus,
            "window:\(windowDaysBucket)",
            selectedSignals.all.map(\.rawValue).sorted().joined(separator: ",")
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .joined(separator: "|"))
    }

    func guidanceVariationKey(selectedSignals: SelectedCoachingSignals) -> String {
        coachingStableHashHex("\(coreMeaningFingerprint(selectedSignals: selectedSignals))|day:\(dayBucket)")
    }
}

enum SafeMinimalCoaching {
    static let line = "Show up today and take one small step; consistency builds from here."
}

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
    let payload: GuidancePayload
    let usedSignals: Set<CoachingSignalID>

    init(
        id: String,
        title: String,
        action: String,
        supportingContext: String?,
        emphasisLabel: String?,
        type: GuidanceType,
        payload: GuidancePayload,
        usedSignals: Set<CoachingSignalID> = []
    ) {
        self.id = id
        self.title = title
        self.action = action
        self.supportingContext = supportingContext
        self.emphasisLabel = emphasisLabel
        self.type = type
        self.payload = payload
        self.usedSignals = usedSignals
    }
}

enum GuidanceNowState: String, Codable, Equatable {
    case before = "BEFORE"
    case during = "DURING"
    case after = "AFTER"
    case forming = "FORMING"
}

enum GuidanceConfidence: String, Codable, Equatable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

struct GuidancePayload: Codable, Equatable {
    let state: GuidanceNowState
    let strongestWindow: String
    let confidence: GuidanceConfidence
    let guidance: String
    let explanation: String
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
    let stateKey: String?
}

struct GuidanceHistoryEntry: Codable, Equatable {
    let templateID: String
    let openingToken: String
    let usedAt: TimeInterval
}

struct GuidanceRotationSnapshot: Codable, Equatable {
    var currentAssignmentByHabitID: [String: GuidanceAssignment] = [:]
    var historyByHabitID: [String: [GuidanceHistoryEntry]] = [:]
    var coachingSentenceHistoryByMeaningKey: [String: [CoachingSentenceHistoryEntry]] = [:]
}

struct CoachingSentenceHistoryEntry: Codable, Equatable {
    let dayOrdinal: Int
    let variantIndex: Int
    let normalizedSentence: String
    let usedAt: TimeInterval
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
        "This locks progress in place",
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
        let consistencyMetrics = HabitInsightsService(calendar: calendar).consistencyMetrics(
            for: input.habit,
            now: input.now
        )
        let snapshot = identitySnapshot ?? HabitIdentityStateResolver.recentSnapshot(
            for: input.habit,
            calendar: calendar,
            now: input.now,
            windowDays: 7
        )
        let selectionContext = selectionContext(
            for: input,
            snapshot: snapshot,
            consistencyDaysCompleted: consistencyMetrics.daysCompleted,
            consistencyDaysAvailable: consistencyMetrics.daysAvailable,
            calendar: calendar
        )
        let confidence = confidenceBand(from: selectionContext.timingConfidence)
        let nowState = nowState(
            timePosition: selectionContext.timePosition,
            confidence: confidence
        )

        let chosenType: GuidanceType = {
            if selectionContext.windowPassed {
                return .recovery
            }
            if !input.isCompletedToday,
               calendar.component(.hour, from: input.now) >= selectionContext.cutoffHour {
                return .atRisk
            }
            return .momentum
        }()

        let candidates = nowTemplates(for: nowState)
        let stateKey = "\(chosenType.rawValue)|\(nowState.rawValue)|\(confidence.rawValue)"
        let template = selectTemplate(
            from: candidates,
            habitID: input.habit.id,
            state: chosenType,
            stateKey: stateKey,
            now: input.now,
            calendar: calendar,
            store: rotationStore
        )
        let strongestWindow = strongestWindowLabel(
            expectedHour: selectionContext.expectedHour
        )
        let guidanceLine = "\(template.title). \(template.action)"
        let explanationLine = "State \(nowState.rawValue), confidence \(confidence.rawValue), strongest window \(strongestWindow)"
        logTimingTrace(
            habitName: input.habit.name,
            expectedHour: selectionContext.expectedHour,
            confidence: selectionContext.timingConfidence,
            title: template.title,
            action: template.action,
            supportingContext: nil
        )

        return validated(
            GuidanceOutput(
                id: template.id,
                title: template.title,
                action: template.action,
                supportingContext: nil,
                emphasisLabel: emphasisLabel(for: chosenType, context: selectionContext),
                type: chosenType,
                payload: GuidancePayload(
                    state: nowState,
                    strongestWindow: strongestWindow,
                    confidence: confidence,
                    guidance: guidanceLine,
                    explanation: explanationLine
                )
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

    static func selectSignals(
        for input: CoachingInput,
        depth: CoachingDepth
    ) -> SelectedCoachingSignals {
        let primary: CoachingSignalID = {
            if let strongest = input.timeOfDayInsights.strongestWindow,
               !strongest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .timeOfDayInsights
            }
            if input.streakState.localizedCaseInsensitiveContains("streak") {
                return .streakState
            }
            if input.consistency > 0 {
                return .consistency
            }
            if !input.recentBehaviourSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .recentBehaviourSummary
            }
            return .identityState
        }()

        guard depth == .premium else {
            return SelectedCoachingSignals(primary: primary, secondary: nil)
        }

        let preferredSecondary: [CoachingSignalID] = [
            .consistency,
            .streakState,
            .timeOfDayInsights,
            .recentBehaviourSummary,
            .todayStatus,
            .identityState
        ]
        let secondary = preferredSecondary.first { signal in
            signal != primary && hasValue(for: signal, input: input)
        }
        return SelectedCoachingSignals(primary: primary, secondary: secondary)
    }

    static func coachingBody(
        from input: CoachingInput,
        depth: CoachingDepth,
        selectedSignals: SelectedCoachingSignals,
        meaningScope: String,
        rotationStore: GuidanceRotationStoring = UserDefaultsGuidanceRotationStore()
    ) -> (text: String, usedSignals: Set<CoachingSignalID>) {
        let variantCount = templateCount(for: input.identityState)
        guard variantCount > 0 else {
            return (SafeMinimalCoaching.line, [])
        }

        let meaningKey = "\(meaningScope)|\(input.coreMeaningFingerprint(selectedSignals: selectedSignals))"
        let variationSeed = "\(input.coreMeaningFingerprint(selectedSignals: selectedSignals))|\(input.dayBucket)"
        var snapshot = rotationStore.snapshot()
        let history = snapshot.coachingSentenceHistoryByMeaningKey[meaningKey] ?? []
        let baseIndex = Int(stableHash64(variationSeed) % UInt64(variantCount))
        let usedSignals: Set<CoachingSignalID> = {
            if depth == .premium, selectedSignals.secondary != nil {
                return selectedSignals.all
            }
            return [selectedSignals.primary]
        }()
        let maxWords = depth == .premium ? 45 : 30

        let previousEntry = history.last
        var chosenText: String?
        var chosenIndex = baseIndex

        for offset in 0..<variantCount {
            let candidateIndex = (baseIndex + offset) % variantCount
            let candidate = normalizeCoachingSentences(
                renderCoachingText(
                input: input,
                depth: depth,
                selectedSignals: selectedSignals,
                variantIndex: candidateIndex,
                variationSeed: variationSeed
                )
            )
            let bounded = boundedWords(candidate, maxWords: maxWords)
            let normalized = normalizeSentence(bounded)
            let isConsecutiveRepeat = previousEntry.map {
                $0.dayOrdinal == input.dayOrdinal - 1 && $0.normalizedSentence == normalized
            } ?? false
            if isConsecutiveRepeat {
                continue
            }
            chosenText = bounded
            chosenIndex = candidateIndex
            break
        }

        if chosenText == nil {
            let fallbackIndex = leastRecentlyUsedVariantIndex(
                variantCount: variantCount,
                history: history
            )
            chosenIndex = fallbackIndex
            chosenText = boundedWords(
                normalizeCoachingSentences(
                    renderCoachingText(
                    input: input,
                    depth: depth,
                    selectedSignals: selectedSignals,
                    variantIndex: fallbackIndex,
                    variationSeed: variationSeed
                    )
                ),
                maxWords: maxWords
            )
        }

        let resolved = chosenText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let resolved, !resolved.isEmpty else {
            return (SafeMinimalCoaching.line, [])
        }

        let entry = CoachingSentenceHistoryEntry(
            dayOrdinal: input.dayOrdinal,
            variantIndex: chosenIndex,
            normalizedSentence: normalizeSentence(resolved),
            usedAt: Date().timeIntervalSince1970
        )
        var updated = history
        updated.append(entry)
        snapshot.coachingSentenceHistoryByMeaningKey[meaningKey] = Array(updated.suffix(20))
        rotationStore.save(snapshot)

        return (resolved, usedSignals)
    }

    private static func logTimingTrace(
        habitName: String,
        expectedHour: Int?,
        confidence: Double,
        title: String,
        action: String,
        supportingContext: String?
    ) {
        #if DEBUG
        guard let expectedHour else { return }
        _ = habitName
        _ = confidence
        _ = title
        _ = action
        _ = supportingContext
        let consumerHour = expectedHour
        let match = consumerHour == expectedHour
        TimeInsightTraceLogger.logConsistency(
            surface: "Detail",
            enginePeak: expectedHour,
            consumerHour: consumerHour
        )
        assert(match, "habit detail now card hour must equal engine peakHour")
        #endif
    }

    private static func hasValue(for signal: CoachingSignalID, input: CoachingInput) -> Bool {
        switch signal {
        case .identityState:
            return true
        case .streakState:
            return !input.streakState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .consistency:
            return input.consistency > 0
        case .timeOfDayInsights:
            return input.timeOfDayInsights.strongestWindow?.isEmpty == false
        case .recentBehaviourSummary:
            return !input.recentBehaviourSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .todayStatus:
            return !input.todayStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func sentence(
        for signal: CoachingSignalID,
        input: CoachingInput,
        variantIndex: Int,
        variationSeed: String
    ) -> String {
        let tone = variationTone(for: input.identityState, variantIndex: variantIndex)
        let insightLead = tone.select(slot: .insightLead, variationSeed: variationSeed)
        switch signal {
        case .identityState:
            switch input.identityState {
            case .strong:
                return mergeLead(insightLead, with: "this routine is steady and easy to repeat.")
            case .steady:
                return mergeLead(insightLead, with: "this routine is holding steady.")
            case .build:
                return mergeLead(insightLead, with: "this routine is taking shape through repeat check-ins.")
            case .start:
                return mergeLead(insightLead, with: "this routine is still taking shape.")
            case .slip:
                return mergeLead(insightLead, with: "your recent pace dipped, and this routine is ready for a reset.")
            case .rebuild:
                return mergeLead(insightLead, with: "you are rebuilding rhythm and getting consistency back.")
            }
        case .streakState:
            return mergeLead(insightLead, with: "your \(input.streakState) is still giving you momentum.")
        case .consistency:
            return mergeLead(insightLead, with: "you have been landing around \(input.consistency)% consistency.")
        case .timeOfDayInsights:
            if let strongest = input.timeOfDayInsights.strongestWindow,
               !strongest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return mergeLead(insightLead, with: "you tend to show up most reliably in \(strongest).")
            }
            return mergeLead(insightLead, with: "timing is still forming, so showing up matters more than precision.")
        case .recentBehaviourSummary:
            return mergeLead(insightLead, with: input.recentBehaviourSummary)
        case .todayStatus:
            return mergeLead(insightLead, with: "today status is \(input.todayStatus.lowercased()).")
        }
    }

    private static func actionSentence(
        input: CoachingInput,
        depth: CoachingDepth,
        variantIndex: Int,
        variationSeed: String
    ) -> String {
        let tone = variationTone(for: input.identityState, variantIndex: variantIndex)
        let actionLead = tone.select(slot: .actionLead, variationSeed: variationSeed)
        if depth == .premium {
            if let strongest = input.timeOfDayInsights.strongestWindow,
               !strongest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(actionLead) around \(strongest) so this feels easier to repeat tomorrow."
            }
            return "\(actionLead) today so this keeps getting easier to repeat."
        }
        return "\(actionLead) today to keep this moving."
    }

    private static func renderCoachingText(
        input: CoachingInput,
        depth: CoachingDepth,
        selectedSignals: SelectedCoachingSignals,
        variantIndex: Int,
        variationSeed: String
    ) -> String {
        let primaryObservation = sentence(
            for: selectedSignals.primary,
            input: input,
            variantIndex: variantIndex,
            variationSeed: variationSeed
        )
        let action = actionSentence(
            input: input,
            depth: depth,
            variantIndex: variantIndex,
            variationSeed: variationSeed
        )
        guard depth == .premium else {
            return "\(primaryObservation). \(action)"
        }

        let patternSignal = selectedSignals.secondary ?? selectedSignals.primary
        let pattern = patternSentence(
            for: patternSignal,
            input: input,
            variantIndex: variantIndex,
            variationSeed: variationSeed
        )
        let implication = implicationSentence(
            input: input,
            variantIndex: variantIndex,
            variationSeed: variationSeed
        )
        return "\(primaryObservation). \(pattern) \(implication). \(action)"
    }

    private static func patternSentence(
        for signal: CoachingSignalID,
        input: CoachingInput,
        variantIndex: Int,
        variationSeed: String
    ) -> String {
        let tone = variationTone(for: input.identityState, variantIndex: variantIndex)
        let patternLead = tone.select(slot: .patternLead, variationSeed: variationSeed)
        let days = max(1, input.windowDays)
        switch signal {
        case .timeOfDayInsights:
            if let strongest = input.timeOfDayInsights.strongestWindow,
               !strongest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Over the past \(days) days, \(patternLead) \(strongest)"
            }
            return "Over the past \(days) days, timing has been less fixed but still recoverable"
        case .consistency:
            return "Over the past \(days) days, you have held near \(input.consistency)% consistency"
        case .streakState:
            return "Over the past \(days) days, the \(input.streakState) has kept showing up"
        case .recentBehaviourSummary:
            let trimmed = input.recentBehaviourSummary
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: ".! "))
            return "Over the past \(days) days, \(trimmed)"
        case .todayStatus:
            return "Over the past \(days) days, today-status patterns have stayed readable"
        case .identityState:
            return "Over the past \(days) days, this identity signal has remained visible"
        }
    }

    private static func implicationSentence(
        input: CoachingInput,
        variantIndex: Int,
        variationSeed: String
    ) -> String {
        let tone = variationTone(for: input.identityState, variantIndex: variantIndex)
        let implicationLead = tone.select(slot: .implicationLead, variationSeed: variationSeed)
        switch input.identityState {
        case .strong, .steady:
            return mergeLead(implicationLead, with: "this should feel easier to keep going")
        case .build, .start:
            return mergeLead(implicationLead, with: "this is starting to hold with less effort")
        case .slip, .rebuild:
            return mergeLead(implicationLead, with: "a quick reset today can bring the rhythm back")
        }
    }

    private static func templateCount(for state: HabitState) -> Int {
        variationTonesByState[state]?.count ?? 1
    }

    private static func variationTone(for state: HabitState, variantIndex: Int) -> VariationTone {
        let templates = variationTonesByState[state] ?? defaultVariationTones
        return templates[variantIndex % templates.count]
    }

    private static let defaultVariationTones: [VariationTone] = [
        VariationTone(
            insightLeads: ["", "Lately,"],
            patternLeads: ["this usually lands around", "you tend to land around"],
            implicationLeads: ["", ""],
            actionLeads: ["Stick with that window again", "Use that window to make this feel easy again"]
        ),
        VariationTone(
            insightLeads: ["", "Most often,"],
            patternLeads: ["this repeats around", "this pattern keeps landing around"],
            implicationLeads: ["", ""],
            actionLeads: ["Stay with that window again", "Use that window again"]
        ),
        VariationTone(
            insightLeads: ["", "In practice,"],
            patternLeads: ["you are most consistent around", "this keeps clustering around"],
            implicationLeads: ["", ""],
            actionLeads: ["Build around that window", "Center today around that window"]
        ),
        VariationTone(
            insightLeads: ["", "Recently,"],
            patternLeads: ["this usually holds around", "you show up most around"],
            implicationLeads: ["", ""],
            actionLeads: ["Protect that window today", "Keep to that window today"]
        )
    ]

    private static let variationTonesByState: [HabitState: [VariationTone]] = [
        .start: defaultVariationTones,
        .build: [
            VariationTone(
                insightLeads: ["", "At this stage,"],
                patternLeads: ["you repeat most often around", "you usually repeat around"],
                implicationLeads: ["", ""],
                actionLeads: ["Lean into", "Build around"]
            ),
            VariationTone(
                insightLeads: ["", "Right now,"],
                patternLeads: ["check-ins keep landing around", "this keeps clustering around"],
                implicationLeads: ["", ""],
                actionLeads: ["Use", "Center today around"]
            ),
            VariationTone(
                insightLeads: ["", "Lately,"],
                patternLeads: ["your pattern keeps returning near", "your routine keeps returning around"],
                implicationLeads: ["", ""],
                actionLeads: ["Build around", "Lean into"]
            ),
            VariationTone(
                insightLeads: ["", "So far,"],
                patternLeads: ["you are most reliable around", "you hold up best around"],
                implicationLeads: ["", ""],
                actionLeads: ["Anchor", "Protect"]
            ),
            VariationTone(
                insightLeads: ["", "Most days,"],
                patternLeads: ["your strongest repeats land near", "your strongest check-ins land around"],
                implicationLeads: ["", ""],
                actionLeads: ["Protect", "Center today around"]
            ),
            VariationTone(
                insightLeads: ["", "Recently,"],
                patternLeads: ["your consistency is strongest around", "your consistency peaks around"],
                implicationLeads: ["", ""],
                actionLeads: ["Center today around", "Build around"]
            )
        ],
        .steady: defaultVariationTones,
        .strong: defaultVariationTones,
        .slip: [
            VariationTone(
                insightLeads: ["", "Recently,"],
                patternLeads: ["this has been less steady around", "your check-ins have been uneven around"],
                implicationLeads: ["", ""],
                actionLeads: ["Get a quick version done", "Reset the rhythm with a short pass"]
            ),
            VariationTone(
                insightLeads: ["", "Lately,"],
                patternLeads: ["this has drifted more around", "this has been harder to hold around"],
                implicationLeads: ["", ""],
                actionLeads: ["Get a quick version done", "Use a short version to reset"]
            )
        ],
        .rebuild: [
            VariationTone(
                insightLeads: ["", "Recently,"],
                patternLeads: ["this is starting to settle around", "this is beginning to stabilize around"],
                implicationLeads: ["", ""],
                actionLeads: ["Use that window to make this feel easy again", "Stick with that window again"]
            ),
            VariationTone(
                insightLeads: ["", "In practice,"],
                patternLeads: ["this has started to return around", "you are getting back to this around"],
                implicationLeads: ["", ""],
                actionLeads: ["Use that window to make this feel easy again", "Keep to that window again"]
            )
        ]
    ]

    private static func mergeLead(_ lead: String, with body: String) -> String {
        let trimmedLead = lead.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLead.isEmpty else { return body }
        if trimmedLead.hasSuffix(",") {
            return "\(trimmedLead) \(body)"
        }
        return "\(trimmedLead) \(body)"
    }

    private static func normalizeCoachingSentences(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\.{2,}", with: ".", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = collapsed
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return SafeMinimalCoaching.line }
        let normalizedParts = parts.map { sentence in
            guard let first = sentence.first else { return sentence }
            return String(first).uppercased() + sentence.dropFirst()
        }
        return normalizedParts.joined(separator: ". ") + "."
    }

    private static func normalizeSentence(_ text: String) -> String {
        let lowered = text.lowercased()
        let collapsed = lowered.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func leastRecentlyUsedVariantIndex(
        variantCount: Int,
        history: [CoachingSentenceHistoryEntry]
    ) -> Int {
        var lastUsedByIndex: [Int: TimeInterval] = [:]
        for entry in history {
            lastUsedByIndex[entry.variantIndex] = max(lastUsedByIndex[entry.variantIndex] ?? 0, entry.usedAt)
        }
        var bestIndex = 0
        var bestStamp = TimeInterval.greatestFiniteMagnitude
        for index in 0..<variantCount {
            let stamp = lastUsedByIndex[index] ?? 0
            if stamp < bestStamp {
                bestStamp = stamp
                bestIndex = index
            }
        }
        return bestIndex
    }

    private static func stableHashHex(_ input: String) -> String {
        String(format: "%016llx", stableHash64(input))
    }

    private static func stableHash64(_ input: String) -> UInt64 {
        let prime: UInt64 = 1099511628211
        var hash: UInt64 = 1469598103934665603
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }

    private enum VariationSlot: String {
        case insightLead
        case patternLead
        case implicationLead
        case actionLead
    }

    private struct VariationTone {
        let insightLeads: [String]
        let patternLeads: [String]
        let implicationLeads: [String]
        let actionLeads: [String]

        func select(slot: VariationSlot, variationSeed: String) -> String {
            let options: [String]
            switch slot {
            case .insightLead:
                options = insightLeads
            case .patternLead:
                options = patternLeads
            case .implicationLead:
                options = implicationLeads
            case .actionLead:
                options = actionLeads
            }
            guard !options.isEmpty else { return "" }
            let slotHash = GuidanceEngine.stableHash64("\(variationSeed)|\(slot.rawValue)")
            let index = Int(slotHash % UInt64(options.count))
            return options[index]
        }
    }

    private static func boundedWords(_ text: String, maxWords: Int) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count > maxWords else { return text }
        return words.prefix(maxWords).joined(separator: " ")
    }

    private static func selectTemplate(
        from templates: [GuidanceTemplate],
        habitID: UUID,
        state: GuidanceType,
        stateKey: String,
        now: Date,
        calendar: Calendar,
        store: GuidanceRotationStoring
    ) -> GuidanceTemplate {
        guard !templates.isEmpty else {
            return GuidanceTemplate(
                id: "fallback-momentum-1",
                title: "Your pattern is still forming",
                action: "A short session now keeps this on track",
                openingToken: "your"
            )
        }

        let habitKey = habitID.uuidString
        var snapshot = store.snapshot()
        let dayStart = calendar.startOfDay(for: now).timeIntervalSince1970

        let recentHistory = (snapshot.historyByHabitID[habitKey] ?? [])
            .filter { now.timeIntervalSince1970 - $0.usedAt < rotationLookback }
        let recentIDs = Set(recentHistory.map(\.templateID))
        let lastTwoOpenings = Array(recentHistory.suffix(2).map(\.openingToken))
        let lastTemplateID = recentHistory.last?.templateID

        let available = templates.filter { !recentIDs.contains($0.id) }
        let pool = available.isEmpty ? templates : available
        let constrained = pool.filter { candidate in
            let avoidsSameOpening = !(lastTwoOpenings.count == 2 && lastTwoOpenings.allSatisfy { $0 == candidate.openingToken })
            let avoidsImmediateRepeat = candidate.id != lastTemplateID
            return avoidsSameOpening && avoidsImmediateRepeat
        }
        let selected = (constrained.isEmpty ? pool : constrained)[0]

        snapshot.currentAssignmentByHabitID[habitKey] = GuidanceAssignment(
            templateID: selected.id,
            type: state,
            dayStamp: dayStart,
            stateKey: stateKey
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

    private static func nowState(
        timePosition: TimePosition,
        confidence: GuidanceConfidence
    ) -> GuidanceNowState {
        if confidence == .low {
            return .forming
        }
        switch timePosition {
        case .beforeOptimal:
            return .before
        case .inOptimal:
            return .during
        case .afterOptimal, .unknown:
            return .after
        }
    }

    private static func confidenceBand(from confidence: Double) -> GuidanceConfidence {
        switch confidence {
        case ..<0.35:
            return .low
        case ..<0.75:
            return .medium
        default:
            return .high
        }
    }

    private static func strongestWindowLabel(expectedHour: Int?) -> String {
        guard let expectedHour else { return "--" }
        return timeWindowLabel(for: expectedHour)
    }

    private static func nowTemplates(for state: GuidanceNowState) -> [GuidanceTemplate] {
        switch state {
        case .before:
            return [
                template("before-1", "Your strongest window is approaching", "A short session now keeps this on track"),
                template("before-2", "You’re heading into your strongest window", "Starting now builds momentum for later"),
                template("before-3", "Your peak time is coming up", "A quick check-in now moves this forward")
            ]
        case .during:
            return [
                template("during-1", "You’re in your strongest window", "This is the best moment to log"),
                template("during-2", "This is your peak time", "Lean into this window"),
                template("during-3", "You’re in your peak window", "A quick check-in now moves this forward")
            ]
        case .after:
            return [
                template("after-1", "Your strongest window has passed", "A quick check-in still counts"),
                template("after-2", "You’re outside your usual window", "Showing up now keeps the rhythm alive"),
                template("after-3", "You’re past your peak window", "A short session now keeps momentum building")
            ]
        case .forming:
            return [
                template("forming-1", "Keep this check-in simple", "A short session now keeps this moving"),
                template("forming-2", "Consistency grows from repetition", "A quick check-in now reinforces the routine"),
                template("forming-3", "Keep this lightweight today", "Simple follow-through is enough right now")
            ]
        }
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
                template("risk-1", "You haven’t done this today", atRiskNudge(for: input)),
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
        consistencyDaysCompleted: Int,
        consistencyDaysAvailable: Int,
        calendar: Calendar
    ) -> GuidanceSelectionContext {
        let currentHour = calendar.component(.hour, from: input.now)
        let optimalSummary = TimeOfDayPerformanceService.peakTimingSummary(
            habitLogs: input.completionHistory,
            globalLogs: input.globalHistory,
            habitName: input.habit.name,
            habitType: input.goalType,
            now: input.now,
            calendar: calendar
        )
        let hasReliableTimingSignal = {
            guard let optimalSummary else { return false }
            return optimalSummary.uniqueEventCount >= 3 && optimalSummary.confidence >= 0.15
        }()
        let optimalPeakHour = hasReliableTimingSignal ? optimalSummary?.peakHour : nil
        let timingConfidence = hasReliableTimingSignal ? (optimalSummary?.confidence ?? 0) : 0
        let optimalBucket = optimalPeakHour.map(bucket(for:))
        let cutoffHour = cutoffHour(for: optimalPeakHour, currentHour: currentHour)
        let isWithinWindow = optimalPeakHour.map { wrappedHourDistance(currentHour, $0) <= 2 } ?? false
        let beforeWindow = optimalPeakHour.map { isBeforePeak(currentHour: currentHour, peakHour: $0) } ?? false
        let currentTimePosition = timePosition(
            now: input.now,
            optimalPeakHour: optimalPeakHour,
            hasBehaviour: optimalBucket != nil && timingConfidence >= 0.5,
            calendar: calendar
        )

        return GuidanceSelectionContext(
            expectedHour: optimalPeakHour,
            isWithinWindow: timingConfidence >= 0.5 ? isWithinWindow : false,
            isNearPeak: timingConfidence >= 0.5 ? isWithinWindow : false,
            windowPassed: timingConfidence >= 0.5 ? (!isWithinWindow && !beforeWindow) : false,
            timingConfidence: timingConfidence,
            behaviourBucket: optimalBucket,
            optimalBucket: optimalBucket,
            timePosition: currentTimePosition,
            cutoffHour: cutoffHour,
            activeDays: max(0, consistencyDaysCompleted),
            windowDays: max(1, consistencyDaysAvailable),
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
        let lowercased = "\(output.title) \(output.action)".lowercased()
        guard forbiddenFragments.allSatisfy({ !lowercased.contains($0) }) &&
                identityFragments.allSatisfy({ !lowercased.contains($0) }) else {
            let fallbackPayload = GuidancePayload(
                state: .forming,
                strongestWindow: "--",
                confidence: .low,
                guidance: "Keep this check-in simple. A short session now keeps this on track",
                explanation: "State FORMING, confidence LOW, strongest window --"
            )
            return GuidanceOutput(
                id: "fallback-safe",
                title: "Keep this check-in simple",
                action: "A short session now keeps this on track",
                supportingContext: nil,
                emphasisLabel: nil,
                type: .momentum,
                payload: fallbackPayload
            )
        }
        return output
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
                type: output.type,
                payload: output.payload
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
            type: output.type,
            payload: output.payload
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
            "around midday",
            "early morning",
            "morning",
            "afternoon",
            "evening",
            "night",
            "at night",
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
        for expectedHour: Int?,
        currentHour: Int
    ) -> Int {
        if let expectedHour {
            return min(max(expectedHour + 4, 18), 22)
        }
        return currentHour >= 18 ? currentHour : 18
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

    private nonisolated static func bucket(for hour: Int) -> TimeBucket {
        switch hour {
        case 5..<8:
            return .earlyMorning
        case 8..<11:
            return .morning
        case 11..<15:
            return .midday
        case 15..<19:
            return .afternoon
        case 19..<23:
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
        "Activity clusters \(bucketPhrase(for: bucket))"
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
            return "at night"
        }
    }

    private static func guidanceTitle(
        for position: TimePosition,
        confidence: Double,
        optimalBucket: TimeBucket?
    ) -> String {
        if confidence < 0.5 {
            if let optimalBucket {
                return "Best window is \(bucketPhrase(for: optimalBucket))"
            }
            return "Your best window is still forming"
        }

        switch position {
        case .inOptimal:
            return "You’re in your strongest window"
        case .beforeOptimal:
            return "Your strongest window is approaching"
        case .afterOptimal:
            return "Your strongest window has passed"
        case .unknown:
            return "Your best window is still forming"
        }
    }

    private static func guidanceAction(
        for position: TimePosition,
        confidence: Double,
        optimalBucket: TimeBucket?
    ) -> String {
        if confidence < 0.5 {
            if optimalBucket != nil {
                return "A short session now keeps this moving"
            }
            return "A short session now keeps this on track"
        }

        switch position {
        case .inOptimal:
            return "A short session now keeps this on track"
        case .beforeOptimal:
            return "A short session now sets you up before peak time"
        case .afterOptimal:
            return "A short version now keeps momentum intact"
        case .unknown:
            return "A short session now keeps this on track"
        }
    }

    private static func timePosition(
        now: Date,
        optimalPeakHour: Int?,
        hasBehaviour: Bool,
        calendar: Calendar
    ) -> TimePosition {
        guard hasBehaviour, let optimalPeakHour else { return .unknown }
        let nowHour = calendar.component(.hour, from: now)
        if wrappedHourDistance(nowHour, optimalPeakHour) <= 2 {
            return .inOptimal
        } else if isBeforePeak(currentHour: nowHour, peakHour: optimalPeakHour) {
            return .beforeOptimal
        }
        return .afterOptimal
    }

    private static func wrappedHourDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let raw = abs(lhs - rhs)
        return min(raw, 24 - raw)
    }

    private static func isBeforePeak(currentHour: Int, peakHour: Int) -> Bool {
        let forwardDistance = (peakHour - currentHour + 24) % 24
        return forwardDistance > 0 && forwardDistance <= 12
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
