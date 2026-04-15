import Foundation

final class GreetingService {
    static let shared = GreetingService()

    private let calendar: Calendar
    private let lock = NSLock()
    private var cachedSessionGreeting: String?

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func currentGreeting(date: Date) -> String {
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Hello"
        }
    }

    func sessionGreeting(date: Date = .now) -> String {
        lock.lock()
        defer { lock.unlock() }

        if let cachedSessionGreeting {
            return cachedSessionGreeting
        }

        let greeting = currentGreeting(date: date)
        cachedSessionGreeting = greeting
        return greeting
    }
}
