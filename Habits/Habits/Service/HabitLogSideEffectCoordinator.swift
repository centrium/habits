import Foundation
import SwiftData
import WidgetKit

actor HabitLogSideEffectCoordinator {
    private let modelContainer: ModelContainer
    private var pendingTask: Task<Void, Never>?
    private var pendingHabitIDs: Set<UUID> = []
    private var latestReferenceDate: Date = .now
    private let coalescingDelayNanoseconds: UInt64 = 900_000_000

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func enqueue(habitID: UUID, referenceDate: Date) {
        pendingHabitIDs.insert(habitID)
        latestReferenceDate = max(latestReferenceDate, referenceDate)
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: coalescingDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await self.flush()
        }
    }

    private func flush() async {
        guard !pendingHabitIDs.isEmpty else { return }
        let referenceDate = latestReferenceDate
        pendingHabitIDs.removeAll()
        pendingTask = nil

        let didWriteWidgets = await syncWidgets(referenceDate: referenceDate)
        if didWriteWidgets {
            await reloadWidgetTimelines()
        }
        await syncEveningReflection(referenceDate: referenceDate)
    }

    private func syncWidgets(referenceDate: Date) async -> Bool {
        await withCheckedContinuation { continuation in
            let modelContainer = self.modelContainer
            DispatchQueue.global(qos: .utility).async {
                LoggingPerformanceMonitor.assertHeavyPathOffMainThread(#function)
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.orderIndex)])
                let habits = (try? context.fetch(descriptor)) ?? []
                let widgetHabits = mapToWidgetHabits(
                    habits,
                    referenceDate: referenceDate
                )
                let didWrite = WidgetDataStore.shared.save(widgetHabits)
                continuation.resume(returning: didWrite)
            }
        }
    }

    @MainActor
    private func reloadWidgetTimelines() {
        let widgetKinds = [
            WidgetDataStore.widgetKind,
            WidgetDataStore.identityStateWidgetKind,
            WidgetDataStore.focusWidgetKind,
            WidgetDataStore.consistencyWidgetKind,
        ]

        for kind in widgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    @MainActor
    private func syncEveningReflection(referenceDate: Date) async {
        await NotificationService.shared.syncEveningReflectionFromStoredSettings(
            referenceDate: referenceDate
        )
    }
}
