//
//  HabitsWidget.swift
//  HabitsWidget
//
//  Created by Matt Adams on 20/03/2026.
//

import Foundation
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> HabitsEntry {
        HabitsEntry(date: Date(), habits: WidgetDataStore.shared.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitsEntry) -> Void) {
        completion(HabitsEntry(date: Date(), habits: WidgetDataStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitsEntry>) -> Void) {
        let entry = HabitsEntry(date: Date(), habits: WidgetDataStore.shared.load())
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct HabitsEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
}

struct HabitsWidgetEntryView: View {
    let entry: HabitsEntry

    private var todayHabits: [WidgetHabit] {
        Array(entry.habits.prefix(3))
    }

    private var incompleteCount: Int {
        entry.habits.filter { !$0.hasActivityToday }.count
    }

    var body: some View {
        WidgetContainer(
            title: "Today",
            trailingValue: "\(incompleteCount)"
        ) {
            if todayHabits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No habits yet")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text("Add a habit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(todayHabits, id: \.id) { habit in
                        Link(destination: habit.deepLinkURL) {
                            TodayRow(name: habit.name, isCompleted: habit.hasActivityToday)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct HabitsWidget: Widget {
    let kind: String = WidgetDataStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HabitsWidgetEntryView(entry: entry)
                .widgetSurface()
        }
        .configurationDisplayName("Today")
        .description("Your habits for today.")
        .supportedFamilies([.systemMedium])
    }
}
