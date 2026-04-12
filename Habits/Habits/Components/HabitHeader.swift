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
    static let contentSpacing: CGFloat = 8
    static let trailingControlSpacing: CGFloat = 8
    static let streakToTitleSpacing: CGFloat = 3
    static let streakToCTASpacing: CGFloat = 12
    static let iconSize: CGFloat = 40
    static let titleSubtitleSpacing: CGFloat = 1
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
        self.secondaryTextOverride = secondaryTextOverride
        self.currentStreak = currentStreak
        self.trailingAccessory = trailingAccessory
        self.onQuickLog = onQuickLog
        self.onQuickLogLongPress = onQuickLogLongPress
    }

    private var iconAccent: Color { habit.curatedColorVariants.base }
    private var actionAccent: Color { habit.curatedColorVariants.strong }

    private var subtitleText: String {
        if let secondaryTextOverride, !secondaryTextOverride.isEmpty {
            return secondaryTextOverride
        }

        let trimmed = habit.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }

        return habit.logs.isEmpty ? "Tap to log" : ""
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

    private var validatedCurrentStreak: Int? {
        guard let currentStreak, currentStreak > 0 else { return nil }
        return currentStreak
    }

    private var streakContext: StreakIndicatorPresentation.Context {
        let displayStreak = max(0, validatedCurrentStreak ?? 0)
        let today = CurrentDayResolver.currentDay(calendar: calendar)
        let isTodayComplete = habit.isComplete(
            for: today,
            calendar: calendar,
            weekStartPreference: weekStartPreference
        )

        return StreakIndicatorPresentation.context(
            displayStreak: displayStreak,
            isTodayComplete: isTodayComplete,
            now: Date(),
            calendar: calendar
        )
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
                accent: iconAccent,
                habitName: habit.name,
                size: HabitRowGrid.iconSize
            )
            .frame(width: HabitRowGrid.iconSize, height: HabitRowGrid.iconSize)
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center]
            }

            VStack(alignment: .leading, spacing: HabitRowGrid.titleSubtitleSpacing) {
                Text(habit.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.system(size: 14))
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if streakContext.showBadge {
                    HabitUnifiedStreakIndicator(context: streakContext)
                        .offset(y: -1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 0)

            Group {
                if isReordering, let trailingAccessory {
                    trailingAccessory
                        .transition(.opacity.combined(with: .scale))
                } else if shouldShowQuickLogButton {
                    GoalProgressButton(
                        accent: actionAccent,
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

private struct HabitUnifiedStreakIndicator: View {
    @Environment(\.colorScheme) private var colorScheme

    let context: StreakIndicatorPresentation.Context
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(flameColor)
                    .baselineOffset(1)

                Text(StreakIndicatorPresentation.valueText(for: context.streak))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(numberColor)
            }
            .monospacedDigit()

            HStack(spacing: 5) {
                ForEach(Array(context.directionalDots.dots.enumerated()), id: \.offset) { index, dot in
                    Circle()
                        .fill(dotFillColor(for: dot, isNextAction: index == nextActionDotIndex))
                        .frame(width: 6, height: 6)
                        .overlay {
                            if dot.isAtRisk {
                                Circle()
                                    .strokeBorder(riskRingColor, lineWidth: 1)
                            } else if index == nextActionDotIndex, !dot.isFilled {
                                Circle()
                                    .strokeBorder(nextActionRingColor, lineWidth: 0.9)
                            } else if dot.isToday && !dot.isFilled {
                                Circle()
                                    .strokeBorder(todayRingColor, lineWidth: 1)
                            }
                        }
                        .animation(.easeOut(duration: 0.35), value: context.directionalDots.filledCount)
                }
            }
            .baselineOffset(0.75)
        }
        .frame(height: 18, alignment: .center)
        .scaleEffect(pulseScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak \(context.streak)")
        .onChange(of: context.streak) { oldValue, newValue in
            guard newValue > oldValue else { return }
            triggerStreakPulse()
        }
    }

    private var flameColor: Color {
        if context.isAtRisk {
            return colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.64)
        }
        return colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.58)
    }

    private var numberColor: Color {
        if context.isAtRisk {
            return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.72)
        }
        return colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.66)
    }

    private var nextActionDotIndex: Int? {
        context.directionalDots.dots.firstIndex { !$0.isFilled }
    }

    private func dotFillColor(
        for dot: StreakIndicatorPresentation.DirectionalDots.Dot,
        isNextAction: Bool
    ) -> Color {
        if dot.isFilled {
            return colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.54)
        }

        if dot.isAtRisk {
            return colorScheme == .dark ? Color.white.opacity(0.34) : Color.black.opacity(0.26)
        }

        if isNextAction {
            return colorScheme == .dark ? Color.white.opacity(0.27) : Color.black.opacity(0.2)
        }

        if dot.isToday {
            return colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.18)
        }

        return colorScheme == .dark ? Color.white.opacity(0.17) : Color.black.opacity(0.14)
    }

    private var todayRingColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.26) : Color.black.opacity(0.18)
    }

    private var riskRingColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.34) : Color.black.opacity(0.24)
    }

    private var nextActionRingColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.14)
    }

    private func triggerStreakPulse() {
        withAnimation(.easeOut(duration: 0.16)) {
            pulseScale = 1.06
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeOut(duration: 0.16)) {
                pulseScale = 1
            }
        }
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
