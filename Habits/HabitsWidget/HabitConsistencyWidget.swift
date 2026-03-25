//
//  HabitConsistencyWidget.swift
//  HabitsWidget
//
//  Created by Codex on 25/03/2026.
//

import WidgetKit
import SwiftUI
import Foundation

struct HabitConsistencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitConsistencyEntry {
        HabitConsistencyEntry(
            date: Date(),
            snapshot: WidgetConsistencySnapshot(
                days: previewDays,
                activeDayCount: previewDays.filter { $0.intensity > 0 }.count,
                lastActiveDayIndex: previewDays.lastIndex(where: { $0.intensity > 0 })
            ),
            accent: WidgetColors.fallbackAccent,
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
            accent: resolveAccent(from: habits),
            hasHabits: !habits.isEmpty
        )
    }

    private func resolveAccent(from habits: [WidgetHabit]) -> Color {
        selectFocusWidgetHabit(habits)?.widgetAccentColor ??
        habits.first?.widgetAccentColor ??
        WidgetColors.fallbackAccent
    }

    private var previewDays: [WidgetHeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -6 + offset, to: today) else {
                return nil
            }

            let previewIntensities = [0, 1, 2, 4, 3, 2, 4]
            return WidgetHeatmapDay(date: date, intensity: previewIntensities[offset])
        }
    }
}

struct HabitConsistencyEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetConsistencySnapshot
    let accent: Color
    let hasHabits: Bool
}

struct HabitConsistencyWidgetEntryView: View {
    let entry: HabitConsistencyEntry

    var body: some View {
        Group {
            if entry.hasHabits {
                VStack(alignment: .leading, spacing: WidgetSpacing.verticalStack) {
                    Text("Consistency")
                        .font(WidgetTypography.primary)
                        .foregroundStyle(WidgetColors.score)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    WidgetHeatmapStrip(days: entry.snapshot.days, accent: entry.accent)

                    Text(entry.snapshot.summaryText)
                        .font(WidgetTypography.secondary)
                        .foregroundStyle(WidgetColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(WidgetSpacing.containerPadding)
            } else {
                HabitConsistencyEmptyState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HabitConsistencyEmptyState: View {
    var body: some View {
        VStack(spacing: WidgetSpacing.verticalStack) {
            Text("No activity yet")
                .font(WidgetTypography.primary)
                .foregroundStyle(WidgetColors.emptyPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("Start building consistency")
                .font(WidgetTypography.secondary)
                .foregroundStyle(WidgetColors.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
        .multilineTextAlignment(.center)
    }
}

struct HabitConsistencyWidget: Widget {
    let kind: String = WidgetDataStore.consistencyWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitConsistencyProvider()) { entry in
            if #available(iOS 17.0, *) {
                HabitConsistencyWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HabitConsistencyWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Cadence: Consistency")
        .description("Your recent activity.")
        .supportedFamilies([.systemSmall])
    }
}
