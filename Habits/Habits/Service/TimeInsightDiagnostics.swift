import Foundation

enum TimeInsightTraceLogger {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["TIME_INSIGHT_DEBUG"]?.lowercased() == "1"
        #else
        false
        #endif
    }

    static func logConsistency(
        surface: String,
        enginePeak: Int,
        consumerHour: Int
    ) {
        guard isEnabled else { return }
        print("[TimeInsight CONSISTENCY CHECK]")
        print("surface: \(surface)")
        print("enginePeak: \(enginePeak)")
        print("consumerHour: \(consumerHour)")
        print("match: \(consumerHour == enginePeak)")
    }
}
