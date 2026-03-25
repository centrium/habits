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
                    Text("Add your first habit")
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
                                isPrimaryRow: index == 0,
                                showsDivider: index < displayedHabits.count - 1
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
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: WidgetSpacing.mediumRowContentSpacing) {
                Image(systemName: habit.widgetSymbolName)
                    .font(WidgetTypography.mediumRowSymbol)
                    .foregroundStyle(iconColor)
                    .frame(width: WidgetSpacing.mediumIconWidth, height: WidgetSpacing.mediumIconWidth)

                Text(habit.name)
                    .font(WidgetTypography.mediumRowName)
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                if habit.streak > 0 {
                    Text(streakText)
                        .font(WidgetTypography.mediumRowStreak)
                        .foregroundStyle(WidgetColors.secondaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("Streak \(habit.streak)")
                }

                WidgetHabitIndicator(habit: habit, accent: accentColor, style: .medium)
                    .frame(width: WidgetSpacing.mediumIndicatorColumnWidth, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, minHeight: WidgetSpacing.mediumRowHeight, alignment: .leading)
            .opacity(rowOpacity)

            if showsDivider {
                Rectangle()
                    .fill(WidgetColors.mediumDivider)
                    .frame(height: WidgetSpacing.mediumDividerHeight)
                    .padding(.leading, WidgetSpacing.mediumIconWidth + WidgetSpacing.mediumRowContentSpacing)
            }
        }
    }

    private var accentColor: Color {
        habit.widgetAccentColor
    }

    private var streakText: String {
        "Streak \(habit.streak)"
    }

    private var nameColor: Color {
        WidgetColors.mediumRowName(isCompleteToday: habit.isCompleteToday)
    }

    private var iconColor: Color {
        WidgetColors.mediumIcon(accent: accentColor, isCompleteToday: habit.isCompleteToday)
    }

    private var rowOpacity: Double {
        isPrimaryRow ? WidgetMetrics.mediumPrimaryRowOpacity : WidgetMetrics.mediumSecondaryRowOpacity
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
            if #available(iOS 17.0, *) {
                HabitsWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HabitsWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Cadence: Today")
        .description("Your key habits at a glance.")
        .supportedFamilies([.systemMedium])
    }
}
