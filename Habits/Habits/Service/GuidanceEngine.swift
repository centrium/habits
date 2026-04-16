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
                title: "You’re in your usual rhythm",
                action: "Now is a good time to show up",
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
                    template("stacking-2", "Right after \(lowercaseDisplay(triggerName))", "Now is a good moment to follow through"),
                    template("stacking-3", "Natural next step", "Act now while you’re in the flow"),
                    template("stacking-4", "In your usual sequence", "A quick session now will land well")
                ]
            }

            if context.isNearPeak {
                return [
                    template("peak-1", "You’re right near your peak time", "Act now while it’s working for you"),
                    template("peak-2", "This is your strongest window", "Start now while it feels natural"),
                    template("peak-3", "You’re approaching your best time", "Get ready to act"),
                    template("peak-4", "This moment works for you", "Take advantage of it")
                ]
            }

            return [
                template("momentum-1", "You’re in your rhythm", "Now is a good time to show up"),
                template("momentum-2", "This is your strongest window", "Start now while it feels natural"),
                template("momentum-3", "Right moment to act", "Now is a good moment to follow through"),
                template("momentum-4", "This moment works for you", "Take advantage of it"),
                template("momentum-5", "This is your window", "Now is the easiest time to act")
            ]

        case .recovery:
            if input.pattern != nil {
                return [
                    template("recovery-1", "You’ve missed your usual time", "A short session keeps things on track"),
                    template("recovery-2", "This is outside your normal window", "Show up anyway to stay consistent"),
                    template("recovery-3", "The usual moment has passed", "A quick version still counts"),
                    template("recovery-4", "Not your typical time", "But showing up still matters")
                ]
            }

            if context.isNearPeak {
                return [
                    template("recovery-peak-1", "This is just past your strongest window", "Show up now to stay in rhythm"),
                    template("recovery-peak-2", "You’ve missed your usual time", "A short session keeps things on track"),
                    template("recovery-peak-3", "The usual moment has passed", "A quick version still counts")
                ]
            }

            return [
                template("recovery-5", "You’ve missed your usual time", "A short session keeps things on track"),
                template("recovery-6", "This is outside your normal window", "Show up anyway to stay consistent"),
                template("recovery-7", "The usual moment has passed", "A quick version still counts"),
                template("recovery-8", "Not your typical time", "But showing up still matters")
            ]

        case .atRisk:
            return [
                template("risk-1", "You haven’t completed this today", "There’s still time to show up"),
                template("risk-2", "Today’s nearly gone", "A quick session keeps your rhythm"),
                template("risk-3", "You’re running out of time today", "Keep it simple and get it done"),
                template("risk-4", "Even a small effort counts today", "Show up before the day ends")
            ]

        case .identity:
            switch identityState {
            case .gettingStarted:
                return [
                    template("identity-1", "This habit is taking shape", "Stay with it today"),
                    template("identity-2", "You’re building something consistent", "Keep it going today")
                ]
            case .building, .steady:
                return [
                    template("identity-3", "This is becoming part of who you are", "Show up today to reinforce it"),
                    template("identity-4", "You’re building something consistent", "Keep it going today"),
                    template("identity-5", "You’re close to locking this in", "Another check-in strengthens it")
                ]
            case .strong:
                return [
                    template("identity-6", "This is becoming part of who you are", "Show up today to reinforce it"),
                    template("identity-7", "You’re building something consistent", "Keep it going today")
                ]
            case .slipping, .rebuilding:
                return [
                    template("identity-8", "This habit is taking shape", "Stay with it today"),
                    template("identity-9", "You’re building something consistent", "Keep it going today")
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
        } else if let expectedHour = context.expectedHour {
            parts.append(humanTime(for: expectedHour))
        }

        switch type {
        case .momentum:
            parts.append(context.isNearPeak ? "Ideal moment" : "Good timing")
        case .recovery:
            parts.append("Still a good moment")
        case .atRisk:
            parts.append("Time still there")
        case .identity:
            parts.append("\(context.activeDays) of last \(context.windowDays) days")
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
        let timing = expectedWindow(from: input.completionHistory, now: input.now, calendar: calendar)
        let currentHour = calendar.component(.hour, from: input.now)
        let cutoffHour = cutoffHour(for: timing, currentHour: currentHour)

        return GuidanceSelectionContext(
            expectedHour: timing?.expectedHour,
            isWithinWindow: timing.map { currentHour >= $0.windowStart && currentHour <= $0.windowEnd } ?? false,
            isNearPeak: timing.map { abs(currentHour - $0.expectedHour) <= 1 } ?? false,
            windowPassed: timing.map { currentHour > $0.windowEnd } ?? false,
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
        guard forbiddenFragments.allSatisfy({ !lowercased.contains($0) }) else {
            return GuidanceOutput(
                id: "fallback-safe",
                title: "You’re in your rhythm",
                action: "Now is a good time to show up",
                supportingContext: "Good timing",
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

    private static func expectedWindow(
        from logs: [HabitLog],
        now: Date,
        calendar: Calendar
    ) -> TimingWindow? {
        let qualifyingLogs = logs
            .filter { ($0.frequencyContribution > 0 || $0.numericValue > 0) && $0.effectiveTimestamp <= now }
            .sorted { $0.effectiveTimestamp > $1.effectiveTimestamp }

        guard qualifyingLogs.count >= 3 else { return nil }

        let recentHours = qualifyingLogs
            .prefix(10)
            .map { calendar.component(.hour, from: $0.effectiveTimestamp) }

        guard !recentHours.isEmpty else { return nil }

        let averageHour = Int(round(Double(recentHours.reduce(0, +)) / Double(recentHours.count)))
        return TimingWindow(
            expectedHour: averageHour,
            windowStart: max(0, averageHour - 1),
            windowEnd: min(23, averageHour + 1)
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
}
