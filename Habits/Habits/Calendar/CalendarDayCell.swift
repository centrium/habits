//
//  CalendarDayCell.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import SwiftUI

struct CalendarDayCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private enum Layout {
        static let cellWidth: CGFloat = 43
        static let cellHeight: CGFloat = 48
        static let cellCornerRadius: CGFloat = 10

        static let dayNumberAreaHeight: CGFloat = 20
        static let dayTopPadding: CGFloat = 4
        static let middleMinHeight: CGFloat = 6

        static let indicatorAreaHeight: CGFloat = 18
        static let indicatorCapsuleHeight: CGFloat = 12
        static let indicatorBottomPadding: CGFloat = 6
        static let indicatorHorizontalPadding: CGFloat = 6
        static let indicatorVerticalPadding: CGFloat = 0

        static let dotSize: CGFloat = 3
        static let dotSpacing: CGFloat = 4
        static let indicatorPlateOpacity: Double = 0.24
        static let indicatorPlateDarkStrokeOpacity: Double = 0.10

        static let selectedBackgroundOpacity: Double = 0.85
        static let outOfMonthBackgroundOpacity: Double = 0.05
        static let disabledBackgroundOpacity: Double = 0.06
        static let disabledOutOfMonthBackgroundOpacity: Double = 0.03
        static let disabledContentOpacity: Double = 0.55

        static let oneLogBackgroundOpacity: Double = 0.08
        static let twoLogsBackgroundOpacity: Double = 0.12
        static let threePlusLogsBackgroundOpacity: Double = 0.18

        static let selectedStrokeOpacity: Double = 0.60
        static let todayStrokeOpacity: Double = 0.32
        static let selectedStrokeWidth: CGFloat = 1.5
        static let todayStrokeWidth: CGFloat = 1
        static let baseStrokeWidth: CGFloat = 0.8
        static let baseStrokeDarkOpacity: Double = 0.10
        static let baseStrokeLightOpacity: Double = 0.06
    }

    let date: Date
    let intensity: Double
    let count: Int
    let indicatorText: String?
    let accent: Color
    let isInDisplayedMonth: Bool
    let isDisabled: Bool
    let isLocked: Bool
    let isSelected: Bool
    let isToday: Bool
    let calendar: Calendar
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    private var backgroundFill: Color {
        if isDisabled {
            return Color.primary.opacity(isInDisplayedMonth ? Layout.disabledBackgroundOpacity : Layout.disabledOutOfMonthBackgroundOpacity)
        }

        if isLocked {
            return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.12)
        }

        return accent.opacity(backgroundOpacity)
    }

    private var backgroundOpacity: Double {
        if isDisabled {
            return 0
        }

        if !isInDisplayedMonth {
            return Layout.outOfMonthBackgroundOpacity
        }

        if isSelected {
            return Layout.selectedBackgroundOpacity
        }

        switch count {
        case 3...:
            return colorScheme == .light ? 0.22 : Layout.threePlusLogsBackgroundOpacity
        case 2:
            return colorScheme == .light ? 0.15 : Layout.twoLogsBackgroundOpacity
        case 1:
            return colorScheme == .light ? 0.10 : Layout.oneLogBackgroundOpacity
        default:
            return 0
        }
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
            return Color.appBackground.opacity(0.95)
        }

        if isInDisplayedMonth {
            return .primary
        }

        return Color.primary.opacity(0.5)
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
        .overlay(selectionOverlay)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !isLocked else { return }
            onLongPress()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
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
            strokeColor = Color.primary.opacity(Layout.selectedStrokeOpacity)
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
                    : Color.primary.opacity(colorScheme == .dark ? Layout.baseStrokeDarkOpacity : Layout.baseStrokeLightOpacity),
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
                        .fill(Color.primary.opacity(Layout.indicatorPlateOpacity))
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.5)
        } else if count <= 5 {
            HStack(spacing: Layout.dotSpacing) {
                ForEach(0..<count, id: \.self) { _ in
                    indicatorDot
                }
            }
        } else {
            HStack(spacing: Layout.dotSpacing) {
                indicatorDot

                Text("+\(count - 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
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
            .brightness(colorScheme == .dark && !isSelected ? 0.08 : 0)
            .shadow(
                color: colorScheme == .dark ? accent.opacity(isSelected ? 0.2 : 0.24) : .clear,
                radius: colorScheme == .dark ? 1.6 : 0,
                y: 0.4
            )
            .frame(width: Layout.dotSize, height: Layout.dotSize)
    }

    private var dotFill: some ShapeStyle {
        if colorScheme == .dark {
            if isSelected {
                return AnyShapeStyle(Color.white.opacity(0.9))
            }

            return AnyShapeStyle(accent.opacity(0.96))
        }

        return AnyShapeStyle(accent)
    }
}
