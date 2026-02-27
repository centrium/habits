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

        static let selectedStrokeOpacity: Double = 0.60
        static let todayStrokeOpacity: Double = 0.32
        static let selectedStrokeWidth: CGFloat = 1.5
        static let todayStrokeWidth: CGFloat = 1
    }

    let date: Date
    let intensity: Double
    let count: Int
    let accent: Color
    let isInDisplayedMonth: Bool
    let isDisabled: Bool
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    private var backgroundOpacity: Double {
        if !isInDisplayedMonth {
            return Layout.outOfMonthBackgroundOpacity
        }

        if isSelected {
            return Layout.selectedBackgroundOpacity
        }

        return max(0, min(1, intensity)) * Layout.intensityOpacityMultiplier
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                    .fill(accent.opacity(backgroundOpacity))

                VStack(spacing: 0) {
                    Text(dayNumber)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.top, Layout.dayTopPadding)
                        .frame(height: Layout.dayNumberAreaHeight, alignment: .top)

                    Spacer(minLength: Layout.middleMinHeight)

                    indicatorContainer
                        .frame(height: Layout.indicatorAreaHeight, alignment: .bottom)
                }
            }
            .frame(width: Layout.cellWidth, height: Layout.cellHeight)
            .opacity(isInDisplayedMonth ? 1.0 : 0.45)
            .overlay(selectionOverlay)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in onLongPress() }
        )
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var selectionOverlay: some View {
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
        if count > 0 {
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
        if count <= 5 {
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
