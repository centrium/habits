import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AICoachInput: Sendable {
    let coachingInput: CoachingInput
    let depth: CoachingDepth
    let selectedSignals: SelectedCoachingSignals
    let habitName: String
    let recentLogs: String
    let state: HabitState
    let timingConfidence: TimingConfidence
    let strongestTime: String?
    let weakestTime: String?
    let streakState: String
    let identity: String?
    let stacking: String?
    let todayStatus: String
    let behaviourSummary: String
}

final class AICoachService {
    enum FailureReason: Equatable {
        case timeout
        case unavailable
        case emptyResult
        case cancelled
        case serviceDeallocated
        case internalError
    }

    enum DiscardReason: Equatable {
        case stale
    }

    enum Outcome: Equatable {
        case success(String)
        case failure(FailureReason)
        case discarded(DiscardReason)
    }

    struct AICoachCache {
        let text: String
        let generatedAt: Date
        let fingerprint: String?
        let depth: CoachingDepth?
    }

    static let shared = AICoachService()

    let loadingText = "Thinking…"
    private let generationTimeout: TimeInterval
    private let cacheTTL: TimeInterval = 60 * 60
    private var generationTask: Task<Void, Never>?
    private var requestSequence: UInt64 = 0
    private var lastRequestKey: String?
    private var cacheByHabitID: [UUID: AICoachCache] = [:]
#if DEBUG
    private var runOverrideForTesting: (@Sendable (AICoachInput, UInt64) async -> Outcome)?
#endif

    init(generationTimeout: TimeInterval = 8.0) {
        self.generationTimeout = generationTimeout
    }

    @MainActor
    func generate(
        habitID: UUID,
        input: AICoachInput,
        fingerprint: String,
        requestKey: String,
        isStillCurrent: (@MainActor @Sendable () -> Bool)? = nil,
        onTerminal: @escaping @MainActor (Outcome) -> Void
    ) {
        guard requestKey != lastRequestKey else {
            onTerminal(.discarded(.stale))
            return
        }
        lastRequestKey = requestKey

        let clean = sanitized(input)
        if let cached = cachedText(
            habitID: habitID,
            fingerprint: fingerprint,
            depth: input.depth
        ) {
            onTerminal(.success(cached))
            return
        }

        print("AI: publish start at \(Date())")

        generationTask?.cancel()
        requestSequence &+= 1
        let sequence = requestSequence

        generationTask = Task.detached(priority: .background) { [weak self] in
            guard let self else {
                await MainActor.run {
                    onTerminal(.failure(.serviceDeallocated))
                }
                return
            }
            let outcome = await self.resolveWithTimeout(clean, sequence: sequence)
            print("AI: main actor hop at \(Date())")
            await MainActor.run {
                guard sequence == self.requestSequence else {
                    onTerminal(.discarded(.stale))
                    return
                }
                if let isStillCurrent, isStillCurrent() == false {
                    onTerminal(.discarded(.stale))
                    return
                }
                if case .success(let result) = outcome {
                    self.updateCache(
                        habitID: habitID,
                        text: result,
                        fingerprint: fingerprint,
                        depth: input.depth,
                        generatedAt: .now
                    )
                }
                print("AI: publish end at \(Date())")
                onTerminal(outcome)
            }
        }
    }

    @MainActor
    private func cachedText(
        habitID: UUID,
        fingerprint: String? = nil,
        depth: CoachingDepth? = nil,
        now: Date = .now
    ) -> String? {
        guard let entry = cacheByHabitID[habitID] else { return nil }
        if now.timeIntervalSince(entry.generatedAt) >= cacheTTL {
            cacheByHabitID.removeValue(forKey: habitID)
            return nil
        }
        if let fingerprint, entry.fingerprint != fingerprint {
            return nil
        }
        if let depth, entry.depth != depth {
            return nil
        }
        return entry.text
    }

    @MainActor
    private func updateCache(
        habitID: UUID,
        text: String,
        fingerprint: String? = nil,
        depth: CoachingDepth? = nil,
        generatedAt: Date = .now
    ) {
        cacheByHabitID[habitID] = AICoachCache(
            text: text,
            generatedAt: generatedAt,
            fingerprint: fingerprint,
            depth: depth
        )
    }

    @MainActor
    func cachedTextIfFresh(
        habitID: UUID,
        fingerprint: String? = nil,
        depth: CoachingDepth? = nil,
        now: Date = .now
    ) -> String? {
        cachedText(
            habitID: habitID,
            fingerprint: fingerprint,
            depth: depth,
            now: now
        )
    }

    @MainActor
    private func resetCache() {
        cacheByHabitID.removeAll()
        generationTask?.cancel()
        generationTask = nil
        requestSequence = 0
        lastRequestKey = nil
#if DEBUG
        runOverrideForTesting = nil
#endif
    }

#if DEBUG
    @MainActor
    func cachedTextForTesting(
        habitID: UUID,
        now: Date = .now
    ) -> String? {
        cachedText(habitID: habitID, now: now)
    }

    @MainActor
    func updateCacheForTesting(
        habitID: UUID,
        text: String,
        fingerprint: String? = nil,
        depth: CoachingDepth? = nil,
        generatedAt: Date = .now
    ) {
        updateCache(
            habitID: habitID,
            text: text,
            fingerprint: fingerprint,
            depth: depth,
            generatedAt: generatedAt
        )
    }

    @MainActor
    func resetCacheForTesting() {
        resetCache()
    }

    @MainActor
    func setRunOverrideForTesting(
        _ block: (@Sendable (AICoachInput, UInt64) async -> Outcome)?
    ) {
        runOverrideForTesting = block
    }

    func outputReferencesSelectedSignalsForTesting(_ output: String, input: AICoachInput) -> Bool {
        outputReferencesSelectedSignals(output, input: input)
    }
#endif

    func sanitized(_ input: AICoachInput) -> AICoachInput {
        AICoachInput(
            coachingInput: input.coachingInput,
            depth: input.depth,
            selectedSignals: input.selectedSignals,
            habitName: input.habitName.isEmpty ? "This habit" : input.habitName,
            recentLogs: input.recentLogs.isEmpty ? "Recent activity is limited." : input.recentLogs,
            state: input.state,
            timingConfidence: input.timingConfidence,
            strongestTime: input.strongestTime,
            weakestTime: input.weakestTime,
            streakState: input.streakState.isEmpty ? "forming" : input.streakState,
            identity: input.identity,
            stacking: input.stacking,
            todayStatus: input.todayStatus.isEmpty ? "Not yet today" : input.todayStatus,
            behaviourSummary: input.behaviourSummary.isEmpty ? "Routine is still forming." : input.behaviourSummary
        )
    }

    private static func buildPrompt(from input: AICoachInput) -> String {
        let strongest = input.coachingInput.timeOfDayInsights.strongestWindow ?? "none"
        let signalHints = input.selectedSignals.all
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
        let depthInstruction: String = {
            switch input.depth {
            case .basic:
                return """
                If basic:
                - Use ONE selected signal only
                - Write 1-2 sentences (max 30 words)
                - Focus on immediate action
                - Structure: observation + action
                """
            case .premium:
                return """
                If premium:
                - Use 2 selected signals if available
                - Write 2-3 sentences (max 45 words)
                - Structure: observation + pattern/implication + action
                - Include horizon language like "over the past \(max(1, input.coachingInput.windowDays)) days"
                """
            }
        }()

        return """
        You are generating coaching for a habit tracking app.

        Habit: \(input.habitName)
        Selected signals: \(signalHints)
        Data:
        - Identity state: \(input.coachingInput.identityState.rawValue)
        - Streak state: \(input.coachingInput.streakState)
        - Consistency: \(input.coachingInput.consistency)%
        - Strongest window: \(strongest)
        - Timing confidence: \(input.coachingInput.timeOfDayInsights.confidence.rawValue)
        - Recent behaviour: \(input.coachingInput.recentBehaviourSummary)
        - Today status: \(input.coachingInput.todayStatus)

        You MUST:
        - Use ONLY the provided CoachingInput and selected signals
        - Explicitly reference the selected signal(s) in the output
        - Clearly mention each selected signal in concrete terms; if one is missing, the output is invalid
        - Match the tone of a calm, observant coach
        - Be concise, natural, specific, and non-generic
        - Never invent data or generalize beyond provided signals

        \(depthInstruction)

        Style:
        - Observational, not motivational
        - Calm, not energetic
        - Slightly understated
        - Specific, not vague
        - Avoid robotic transitions like "that suggests" or "this indicates"

        Bad examples:
        - "Keep going, you're doing great"
        - "Stay consistent and you will succeed"
        - "That suggests your routine is improving"

        Good examples:
        - "You're most consistent in the evening. Stick with that window again today."
        - "Over the past \(max(1, input.coachingInput.windowDays)) days, you usually show up in the evening. This is starting to hold with less effort, so use that window again today."

        Return only coaching text.
        """
    }

    private func run(_ input: AICoachInput, sequence: UInt64) async -> Outcome {
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else {
            if await isCurrent(sequence: sequence) {
                return .failure(.cancelled)
            }
            return .discarded(.stale)
        }

        print("AI: start at \(Date())")

        let prompt = Self.buildPrompt(from: input)

        do {
            let result = try await generateFromAppleIntelligence(prompt: prompt)
            guard !Task.isCancelled else {
                if await isCurrent(sequence: sequence) {
                    return .failure(.cancelled)
                }
                return .discarded(.stale)
            }
            guard await isCurrent(sequence: sequence) else { return .discarded(.stale) }
            var trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if input.depth == .premium, trimmed.wordCount > 40 {
                trimmed = tightenPremiumPhrasing(trimmed)
            }
            if !outputReferencesSelectedSignals(trimmed, input: input) {
                print("AI: soft-fail, allowing output with reduced confidence")
            }
            print("AI: end at \(Date())")
            return trimmed.isEmpty ? .failure(.emptyResult) : .success(trimmed)
        } catch {
            guard !Task.isCancelled else {
                if await isCurrent(sequence: sequence) {
                    return .failure(.cancelled)
                }
                return .discarded(.stale)
            }
            guard await isCurrent(sequence: sequence) else { return .discarded(.stale) }
            print("AI: end at \(Date())")
            if let aiError = error as? AICoachError, case .unavailable = aiError {
                return .failure(.unavailable)
            }
            return .failure(.internalError)
        }
    }

    private func resolveWithTimeout(_ input: AICoachInput, sequence: UInt64) async -> Outcome {
        await withTaskGroup(of: Outcome.self) { group in
            group.addTask { [weak self] in
                guard let self else { return .failure(.serviceDeallocated) }
#if DEBUG
                if let override = await MainActor.run(body: { self.runOverrideForTesting }) {
                    return await override(input, sequence)
                }
#endif
                return await self.run(input, sequence: sequence)
            }
            group.addTask { [weak self] in
                guard let self else { return .failure(.serviceDeallocated) }
                let timeoutNanos = UInt64(max(self.generationTimeout, 0) * 1_000_000_000)
                if timeoutNanos > 0 {
                    try? await Task.sleep(nanoseconds: timeoutNanos)
                }
                guard !Task.isCancelled else { return .discarded(.stale) }
                guard await self.isCurrent(sequence: sequence) else { return .discarded(.stale) }
                return .failure(.timeout)
            }

            let firstResult = await group.next() ?? .failure(.internalError)
            group.cancelAll()
            return firstResult
        }
    }

    func isAppleIntelligenceAvailable() -> Bool {
#if targetEnvironment(simulator)
        guard simulatorRepresentsAppleIntelligenceCapableDevice() else { return false }
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
#endif
        return false
#else
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
#endif
        return false
#endif
    }

    private func isCurrent(sequence: UInt64) async -> Bool {
        await MainActor.run { sequence == self.requestSequence }
    }

    private func generateFromAppleIntelligence(prompt: String) async throws -> String {
#if targetEnvironment(simulator)
        guard simulatorRepresentsAppleIntelligenceCapableDevice() else {
            _ = prompt
            throw AICoachError.unavailable
        }
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw AICoachError.unavailable
            }

            let session = LanguageModelSession(model: model)
            let options = GenerationOptions(
                temperature: 0.4,
                maximumResponseTokens: 120
            )
            let response = try await session.respond(to: prompt, options: options)
            return response.content
        }
#endif
        throw AICoachError.unavailable
#else
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw AICoachError.unavailable
            }

            let session = LanguageModelSession(model: model)
            let options = GenerationOptions(
                temperature: 0.4,
                maximumResponseTokens: 120
            )
            let response = try await session.respond(to: prompt, options: options)
            return response.content
        }
#endif
        throw AICoachError.unavailable
#endif
    }

#if targetEnvironment(simulator)
    private func simulatorRepresentsAppleIntelligenceCapableDevice() -> Bool {
        // SIMULATOR_MODEL_IDENTIFIER examples:
        // iPhone15,2 (14 Pro), iPhone16,1 (15 Pro), iPhone17,1 (16 Pro)
        guard let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] else {
            return false
        }
        guard identifier.hasPrefix("iPhone"),
              let familyToken = identifier
                .split(separator: ",")
                .first?
                .replacingOccurrences(of: "iPhone", with: ""),
              let family = Int(familyToken) else {
            return false
        }

        // Apple Intelligence-capable iPhones start at iPhone16,x (15 Pro generation) and newer.
        return family >= 16
    }
#endif

    private func outputReferencesSelectedSignals(_ output: String, input: AICoachInput) -> Bool {
        if containsGenericMotivationalPhrase(output) {
            #if DEBUG
            print(
                """
                AI Coach Validation Failed
                Reason: generic motivational phrasing
                Output: \(output)
                """
            )
            #endif
            return false
        }

        let normalized = normalizedText(output)
        let lowercased = output.lowercased()
        let missingSignals = input.selectedSignals.all.filter { signal in
            !signalFamilyMatch(
                signal: signal,
                normalizedOutput: normalized,
                rawLowercasedOutput: lowercased,
                input: input
            )
        }
        let selectedSignals = input.selectedSignals.all
        let total = selectedSignals.count
        let matched = total - missingSignals.count
        let matchedSignals = selectedSignals.subtracting(missingSignals)
        let requiresTimingAndConsistency = selectedSignals.contains(.timeOfDayInsights)
            && selectedSignals.contains(.consistency)
        let hasTimingAndConsistency = matchedSignals.contains(.timeOfDayInsights)
            && matchedSignals.contains(.consistency)
        let passesAdherence = missingSignals.isEmpty
            && (!requiresTimingAndConsistency || hasTimingAndConsistency)
        #if DEBUG
        if !passesAdherence {
            let joinedMissing = missingSignals.map(\.rawValue).sorted().joined(separator: ",")
            let joinedMatched = matchedSignals.map(\.rawValue).sorted().joined(separator: ",")
            print(
                """
                AI Coach Validation Failed
                Missing: \(joinedMissing)
                Matched: \(joinedMatched)
                Output: \(output)
                Normalized: \(normalized)
                Matched: \(matched)/\(total)
                Depth: \(input.depth.rawValue)
                """
            )
        }
        #endif
        return passesAdherence
    }

    private func signalFamilyMatch(
        signal: CoachingSignalID,
        normalizedOutput: String,
        rawLowercasedOutput: String,
        input: AICoachInput
    ) -> Bool {
        let terms = signalFamilyTerms(for: signal, input: input)
        if terms.contains(where: { containsSignalTerm($0, in: normalizedOutput) }) {
            return true
        }
        if signal == .timeOfDayInsights, containsExplicitTimeExpression(in: rawLowercasedOutput) {
            return true
        }
        return false
    }

    private func signalFamilyTerms(for signal: CoachingSignalID, input: AICoachInput) -> [String] {
        switch signal {
        case .identityState:
            switch input.coachingInput.identityState {
            case .start:
                return ["forming", "early stage", "starting"]
            case .build:
                return ["building", "taking shape", "developing"]
            case .steady:
                return ["consistent", "reliable", "steady"]
            case .strong:
                return ["locked in", "strong", "stable"]
            case .slip:
                return ["slip", "dropped", "re-engage", "recover"]
            case .rebuild:
                return ["rebuild", "regain", "restore"]
            }
        case .streakState:
            let numericTokens = input.coachingInput.streakState.split(whereSeparator: { !$0.isNumber }).map(String.init)
            return ["streak", "in a row", "consecutive", "momentum", "run"] + numericTokens
        case .consistency:
            return [
                "consistent",
                "consistency",
                "regular",
                "regularly",
                "pattern",
                "routine",
                "rhythm",
                "steady",
                "reliable",
                "\(input.coachingInput.consistency)%"
            ]
        case .timeOfDayInsights:
            var anchors = [
                "morning",
                "afternoon",
                "evening",
                "night",
                "window",
                "time",
                "later",
                "early",
                "after work",
                "after dinner",
                "before bed"
            ]
            if let strongest = input.coachingInput.timeOfDayInsights.strongestWindow?.lowercased(),
               !strongest.isEmpty {
                anchors.append(strongest)
            }
            return anchors
        case .recentBehaviourSummary:
            let summaryTerms = input.coachingInput.recentBehaviourSummary.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count > 4 }
                .prefix(3)
            return ["often", "usually", "tend to", "recently"] + Array(summaryTerms)
        case .todayStatus:
            return ["today"] + input.coachingInput.todayStatus.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count > 3 }
        }
    }

    private func normalizedText(_ text: String) -> String {
        let collapsed = text.lowercased().replacingOccurrences(
            of: "[^a-z0-9%:]+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsSignalTerm(_ term: String, in normalizedOutput: String) -> Bool {
        let cleanedTerm = normalizedText(term)
        guard !cleanedTerm.isEmpty else { return false }
        if normalizedOutput.contains(cleanedTerm) {
            return normalizedOutput.contains(cleanedTerm)
        }
        return false
    }

    private func containsExplicitTimeExpression(in lowercasedOutput: String) -> Bool {
        let pattern = #"(\b([1-9]|1[0-2])\s?(am|pm)\b)|(\b([01]?\d|2[0-3]):[0-5]\d\b)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(lowercasedOutput.startIndex..<lowercasedOutput.endIndex, in: lowercasedOutput)
        return regex.firstMatch(in: lowercasedOutput, options: [], range: range) != nil
    }

    private func containsGenericMotivationalPhrase(_ output: String) -> Bool {
        let normalized = normalizedText(output)
        let genericPhrases = [
            "keep going",
            "you re doing great",
            "you are doing great",
            "stay consistent",
            "you will succeed",
            "you got this",
            "don t give up",
            "dont give up"
        ]
        return genericPhrases.contains { normalized.contains($0) }
    }

    private func tightenPremiumPhrasing(_ text: String) -> String {
        var compressed = text
            .replacingOccurrences(of: "at the moment", with: "")
            .replacingOccurrences(of: "right now", with: "")
            .replacingOccurrences(of: "you can", with: "")
            .replacingOccurrences(of: "very", with: "")
            .replacingOccurrences(of: "really", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compressed.wordCount > 45 {
            compressed = compressed.split(whereSeparator: \.isWhitespace).prefix(45).joined(separator: " ")
        }
        return compressed
    }
}

private extension String {
    var wordCount: Int {
        split(whereSeparator: \.isWhitespace).count
    }
}

private enum AICoachError: Error {
    case unavailable
}
