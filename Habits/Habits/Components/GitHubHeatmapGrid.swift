//
//  GitHubHeatmapGrid.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct GitHubHeatmapGrid: View {
    let accent: Color
    let weeks: [Week]
    let cellSize: CGFloat = 10
    let cellSpacing: CGFloat = 4
    let selectedDate: Date
    let intensityFor: (Date) -> Double
    let onTapDay: (Date) -> Void

    private let rows: CGFloat = 7
    private let monthLabelHeight: CGFloat = 14
    private let dayLabelWidth: CGFloat = 14
    private let dividerVerticalInset: CGFloat = 2
    private let dividerHorizontalInset: CGFloat = 2

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            dayLabels
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    monthLabels
                    gridColumns
                }
            }
        }
    }

    private var dayLabels: some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(0..<Int(rows), id: \.self) { index in
                let label = dayLabel(for: index)
                if let label {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: dayLabelWidth, height: cellSize, alignment: .center)
                } else {
                    Color.clear
                        .frame(width: dayLabelWidth, height: cellSize)
                }
            }
        }
        .padding(.trailing, cellSpacing)
        .frame(height: monthLabelHeight + gridHeight, alignment: .bottom)
    }

    private var monthLabels: some View {
        LazyHStack(alignment: .top, spacing: 0) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                let isMonthBoundary = index == 0 || week.month != weeks[index - 1].month
                let trailingGap = isMonthBoundary
                    ? cellSpacing + (dividerHorizontalInset * 2)
                    : cellSpacing

                Color.clear
                    .frame(width: cellSize, height: monthLabelHeight)
                    .overlay(alignment: .leading) {
                        if isMonthBoundary {
                            Text(monthLabel(for: week.id))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                                .offset(x: -1)
                        }
                    }
                    .padding(.trailing, trailingGap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: monthLabelHeight)
    }

    private var gridColumns: some View {
        LazyHStack(alignment: .top, spacing: 0) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                let isMonthBoundary = index > 0 && week.month != weeks[index - 1].month
                let trailingGap = isMonthBoundary
                    ? cellSpacing + (dividerHorizontalInset * 2)
                    : cellSpacing

                VStack(spacing: cellSpacing) {
                    ForEach(week.days.indices, id: \.self) { i in
                        let day = week.days[i]

                        if let day {
                            HeatCell(
                                date: day,
                                accent: accent,
                                intensity: intensityFor(day),
                                size: cellSize,
                                isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                                isToday: Calendar.current.isDateInToday(day),
                                onTap: { onTapDay(day) }
                            )
                        } else {
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
                // Keep a consistent rhythm between weeks.
                .padding(.trailing, trailingGap)
                .overlay(alignment: .trailing) {
                    if isMonthBoundary {
                        ZStack {
                            // Invisible container that owns horizontal air
                            Color.clear
                                .frame(width: trailingGap)

                            // The actual divider, centred
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                        .frame(height: gridHeight - (dividerVerticalInset * 2))
                        .offset(x: -(trailingGap / 2) + dividerHorizontalInset + 2)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: gridHeight)
    }

    private func dayLabel(for index: Int) -> String? {
        switch index {
        case 1:
            return "M"
        case 3:
            return "W"
        case 5:
            return "F"
        default:
            return nil
        }
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private var gridHeight: CGFloat {
        (cellSize * rows) + (cellSpacing * (rows - 1))
    }
}
