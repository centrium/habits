import Foundation
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AICoachService: ObservableObject {
    static let shared = AICoachService()

    @Published var text: String = "Loading..."

    private let fallbackText = "Hello world — let’s get started."

    func generateHelloWorld() {
        Task {
            await runHelloWorld()
        }
    }

    private func runHelloWorld() async {
        let prompt = "Say hello world like a premium habit coach."

        do {
            let result = try await generateFromAppleIntelligence(prompt: prompt)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            self.text = trimmed.isEmpty ? fallbackText : trimmed
        } catch {
            self.text = fallbackText
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
