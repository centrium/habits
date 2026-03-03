//
//  CalendarDayCell.swift
//  Habits
//
//  Created by Matt Adams on 24/02/2026.
//


import SwiftUI

struct CalendarDayCell: View {
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

        static let intensityOpacityMultiplier: Double = 0.45
        static let selectedBackgroundOpacity: Double = 0.85
        static let outOfMonthBackgroundOpacity: Double = 0.05
        static let disabledBackgroundOpacity: Double = 0.06
        static let disabledOutOfMonthBackgroundOpacity: Double = 0.03
        static let disabledContentOpacity: Double = 0.55

        static let selectedStrokeOpacity: Double = 0.60
        static let todayStrokeOpacity: Double = 0.32
        static let selectedStrokeWidth: CGFloat = 1.5
        static let todayStrokeWidth: CGFloat = 1
    }

    let date: Date
    let intensity: Double
    let count: Int
    let indicatorText: String?
    let accent: Color
    let isInDisplayedMonth: Bool
    let isDisabled: Bool
    let isSelected: Bool
    let isToday: Bool
    let calendar: Calendar
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    private var backgroundFill: Color {
        if isDisabled {
            return Color.primary.opacity(isInDisplayedMonth ? Layout.disabledBackgroundOpacity : Layout.disabledOutOfMonthBackgroundOpacity)
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

        return max(0, min(1, intensity)) * Layout.intensityOpacityMultiplier
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var dayNumberColor: Color {
        if isDisabled {
            return Color.primary.opacity(isInDisplayedMonth ? 0.38 : 0.24)
        }

        if isSelected {
            return .white.opacity(0.95)
        }

        if isInDisplayedMonth {
            return .primary
        }

        return Color.primary.opacity(0.5)
    }

    private var contentOpacity: Double {
        isDisabled ? Layout.disabledContentOpacity : 1
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
        .gesture(dayGesture)
        .allowsHitTesting(!isDisabled)
        .contextMenu {
            if !isDisabled {
                Button("Open Day Actions") {
                    onLongPress()
                }
            }
        }
        .accessibilityAction(named: Text("Open Day Actions")) {
            guard !isDisabled else { return }
            onLongPress()
        }
        .animation(isDisabled ? nil : .easeInOut(duration: 0.18), value: intensity)
        .animation(isDisabled ? nil : .easeInOut(duration: 0.18), value: count)
        .animation(isDisabled ? nil : .easeInOut(duration: 0.18), value: indicatorText)
        .disabled(isDisabled)
    }

    private var dayGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .exclusively(before: TapGesture())
            .onEnded { value in
                guard !isDisabled else { return }

                switch value {
                case .first(true):
                    onLongPress()
                case .second:
                    onTap()
                default:
                    break
                }
            }
    }

    private var selectionOverlay: some View {
        if isDisabled {
            return RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                .strokeBorder(.clear, lineWidth: 0)
        }

        let strokeColor: Color?
        let lineWidth: CGFloat

        if isSelected {
            strokeColor = Color.white.opacity(Layout.selectedStrokeOpacity)
            lineWidth = Layout.selectedStrokeWidth
        } else if isToday {
            strokeColor = Color.white.opacity(Layout.todayStrokeOpacity)
            lineWidth = Layout.todayStrokeWidth
        } else {
            strokeColor = nil
            lineWidth = 0
        }

        return RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
            .strokeBorder(strokeColor ?? .clear, lineWidth: lineWidth)
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
                        .fill(Color.black.opacity(Layout.indicatorPlateOpacity))
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
                    Circle()
                        .fill(accent)
                        .frame(width: Layout.dotSize, height: Layout.dotSize)
                }
            }
        } else {
            HStack(spacing: Layout.dotSpacing) {
                Circle()
                    .fill(accent)
                    .frame(width: Layout.dotSize, height: Layout.dotSize)

                Text("+\(count - 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
