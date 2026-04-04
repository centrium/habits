//
//  HabitConsistencyWidget.swift
//  HabitsWidget
//

import Foundation
import SwiftUI
import WidgetKit

struct HabitConsistencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitConsistencyEntry {
        HabitConsistencyEntry(
            date: Date(),
            snapshot: WidgetConsistencySnapshot(
                days: previewDays,
                activeDayCount: previewDays.filter { $0.intensity > 0 }.count,
                lastActiveDayIndex: previewDays.lastIndex(where: { $0.intensity > 0 })
            ),
            hasHabits: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitConsistencyEntry) -> Void) {
        let habits = WidgetDataStore.shared.load()
        completion(makeEntry(from: habits, date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitConsistencyEntry>) -> Void) {
        let now = Date()
        let habits = WidgetDataStore.shared.load()
        let entry = makeEntry(from: habits, date: now)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry(from habits: [WidgetHabit], date: Date) -> HabitConsistencyEntry {
        HabitConsistencyEntry(
            date: date,
            snapshot: makeWidgetConsistencySnapshot(from: habits, referenceDate: date),
            hasHabits: !habits.isEmpty
        )
    }

    private var previewDays: [WidgetHeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previewIntensities = [0, 1, 2, 4, 3, 2, 4]

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -6 + offset, to: today) else {
                return nil
            }
            return WidgetHeatmapDay(date: date, intensity: previewIntensities[offset])
        }
    }
}

struct HabitConsistencyEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetConsistencySnapshot
    let hasHabits: Bool
}

struct HabitConsistencyWidgetEntryView: View {
    let entry: HabitConsistencyEntry

    var body: some View {
        WidgetContainer(
            title: "Consistency",
            trailingValue: nil
        ) {
            if entry.hasHabits {
                MicroGraph(days: entry.snapshot.days)

                Text("7 Day View")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No habits yet")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Add a habit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct HabitConsistencyWidget: Widget {
    let kind: String = WidgetDataStore.consistencyWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitConsistencyProvider()) { entry in
            HabitConsistencyWidgetEntryView(entry: entry)
                .widgetSurface()
        }
        .configurationDisplayName("Consistency")
        .description("Your 7-day pattern.")
        .supportedFamilies([.systemSmall])
    }
}
