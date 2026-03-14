//
//  GitHubHeatmapGrid.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct GitHubHeatmapGrid: View {
    let accent: Color
    let style: HeatmapStyleConfiguration
    let calendarProvider: CalendarProvider
    let weeks: [Week]
    let selectedDate: Date
    let isInteractive: Bool
    let intensityFor: (Date) -> Double
    let onTapDay: (Date) -> Void

    private let rows: CGFloat = 7

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            dayLabels
            scrollableGrid
        }
        .allowsHitTesting(isInteractive)
    }

    private var dayLabels: some View {
        VStack(alignment: .leading, spacing: style.verticalSpacing) {
            ForEach(0..<Int(rows), id: \.self) { index in
                let label = dayLabel(for: index)
                if let label {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(style.rowLabelOpacity))
                        .frame(width: style.dayLabelWidth, height: style.cellSize, alignment: .center)
                } else {
                    Color.clear
                        .frame(width: style.dayLabelWidth, height: style.cellSize)
                }
            }
        }
        .padding(.leading, style.rowLabelLeadingPadding)
        .padding(.trailing, style.horizontalSpacing + 1)
        .frame(
            width: style.dayLabelWidth + style.rowLabelLeadingPadding + style.horizontalSpacing + 1,
            height: style.monthLabelHeight + style.monthLabelToGridSpacing + gridHeight,
            alignment: .bottomLeading
        )
    }

    private var monthLabels: some View {
        LazyHStack(alignment: .top, spacing: style.horizontalSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in

                let isMonthBoundary = index == 0 || week.month != weeks[index - 1].month

                let shouldShowLabel: Bool = {
                    guard isMonthBoundary else { return false }

                    if let nextIndex = weeks.indices.dropFirst(index + 1).first(where: {
                        weeks[$0].month != week.month
                    }) {
                        let distance = nextIndex - index
                        return distance >= 3
                    }

                    return true
                }()

                Color.clear
                    .frame(width: style.cellSize, height: style.monthLabelHeight)
                    .overlay(alignment: .leading) {
                        if shouldShowLabel {
                            Text(monthLabel(for: week.id))
                                .font(.caption2)
                                .foregroundStyle(Color.secondary.opacity(style.monthLabelOpacity))
                                .tracking(style.monthLabelTracking)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: style.monthLabelHeight)
    }

    private var gridColumns: some View {
        LazyHStack(alignment: .top, spacing: style.horizontalSpacing) {
            ForEach(weeks, id: \.id) { week in
                VStack(spacing: style.verticalSpacing) {
                    ForEach(week.days.indices, id: \.self) { i in
                        let day = week.days[i]

                        if let day {
                            HeatCell(
                                date: day,
                                accent: accent,
                                intensity: intensityFor(day),
                                size: style.cellSize,
                                style: style,
                                isSelected: calendarProvider.calendar.isDate(day, inSameDayAs: selectedDate),
                                isToday: calendarProvider.calendar.isDateInToday(day),
                                isInteractive: isInteractive,
                                onTap: { onTapDay(day) }
                            )
                        } else {
                            Color.clear
                                .frame(width: style.cellSize, height: style.cellSize)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: gridHeight)
    }

    private var scrollableGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: style.monthLabelToGridSpacing) {
                monthLabels
                gridColumns
            }
            .padding(.trailing, style.rightEdgeFadeWidth)
        }
        .mask {
            HStack(spacing: 0) {
                Rectangle().fill(.white)
                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: style.rightEdgeFadeWidth)
            }
        }
    }

    private func dayLabel(for index: Int) -> String? {
        calendarProvider.heatmapRowLabel(forRow: index)
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendarProvider.calendar
        formatter.locale = calendarProvider.calendar.locale ?? .current
        formatter.timeZone = calendarProvider.calendar.timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private var gridHeight: CGFloat {
        (style.cellSize * rows) + (style.verticalSpacing * (rows - 1))
    }
}
