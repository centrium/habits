import Foundation
import Combine

@MainActor
final class HabitUIStateStore: ObservableObject {
    @Published var progressByHabitAndDate: [String: Double] = [:]
    @Published var completionByHabitAndDate: [String: Bool] = [:]

    func key(habitId: UUID, date: Date) -> String {
        "\(habitId.uuidString)-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
    }

    func setProgress(habitId: UUID, date: Date, progress: Double, isComplete: Bool) {
        let key = key(habitId: habitId, date: date)
        progressByHabitAndDate[key] = progress
        completionByHabitAndDate[key] = isComplete
    }

    func reconcileProgress(habitId: UUID, date: Date, progress: Double, isComplete: Bool) {
        let key = key(habitId: habitId, date: date)
        let existingProgress = progressByHabitAndDate[key]
        let existingComplete = completionByHabitAndDate[key]
        guard existingProgress != progress || existingComplete != isComplete else { return }
        progressByHabitAndDate[key] = progress
        completionByHabitAndDate[key] = isComplete
    }

    func progress(habitId: UUID, date: Date) -> Double? {
        progressByHabitAndDate[key(habitId: habitId, date: date)]
    }

    func isComplete(habitId: UUID, date: Date) -> Bool? {
        completionByHabitAndDate[key(habitId: habitId, date: date)]
    }

    func clear(habitId: UUID, date: Date) {
        let key = key(habitId: habitId, date: date)
        progressByHabitAndDate.removeValue(forKey: key)
        completionByHabitAndDate.removeValue(forKey: key)
    }

    func clearIfPresent(habitId: UUID, date: Date) {
        let key = key(habitId: habitId, date: date)
        let hasProgress = progressByHabitAndDate[key] != nil
        let hasCompletion = completionByHabitAndDate[key] != nil
        guard hasProgress || hasCompletion else { return }
        progressByHabitAndDate.removeValue(forKey: key)
        completionByHabitAndDate.removeValue(forKey: key)
    }
}
