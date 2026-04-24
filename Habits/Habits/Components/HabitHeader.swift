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
    static let iconToTitleSpacing: CGFloat = 13
    static let trailingControlSpacing: CGFloat = 8
    static let streakToTitleSpacing: CGFloat = 3
    static let streakToCTASpacing: CGFloat = 12
    static let iconSize: CGFloat = 36
    static let titleRowHeight: CGFloat = 21
    static let titleToMetaSpacing: CGFloat = 3
    static let titleToSubtitleSpacing: CGFloat = 7
    static let metaRowHeight: CGFloat = 18
    static let subtitleToStreakSpacing: CGFloat = 2
    static let streakIconToValueSpacing: CGFloat = 4
    static let streakValueToDotsSpacing: CGFloat = 7
    static let headerToHeatmapSpacing: CGFloat = 12
    static let spineOpticalCorrection: CGFloat = -1

    private static let spineBaseXInList: CGFloat = 8

    static var spineXInList: CGFloat {
        spineBaseXInList + spineOpticalCorrection
    }

    static var cardLeadingInList: CGFloat {
        max(listSafeLeading, spineXInList + spineToCardGutter)
    }

    static var headerContentHeight: CGFloat {
        titleRowHeight + titleToMetaSpacing + metaRowHeight
    }
}

struct HabitHeader: View {
    @EnvironmentObject private var uiStateStore: HabitUIStateStore
    @EnvironmentObject private var habitLogService: HabitLogService

    let habit: Habit
    let selectedDate: Date
    let calendar: Calendar
    let weekStartPreference: WeekStartPreference
    let isReordering: Bool
    let showsQuickLogButton: Bool
    let showsQuickLogForFrequencyHabits: Bool
    let secondaryTextOverride: String?
    let streakState: StreakState?
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
        streakState: StreakState? = nil,
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
        self.streakState = streakState
        self.trailingAccessory = trailingAccessory
        self.onQuickLog = onQuickLog
        self.onQuickLogLongPress = onQuickLogLongPress
    }

    private var iconAccent: Color { habit.curatedColorVariants.base }
    private var actionAccent: Color { habit.curatedColorVariants.strong }

    private var subtitleText: String? {
        if let secondaryTextOverride, !secondaryTextOverride.isEmpty {
            return normalizedSubtitleText(secondaryTextOverride)
        }

        return normalizedSubtitleText(habit.subtitle)
    }

    private var iconName: String? {
        let trimmed = habit.iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var goalProgressFraction: Double {
        let normalizedDay = calendar.startOfDay(for: selectedDate)
        return uiStateStore.projectedDayState(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )?.progress ?? 0
    }

    private var isComplete: Bool {
        let normalizedDay = calendar.startOfDay(for: selectedDate)
        return uiStateStore.projectedDayState(
            habitID: habit.id,
            day: normalizedDay,
            calendar: calendar
        )?.isComplete ?? false
    }

    private var quickLogAccessibilityLabel: String {
        let dateText = selectedDate.formatted(date: .abbreviated, time: .omitted)
        return "Log \(habit.name) for \(dateText)"
    }

    private var resolvedStreakState: StreakState? {
        if let cached = habitLogService.computedStateByHabitID[habit.id]?.streakState {
            return cached
        }
        return streakState
    }

    private var streakContext: StreakIndicatorPresentation.Context? {
        guard let resolvedStreakState else { return nil }
        return StreakIndicatorPresentation.context(streakState: resolvedStreakState)
    }

    private var shouldShowQuickLogButton: Bool {
        guard showsQuickLogButton else { return false }
        if habit.goalType == .frequency {
            return showsQuickLogForFrequencyHabits
        }
        return true
    }

    private var hasSubtitle: Bool {
        subtitleText != nil
    }

    private var subtitleLineLimit: Int {
        showsStreak ? 1 : 2
    }

    private func normalizedSubtitleText(_ text: String?) -> String? {
        guard let text else { return nil }

        let collapsedWhitespace = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsedWhitespace.isEmpty else { return nil }

        let meaningfulCharacters = collapsedWhitespace.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }

        return meaningfulCharacters.isEmpty ? nil : collapsedWhitespace
    }

    private var showsStreak: Bool {
        streakContext?.showBadge == true
    }

    private var hasMetadataContent: Bool {
        hasSubtitle || showsStreak
    }

    @ViewBuilder
    private var metadataStack: some View {
        if let subtitleText {
            Text(subtitleText)
                .font(.system(size: 13))
                .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.74))
                .lineLimit(subtitleLineLimit)
                .truncationMode(.tail)
                .lineSpacing(0)
        }

        if showsStreak, let streakContext {
            HabitUnifiedStreakIndicator(
                context: streakContext,
                accent: iconAccent
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: HabitRowGrid.contentSpacing) {
            HStack(alignment: .top, spacing: HabitRowGrid.iconToTitleSpacing) {
                HabitBadge(
                    iconName: iconName,
                    accent: iconAccent,
                    habitName: habit.name,
                    size: HabitRowGrid.iconSize
                )
                .frame(width: HabitRowGrid.iconSize, height: HabitRowGrid.iconSize, alignment: .top)

                VStack(
                    alignment: .leading,
                    spacing: hasSubtitle ? HabitRowGrid.titleToSubtitleSpacing : (hasMetadataContent ? HabitRowGrid.titleToMetaSpacing : 0)
                ) {
                    Text(habit.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CadenceTokens.Color.Text.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: HabitRowGrid.titleRowHeight, alignment: .topLeading)
                        .layoutPriority(1)

                    if hasMetadataContent {
                        VStack(
                            alignment: .leading,
                            spacing: hasSubtitle && showsStreak
                                ? HabitRowGrid.subtitleToStreakSpacing
                                : 0
                        ) {
                            metadataStack
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(
                    minHeight: hasMetadataContent
                        ? HabitRowGrid.headerContentHeight
                        : HabitRowGrid.titleRowHeight,
                    alignment: .topLeading
                )
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
            .frame(height: HabitRowGrid.titleRowHeight, alignment: .center)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isReordering)
        }
    }
}

private struct HabitUnifiedStreakIndicator: View {
    @Environment(\.colorScheme) private var colorScheme

    let context: StreakIndicatorPresentation.Context
    let accent: Color
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HabitRowGrid.streakValueToDotsSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: HabitRowGrid.streakIconToValueSpacing) {
                Image(systemName: context.isAtRisk ? "exclamationmark.triangle.fill" : "flame.fill")
                    .font(.system(size: context.isAtRisk ? 11.4 : 12, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(iconColor)
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[.bottom] - 1
                    }

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
            .baselineOffset(1)
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

    private var iconColor: Color {
        if context.isAtRisk {
            return warningColor.opacity(colorScheme == .dark ? 0.95 : 0.9)
        }
        return accent.opacity(colorScheme == .dark ? 1 : 0.88)
    }

    private var warningColor: Color {
        .orange
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
        let baseColor = colorScheme == .dark ? Color.white : Color.black

        if dot.isFilled {
            return baseColor.opacity(1)
        }

        if dot.isAtRisk {
            return baseColor.opacity(0.52)
        }

        if isNextAction {
            return baseColor.opacity(0.3)
        }

        if dot.isToday {
            return baseColor.opacity(0.5)
        }

        return baseColor.opacity(0.27)
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

    private var displaySubtitle: String? {
        let collapsedWhitespace = subtitle?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !collapsedWhitespace.isEmpty else { return nil }

        let meaningfulCharacters = collapsedWhitespace.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }

        return meaningfulCharacters.isEmpty ? nil : collapsedWhitespace
    }

    private var resolvedIcon: String? {
        let trimmed = iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        HStack(alignment: .top, spacing: HabitRowGrid.iconToTitleSpacing) {
            HabitBadge(
                iconName: resolvedIcon,
                accent: accent,
                habitName: name.isEmpty ? "Habit name" : name,
                size: HabitRowGrid.iconSize
            )
            .frame(width: HabitRowGrid.iconSize, height: HabitRowGrid.iconSize, alignment: .top)

            VStack(alignment: .leading, spacing: HabitRowGrid.titleToSubtitleSpacing) {
                Text(name.isEmpty ? "Habit name" : name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: HabitRowGrid.titleRowHeight, alignment: .topLeading)
                    .layoutPriority(1)

                Group {
                    if let displaySubtitle {
                        Text(displaySubtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.74))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .lineSpacing(0)
                    } else {
                        Color.clear
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: HabitRowGrid.metaRowHeight, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: HabitRowGrid.headerContentHeight, alignment: .topLeading)
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
    }
}
