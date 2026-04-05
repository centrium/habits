//
//  HabitHeader.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//

import SwiftUI

enum HabitRowGrid {
    static let listSafeLeading: CGFloat = 10
    static let cardTrailingInList: CGFloat = 8
    static let spineToCardGutter: CGFloat = 16
    static let contentLeading: CGFloat = 16
    static let contentSpacing: CGFloat = 12
    static let iconSize: CGFloat = 40
    static let titleSubtitleSpacing: CGFloat = 2
    static let headerToHeatmapSpacing: CGFloat = 12
    static let spineOpticalCorrection: CGFloat = -1

    private static let spineBaseXInList: CGFloat = 8

    static var spineXInList: CGFloat {
        spineBaseXInList + spineOpticalCorrection
    }

    static var cardLeadingInList: CGFloat {
        max(listSafeLeading, spineXInList + spineToCardGutter)
    }
}

struct HabitHeader: View {
    @EnvironmentObject private var uiStateStore: HabitUIStateStore

    let habit: Habit
    let selectedDate: Date
    let calendar: Calendar
    let weekStartPreference: WeekStartPreference
    let isReordering: Bool
    let showsQuickLogButton: Bool
    let showsQuickLogForFrequencyHabits: Bool
    let showsInlineProgressText: Bool
    let secondaryTextOverride: String?
    let currentStreak: Int?
    let trailingAccessory: AnyView?
    let onQuickLog: (Date) -> Void
    let onQuickLogLongPress: ((Date) -> Void)?

    init(
        habit: Habit,
        selectedDate: Date,
        calendar: Calendar = .current,
        weekStartPreference: WeekStartPreference = .system,
        isReordering: Bool = false,
        showsQuickLogButton: Bool,
        showsQuickLogForFrequencyHabits: Bool = true,
        showsInlineProgressText: Bool,
        secondaryTextOverride: String?,
        currentStreak: Int? = nil,
        trailingAccessory: AnyView? = nil,
        onQuickLog: @escaping (Date) -> Void,
        onQuickLogLongPress: ((Date) -> Void)? = nil
    ) {
        self.habit = habit
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.weekStartPreference = weekStartPreference
        self.isReordering = isReordering
        self.showsQuickLogButton = showsQuickLogButton
        self.showsQuickLogForFrequencyHabits = showsQuickLogForFrequencyHabits
        self.showsInlineProgressText = showsInlineProgressText
        self.secondaryTextOverride = secondaryTextOverride
        self.currentStreak = currentStreak
        self.trailingAccessory = trailingAccessory
        self.onQuickLog = onQuickLog
        self.onQuickLogLongPress = onQuickLogLongPress
    }

    private var accent: Color { habit.curatedAccentColor }

    private var subtitleText: String {
        if let secondaryTextOverride, !secondaryTextOverride.isEmpty {
            return secondaryTextOverride
        }

        let trimmed = habit.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let progressText = showsInlineProgressText
            ? (habit.inlineProgressText(
                for: selectedDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            ) ?? "")
            : ""

        if !progressText.isEmpty {
            return progressText
        }

        return trimmed.isEmpty ? "Tap to log" : trimmed
    }

    private var iconName: String? {
        let trimmed = habit.iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var goalProgressFraction: Double {
        if let optimistic = uiStateStore.progress(habitId: habit.id, date: selectedDate) {
            return optimistic
        } else {
            return habit.progressFraction(
                for: selectedDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            ) ?? 0
        }
    }

    private var isComplete: Bool {
        if let optimistic = uiStateStore.isComplete(habitId: habit.id, date: selectedDate) {
            return optimistic
        } else {
            return habit.isComplete(
                for: selectedDate,
                calendar: calendar,
                weekStartPreference: weekStartPreference
            )
        }
    }

    private var quickLogAccessibilityLabel: String {
        let dateText = selectedDate.formatted(date: .abbreviated, time: .omitted)
        return "Log \(habit.name) for \(dateText)"
    }

    private var resolvedCurrentStreak: Int {
        max(0, currentStreak ?? 0)
    }

    private var shouldShowQuickLogButton: Bool {
        guard showsQuickLogButton else { return false }
        if habit.goalType == .frequency {
            return showsQuickLogForFrequencyHabits
        }
        return true
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HabitRowGrid.contentSpacing) {
            HabitBadge(
                iconName: iconName,
                accent: accent,
                habitName: habit.name,
                size: HabitRowGrid.iconSize
            )
            .frame(width: HabitRowGrid.iconSize, height: HabitRowGrid.iconSize)
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }

            VStack(alignment: .leading, spacing: HabitRowGrid.titleSubtitleSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(habit.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CadenceTokens.Color.Text.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    HabitHeaderStreakIndicator(streak: resolvedCurrentStreak)
                }

                Text(subtitleText)
                    .font(.system(size: 14))
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer()

            Group {
                if isReordering, let trailingAccessory {
                    trailingAccessory
                        .transition(.opacity.combined(with: .scale))
                } else if shouldShowQuickLogButton {
                    GoalProgressButton(
                        accent: accent,
                        hasGoal: habit.hasGoal,
                        progressFraction: goalProgressFraction,
                        isComplete: isComplete,
                        symbolName: habit.goalType == .cumulative ? "plusminus.circle.fill" : "plus.circle.fill",
                        isSecondaryEmphasis: habit.goalType == .cumulative,
                        accessibilityLabel: quickLogAccessibilityLabel,
                        action: {
                            onQuickLog(selectedDate)
                        },
                        longPressAction: onQuickLogLongPress.map { action in
                            { action(selectedDate) }
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isReordering)
        }
    }
}

private struct HabitHeaderStreakIndicator: View {
    @Environment(\.colorScheme) private var colorScheme
    let streak: Int

    private var showsIndicator: Bool {
        StreakIndicatorPresentation.shouldShow(streak: streak)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(CadenceTokens.Typography.supporting)
                Text("888")
                    .font(CadenceTokens.Typography.supporting.weight(.regular))
            }
            .monospacedDigit()
            .opacity(0)

            if showsIndicator {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(CadenceTokens.Typography.supporting)
                        .foregroundStyle(flameColor)

                    Text(StreakIndicatorPresentation.valueText(for: streak))
                        .font(CadenceTokens.Typography.supporting.weight(.regular))
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                }
                .monospacedDigit()
            }
        }
        .frame(width: StreakIndicatorPresentation.reservedWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsIndicator ? "Streak \(streak)" : "")
        .accessibilityHidden(!showsIndicator)
    }

    private var flameColor: Color {
        colorScheme == .dark
            ? CadenceTokens.Color.State.warning.opacity(0.78)
            : CadenceTokens.Color.State.warning
    }
}

struct HabitHeaderPreview: View {
    let name: String
    let subtitle: String?
    let iconName: String?
    let colorHex: String

    private var accent: Color { HabitColor.from(hex: colorHex).color }

    private var displaySubtitle: String {
        let trimmed = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Optional subtitle" : trimmed
    }

    private var resolvedIcon: String? {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HabitRowGrid.contentSpacing) {
            HabitBadge(
                iconName: resolvedIcon,
                accent: accent,
                habitName: name.isEmpty ? "Habit name" : name,
                size: HabitRowGrid.iconSize
            )
            .frame(width: HabitRowGrid.iconSize, height: HabitRowGrid.iconSize)
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }

            VStack(alignment: .leading, spacing: HabitRowGrid.titleSubtitleSpacing) {
                Text(name.isEmpty ? "Habit name" : name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Text(displaySubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer()
        }
    }
}
