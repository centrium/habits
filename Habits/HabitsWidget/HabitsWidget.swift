//
//  HabitsWidget.swift
//  HabitsWidget
//
//  Created by Matt Adams on 20/03/2026.
//

import WidgetKit
import SwiftUI
import Foundation

func selectTopHabits(_ habits: [WidgetHabit]) -> [WidgetHabit] {
    selectTopWidgetHabits(habits)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> HabitsEntry {
        let habits = WidgetDataStore.shared.load()
        let selected = selectTopHabits(habits)
        return HabitsEntry(date: Date(), habits: selected)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitsEntry) -> Void) {
        let habits = WidgetDataStore.shared.load()
        let selected = selectTopHabits(habits)
        completion(HabitsEntry(date: Date(), habits: selected))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitsEntry>) -> Void) {
        let habits = WidgetDataStore.shared.load()
        let selected = selectTopHabits(habits)
        let entry = HabitsEntry(date: Date(), habits: selected)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct HabitsEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
}

struct HabitsWidgetEntryView: View {
    var entry: HabitsEntry
    private let displayedHabitsCount = 3
    private var displayedHabits: [WidgetHabit] {
        Array(entry.habits.prefix(displayedHabitsCount))
    }

    var body: some View {
        Group {
            if displayedHabits.isEmpty {
                VStack(spacing: WidgetSpacing.verticalStack) {
                    Text("No habits yet")
                        .font(WidgetTypography.mediumEmptyTitle)
                        .foregroundStyle(WidgetColors.emptyPrimary)
                    Text("Add a habit")
                        .font(WidgetTypography.mediumEmptySubtitle)
                        .foregroundStyle(WidgetColors.secondaryText)
                        .lineLimit(2)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: WidgetSpacing.mediumListSpacing) {
                    ForEach(Array(displayedHabits.enumerated()), id: \.element.id) { index, habit in
                        Link(destination: habit.deepLinkURL) {
                            HabitWidgetRow(
                                habit: habit,
                                isPrimaryRow: index == 0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, WidgetSpacing.mediumHorizontalPadding)
        .padding(.top, WidgetSpacing.mediumTopPadding)
        .padding(.bottom, WidgetSpacing.mediumBottomPadding)
    }
}

private struct HabitWidgetRow: View {
    let habit: WidgetHabit
    let isPrimaryRow: Bool

    var body: some View {
        HStack(alignment: .center, spacing: WidgetSpacing.mediumRowContentSpacing) {
            Image(systemName: habit.widgetSymbolName)
                .font(WidgetTypography.mediumRowSymbol)
                .foregroundStyle(iconColor)
                .frame(width: WidgetSpacing.mediumIconWidth, height: WidgetSpacing.mediumIconWidth)
                .offset(y: WidgetSpacing.opticalIconLift)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(nameFont)
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if isPrimaryRow, habit.streak > 0 {
                    Text(streakText)
                        .font(WidgetTypography.mediumRowStreak)
                        .foregroundStyle(WidgetColors.secondaryText)
                        .lineLimit(1)
                        .accessibilityLabel("Streak \(habit.streak)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WidgetHabitIndicator(habit: habit, accent: accentColor, style: .medium)
                .frame(width: WidgetSpacing.mediumIndicatorColumnWidth, alignment: .trailing)
                .offset(y: WidgetSpacing.opticalIconLift)
        }
        .frame(maxWidth: .infinity, minHeight: WidgetSpacing.mediumRowHeight, alignment: .leading)
    }

    private var accentColor: Color {
        habit.widgetAccentColor
    }

    private var streakText: String {
        "Streak \(habit.streak)"
    }

    private var nameColor: Color {
        WidgetColors.mediumRowName(isPrimaryRow: isPrimaryRow)
    }

    private var nameFont: Font {
        isPrimaryRow ? WidgetTypography.mediumRowPrimaryName : WidgetTypography.mediumRowSecondaryName
    }

    private var iconColor: Color {
        WidgetColors.mediumIcon(
            accent: accentColor,
            isPrimaryRow: isPrimaryRow,
            isCompleteToday: habit.isCompleteToday
        )
    }
}

private extension WidgetHabit {
    var widgetSymbolName: String {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "circle.grid.2x2.fill" : trimmed
    }
}

struct HabitsWidget: Widget {
    let kind: String = WidgetDataStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HabitsWidgetEntryView(entry: entry)
                .widgetSurface()
        }
        .configurationDisplayName("Cadence: Today")
        .description("Your key cadences at a glance.")
        .supportedFamilies([.systemMedium])
    }
}
