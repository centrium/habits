import Foundation
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AICoachInput {
    let habitName: String
    let recentLogs: String
    let strongestTime: String?
    let weakestTime: String?
    let momentum: String
    let momentumConfidence: String
    let consistency: Int?
    let streakState: String
    let identity: String?
    let stacking: String?
    let todayStatus: String
    let behaviourSummary: String
}

@MainActor
final class AICoachService: ObservableObject {
    static let shared = AICoachService()

    @Published var text: String = ""
    @Published var isLoading: Bool = false

    let loadingText = "Thinking…"
    private let fallbackGuidance = "Pattern still forming. Keep the next step clear and repeatable."
    private var generationTask: Task<Void, Never>?
    private var requestSequence: UInt64 = 0
    private var lastRequestKey: String?

    func generate(input: AICoachInput, requestKey: String) {
        guard requestKey != lastRequestKey else { return }
        lastRequestKey = requestKey

        let clean = sanitized(input)

        // Clear stale text immediately so prior output never flashes while loading.
        text = ""
        isLoading = true

        generationTask?.cancel()
        requestSequence &+= 1
        let sequence = requestSequence

        generationTask = Task {
            await run(clean, sequence: sequence)
        }
    }

    func sanitized(_ input: AICoachInput) -> AICoachInput {
        AICoachInput(
            habitName: input.habitName.isEmpty ? "This habit" : input.habitName,
            recentLogs: input.recentLogs.isEmpty ? "Recent activity is limited." : input.recentLogs,
            strongestTime: input.strongestTime,
            weakestTime: input.weakestTime,
            momentum: input.momentum.isEmpty ? "stable" : input.momentum,
            momentumConfidence: input.momentumConfidence.isEmpty ? "forming" : input.momentumConfidence,
            consistency: input.consistency,
            streakState: input.streakState.isEmpty ? "forming" : input.streakState,
            identity: input.identity,
            stacking: input.stacking,
            todayStatus: input.todayStatus.isEmpty ? "not completed yet" : input.todayStatus,
            behaviourSummary: input.behaviourSummary.isEmpty ? "Pattern still forming." : input.behaviourSummary
        )
    }

    func buildPrompt(from input: AICoachInput) -> String {
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
        - Strongest time: \(strongest)
        - Weakest time: \(weakest)
        - Momentum: \(input.momentum)
        - Momentum confidence: \(input.momentumConfidence)
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
        
        Confidence handling:

        - If confidence is LOW or "forming":
          - Treat patterns as emerging, not established
          - Use softer, observational language (e.g. "appears", "is starting to")
          - Do not present timing as fixed or reliable
          - Do not introduce corrective actions based on weak signals
          - Focus on reinforcing a single visible behaviour without overfitting

        - If confidence is MEDIUM:
          - Treat patterns as directional but not fully stable
          - You may reference the strongest time as a useful anchor
          - Keep guidance light and flexible, not rigid

        - If confidence is HIGH:
          - Treat patterns as reliable and repeatable
          - Use confident, direct phrasing
          - Reinforce the strongest time or stacking behaviour as a stable anchor
          - Guidance can be more decisive and structured

        Structure:
        - Sentence 1 must reflect the dominant (strongest) observed pattern
        - Sentence 2: give a precise directional nudge

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

    private func run(_ input: AICoachInput, sequence: UInt64) async {
        let prompt = buildPrompt(from: input)

        do {
            let result = try await generateFromAppleIntelligence(prompt: prompt)
            guard !Task.isCancelled, sequence == requestSequence else { return }
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            isLoading = false
            text = trimmed.isEmpty ? fallbackGuidance : trimmed
        } catch {
            guard !Task.isCancelled, sequence == requestSequence else { return }
            isLoading = false
            text = fallbackGuidance
        }
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
