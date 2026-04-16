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
    let pattern: HabitPattern?
    let goalType: GoalType
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

struct GuidanceSelectionContext: Equatable {
    let expectedHour: Int?
    let isWithinWindow: Bool
    let isNearPeak: Bool
    let windowPassed: Bool
    let timingContextLabel: String?
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

        return validated(
            GuidanceOutput(
                id: template.id,
                title: template.title,
                action: template.action,
                supportingContext: supportingContext(
                    for: chosenType,
                    input: input,
                    context: selectionContext,
                    calendar: calendar
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
                title: "You’re in a strong rhythm",
                action: "A short session now keeps this moving",
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
        for type: GuidanceType,
        input: GuidanceInput,
        context: GuidanceSelectionContext,
        calendar: Calendar
    ) -> String? {
        var parts: [String] = []

        if let anchor = context.pattern?.anchor {
            parts.append(shortContextAnchor(anchor))
        } else if let timingContextLabel = context.timingContextLabel {
            parts.append(timingContextLabel)
        }

        switch type {
        case .momentum:
            parts.append(context.isNearPeak ? "Good timing" : "Works well")
        case .recovery:
            parts.append("Still workable now")
        case .atRisk:
            parts.append("Time is tight")
        case .identity:
            parts.append(
                consistencyLabel(
                    completed: context.activeDays,
                    total: context.windowDays
                )
            )
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
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

        return GuidanceSelectionContext(
            expectedHour: timing?.expectedHour,
            isWithinWindow: timing.map { currentHour >= $0.windowStart && currentHour <= $0.windowEnd } ?? false,
            isNearPeak: timing.map { abs(currentHour - $0.expectedHour) <= 1 } ?? false,
            windowPassed: timing.map { currentHour > $0.windowEnd } ?? false,
            timingContextLabel: timingPattern.contextLabel,
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
                title: "You’re in a strong rhythm",
                action: "A short session now keeps this moving",
                supportingContext: "Works well now",
                emphasisLabel: nil,
                type: .momentum
            )
        }
        return output
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
        let contextLabel: String?
    }

    private enum TimeBucket: CaseIterable {
        case earlyMorning
        case morning
        case midday
        case afternoon
        case evening
        case night
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
            return TimingPattern(window: nil, contextLabel: nil)
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
            return TimingPattern(window: nil, contextLabel: nil)
        }

        let sortedBuckets = counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return bucketOrder(lhs.key) < bucketOrder(rhs.key)
                }
                return lhs.value > rhs.value
            }
        let primaryBucket = primary.key
        let primaryCount = primary.value
        let totalCount = recentHours.count
        let primaryRatio = Double(primaryCount) / Double(max(1, totalCount))

        let secondary: (bucket: TimeBucket, count: Int)? = {
            guard sortedBuckets.count > 1 else { return nil }
            let candidate = sortedBuckets[1]
            return candidate.value >= Int(ceil(Double(primaryCount) * 0.5))
                ? (candidate.key, candidate.value)
                : nil
        }()

        let contextLabel = timingContextLabel(
            primary: primaryBucket,
            secondary: secondary?.bucket,
            totalCount: totalCount,
            primaryRatio: primaryRatio,
            distinctBucketCount: counts.count
        )

        guard totalCount >= 3, primaryRatio >= 0.4 else {
            return TimingPattern(window: nil, contextLabel: contextLabel)
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
            contextLabel: contextLabel
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

    private static func shortContextAnchor(_ value: String) -> String {
        let lowered = lowercaseDisplay(value)
        if lowered.hasSuffix("running") {
            return "After running"
        }
        if lowered.hasPrefix("run") {
            return "Post-run"
        }
        return "After \(lowered)"
    }

    private static func timingContextLabel(
        primary: TimeBucket,
        secondary: TimeBucket?,
        totalCount: Int,
        primaryRatio: Double,
        distinctBucketCount: Int
    ) -> String {
        if totalCount < 3 {
            return "Recently around \(bucketLabel(primary))"
        }

        if distinctBucketCount >= 4 && primaryRatio < 0.4 {
            return "Varies throughout the day"
        }

        if let secondary {
            if totalCount >= 7 && primaryRatio >= 0.6 {
                return "Mostly around \(bucketLabel(primary)), sometimes in the \(bucketLabel(secondary))"
            }
            return "Usually around \(bucketLabel(primary)), sometimes in the \(bucketLabel(secondary))"
        }

        if totalCount >= 7 && primaryRatio >= 0.7 {
            return "Consistently around \(bucketLabel(primary))"
        }
        if totalCount <= 6 {
            return "Usually around \(bucketLabel(primary))"
        }
        return "Often around \(bucketLabel(primary))"
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

    private static func bucketLabel(_ bucket: TimeBucket) -> String {
        switch bucket {
        case .earlyMorning:
            return "early morning"
        case .morning:
            return "morning"
        case .midday:
            return "midday"
        case .afternoon:
            return "afternoon"
        case .evening:
            return "evening"
        case .night:
            return "later at night"
        }
    }

    private static func consistencyLabel(completed: Int, total: Int) -> String {
        let safeCompleted = max(0, completed)
        let safeTotal = max(1, total)

        if safeCompleted == 0 {
            return "Ready to get started"
        }
        if safeCompleted >= safeTotal {
            return "Locked in this week"
        }

        let ratio = Double(safeCompleted) / Double(safeTotal)
        switch ratio {
        case 0.9...:
            return "Strong consistency"
        case 0.7..<0.9:
            return "Consistent this week"
        case 0.5..<0.7:
            return "Building consistency"
        case 0.3..<0.5:
            return "Getting started"
        default:
            return "Just getting going"
        }
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
            return "A few minutes now keeps this going"
        }
        if isFinanceHabit(input.habit) {
            return "Putting something aside now keeps momentum"
        }
        if isFitnessHabit(input.habit) {
            return "A short walk now keeps things moving"
        }
        return "A short session now keeps this moving"
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
            return "A few minutes today keeps this going"
        }
        if isFinanceHabit(input.habit) {
            return "Putting something aside today keeps momentum"
        }
        if isFitnessHabit(input.habit) {
            return "A short walk today keeps things moving"
        }
        return "A short session today keeps this moving"
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
