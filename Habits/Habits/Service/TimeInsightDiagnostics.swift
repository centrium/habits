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

enum StateConsistencyTraceLogger {
    private struct Signature: Equatable {
        let identity: HabitIdentityState
        let streak: Int
        let consistency: Int
    }

    private struct Record {
        let surface: String
        let signature: Signature
    }

    private static var recordsByHabitID: [UUID: Record] = [:]
    private static let lock = NSLock()
    private static let isRunningTests: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["STATE_CONSISTENCY_DEBUG"]?.lowercased() == "1"
        #else
        false
        #endif
    }

    static func log(
        surface: String,
        habitID: UUID,
        state: HabitComputedState
    ) {
        guard isEnabled else { return }
        let signature = Signature(
            identity: state.identityState,
            streak: state.streakState.currentStreak,
            consistency: state.consistency.percentage
        )

        lock.lock()
        let existing = recordsByHabitID[habitID]
        if let existing, existing.signature != signature {
            print("[State CONSISTENCY MISMATCH]")
            print("habitID: \(habitID.uuidString)")
            print("existingSurface: \(existing.surface)")
            print("existingIdentity: \(existing.signature.identity)")
            print("existingStreak: \(existing.signature.streak)")
            print("existingConsistency: \(existing.signature.consistency)%")
            print("surface: \(surface)")
            print("identity: \(signature.identity)")
            print("streak: \(signature.streak)")
            print("consistency: \(signature.consistency)%")
            recordsByHabitID[habitID] = Record(surface: surface, signature: signature)
            lock.unlock()
            if !isRunningTests {
                assertionFailure("state mismatch across surfaces for habit \(habitID.uuidString)")
            }
            return
        }
        recordsByHabitID[habitID] = Record(surface: surface, signature: signature)
        lock.unlock()

        print("[State CONSISTENCY CHECK]")
        print("surface: \(surface)")
        print("habitID: \(habitID.uuidString)")
        print("identity: \(signature.identity)")
        print("streak: \(signature.streak)")
        print("consistency: \(signature.consistency)% (\(state.consistency.daysCompleted)/\(state.consistency.daysAvailable))")
    }
}
