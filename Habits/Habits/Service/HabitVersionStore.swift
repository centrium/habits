import Combine
import Foundation

final class HabitVersionStore: ObservableObject {
    @Published private(set) var versions: [UUID: Int] = [:]

    func bump(for habitId: UUID) {
        versions[habitId, default: 0] += 1
    }

    func version(for habitId: UUID) -> Int {
        versions[habitId, default: 0]
    }
}
