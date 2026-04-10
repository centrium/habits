//
//  CalendarDayCell.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import SwiftUI

struct CalendarDayCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed: Bool = false

    private enum Layout {
        static let cellWidth: CGFloat = 43
        static let cellHeight: CGFloat = 48
        static let cellCornerRadius: CGFloat = 10

        static let dayNumberAreaHeight: CGFloat = 20
        static let dayTopPadding: CGFloat = 4
        static let middleMinHeight: CGFloat = 6

        static let indicatorAreaHeight: CGFloat = 19
        static let indicatorCapsuleHeight: CGFloat = 13
        static let indicatorBottomPadding: CGFloat = 6
        static let indicatorHorizontalPadding: CGFloat = 7
        static let indicatorVerticalPadding: CGFloat = 0

        static let dotSize: CGFloat = 3.4
        static let dotSpacing: CGFloat = 4.4
        static let indicatorPlateOpacity: Double = 0.30
        static let indicatorPlateDarkStrokeOpacity: Double = 0.10

        static let selectedBackgroundOpacity: Double = 0.72
        static let outOfMonthBackgroundOpacity: Double = 0.035
        static let disabledBackgroundOpacity: Double = 0.06
        static let disabledOutOfMonthBackgroundOpacity: Double = 0.03
        static let disabledContentOpacity: Double = 0.55

        static let oneLogBackgroundOpacity: Double = 0.07
        static let twoLogsBackgroundOpacity: Double = 0.10
        static let threePlusLogsBackgroundOpacity: Double = 0.14

        static let selectedStrokeOpacity: Double = 0.60
        static let todayStrokeOpacity: Double = 0.32
        static let selectedStrokeWidth: CGFloat = 1.5
        static let todayStrokeWidth: CGFloat = 1
        static let baseStrokeWidth: CGFloat = 0.8
        static let baseStrokeDarkOpacity: Double = 0.14
        static let baseStrokeLightOpacity: Double = 0.09
    }

    let date: Date
    let count: Int
    let indicatorText: String?
    let habitColor: HabitColor
    let selectedAccent: Color
    let isInDisplayedMonth: Bool
    let isDisabled: Bool
    let isLocked: Bool
    let isSelected: Bool
    let isToday: Bool
    let calendar: Calendar
    let onTap: () -> Void
    let onLongPress: () -> Void

    private var intensityVisual: IntensityVisualStyle {
        IntensityColorEngine.style(
            forLogCount: count,
            habitColor: habitColor,
            colorScheme: colorScheme
        )
    }
    
    private var backgroundFill: Color {
        if isDisabled {
            return Color.primary.opacity(isInDisplayedMonth ? Layout.disabledBackgroundOpacity : Layout.disabledOutOfMonthBackgroundOpacity)
        }

        if isLocked {
            return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.12)
        }

        if isSelected {
            return selectedAccent.opacity(Layout.selectedBackgroundOpacity)
        }

        if !isInDisplayedMonth {
            return Color.primary.opacity(Layout.outOfMonthBackgroundOpacity)
        }

        return intensityVisual.fill
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var dayNumberColor: Color {
        if isDisabled {
            return Color.primary.opacity(isInDisplayedMonth ? 0.38 : 0.24)
        }

        if isLocked {
            return Color.primary.opacity(isInDisplayedMonth ? 0.7 : 0.45)
        }

        if isSelected {
            return .white.opacity(0.95)
        }

        if intensityVisual.level >= 3 {
            return Color.black.opacity(colorScheme == .dark ? 0.86 : 0.80)
        }

        if intensityVisual.level > 0 {
            return Color.black.opacity(colorScheme == .dark ? 0.90 : 0.84)
        }

        if isInDisplayedMonth {
            return Color.primary.opacity(0.78)
        }

        return Color.primary.opacity(0.54)
    }

    private var contentOpacity: Double {
        if isDisabled {
            return Layout.disabledContentOpacity
        }

        if isLocked {
            return 0.92
        }

        return 1
    }

    private var showsIndicator: Bool {
        !isDisabled && (count > 0 || indicatorText != nil)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                .fill(backgroundFill)

            if isSelected {
                RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                    .fill(Color.black.opacity(0.24))
            }

            VStack(spacing: 0) {
                Text(dayNumber)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(dayNumberColor)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Layout.dayTopPadding)
                    .frame(height: Layout.dayNumberAreaHeight, alignment: .top)

                Spacer(minLength: Layout.middleMinHeight)

                if showsIndicator {
                    indicatorContainer
                        .frame(height: Layout.indicatorAreaHeight, alignment: .bottom)
                } else {
                    Spacer()
                        .frame(height: Layout.indicatorAreaHeight)
                }
            }
        }
        .opacity(contentOpacity)
        .frame(width: Layout.cellWidth, height: Layout.cellHeight)
        .scaleEffect((isPressed ? 1.025 : 1) * intensityVisual.peakScale)
        .shadow(
            color: intensityVisual.peakShadowColor,
            radius: intensityVisual.peakShadowRadius,
            y: intensityVisual.peakShadowYOffset
        )
        .overlay(selectionOverlay)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLocked {
                Haptics.impactLight()
            }
            withAnimation(.easeInOut(duration: 0.09)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.easeInOut(duration: 0.14)) {
                    isPressed = false
                }
            }
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !isLocked else { return }
            onLongPress()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: count)
        .animation(.easeInOut(duration: 0.2), value: indicatorText)
        .allowsHitTesting(!isDisabled)
        .accessibilityAction(named: Text("Open Day Actions")) {
            guard !isDisabled, !isLocked else { return }
            onLongPress()
        }
        .disabled(isDisabled)
    }

    private var selectionOverlay: some View {
        let strokeColor: Color?
        let lineWidth: CGFloat

        if isSelected {
            strokeColor = selectedAccent.opacity(Layout.selectedStrokeOpacity)
            lineWidth = Layout.selectedStrokeWidth
        } else if isToday {
            strokeColor = Color.primary.opacity(colorScheme == .light ? 0.28 : Layout.todayStrokeOpacity)
            lineWidth = Layout.todayStrokeWidth
        } else {
            strokeColor = nil
            lineWidth = 0
        }

        return ZStack {
            RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                .strokeBorder(
                    isLocked
                    ? Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.14)
                    : (intensityVisual.level > 0
                       ? intensityVisual.border.opacity(colorScheme == .dark ? 0.9 : 0.82)
                       : Color.primary.opacity(colorScheme == .dark ? Layout.baseStrokeDarkOpacity : Layout.baseStrokeLightOpacity)),
                    lineWidth: Layout.baseStrokeWidth
                )

            RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                .strokeBorder(strokeColor ?? .clear, lineWidth: lineWidth)
        }
    }
    
    @ViewBuilder
    private var indicatorContainer: some View {
        if showsIndicator {
            indicatorContent
                .frame(height: Layout.indicatorCapsuleHeight, alignment: .center)
                .padding(.horizontal, Layout.indicatorHorizontalPadding)
                .padding(.vertical, Layout.indicatorVerticalPadding)
                .background(
                    Capsule()
                        .fill(indicatorPlateFill)
                        .overlay {
                            if colorScheme == .dark {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(Layout.indicatorPlateDarkStrokeOpacity))
                            }
                        }
                )
                .padding(.bottom, Layout.indicatorBottomPadding)
        }
    }
    
    @ViewBuilder
    private var indicatorContent: some View {
        if let indicatorText {
            Text(indicatorText)
                .id("value-\(indicatorText)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(indicatorForegroundColor)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.5)
                .transition(.opacity.combined(with: .offset(y: 3)))
        } else if count <= 5 {
            HStack(spacing: Layout.dotSpacing) {
                ForEach(0..<count, id: \.self) { _ in
                    indicatorDot
                }
            }
        } else {
            Text("+\(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(indicatorForegroundColor)
        }
    }

    private var indicatorDot: some View {
        Circle()
            .fill(dotFill)
            .overlay {
                if colorScheme == .dark {
                    Circle()
                        .strokeBorder(Color.white.opacity(isSelected ? 0.32 : 0.22), lineWidth: 0.4)
                }
            }
            .shadow(
                color: colorScheme == .dark ? selectedAccent.opacity(isSelected ? 0.2 : 0.24) : .clear,
                radius: colorScheme == .dark ? 1.6 : 0,
                y: 0.4
            )
            .frame(width: Layout.dotSize, height: Layout.dotSize)
    }

    private var dotFill: some ShapeStyle {
        AnyShapeStyle(indicatorDotColor)
    }

    private var indicatorForegroundColor: Color {
        if isSelected {
            return .white.opacity(0.95)
        }

        if intensityVisual.level > 0 {
            return Color.black.opacity(colorScheme == .dark ? 0.78 : 0.72)
        }

        return colorScheme == .dark ? .white.opacity(0.90) : Color.primary.opacity(0.72)
    }

    private var indicatorPlateFill: Color {
        if isSelected {
            return Color.white.opacity(colorScheme == .dark ? 0.30 : 0.26)
        }

        if intensityVisual.level > 0 {
            return Color.white.opacity(colorScheme == .dark ? 0.30 : 0.26)
        }

        return Color.white.opacity(colorScheme == .dark ? 0.14 : 0.20)
    }

    private var indicatorDotColor: Color {
        if isSelected {
            return Color.white.opacity(0.9)
        }

        if intensityVisual.level > 0 {
            return Color.black.opacity(colorScheme == .dark ? 0.72 : 0.64)
        }

        return colorScheme == .dark ? .white.opacity(0.86) : Color.primary.opacity(0.62)
    }
}
