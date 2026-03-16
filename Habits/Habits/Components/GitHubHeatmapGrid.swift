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
    let premiumHistoryGate: PremiumHistoryGate.Context
    let intensityFor: (Date) -> Double
    let streakEmphasisFor: (Date) -> HeatmapStreakEmphasis
    let onTapDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    private let rows: CGFloat = 7

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            dayLabels
            scrollableGrid
        }
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
                    .overlay(alignment: .center) {
                        if premiumBoundaryWeekIndex == index {
                            PremiumBoundaryIndicator()
                                .offset(y: 8)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: style.monthLabelHeight)
    }

    private var gridColumns: some View {
        LazyHStack(alignment: .top, spacing: style.horizontalSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                VStack(spacing: style.verticalSpacing) {
                    ForEach(week.days.indices, id: \.self) { i in
                        let day = week.days[i]

                        if let day {
                            let isLockedDay = premiumHistoryGate.isLocked(date: day)
                            HeatCell(
                                date: day,
                                accent: accent,
                                intensity: premiumHistoryGate.visibleIntensity(
                                    for: intensityFor(day),
                                    on: day
                                ),
                                streakEmphasis: streakEmphasisFor(day),
                                size: style.cellSize,
                                style: style,
                                isSelected: calendarProvider.calendar.isDate(day, inSameDayAs: selectedDate),
                                isToday: calendarProvider.calendar.isDateInToday(day),
                                isInteractive: isInteractive || isLockedDay,
                                isLocked: premiumHistoryGate.usesLockedStyle(on: day),
                                inactiveEmphasis: premiumBoundaryWeekIndex == index ? 1.45 : 1,
                                onTap: {
                                    if isLockedDay {
                                        onTapLockedDay(day)
                                    } else {
                                        onTapDay(day)
                                    }
                                }
                            )
                        } else {
                            Color.clear
                                .frame(width: style.cellSize, height: style.cellSize)
                        }
                    }
                }
                .overlay {
                    if premiumBoundaryWeekIndex == index,
                       let premiumBoundaryDate {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                TapGesture().onEnded {
                                    onTapLockedDay(premiumBoundaryDate)
                                }
                            )
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
        .defaultScrollAnchor(.trailing)
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

    private var boundaryLockedDate: Date? {
        weeks
            .flatMap(\.days)
            .compactMap { $0 }
            .last(where: { premiumHistoryGate.isLocked(date: $0) })
    }

    private var premiumBoundaryWeekIndex: Int? {
        guard premiumHistoryGate.premiumStatus == .free else {
            return nil
        }

        let accessibleWeekCount = premiumHistoryGate.premiumBoundaryWeekCount
        guard weeks.count > accessibleWeekCount else {
            return nil
        }

        return weeks.index(weeks.endIndex, offsetBy: -(accessibleWeekCount + 1))
    }

    private var premiumBoundaryDate: Date? {
        guard let premiumBoundaryWeekIndex else {
            return boundaryLockedDate
        }

        return weeks[premiumBoundaryWeekIndex].days.compactMap { $0 }.max()
    }
}

private struct PremiumBoundaryIndicator: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "lock.fill")
                .font(.caption2.weight(.semibold))

            Text("Premium")
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.96))
        )
    }
}
