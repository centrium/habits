import XCTest
import SwiftData
@testable import Habits

@MainActor
final class WidgetHabitIdentityStateTests: BaseTestCase {
    private let calendar = TestDateFactory.utcCalendar
    private var referenceDate: Date { calendar.startOfDay(for: Date()) }

    func testIdentitySummaryUsesStateLabelAndRecentCompletionText() async throws {
        let habit = try await makeProjectedWidgetHabit(
            recentActivityValues: [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1],
            olderActiveDays: 2
        )

        let summary = habit.identityStateSummary

        XCTAssertEqual(summary.state, .building)
        XCTAssertEqual(summary.shortLabel, "Build")
        XCTAssertEqual(summary.recentCompletionText, "5 days this week")
        XCTAssertEqual(summary.insightLine, "This habit is taking shape.")
    }

    func testIdentitySummaryUsesRebuildingInsightCopy() {
        let habit = makeHabit(identityState: .rebuilding, recentActivity: [])

        let summary = habit.identityStateSummary

        XCTAssertEqual(summary.insightLine, "This habit is getting back into it.")
    }

    func testDecodingWithoutIdentityStateDefaultsToStarting() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000099",
          "name": "Read",
          "isCompleteToday": false,
          "streak": 0,
          "goalType": "binary"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WidgetHabit.self, from: json)
        XCTAssertEqual(decoded.identityState, .gettingStarted)
    }

    private func makeHabit(
        identityState: WidgetHabitIdentityState,
        recentActivity: [WidgetActivitySample]
    ) -> WidgetHabit {
        WidgetHabit(
            id: UUID(),
            name: "Habit",
            isCompleteToday: false,
            streak: 0,
            goalType: .binary,
            progress: nil,
            hasActivityToday: false,
            iconName: nil,
            colorHex: nil,
            identityState: identityState,
            recentActivity: recentActivity
        )
    }

    private func makeProjectedWidgetHabit(
        recentActivityValues: [Double],
        olderActiveDays: Int
    ) async throws -> WidgetHabit {
        let persistence = try TestPersistence()
        let habit = TestHabitFactory.frequency(name: "Habit", target: 1, calendar: calendar)
        persistence.insert(habit)
        try persistence.save()

        let uiStateStore = HabitUIStateStore()
        let service = HabitLogService(
            modelContext: persistence.context,
            calendar: calendar,
            uiStateStore: uiStateStore
        )

        for index in 0..<max(olderActiveDays, 0) {
            let oldDay = TestDateFactory.addingDays(-(20 + index), to: referenceDate, calendar: calendar)
            _ = service.addLog(for: habit, on: oldDay, value: 1)
        }

        for (index, value) in recentActivityValues.enumerated() where value > 0 {
            let day = TestDateFactory.addingDays(-13 + index, to: referenceDate, calendar: calendar)
            _ = service.addLog(for: habit, on: day, value: value)
        }

        try await waitForReconciliation(uiStateStore: uiStateStore, habitID: habit.id)

        let descriptor = FetchDescriptor<Habit>()
        let readContext = ModelContext(persistence.container)
        let persistedHabits = try readContext.fetch(descriptor)
        let persistedHabit = try XCTUnwrap(persistedHabits.first(where: { $0.id == habit.id }))
        let widgetHabit = try XCTUnwrap(
            mapToWidgetHabits(
                [persistedHabit],
                referenceDate: referenceDate,
                calendar: calendar,
                weekStartPreference: .monday
            ).first
        )
        return widgetHabit
    }

    private func waitForReconciliation(
        uiStateStore: HabitUIStateStore,
        habitID: UUID,
        timeout: TimeInterval = 4
    ) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if uiStateStore.pendingMutations(for: habitID).isEmpty {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for pending mutations to reconcile")
    }

    private func samples(values: [Double]) -> [WidgetActivitySample] {
        let calendar = TestDateFactory.utcCalendar
        let referenceDate = TestDateFactory.referenceNow

        return values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .day, value: -13 + index, to: referenceDate) else {
                return nil
            }

            return WidgetActivitySample(date: date, value: value)
        }
    }
}
