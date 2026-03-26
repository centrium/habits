//
//  WidgetDesignSystem.swift
//  HabitsWidget
//
//  Created by Codex on 25/03/2026.
//

import SwiftUI
import WidgetKit

struct WidgetTypography {
    static let primary = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let secondary = Font.system(size: 12, weight: .semibold)
    static let tertiary = Font.system(size: 11, weight: .medium)
    static let habitName = Font.system(size: 12, weight: .medium)
    static let score = Font.system(size: 56, weight: .bold, design: .rounded)
    static let status = Font.system(size: 12, weight: .semibold)

    static let mediumEmptyTitle = Font.system(size: 15, weight: .semibold)
    static let mediumEmptySubtitle = Font.system(size: 12)
    static let mediumRowSymbol = Font.system(size: 13, weight: .medium)
    static let mediumRowPrimaryName = Font.system(size: 17, weight: .semibold)
    static let mediumRowSecondaryName = Font.system(size: 15, weight: .medium)
    static let mediumRowStreak = Font.system(size: 12, weight: .medium)
    static let mediumCompletionCheck = Font.system(size: 8, weight: .bold)
    static let focusHeroCheck = Font.system(size: 12, weight: .bold)
    static let focusTitle = Font.system(size: 16, weight: .semibold)
    static let consistencyLabel = Font.system(size: 11, weight: .semibold)
    static let consistencySummary = Font.system(size: 13, weight: .semibold)
    static let momentumState = Font.system(size: 15, weight: .semibold)
    static let momentumTrend = Font.system(size: 11, weight: .medium)

    static let momentumEmptyTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let momentumEmptySubtitle = Font.system(size: 12, weight: .medium)
}

struct WidgetSpacing {
    static let verticalStack: CGFloat = 6
    static let containerPadding: CGFloat = 14
    static let pillHorizontal: CGFloat = 10
    static let pillVertical: CGFloat = 4

    static let mediumListSpacing: CGFloat = 11
    static let mediumHorizontalPadding: CGFloat = 16
    static let mediumTopPadding: CGFloat = 14
    static let mediumBottomPadding: CGFloat = 14
    static let mediumRowContentSpacing: CGFloat = 12
    static let mediumIconWidth: CGFloat = 20
    static let mediumIndicatorSize: CGFloat = 18
    static let mediumIndicatorColumnWidth: CGFloat = 24
    static let mediumRowHeight: CGFloat = 50
    static let mediumPlaceholderInset: CGFloat = 2
}

struct WidgetMetrics {
    static let mediumPrimaryRowOpacity: Double = 1.0
    static let mediumSecondaryRowOpacity: Double = 0.7
    static let momentumAnimationDuration = 0.2
    static let consistencyStripHeight: CGFloat = 28
    static let widgetCornerRadius: CGFloat = 24
    static let lightSurfaceShadowRadius: CGFloat = 6
    static let lightSurfaceShadowYOffset: CGFloat = 2
    static let lightSurfaceShadowOpacity: Double = 0.1
    static let darkSurfaceShadowRadius: CGFloat = 4
    static let darkSurfaceShadowYOffset: CGFloat = 1
    static let darkSurfaceShadowOpacity: Double = 0.06
}

struct WidgetIndicatorStyle {
    let size: CGFloat
    let lineWidth: CGFloat
    let placeholderInset: CGFloat
    let placeholderCoreScale: CGFloat
    let completionShadowRadius: CGFloat
    let completionCheckFont: Font

    static let medium = WidgetIndicatorStyle(
        size: WidgetSpacing.mediumIndicatorSize,
        lineWidth: 1.8,
        placeholderInset: WidgetSpacing.mediumPlaceholderInset,
        placeholderCoreScale: 0.36,
        completionShadowRadius: 2,
        completionCheckFont: WidgetTypography.mediumCompletionCheck
    )

    static let focusHero = WidgetIndicatorStyle(
        size: 30,
        lineWidth: 2.2,
        placeholderInset: 2.8,
        placeholderCoreScale: 0.34,
        completionShadowRadius: 0,
        completionCheckFont: WidgetTypography.focusHeroCheck
    )

    static let focusCelebration = WidgetIndicatorStyle(
        size: 24,
        lineWidth: 2.0,
        placeholderInset: 2.2,
        placeholderCoreScale: 0.34,
        completionShadowRadius: 0,
        completionCheckFont: WidgetTypography.mediumCompletionCheck
    )
}

struct WidgetColors {
    private static let systemAccentLight = UIColor(
        red: 58 / 255,
        green: 243 / 255,
        blue: 247 / 255,
        alpha: 1
    )
    private static let systemAccentDark = UIColor(
        red: 51 / 255,
        green: 214 / 255,
        blue: 217 / 255,
        alpha: 1
    )
    private static let momentumSlippingLight = UIColor(
        red: 146 / 255,
        green: 120 / 255,
        blue: 112 / 255,
        alpha: 1
    )
    private static let momentumSlippingDark = UIColor(
        red: 182 / 255,
        green: 156 / 255,
        blue: 148 / 255,
        alpha: 1
    )
    private static let momentumSteadyLight = UIColor(
        red: 110 / 255,
        green: 122 / 255,
        blue: 138 / 255,
        alpha: 1
    )
    private static let momentumSteadyDark = UIColor(
        red: 148 / 255,
        green: 159 / 255,
        blue: 174 / 255,
        alpha: 1
    )
    private static let momentumBuildingLight = UIColor(
        red: 86 / 255,
        green: 129 / 255,
        blue: 136 / 255,
        alpha: 1
    )
    private static let momentumBuildingDark = UIColor(
        red: 118 / 255,
        green: 156 / 255,
        blue: 162 / 255,
        alpha: 1
    )

    static let surfaceBackground = Color(
        uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 32 / 255, green: 32 / 255, blue: 34 / 255, alpha: 1)
            default:
                return .secondarySystemBackground
            }
        }
    )
    static let primaryText = Color(uiColor: .label).opacity(0.96)
    static let secondaryText = Color(uiColor: .label).opacity(0.68)
    static let tertiaryText = Color(uiColor: .label).opacity(0.46)
    static let systemAccent = Color(
        uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return systemAccentDark
            default:
                return systemAccentLight
            }
        }
    )
    static let systemAccentMuted = systemAccent.opacity(0.24)
    static let systemAccentSuccessBackground = systemAccent.opacity(0.07)

    static func widgetAccentSoft(accent: Color) -> Color {
        accent.opacity(0.12)
    }

    static func widgetAccentStrong(accent: Color) -> Color {
        accent.opacity(0.88)
    }

    static func statusBackground(accent: Color) -> Color {
        accent.opacity(0.12)
    }

    static func statusText(accent: Color) -> Color {
        accent.opacity(0.92)
    }

    static let habitName = tertiaryText
    static let score = primaryText
    static let emptyPrimary = primaryText
    static let mediumRowName = primaryText
    static let mediumCompletedRowName = primaryText.opacity(0.92)
    static let mediumProgressTrack = primaryText.opacity(0.18)
    static let completionGlyph = Color.white.opacity(0.92)
    static let fallbackAccent = Color.secondary
    static let placeholderFill = primaryText.opacity(0.08)
    static let placeholderCore = primaryText.opacity(0.18)

    static func mediumRowName(isCompleteToday: Bool) -> Color {
        isCompleteToday ? mediumCompletedRowName : mediumRowName
    }

    static func mediumIcon(accent: Color, isPrimaryRow: Bool, isCompleteToday: Bool) -> Color {
        if isCompleteToday {
            return accent.opacity(isPrimaryRow ? 0.7 : 0.56)
        }

        return accent.opacity(isPrimaryRow ? 0.56 : 0.4)
    }

    static func mediumCompletionShadow(accent: Color) -> Color {
        accent.opacity(0.16)
    }

    static let systemConsistencyTrack = systemAccentMuted

    static func systemConsistencyFill(intensity: Int) -> Color {
        intensity > 0 ? systemAccent : .clear
    }

    static func momentumStateText(_ state: WidgetMomentumState) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                switch state {
                case .slipping:
                    return traitCollection.userInterfaceStyle == .dark
                        ? momentumSlippingDark
                        : momentumSlippingLight
                case .steady:
                    return traitCollection.userInterfaceStyle == .dark
                        ? momentumSteadyDark
                        : momentumSteadyLight
                case .building:
                    return traitCollection.userInterfaceStyle == .dark
                        ? momentumBuildingDark
                        : momentumBuildingLight
                }
            }
        )
    }

    static func momentumDirectionText(_ direction: WidgetMomentumDirection) -> Color {
        switch direction {
        case .improving:
            return momentumStateText(.building).opacity(0.82)
        case .stable:
            return secondaryText
        case .declining:
            return momentumStateText(.slipping).opacity(0.82)
        case .unavailable:
            return tertiaryText
        }
    }
}

struct WidgetScoreText: View {
    let score: Int

    var body: some View {
        Text("\(score)%")
            .font(WidgetTypography.score)
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundStyle(WidgetColors.score)
            .contentTransition(.numericText())
    }
}

struct WidgetStatusPill: View {
    let text: String
    let style: WidgetStatusPillStyle

    var body: some View {
        Text(text)
            .font(WidgetTypography.status)
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, WidgetSpacing.pillHorizontal)
            .padding(.vertical, WidgetSpacing.pillVertical)
            .background(style.backgroundColor, in: Capsule())
    }
}

struct WidgetStatusPillStyle {
    let foregroundColor: Color
    let backgroundColor: Color

    static func standard(accent: Color) -> WidgetStatusPillStyle {
        WidgetStatusPillStyle(
            foregroundColor: WidgetColors.statusText(accent: accent),
            backgroundColor: WidgetColors.statusBackground(accent: accent)
        )
    }

    static func momentumZero(accent: Color) -> WidgetStatusPillStyle {
        WidgetStatusPillStyle(
            foregroundColor: accent.opacity(0.8),
            backgroundColor: accent.opacity(0.08)
        )
    }
}

struct WidgetHeatmapStrip: View {
    let days: [WidgetHeatmapDay]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(days, id: \.date) { day in
                WidgetConsistencyBar(day: day)
            }
        }
        .frame(height: WidgetMetrics.consistencyStripHeight)
    }
}

private struct WidgetConsistencyBar: View {
    let day: WidgetHeatmapDay

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(WidgetColors.systemConsistencyTrack)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(WidgetColors.systemConsistencyFill(intensity: day.intensity))
                    .frame(height: fillHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fillHeight: CGFloat {
        switch day.intensity {
        case 1:
            return WidgetMetrics.consistencyStripHeight * 0.3
        case 2:
            return WidgetMetrics.consistencyStripHeight * 0.52
        case 3:
            return WidgetMetrics.consistencyStripHeight * 0.76
        case 4:
            return WidgetMetrics.consistencyStripHeight
        default:
            return 0
        }
    }
}

struct WidgetHabitIndicator: View {
    let habit: WidgetHabit
    let accent: Color
    let style: WidgetIndicatorStyle

    var body: some View {
        Group {
            if !habit.hasActivityToday {
                WidgetPlaceholderIndicator(style: style)
            } else {
                switch habit.goalType {
                case .goal:
                    if habit.goalProgress < 1 {
                        WidgetProgressRing(progress: habit.goalProgress, accent: accent, style: style)
                    } else {
                        WidgetCompletionDot(accent: accent, style: style)
                    }
                case .binary, .openEnded:
                    WidgetCompletionDot(accent: accent, style: style)
                }
            }
        }
        .frame(width: style.size, height: style.size)
    }
}

struct WidgetCompletionDot: View {
    let accent: Color
    let style: WidgetIndicatorStyle

    var body: some View {
        Circle()
            .fill(accent)
            .shadow(
                color: WidgetColors.mediumCompletionShadow(accent: accent),
                radius: style.completionShadowRadius,
                x: 0,
                y: 0
            )
            .overlay {
                Image(systemName: "checkmark")
                    .font(style.completionCheckFont)
                    .foregroundStyle(WidgetColors.completionGlyph)
            }
            .frame(width: style.size, height: style.size)
    }
}

struct WidgetSystemCompletionBadge: View {
    let style: WidgetIndicatorStyle

    var body: some View {
        Circle()
            .fill(WidgetColors.systemAccentSuccessBackground)
            .overlay {
                Image(systemName: "checkmark")
                    .font(style.completionCheckFont)
                    .foregroundStyle(WidgetColors.systemAccent)
            }
            .frame(width: style.size, height: style.size)
    }
}

struct WidgetProgressRing: View {
    let progress: Double
    let accent: Color
    let style: WidgetIndicatorStyle

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(WidgetColors.mediumProgressTrack, lineWidth: style.lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: style.size, height: style.size)
    }
}

struct WidgetPlaceholderIndicator: View {
    let style: WidgetIndicatorStyle

    var body: some View {
        Circle()
            .fill(WidgetColors.placeholderFill)
            .overlay {
                Circle()
                    .fill(WidgetColors.placeholderCore)
                    .padding(style.size * (1 - style.placeholderCoreScale) / 2)
            }
            .padding(style.placeholderInset)
            .frame(width: style.size, height: style.size)
    }
}

struct WidgetSurfaceBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: WidgetMetrics.widgetCornerRadius, style: .continuous)
            .fill(WidgetColors.surfaceBackground)
            .shadow(
                color: Color.black.opacity(surfaceShadowOpacity),
                radius: surfaceShadowRadius,
                x: 0,
                y: surfaceShadowYOffset
            )
    }

    private var surfaceShadowOpacity: Double {
        colorScheme == .dark
            ? WidgetMetrics.darkSurfaceShadowOpacity
            : WidgetMetrics.lightSurfaceShadowOpacity
    }

    private var surfaceShadowRadius: CGFloat {
        colorScheme == .dark
            ? WidgetMetrics.darkSurfaceShadowRadius
            : WidgetMetrics.lightSurfaceShadowRadius
    }

    private var surfaceShadowYOffset: CGFloat {
        colorScheme == .dark
            ? WidgetMetrics.darkSurfaceShadowYOffset
            : WidgetMetrics.lightSurfaceShadowYOffset
    }
}

private struct WidgetSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                WidgetSurfaceBackground()
            }
        } else {
            content
                .background(WidgetSurfaceBackground())
                .clipShape(RoundedRectangle(cornerRadius: WidgetMetrics.widgetCornerRadius, style: .continuous))
        }
    }
}

extension View {
    func widgetSurface() -> some View {
        modifier(WidgetSurfaceModifier())
    }
}

extension WidgetHabit {
    var deepLinkURL: URL {
        URL(string: "habits://habit/\(id.uuidString)")!
    }

    var widgetAccentColor: Color {
        guard
            let colorHex,
            let color = Color(widgetHex: colorHex)
        else {
            return WidgetColors.fallbackAccent
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
