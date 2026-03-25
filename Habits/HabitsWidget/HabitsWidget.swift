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
        let habits = loadHabits()
        let selected = selectTopHabits(habits)
        return HabitsEntry(date: Date(), habits: selected)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitsEntry) -> Void) {
        let habits = loadHabits()
        let selected = selectTopHabits(habits)
        completion(HabitsEntry(date: Date(), habits: selected))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitsEntry>) -> Void) {
        let habits = loadHabits()
        let selected = selectTopHabits(habits)
        let entry = HabitsEntry(date: Date(), habits: selected)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }

    private func loadHabits() -> [WidgetHabit] {
        guard let defaults = UserDefaults(suiteName: WidgetDataStore.suiteName) else {
            assertionFailure("Shared UserDefaults suite unavailable: \(WidgetDataStore.suiteName)")
            WidgetHabitLogger.logStorageFailure(
                context: "load",
                reason: "Failed to resolve shared UserDefaults suite"
            )
            return []
        }

        guard
            let data = defaults.data(forKey: WidgetDataStore.key)
        else {
            WidgetHabitLogger.logWidgetRead(count: 0)
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([WidgetHabit].self, from: data)
            WidgetHabitLogger.logWidgetRead(count: decoded.count)
            return decoded
        } catch {
            WidgetHabitLogger.logStorageFailure(
                context: "load",
                reason: "Failed to decode widget habits. Raw data size: \(data.count) bytes. Error: \(error.localizedDescription)"
            )
            return  []
        }
    }
}

struct HabitsEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
}

struct HabitsWidgetEntryView: View {
    var entry: HabitsEntry
    private let displayedHabitsCount = 3
    private let rowSpacing: CGFloat = 8
    private var displayedHabits: [WidgetHabit] {
        Array(entry.habits.prefix(displayedHabitsCount))
    }

    var body: some View {
        Group {
            if displayedHabits.isEmpty {
                VStack(spacing: 4) {
                    Text("No habits yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Add your first habit")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: rowSpacing) {
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
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

private struct HabitWidgetRow: View {
    let habit: WidgetHabit
    let isPrimaryRow: Bool
    let showsDivider: Bool
    private let iconContainerWidth: CGFloat = 24
    private let indicatorSize: CGFloat = 18
    private let indicatorColumnWidth: CGFloat = 24
    private let contentSpacing: CGFloat = 10
    private let rowHeight: CGFloat = 46

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: contentSpacing) {
                Image(systemName: habit.widgetSymbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: iconContainerWidth, height: iconContainerWidth)

                Text(habit.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                if habit.streak > 0 {
                    Text(streakText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("Streak \(habit.streak)")
                }

                HabitIndicator(habit: habit, accentColor: accentColor)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .frame(width: indicatorColumnWidth, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
            .opacity(rowOpacity)

            if showsDivider {
                Rectangle()
                    .fill(.secondary.opacity(0.16))
                    .frame(height: 0.5)
                    .padding(.leading, iconContainerWidth + contentSpacing)
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
        habit.isCompleteToday ? .primary.opacity(0.92) : .primary
    }

    private var iconColor: Color {
        habit.isCompleteToday ? accentColor.opacity(0.78) : accentColor
    }

    private var rowOpacity: Double {
        isPrimaryRow ? 1.0 : 0.93
    }
}

private struct HabitIndicator: View {
    let habit: WidgetHabit
    let accentColor: Color
    private let indicatorSize: CGFloat = 18

    var body: some View {
        Group {
            if !habit.hasActivityToday {
                DottedIndicator()
            } else {
                switch habit.goalType {
                case .goal:
                    if habit.goalProgress < 1 {
                        ProgressRing(progress: habit.goalProgress, accentColor: accentColor)
                    } else {
                        CompletionDot(accentColor: accentColor)
                    }
                case .binary, .openEnded:
                    CompletionDot(accentColor: accentColor)
                }
            }
        }
        .frame(width: indicatorSize, height: indicatorSize)
    }
}

private struct CompletionDot: View {
    let accentColor: Color

    var body: some View {
        Circle()
            .fill(accentColor)
            .shadow(color: accentColor.opacity(0.22), radius: 2, x: 0, y: 0)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(width: 18, height: 18)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.secondary.opacity(0.22), lineWidth: 1.8)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}

private struct DottedIndicator: View {
    var body: some View {
        Circle()
            .stroke(
                .secondary.opacity(0.38),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [1.2, 2.2])
            )
            .padding(1.6)
            .frame(width: 18, height: 18)
    }
}

private extension WidgetHabit {
    var deepLinkURL: URL {
        URL(string: "habits://habit/\(id.uuidString)")!
    }

    var widgetSymbolName: String {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "circle.grid.2x2.fill" : trimmed
    }

    var widgetAccentColor: Color {
        guard
            let colorHex,
            let color = Color(widgetHex: colorHex)
        else {
            return .secondary
        }
        return color
    }
}

private extension Color {
    init?(widgetHex: String) {
        var cleaned = widgetHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self = Color(red: red, green: green, blue: blue)
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
                    .background()
            }
        }
        .configurationDisplayName("Today")
        .description("See your most important habits for today.")
        .supportedFamilies([.systemMedium])
    }
}
