//
//  WidgetDesignSystem.swift
//  HabitsWidget
//
//  Created by Codex on 25/03/2026.
//

import SwiftUI

struct WidgetTypography {
    static let primary = Font.system(size: 24, weight: .bold, design: .rounded)
    static let secondary = Font.system(size: 12, weight: .semibold)
    static let tertiary = Font.system(size: 11, weight: .medium)
    static let habitName = Font.system(size: 12, weight: .medium)
    static let score = Font.system(size: 56, weight: .bold, design: .rounded)
    static let status = Font.system(size: 12, weight: .semibold)

    static let mediumEmptyTitle = Font.system(size: 15, weight: .semibold)
    static let mediumEmptySubtitle = Font.system(size: 12)
    static let mediumRowSymbol = Font.system(size: 14, weight: .medium)
    static let mediumRowName = Font.system(size: 17, weight: .semibold)
    static let mediumRowStreak = Font.system(size: 13, weight: .medium)
    static let mediumCompletionCheck = Font.system(size: 8, weight: .bold)
    static let focusHeroCheck = Font.system(size: 12, weight: .bold)

    static let momentumEmptyTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let momentumEmptySubtitle = Font.system(size: 12, weight: .medium)
}

struct WidgetSpacing {
    static let verticalStack: CGFloat = 4
    static let containerPadding: CGFloat = 12
    static let pillHorizontal: CGFloat = 10
    static let pillVertical: CGFloat = 4

    static let mediumListSpacing: CGFloat = 8
    static let mediumHorizontalPadding: CGFloat = 14
    static let mediumTopPadding: CGFloat = 12
    static let mediumBottomPadding: CGFloat = 10
    static let mediumRowContentSpacing: CGFloat = 10
    static let mediumIconWidth: CGFloat = 24
    static let mediumIndicatorSize: CGFloat = 18
    static let mediumIndicatorColumnWidth: CGFloat = 24
    static let mediumRowHeight: CGFloat = 46
    static let mediumDividerHeight: CGFloat = 0.5
    static let mediumDottedPadding: CGFloat = 1.6
}

struct WidgetMetrics {
    static let mediumPrimaryRowOpacity: Double = 1.0
    static let mediumSecondaryRowOpacity: Double = 0.93
    static let momentumAnimationDuration = 0.2
    static let consistencyStripHeight: CGFloat = 28
}

struct WidgetIndicatorStyle {
    let size: CGFloat
    let lineWidth: CGFloat
    let dottedPadding: CGFloat
    let dottedStrokeOpacity: Double
    let completionShadowRadius: CGFloat
    let completionCheckFont: Font
    let dottedDash: [CGFloat]

    static let medium = WidgetIndicatorStyle(
        size: WidgetSpacing.mediumIndicatorSize,
        lineWidth: 1.8,
        dottedPadding: WidgetSpacing.mediumDottedPadding,
        dottedStrokeOpacity: 0.38,
        completionShadowRadius: 2,
        completionCheckFont: WidgetTypography.mediumCompletionCheck,
        dottedDash: [1.2, 2.2]
    )

    static let focusHero = WidgetIndicatorStyle(
        size: 30,
        lineWidth: 2.2,
        dottedPadding: 2.4,
        dottedStrokeOpacity: 0.62,
        completionShadowRadius: 0,
        completionCheckFont: WidgetTypography.focusHeroCheck,
        dottedDash: [1.6, 2.6]
    )

    static let focusCelebration = WidgetIndicatorStyle(
        size: 24,
        lineWidth: 2.0,
        dottedPadding: 2.0,
        dottedStrokeOpacity: 0.62,
        completionShadowRadius: 0,
        completionCheckFont: WidgetTypography.mediumCompletionCheck,
        dottedDash: [1.4, 2.4]
    )
}

struct WidgetColors {
    static func widgetAccentSoft(accent: Color) -> Color {
        accent.opacity(0.09)
    }

    static func widgetAccentStrong(accent: Color) -> Color {
        accent.opacity(0.9)
    }

    static func statusBackground(accent: Color) -> Color {
        accent.opacity(0.12)
    }

    static func statusBorder(accent: Color) -> Color {
        accent.opacity(0.2)
    }

    static func statusText(accent: Color) -> Color {
        accent
    }

    static let habitName = Color.primary.opacity(0.7)
    static let score = Color.primary
    static let secondaryText = Color.secondary
    static let emptyPrimary = Color.primary
    static let mediumRowName = Color.primary
    static let mediumCompletedRowName = Color.primary.opacity(0.92)
    static let mediumDivider = Color.secondary.opacity(0.16)
    static let mediumProgressTrack = Color.secondary.opacity(0.22)
    static let mediumDottedStroke = Color.secondary.opacity(0.38)
    static let completionGlyph = Color.white.opacity(0.92)
    static let fallbackAccent = Color.secondary

    static func mediumRowName(isCompleteToday: Bool) -> Color {
        isCompleteToday ? mediumCompletedRowName : mediumRowName
    }

    static func mediumIcon(accent: Color, isCompleteToday: Bool) -> Color {
        isCompleteToday ? accent.opacity(0.78) : accent
    }

    static func mediumCompletionShadow(accent: Color) -> Color {
        accent.opacity(0.22)
    }

    static func dottedStroke(opacity: Double) -> Color {
        Color.secondary.opacity(opacity)
    }

    static func consistencyTrack(accent: Color) -> Color {
        widgetAccentSoft(accent: accent)
    }

    static func consistencyFill(intensity: Int, accent: Color, isLatestActive: Bool) -> Color {
        let baseColor: Color = isLatestActive ? widgetAccentStrong(accent: accent) : accent
        switch max(0, min(4, intensity)) {
        case 0:
            return .clear
        case 1:
            return baseColor.opacity(0.28)
        case 2:
            return baseColor.opacity(0.48)
        case 3:
            return baseColor.opacity(0.72)
        default:
            return baseColor
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
            .overlay {
                Capsule()
                    .stroke(style.borderColor, lineWidth: 0.5)
            }
    }
}

struct WidgetStatusPillStyle {
    let foregroundColor: Color
    let backgroundColor: Color
    let borderColor: Color

    static func standard(accent: Color) -> WidgetStatusPillStyle {
        WidgetStatusPillStyle(
            foregroundColor: WidgetColors.statusText(accent: accent),
            backgroundColor: WidgetColors.statusBackground(accent: accent),
            borderColor: WidgetColors.statusBorder(accent: accent)
        )
    }

    static func momentumZero(accent: Color) -> WidgetStatusPillStyle {
        WidgetStatusPillStyle(
            foregroundColor: accent.opacity(0.8),
            backgroundColor: accent.opacity(0.08),
            borderColor: accent.opacity(0.16)
        )
    }
}

struct WidgetHeatmapStrip: View {
    let days: [WidgetHeatmapDay]
    let accent: Color

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                WidgetConsistencyBar(
                    day: day,
                    accent: accent,
                    isLatestActive: index == days.lastIndex(where: { $0.intensity > 0 }),
                    isToday: calendar.isDateInToday(day.date)
                )
            }
        }
        .frame(height: WidgetMetrics.consistencyStripHeight)
    }
}

private struct WidgetConsistencyBar: View {
    let day: WidgetHeatmapDay
    let accent: Color
    let isLatestActive: Bool
    let isToday: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(WidgetColors.consistencyTrack(accent: accent))
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        WidgetColors.consistencyFill(
                            intensity: day.intensity,
                            accent: accent,
                            isLatestActive: isLatestActive
                        )
                    )
                    .frame(height: fillHeight)
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                }
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
                WidgetDottedIndicator(style: style)
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

struct WidgetDottedIndicator: View {
    let style: WidgetIndicatorStyle

    var body: some View {
        Circle()
            .stroke(
                WidgetColors.dottedStroke(opacity: style.dottedStrokeOpacity),
                style: StrokeStyle(
                    lineWidth: style.lineWidth,
                    lineCap: .round,
                    dash: style.dottedDash
                )
            )
            .padding(style.dottedPadding)
            .frame(width: style.size, height: style.size)
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
