//
//  CalendarDayCell.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import SwiftUI

struct CalendarDayCell: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme

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

    static func == (lhs: CalendarDayCell, rhs: CalendarDayCell) -> Bool {
        lhs.date == rhs.date &&
        lhs.count == rhs.count &&
        lhs.indicatorText == rhs.indicatorText &&
        lhs.habitColor == rhs.habitColor &&
        lhs.isInDisplayedMonth == rhs.isInDisplayedMonth &&
        lhs.isDisabled == rhs.isDisabled &&
        lhs.isLocked == rhs.isLocked &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isToday == rhs.isToday &&
        lhs.calendar.identifier == rhs.calendar.identifier &&
        lhs.calendar.timeZone == rhs.calendar.timeZone &&
        lhs.calendar.firstWeekday == rhs.calendar.firstWeekday
    }

    private var intensityVisual: IntensityVisualStyle {
        IntensityColorEngine.style(
            forLogCount: count,
            habitColor: habitColor,
            colorScheme: colorScheme
        )
    }
    
    private var backgroundFill: Color {
        isSelected
            ? selectedAccent.opacity(colorScheme == .dark ? 0.25 : 0.12)
            : .clear
    }

    private var neutralBaseFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.03)
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var dayNumberColor: Color {
        isInDisplayedMonth
            ? Color.primary
            : Color.secondary.opacity(0.5)
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
                .background(
                    RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                        .fill(neutralBaseFill)
                )

            VStack(spacing: 0) {
                Text(dayNumber)
                    .font(.system(size: 16, weight: .semibold))
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
        .scaleEffect(intensityVisual.peakScale)
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
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !isLocked else { return }
            onLongPress()
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
            strokeColor = selectedAccent
            lineWidth = 1.5
        } else if isToday {
            strokeColor = Color.secondary.opacity(colorScheme == .light ? 0.28 : Layout.todayStrokeOpacity)
            lineWidth = Layout.todayStrokeWidth
        } else {
            strokeColor = nil
            lineWidth = 0
        }

        return ZStack {
            RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                .strokeBorder(
                    isLocked
                    ? Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.14)
                    : Color.secondary.opacity(colorScheme == .dark ? Layout.baseStrokeDarkOpacity : Layout.baseStrokeLightOpacity),
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
                .padding(.bottom, Layout.indicatorBottomPadding)
        }
    }
    
    @ViewBuilder
    private var indicatorContent: some View {
        if let indicatorText {
            Text(indicatorText)
                .id("value-\(indicatorText)")
                .font(.caption2.weight(.regular))
                .foregroundStyle(indicatorForegroundColor)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, Layout.indicatorHorizontalPadding)
                .padding(.vertical, Layout.indicatorVerticalPadding)
                .background(
                    Capsule()
                        .fill(indicatorPlateFill)
                        .overlay {
                            if colorScheme == .dark {
                                Capsule()
                                    .strokeBorder(Color.secondary.opacity(Layout.indicatorPlateDarkStrokeOpacity))
                            }
                        }
                )
        } else {
            let logCount = max(0, count)
            let usesDots = logCount <= 5

            if usesDots {
                let dotOpacity: Double = logCount >= 4 ? 0.55 : 0.35
                HStack(spacing: 3) {
                    ForEach(0..<logCount, id: \.self) { _ in
                        Circle()
                            .fill(Color.primary.opacity(dotOpacity))
                            .frame(width: 3, height: 3)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.12)
                        )
                )
            } else {
                Text("\(logCount)")
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(Color.secondary.opacity(0.72))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.12)
                            )
                    )
            }
        }
    }

    private var indicatorForegroundColor: Color {
        Color.secondary.opacity(0.72)
    }

    private var indicatorPlateFill: Color {
        if isSelected {
            return Color.secondary.opacity(colorScheme == .dark ? 0.22 : 0.18)
        }

        if intensityVisual.level > 0 {
            return Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.16)
        }

        return Color.secondary.opacity(colorScheme == .dark ? 0.14 : 0.12)
    }
}
