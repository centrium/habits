//
//  HabitIdentityStateWidget.swift
//  HabitsWidget
//

import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct HabitIdentityStateProvider: AppIntentTimelineProvider {
    typealias Intent = HabitSelectionIntent

    func placeholder(in context: Context) -> HabitIdentityStateEntry {
        HabitIdentityStateEntry(date: Date(), habit: .identityStatePreview)
    }

    func snapshot(for configuration: HabitSelectionIntent, in context: Context) async -> HabitIdentityStateEntry {
        let habits = WidgetDataStore.shared.load()
        return HabitIdentityStateEntry(
            date: Date(),
            habit: resolveHabit(from: habits, configuration: configuration)
        )
    }

    func timeline(for configuration: HabitSelectionIntent, in context: Context) async -> Timeline<HabitIdentityStateEntry> {
        let habits = WidgetDataStore.shared.load()
        let entry = HabitIdentityStateEntry(
            date: Date(),
            habit: resolveHabit(from: habits, configuration: configuration)
        )

        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func resolveHabit(
        from habits: [WidgetHabit],
        configuration: HabitSelectionIntent
    ) -> WidgetHabit? {
        guard !habits.isEmpty else { return nil }

        if let selectedID = configuration.habit?.id,
           let selectedHabit = habits.first(where: { $0.id == selectedID }) {
            return selectedHabit
        }

        return habits.first
    }
}

struct HabitIdentityStateEntry: TimelineEntry {
    let date: Date
    let habit: WidgetHabit?
}

struct HabitIdentityStateWidgetEntryView: View {
    let entry: HabitIdentityStateEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Identity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.systemAccent)

                Spacer()

                if let trailingValue {
                    Text(trailingValue)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 4)

            if let habit = entry.habit {

                // GROUP 1 — Identity + Habit (tight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.identityTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)

                    if shouldShowHabitName(for: habit) {
                        Text(habit.name)
                            .font(.caption2) // slightly smaller = subtitle feel
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                // GROUP 2 — Supporting text (looser)
                VStack(alignment: .leading, spacing: 2) {
                    if let line1 = habit.identityLine1 {
                        Text(line1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let line2 = habit.identityLine2 {
                        Text(line2)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Choose a habit")
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(2)

                Text("is starting")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.systemAccent)
                    .lineLimit(1)

                Text("Pick one in Edit Widget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
        )
        .widgetURL(entry.habit?.deepLinkURL)
    }

    private var trailingValue: String? {
        guard let habit = entry.habit else { return nil }
        return "\(habit.recentCompletionCount(days: 7))/7"
    }

    private func shouldShowHabitName(for habit: WidgetHabit) -> Bool {
        let title = habit.identityTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let name = habit.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !name.isEmpty else { return false }
        return !title.contains(name)
    }
}

struct HabitIdentityStateWidget: Widget {
    let kind: String = WidgetDataStore.identityStateWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HabitSelectionIntent.self,
            provider: HabitIdentityStateProvider()
        ) { entry in
            HabitIdentityStateWidgetEntryView(entry: entry)
                .widgetSurface()
        }
        .configurationDisplayName("Identity")
        .description("A quick identity signal.")
        .supportedFamilies([.systemMedium])
    }
}

private extension WidgetHabit {
    static let identityStatePreview = WidgetHabit(
        id: UUID(),
        name: "Read",
        isCompleteToday: false,
        streak: 4,
        goalType: .goal,
        progress: 0.7,
        hasActivityToday: true,
        iconName: "book.closed.fill",
        colorHex: "#1F7A8C",
        identityState: .building,
        recentActivity: identityStatePreviewActivity
    )

    static var identityStatePreviewActivity: [WidgetActivitySample] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let values = [0.2, 0.3, 0.2, 0.4, 0.3, 0.4, 0.3, 0.3, 0.4, 0.4, 0.5, 0.4, 0.4, 0.4]

        return values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .day, value: -13 + index, to: today) else {
                return nil
            }

            return WidgetActivitySample(date: date, value: value)
        }
    }
}
