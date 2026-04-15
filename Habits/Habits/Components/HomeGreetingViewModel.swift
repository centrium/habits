import Dispatch
import Foundation

final class HomeGreetingViewModel {
    private let greetingService: GreetingService
    private let nameService: NameService

    init(
        greetingService: GreetingService,
        nameService: NameService
    ) {
        self.greetingService = greetingService
        self.nameService = nameService
    }

    convenience init() {
        self.init(
            greetingService: GreetingService.shared,
            nameService: NameService.shared
        )
    }

    func initialDisplayText() -> String {
        greetingService.sessionGreeting()
    }

    func resolveDisplayText(completion: @escaping (String) -> Void) {
        let greeting = greetingService.sessionGreeting()

        DispatchQueue.global(qos: .utility).async { [nameService] in
            let firstName = nameService.resolvedFirstName()
            let text = Self.displayText(greeting: greeting, firstName: firstName)
            DispatchQueue.main.async {
                completion(text)
            }
        }
    }

    static func displayText(greeting: String, firstName: String?) -> String {
        guard let firstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !firstName.isEmpty else {
            return greeting
        }

        return "\(greeting), \(firstName)"
    }
}
