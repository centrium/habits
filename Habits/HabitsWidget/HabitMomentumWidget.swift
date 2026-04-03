//
//  HabitIdentityStateWidget.swift
//  HabitsWidget
//
//  Created by Codex on 25/03/2026.
//

import AppIntents
import WidgetKit
import SwiftUI
import Foundation

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
        Group {
            if let habit = entry.habit {
                HabitIdentityStateCard(habit: habit)
                    .widgetURL(identityStateDeepLinkURL(for: habit))
            } else {
                EmptyHabitIdentityStateCard()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HabitIdentityStateCard: View {
    let habit: WidgetHabit

    private var summary: WidgetIdentityStateSummary {
        habit.identityStateSummary
    }

    var body: some View {
        VStack(spacing: WidgetSpacing.identityClusterSpacing) {
            Text(habit.name)
                .font(WidgetTypography.tertiary)
                .foregroundStyle(WidgetColors.habitName)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            VStack(spacing: WidgetSpacing.identityTextSpacing) {
                Text(summary.shortLabel)
                    .font(WidgetTypography.identityState)
                    .foregroundStyle(WidgetColors.identityStateText(summary.state))
                    .lineLimit(1)

                Text(summary.recentCompletionText)
                    .font(WidgetTypography.identitySupport)
                    .foregroundStyle(WidgetColors.identitySupportText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: WidgetMetrics.identityAnimationDuration), value: summary.shortLabel)
    }
}

private struct EmptyHabitIdentityStateCard: View {
    var body: some View {
        VStack(spacing: WidgetSpacing.verticalStack) {
            Text("Choose a habit")
                .font(WidgetTypography.identityEmptyTitle)
                .foregroundStyle(WidgetColors.emptyPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Pick one in Edit Widget")
                .font(WidgetTypography.identityEmptySubtitle)
                .foregroundStyle(WidgetColors.secondaryText)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
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
        .configurationDisplayName("Cadence: Identity State")
        .description("Track your current identity state.")
        .supportedFamilies([.systemSmall])
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

private func identityStateDeepLinkURL(for habit: WidgetHabit) -> URL {
    URL(string: "habits://habit/\(habit.id.uuidString)")!
}
