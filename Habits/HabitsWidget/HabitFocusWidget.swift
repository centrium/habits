//
//  HabitFocusWidget.swift
//  HabitsWidget
//

import Foundation
import SwiftUI
import WidgetKit

struct HabitFocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitFocusEntry {
        HabitFocusEntry(date: Date(), state: .needsAttention(.focusPreview))
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitFocusEntry) -> Void) {
        let habits = WidgetDataStore.shared.load()
        completion(HabitFocusEntry(date: Date(), state: resolveFocusWidgetState(habits)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitFocusEntry>) -> Void) {
        let habits = WidgetDataStore.shared.load()
        let entry = HabitFocusEntry(date: Date(), state: resolveFocusWidgetState(habits))
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct HabitFocusEntry: TimelineEntry {
    let date: Date
    let state: WidgetFocusState
}

struct HabitFocusWidgetEntryView: View {
    let entry: HabitFocusEntry

    var body: some View {
        switch entry.state {
        case .needsAttention(let habit):
            WidgetContainer(
                title: "Focus",
                trailingValue: habit.streak > 0 ? "\(habit.streak)" : nil
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name)
                        .font(.system(size: 19, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("Show up today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }            }
            .widgetURL(habit.deepLinkURL)

        case .allComplete(_, let completedCount):
            WidgetContainer(
                title: "Focus",
                trailingValue: "\(completedCount)"
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All habits logged")
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Great consistency today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

        case .noHabits:
            WidgetContainer(title: "Focus", trailingValue: nil) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start your first habit")
                        .font(.system(size: 19, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("Build your rhythm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct HabitFocusWidget: Widget {
    let kind: String = WidgetDataStore.focusWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitFocusProvider()) { entry in
            HabitFocusWidgetEntryView(entry: entry)
                .widgetSurface()
        }
        .configurationDisplayName("Focus")
        .description("Your next action.")
        .supportedFamilies([.systemSmall])
    }
}

private extension WidgetHabit {
    static let focusPreview = WidgetHabit(
        id: UUID(),
        name: "Read",
        isCompleteToday: false,
        streak: 6,
        goalType: .goal,
        progress: 0,
        hasActivityToday: false,
        iconName: "book.closed.fill",
        colorHex: CadenceColorPalette.light(for: .teal).base,
        identityState: .rebuilding
    )
}
