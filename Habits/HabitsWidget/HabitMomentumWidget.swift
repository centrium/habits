//
//  HabitMomentumWidget.swift
//  HabitsWidget
//
//  Created by Codex on 25/03/2026.
//

import AppIntents
import WidgetKit
import SwiftUI
import Foundation

struct HabitMomentumProvider: AppIntentTimelineProvider {
    typealias Intent = HabitSelectionIntent

    func placeholder(in context: Context) -> HabitMomentumEntry {
        HabitMomentumEntry(date: Date(), habit: .momentumPreview)
    }

    func snapshot(for configuration: HabitSelectionIntent, in context: Context) async -> HabitMomentumEntry {
        let habits = WidgetDataStore.shared.load()
        return HabitMomentumEntry(
            date: Date(),
            habit: resolveHabit(from: habits, configuration: configuration)
        )
    }

    func timeline(for configuration: HabitSelectionIntent, in context: Context) async -> Timeline<HabitMomentumEntry> {
        let habits = WidgetDataStore.shared.load()
        let entry = HabitMomentumEntry(
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

struct HabitMomentumEntry: TimelineEntry {
    let date: Date
    let habit: WidgetHabit?
}

struct HabitMomentumWidgetEntryView: View {
    let entry: HabitMomentumEntry

    var body: some View {
        Group {
            if let habit = entry.habit {
                HabitMomentumCard(habit: habit)
                    .widgetURL(momentumDeepLinkURL(for: habit))
            } else {
                EmptyHabitMomentumCard()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HabitMomentumCard: View {
    let habit: WidgetHabit

    private var momentum: WidgetMomentumSummary {
        habit.momentumSummary
    }

    var body: some View {
        VStack(spacing: WidgetSpacing.momentumClusterSpacing) {
            Text(habit.name)
                .font(WidgetTypography.tertiary)
                .foregroundStyle(WidgetColors.habitName)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            VStack(spacing: WidgetSpacing.momentumTextSpacing) {
                WidgetScoreText(score: momentum.score)

                VStack(spacing: WidgetSpacing.momentumTextSpacing) {
                    Text(momentum.state.rawValue)
                        .font(WidgetTypography.momentumState)
                        .foregroundStyle(WidgetColors.momentumStateText(momentum.state))
                        .lineLimit(1)

                    Text(momentum.direction.summaryText)
                        .font(WidgetTypography.momentumTrend)
                        .foregroundStyle(WidgetColors.momentumDirectionText(momentum.direction))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: WidgetMetrics.momentumAnimationDuration), value: momentum.score)
    }
}

private struct EmptyHabitMomentumCard: View {
    var body: some View {
        VStack(spacing: WidgetSpacing.verticalStack) {
            Text("Choose a habit")
                .font(WidgetTypography.momentumEmptyTitle)
                .foregroundStyle(WidgetColors.emptyPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Pick one in Edit Widget")
                .font(WidgetTypography.momentumEmptySubtitle)
                .foregroundStyle(WidgetColors.secondaryText)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
    }
}

struct HabitMomentumWidget: Widget {
    let kind: String = WidgetDataStore.momentumWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HabitSelectionIntent.self,
            provider: HabitMomentumProvider()
        ) { entry in
            HabitMomentumWidgetEntryView(entry: entry)
                .widgetSurface()
        }
        .configurationDisplayName("Cadence: Momentum")
        .description("Track your current momentum.")
        .supportedFamilies([.systemSmall])
    }
}

private extension WidgetHabit {
    static let momentumPreview = WidgetHabit(
        id: UUID(),
        name: "Read",
        isCompleteToday: false,
        streak: 4,
        goalType: .goal,
        progress: 0.7,
        hasActivityToday: true,
        iconName: "book.closed.fill",
        colorHex: "#1F7A8C",
        momentumScore: 72,
        recentActivity: momentumPreviewActivity
    )

    static var momentumPreviewActivity: [WidgetActivitySample] {
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

private func momentumDeepLinkURL(for habit: WidgetHabit) -> URL {
    URL(string: "habits://habit/\(habit.id.uuidString)")!
}
