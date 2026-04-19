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
    static let shared = AICoachService()

    let loadingText = "Thinking…"
    private let fallbackGuidance = "Pattern still forming. Keep the next step clear and repeatable."
    private var generationTask: Task<Void, Never>?
    private var requestSequence: UInt64 = 0
    private var lastRequestKey: String?

    @MainActor
    func generate(
        input: AICoachInput,
        requestKey: String,
        onComplete: @escaping @MainActor (String) -> Void
    ) {
        guard requestKey != lastRequestKey else { return }
        lastRequestKey = requestKey

        let clean = sanitized(input)

        print("AI: publish start at \(Date())")

        generationTask?.cancel()
        requestSequence &+= 1
        let sequence = requestSequence

        generationTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            guard let result = await self.run(clean, sequence: sequence) else { return }
            print("AI: main actor hop at \(Date())")
            await MainActor.run {
                print("AI: publish end at \(Date())")
                onComplete(result)
            }
        }
    }

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
            todayStatus: input.todayStatus.isEmpty ? "not completed yet" : input.todayStatus,
            behaviourSummary: input.behaviourSummary.isEmpty ? "Pattern still forming." : input.behaviourSummary
        )
    }

    private static func buildPrompt(from input: AICoachInput) -> String {
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
        - Maximum 30 words total
        - Do NOT mention scores, percentages, or metrics
        - Convert everything into natural behaviour language
        - Only mention time if it is not "none"
        - Only mention stacking if it is not "none"
        - Use the habit name naturally
        - Focus on the single strongest signal only
        - Do NOT mention secondary patterns, dips, or weaker signals
        - Remove any unnecessary qualifiers (e.g. "consistent", "clear")
        - Use direct, confident phrasing
        - Prefer fewer words over more explanation
        - The strongest time window represents where the habit most reliably occurs and must be treated as a positive anchor, not a weakness
        - Do not contradict the provided signals
        - Do not invent or infer times that are not explicitly provided
        - Use natural verbs that match real behaviour (e.g. "happens", "shows up", "occurs")
        - Avoid artificial verbs like "test", "execute", "perform"
        - Match tone to State:
          - STRONG = confident, stable, reinforcing
          - BUILD/START = exploratory
        
        State handling:
        - The State represents the user’s identity and is the primary truth
        - If State is START:
          - Treat behaviour as just beginning
          - Keep guidance simple and easy to act on
        - If State is BUILD:
          - Reinforce repetition and early consistency
          - Keep guidance light and supportive
        - If State is STEADY:
          - Treat behaviour as forming into a routine
          - Encourage stabilisation
        - If State is STRONG:
          - Treat behaviour as consistent and reliable
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
        - Sentence 1 must reflect the dominant (strongest) observed pattern
        - Sentence 2 should reinforce or stabilise the pattern, not repeat or restate it

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
