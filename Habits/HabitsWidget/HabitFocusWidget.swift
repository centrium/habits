//
//  HabitFocusWidget.swift
//  HabitsWidget
//
//  Created by Codex on 25/03/2026.
//

import WidgetKit
import SwiftUI
import Foundation

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
        Group {
            switch entry.state {
            case .needsAttention(let habit):
                HabitFocusCard(habit: habit)
                    .widgetURL(habit.deepLinkURL)
            case .allComplete(let primaryHabit, let completedCount):
                HabitFocusAllDoneState(accent: primaryHabit.widgetAccentColor, completedCount: completedCount)
            case .noHabits:
                HabitFocusEmptyState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HabitFocusCard: View {
    let habit: WidgetHabit

    private var state: WidgetFocusState {
        .needsAttention(habit)
    }

    var body: some View {
        VStack(spacing: WidgetSpacing.verticalStack) {
            Text(state.titleText)
                .font(WidgetTypography.tertiary)
                .foregroundStyle(WidgetColors.habitName)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            WidgetHabitIndicator(habit: habit, accent: habit.widgetAccentColor, style: .focusHero)

            Text(state.subtitleText)
                .font(WidgetTypography.secondary)
                .foregroundStyle(WidgetColors.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
        .multilineTextAlignment(.center)
    }
}

private struct HabitFocusAllDoneState: View {
    let accent: Color
    let completedCount: Int

    private var state: WidgetFocusState {
        .allComplete(primaryHabit: .focusPreview, completedCount: completedCount)
    }

    var body: some View {
        VStack(spacing: WidgetSpacing.verticalStack) {
            Text(state.titleText)
                .font(WidgetTypography.primary)
                .foregroundStyle(WidgetColors.score)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            WidgetCompletionDot(accent: accent, style: .focusCelebration)

            Text(state.subtitleText)
                .font(WidgetTypography.secondary)
                .foregroundStyle(WidgetColors.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
        .multilineTextAlignment(.center)
    }
}

private struct HabitFocusEmptyState: View {
    private let state: WidgetFocusState = .noHabits

    var body: some View {
        VStack(spacing: WidgetSpacing.verticalStack) {
            Text(state.titleText)
                .font(WidgetTypography.primary)
                .foregroundStyle(WidgetColors.emptyPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(state.subtitleText)
                .font(WidgetTypography.secondary)
                .foregroundStyle(WidgetColors.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(WidgetSpacing.containerPadding)
        .multilineTextAlignment(.center)
    }
}

struct HabitFocusWidget: Widget {
    let kind: String = WidgetDataStore.focusWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitFocusProvider()) { entry in
            if #available(iOS 17.0, *) {
                HabitFocusWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HabitFocusWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Cadence: Focus")
        .description("See what needs your attention today.")
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
        colorHex: "#1F7A8C",
        momentumScore: 28
    )
}
