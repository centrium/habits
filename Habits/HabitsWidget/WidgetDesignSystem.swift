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
    static let secondary = Font.system(size: 12, weight: .regular)
    static let tertiary = Font.system(size: 11, weight: .regular)
    static let habitName = Font.system(size: 12, weight: .regular)
    static let score = Font.system(size: 56, weight: .semibold, design: .rounded)
    static let status = Font.system(size: 12, weight: .semibold)

    static let mediumEmptyTitle = Font.system(size: 15, weight: .semibold)
    static let mediumEmptySubtitle = Font.system(size: 12, weight: .regular)
    static let mediumRowSymbol = Font.system(size: 13, weight: .medium)
    static let mediumRowPrimaryName = Font.system(size: 17, weight: .semibold)
    static let mediumRowSecondaryName = Font.system(size: 15, weight: .regular)
    static let mediumRowStreak = Font.system(size: 12, weight: .regular)
    static let mediumCompletionCheck = Font.system(size: 8, weight: .bold)
    static let focusHeroCheck = Font.system(size: 12, weight: .bold)
    static let focusTitle = Font.system(size: 16, weight: .semibold)
    static let consistencyLabel = Font.system(size: 11, weight: .regular)
    static let consistencySummary = Font.system(size: 13, weight: .semibold)
    static let momentumState = Font.system(size: 15, weight: .semibold)
    static let momentumTrend = Font.system(size: 11, weight: .regular)

    static let momentumEmptyTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let momentumEmptySubtitle = Font.system(size: 12, weight: .regular)
}

struct WidgetSpacing {
    static let verticalStack: CGFloat = 8
    static let containerPadding: CGFloat = 16
    static let pillHorizontal: CGFloat = 10
    static let pillVertical: CGFloat = 4
    static let momentumClusterSpacing: CGFloat = 4
    static let momentumTextSpacing: CGFloat = 2
    static let opticalIconLift: CGFloat = -1

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
    static let momentumAnimationDuration = 0.2
    static let consistencyStripHeight: CGFloat = 28
    static let widgetCornerRadius: CGFloat = 24
}

struct WidgetIndicatorStyle {
    let size: CGFloat
    let lineWidth: CGFloat
    let placeholderInset: CGFloat
    let placeholderCoreScale: CGFloat
    let completionCheckFont: Font

    static let medium = WidgetIndicatorStyle(
        size: WidgetSpacing.mediumIndicatorSize,
        lineWidth: 2.0,
        placeholderInset: WidgetSpacing.mediumPlaceholderInset,
        placeholderCoreScale: 0.36,
        completionCheckFont: WidgetTypography.mediumCompletionCheck
    )

    static let focusHero = WidgetIndicatorStyle(
        size: 30,
        lineWidth: 2.4,
        placeholderInset: 2.8,
        placeholderCoreScale: 0.34,
        completionCheckFont: WidgetTypography.focusHeroCheck
    )

    static let focusCelebration = WidgetIndicatorStyle(
        size: 24,
        lineWidth: 2.2,
        placeholderInset: 2.2,
        placeholderCoreScale: 0.34,
        completionCheckFont: WidgetTypography.mediumCompletionCheck
    )
}

struct WidgetColors {
    private static let textPrimaryLight = UIColor(red: 28 / 255, green: 29 / 255, blue: 31 / 255, alpha: 1)
    private static let textPrimaryDark = UIColor(red: 247 / 255, green: 247 / 255, blue: 250 / 255, alpha: 1)
    private static let textSecondaryLight = UIColor(red: 94 / 255, green: 99 / 255, blue: 108 / 255, alpha: 1)
    private static let textSecondaryDark = UIColor(red: 199 / 255, green: 201 / 255, blue: 207 / 255, alpha: 1)
    private static let textTertiaryLight = UIColor(red: 123 / 255, green: 128 / 255, blue: 138 / 255, alpha: 1)
    private static let textTertiaryDark = UIColor(red: 158 / 255, green: 161 / 255, blue: 169 / 255, alpha: 1)

    private static let surfacePrimaryLight = UIColor(red: 243 / 255, green: 244 / 255, blue: 247 / 255, alpha: 1)
    private static let surfacePrimaryDark = UIColor(red: 28 / 255, green: 29 / 255, blue: 31 / 255, alpha: 1)
    private static let surfaceElevatedLight = UIColor(red: 229 / 255, green: 232 / 255, blue: 237 / 255, alpha: 1)
    private static let surfaceElevatedDark = UIColor(red: 52 / 255, green: 54 / 255, blue: 58 / 255, alpha: 1)

    private static let accentPrimaryLight = UIColor(red: 22 / 255, green: 128 / 255, blue: 136 / 255, alpha: 1)
    private static let accentPrimaryDark = UIColor(red: 116 / 255, green: 214 / 255, blue: 218 / 255, alpha: 1)
    private static let statePositiveLight = UIColor(red: 62 / 255, green: 120 / 255, blue: 114 / 255, alpha: 1)
    private static let statePositiveDark = UIColor(red: 154 / 255, green: 211 / 255, blue: 201 / 255, alpha: 1)
    private static let stateNeutralLight = UIColor(red: 102 / 255, green: 110 / 255, blue: 123 / 255, alpha: 1)
    private static let stateNeutralDark = UIColor(red: 177 / 255, green: 184 / 255, blue: 196 / 255, alpha: 1)
    private static let stateNegativeLight = UIColor(red: 158 / 255, green: 96 / 255, blue: 84 / 255, alpha: 1)
    private static let stateNegativeDark = UIColor(red: 223 / 255, green: 162 / 255, blue: 149 / 255, alpha: 1)

    static let textPrimary = dynamicColor(light: textPrimaryLight, dark: textPrimaryDark)
    static let textSecondary = dynamicColor(light: textSecondaryLight, dark: textSecondaryDark)
    static let textTertiary = dynamicColor(light: textTertiaryLight, dark: textTertiaryDark)
    static let surfacePrimary = dynamicColor(light: surfacePrimaryLight, dark: surfacePrimaryDark)
    static let surfaceElevated = dynamicColor(light: surfaceElevatedLight, dark: surfaceElevatedDark)
    static let accentPrimary = dynamicColor(light: accentPrimaryLight, dark: accentPrimaryDark)
    static let statePositive = dynamicColor(light: statePositiveLight, dark: statePositiveDark)
    static let stateNeutral = dynamicColor(light: stateNeutralLight, dark: stateNeutralDark)
    static let stateNegative = dynamicColor(light: stateNegativeLight, dark: stateNegativeDark)

    static let surfaceBackground = surfacePrimary
    static let primaryText = textPrimary
    static let secondaryText = textSecondary
    static let tertiaryText = textTertiary
    static let systemAccent = accentPrimary
    static let systemAccentMuted = tintedSurface(using: accentPrimary, lightAmount: 0.18, darkAmount: 0.24)
    static let systemAccentSuccessBackground = tintedSurface(using: statePositive, lightAmount: 0.16, darkAmount: 0.22)

    static func widgetAccentSoft(accent: Color) -> Color {
        tintedSurface(using: accent, lightAmount: 0.14, darkAmount: 0.22)
    }

    static func widgetAccentStrong(accent: Color) -> Color {
        emphasizedAccent(accent, lightAmount: 0.18, darkAmount: 0.1)
    }

    static func statusBackground(accent: Color) -> Color {
        tintedSurface(using: accent, lightAmount: 0.18, darkAmount: 0.24)
    }

    static func statusText(accent: Color) -> Color {
        emphasizedAccent(accent, lightAmount: 0.28, darkAmount: 0.14)
    }

    static let habitName = textSecondary
    static let score = textPrimary
    static let emptyPrimary = textPrimary
    static let mediumProgressTrack = tintedSurface(using: textSecondary, lightAmount: 0.18, darkAmount: 0.24)
    static let fallbackAccent = accentPrimary
    static let placeholderFill = tintedSurface(using: textSecondary, lightAmount: 0.14, darkAmount: 0.2)
    static let placeholderCore = tintedSurface(using: textSecondary, lightAmount: 0.54, darkAmount: 0.6)
    static let systemConsistencyTrack = surfaceElevated

    static func mediumRowName(isPrimaryRow: Bool) -> Color {
        isPrimaryRow ? textPrimary : textSecondary
    }

    static func mediumIcon(accent: Color, isPrimaryRow: Bool, isCompleteToday: Bool) -> Color {
        if isCompleteToday {
            return isPrimaryRow
                ? emphasizedAccent(accent, lightAmount: 0.22, darkAmount: 0.12)
                : emphasizedAccent(accent, lightAmount: 0.34, darkAmount: 0.2)
        }

        return isPrimaryRow
            ? emphasizedAccent(accent, lightAmount: 0.14, darkAmount: 0.08)
            : tintedAccent(accent, lightAmount: 0.34, darkAmount: 0.2)
    }

    static func completionGlyph(accent: Color) -> Color {
        accessibleForeground(for: widgetAccentStrong(accent: accent))
    }

    static func systemConsistencyFill(intensity: Int) -> Color {
        switch intensity {
        case 1:
            return tintedSurface(using: accentPrimary, lightAmount: 0.26, darkAmount: 0.32)
        case 2:
            return tintedSurface(using: accentPrimary, lightAmount: 0.42, darkAmount: 0.48)
        case 3:
            return tintedSurface(using: accentPrimary, lightAmount: 0.62, darkAmount: 0.68)
        case 4...:
            return accentPrimary
        default:
            return .clear
        }
    }

    static func momentumStateText(_ state: WidgetMomentumState) -> Color {
        switch state {
        case .slipping:
            return stateNegative
        case .steady:
            return stateNeutral
        case .building:
            return statePositive
        }
    }

    static func momentumDirectionText(_ direction: WidgetMomentumDirection) -> Color {
        switch direction {
        case .improving:
            return lightlyTintedText(using: statePositive)
        case .stable:
            return textSecondary
        case .declining:
            return lightlyTintedText(using: stateNegative)
        case .unavailable:
            return textTertiary
        }
    }

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return dark
                default:
                    return light
                }
            }
        )
    }

    private static func emphasizedAccent(_ accent: Color, lightAmount: CGFloat, darkAmount: CGFloat) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                let accentColor = UIColor(accent).resolvedColor(with: traitCollection)
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return accentColor.mixed(with: textPrimaryDark, amount: darkAmount)
                default:
                    return accentColor.mixed(with: textPrimaryLight, amount: lightAmount)
                }
            }
        )
    }

    private static func tintedAccent(_ accent: Color, lightAmount: CGFloat, darkAmount: CGFloat) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                let accentColor = UIColor(accent).resolvedColor(with: traitCollection)
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return accentColor.mixed(with: textSecondaryDark, amount: darkAmount)
                default:
                    return accentColor.mixed(with: textSecondaryLight, amount: lightAmount)
                }
            }
        )
    }

    private static func tintedSurface(using tint: Color, lightAmount: CGFloat, darkAmount: CGFloat) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                let tintColor = UIColor(tint).resolvedColor(with: traitCollection)
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return surfaceElevatedDark.mixed(with: tintColor, amount: darkAmount)
                default:
                    return surfaceElevatedLight.mixed(with: tintColor, amount: lightAmount)
                }
            }
        )
    }

    private static func lightlyTintedText(using tint: Color) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                let tintColor = UIColor(tint).resolvedColor(with: traitCollection)
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return textSecondaryDark.mixed(with: tintColor, amount: 0.28)
                default:
                    return textSecondaryLight.mixed(with: tintColor, amount: 0.22)
                }
            }
        )
    }

    private static func accessibleForeground(for fill: Color) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                let resolvedFill = UIColor(fill).resolvedColor(with: traitCollection)
                return resolvedFill.relativeLuminance > 0.5 ? textPrimaryLight : textPrimaryDark
            }
        )
    }
}

struct WidgetScoreText: View {
    let score: Int

    var body: some View {
        Text("\(score)%")
            .font(WidgetTypography.score)
            .monospacedDigit()
            .tracking(-1.2)
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
            foregroundColor: WidgetColors.statusText(accent: accent),
            backgroundColor: WidgetColors.statusBackground(accent: accent)
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
            .fill(WidgetColors.widgetAccentStrong(accent: accent))
            .overlay {
                Image(systemName: "checkmark")
                    .font(style.completionCheckFont)
                    .foregroundStyle(WidgetColors.completionGlyph(accent: accent))
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
                    .foregroundStyle(WidgetColors.statePositive)
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
                    WidgetColors.widgetAccentStrong(accent: accent),
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
    var body: some View {
        RoundedRectangle(cornerRadius: WidgetMetrics.widgetCornerRadius, style: .continuous)
            .fill(WidgetColors.surfaceBackground)
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

private extension UIColor {
    func mixed(with color: UIColor, amount: CGFloat) -> UIColor {
        let clampedAmount = min(max(amount, 0), 1)
        let source = resolvedSRGBComponents
        let target = color.resolvedSRGBComponents

        return UIColor(
            red: source.red + (target.red - source.red) * clampedAmount,
            green: source.green + (target.green - source.green) * clampedAmount,
            blue: source.blue + (target.blue - source.blue) * clampedAmount,
            alpha: source.alpha + (target.alpha - source.alpha) * clampedAmount
        )
    }

    var relativeLuminance: CGFloat {
        let components = resolvedSRGBComponents

        func convert(_ component: CGFloat) -> CGFloat {
            if component <= 0.03928 {
                return component / 12.92
            }

            return pow((component + 0.055) / 1.055, 2.4)
        }

        let red = convert(components.red)
        let green = convert(components.green)
        let blue = convert(components.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private var resolvedSRGBComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }

        let converted = CIColor(color: self)
        return (converted.red, converted.green, converted.blue, converted.alpha)
    }
}
