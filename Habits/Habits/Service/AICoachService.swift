import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AICoachInput: Sendable {
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
    struct AICoachCache {
        let text: String
        let generatedAt: Date
    }

    static let shared = AICoachService()

    let loadingText = "Thinking…"
    private let fallbackGuidance = "Your timing signal is becoming clearer as you keep showing up. Keep today’s check-in light and specific so this routine stays easy to repeat."
    private let cacheTTL: TimeInterval = 60 * 60
    private var generationTask: Task<Void, Never>?
    private var requestSequence: UInt64 = 0
    private var lastRequestKey: String?
    private var cacheByHabitID: [UUID: AICoachCache] = [:]

    @MainActor
    func generate(
        habitID: UUID,
        input: AICoachInput,
        requestKey: String,
        onComplete: @escaping @MainActor (String) -> Void
    ) {
        guard requestKey != lastRequestKey else { return }
        lastRequestKey = requestKey

        let clean = sanitized(input)
        if let cached = cachedText(habitID: habitID) {
            onComplete(cached)
            return
        }

        print("AI: publish start at \(Date())")

        generationTask?.cancel()
        requestSequence &+= 1
        let sequence = requestSequence

        generationTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            guard let result = await self.run(clean, sequence: sequence) else { return }
            print("AI: main actor hop at \(Date())")
            await MainActor.run {
                self.updateCache(
                    habitID: habitID,
                    text: result,
                    generatedAt: .now
                )
                print("AI: publish end at \(Date())")
                onComplete(result)
            }
        }
    }

    @MainActor
    private func cachedText(
        habitID: UUID,
        now: Date = .now
    ) -> String? {
        guard let entry = cacheByHabitID[habitID] else { return nil }
        if now.timeIntervalSince(entry.generatedAt) >= cacheTTL {
            cacheByHabitID.removeValue(forKey: habitID)
            return nil
        }
        return entry.text
    }

    @MainActor
    private func updateCache(
        habitID: UUID,
        text: String,
        generatedAt: Date = .now
    ) {
        cacheByHabitID[habitID] = AICoachCache(
            text: text,
            generatedAt: generatedAt
        )
    }

    @MainActor
    func cachedTextIfFresh(
        habitID: UUID,
        now: Date = .now
    ) -> String? {
        cachedText(habitID: habitID, now: now)
    }

    @MainActor
    private func resetCache() {
        cacheByHabitID.removeAll()
        generationTask?.cancel()
        generationTask = nil
        requestSequence = 0
        lastRequestKey = nil
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
        generatedAt: Date = .now
    ) {
        updateCache(habitID: habitID, text: text, generatedAt: generatedAt)
    }

    @MainActor
    func resetCacheForTesting() {
        resetCache()
    }
#endif

    func sanitized(_ input: AICoachInput) -> AICoachInput {
        AICoachInput(
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

    nonisolated private static func buildPrompt(from input: AICoachInput) -> String {
        let strongest = input.strongestTime ?? "none"
        let weakest = input.weakestTime ?? "none"
        let stacking = input.stacking ?? "none"
        let identity = input.identity ?? "none"

        return """
        You are an AI habit coach inside a premium app.

        You interpret behaviour and express it simply. You never explain metrics.

        Habit: \(input.habitName)

        Recent activity:
        \(input.recentLogs)

        Patterns:
        - State: \(input.state.rawValue.uppercased())
        - Timing Confidence: \(input.timingConfidence.rawValue.uppercased())
        - Strongest time: \(strongest)
        - Weakest time: \(weakest)
        - Streak: \(input.streakState)

        Identity:
        \(identity)

        Stacking:
        \(stacking)

        Context:
        - Today: \(input.todayStatus)
        - Behaviour: \(input.behaviourSummary)

        ---

        Write exactly 2 sentences.

        Rules:
        - Target 28-45 words total
        - Minimum 2 full sentences
        - Do NOT mention scores, percentages, or metrics
        - Convert everything into natural behaviour language
        - Only mention time if it is not "none"
        - Only mention stacking if it is not "none"
        - Use the habit name naturally
        - Focus on the single strongest signal only
        - Do NOT mention dips or weak windows
        - Use direct, confident phrasing
        - Be concise but substantial enough to feel complete
        - The strongest time window represents where the habit most reliably occurs and must be treated as a positive anchor, not a weakness
        - Do not contradict the provided signals
        - Do not invent or infer times that are not explicitly provided
        - Do not infer behaviour beyond provided state
        - Do not upgrade identity language beyond the provided State
        - Use natural verbs that match real behaviour (e.g. "happens", "shows up", "occurs")
        - Avoid artificial verbs like "test", "execute", "perform"
        - Avoid generic motivational lines
        - Avoid empty praise and filler
        - Use the phrase "strongest window" when mentioning timing
        - Match tone to State:
          - STRONG = confident, reinforcing
          - BUILD/START = exploratory
        - Never describe the habit as stable, strong, or consistent unless State is STEADY or STRONG
        - Use state language:
          - START: "forming" or "early stage"
          - BUILD: "building" or "taking shape"
          - STEADY: "consistent"
          - STRONG: "locked in"

        State handling:
        - The State represents the user’s identity and is the primary truth
        - If State is START:
          - Treat behaviour as just beginning
          - Keep guidance simple and easy to act on
        - If State is BUILD:
          - Reinforce repetition and early consistency
          - Keep guidance light and supportive
        - If State is STEADY:
          - Treat behaviour as consistent and reliable
          - Encourage reinforcement
        - If State is STRONG:
          - Treat behaviour as locked in
          - Use confident, reinforcing language
        - If State is SLIP:
          - Acknowledge drop-off without judgment
          - Focus on re-engagement
        - If State is REBUILD:
          - Focus on regaining rhythm
          - Keep guidance simple and achievable

        Timing handling:
        - Timing Confidence defines how reliable the time pattern is
        - If timing is LOW:
          - Treat time as emerging
          - Do not give precise optimisation
        - If timing is HIGH:
          - Use strongest time as a clear anchor

        Rules:
        - Never contradict the State
        - Never downgrade a strong state due to weak timing

        Structure:
        - Sentence 1: state the concrete behaviour pattern, grounded in timing/logging behaviour.
        - Sentence 2: give a calm, specific nudge for today that reinforces consistency or identity.

        Tone:
        - Calm, sharp, observational
        - No filler, no hype, no coaching clichés

        Avoid:
        - "consider"
        - "you should"
        - "keep going"
        - "momentum indicates"
        - any generic phrasing

        Return only the 2 sentences.
        """
    }

    private func run(_ input: AICoachInput, sequence: UInt64) async -> String? {
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else { return nil }

        print("AI: start at \(Date())")

        let prompt = await Task.detached(priority: .background) {
            Self.buildPrompt(from: input)
        }.value

        do {
            let result = try await generateFromAppleIntelligence(prompt: prompt)
            guard !Task.isCancelled, await isCurrent(sequence: sequence) else { return nil }
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            print("AI: end at \(Date())")
            return trimmed.isEmpty ? fallbackGuidance : trimmed
        } catch {
            guard !Task.isCancelled, await isCurrent(sequence: sequence) else { return nil }
            print("AI: end at \(Date())")
            return fallbackGuidance
        }
    }

    private func isCurrent(sequence: UInt64) async -> Bool {
        await MainActor.run { sequence == self.requestSequence }
    }

    private func generateFromAppleIntelligence(prompt: String) async throws -> String {
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
    }
}

private enum AICoachError: Error {
    case unavailable
}
