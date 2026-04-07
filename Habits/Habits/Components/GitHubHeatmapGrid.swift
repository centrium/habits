//
//  GitHubHeatmapGrid.swift
//  Habits
//
//  Created by Matt Adams on 23/02/2026.
//


import SwiftUI

struct GitHubHeatmapGrid: View {
    let accent: Color
    let selectionAccent: Color
    let style: HeatmapStyleConfiguration
    let calendarProvider: CalendarProvider
    let weeks: [Week]
    let selectedDate: Date
    let isInteractive: Bool
    let isDateLocked: (Date) -> Bool
    private let intensityByDate: [Date: Double]
    private let lockedDates: Set<Date>
    let onTapDay: (Date) -> Void
    let onTapLockedDay: (Date) -> Void

    private let rows: CGFloat = 7

    private struct MonthMarker: Identifiable {
        let id: Int
        let label: String
        let x: CGFloat
    }

    init(
        accent: Color,
        selectionAccent: Color,
        style: HeatmapStyleConfiguration,
        calendarProvider: CalendarProvider,
        weeks: [Week],
        selectedDate: Date,
        isInteractive: Bool,
        isDateLocked: @escaping (Date) -> Bool,
        intensityByDate: [Date: Double],
        lockedDates: Set<Date>,
        onTapDay: @escaping (Date) -> Void,
        onTapLockedDay: @escaping (Date) -> Void
    ) {
        self.accent = accent
        self.selectionAccent = selectionAccent
        self.style = style
        self.calendarProvider = calendarProvider
        self.weeks = weeks
        self.selectedDate = selectedDate
        self.isInteractive = isInteractive
        self.isDateLocked = isDateLocked
        self.intensityByDate = intensityByDate
        self.lockedDates = lockedDates
        self.onTapDay = onTapDay
        self.onTapLockedDay = onTapLockedDay
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            dayLabels
            scrollableGrid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        ZStack(alignment: .topLeading) {
            ForEach(monthMarkers) { marker in
                Text(marker.label)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(style.monthLabelOpacity))
                    .tracking(style.monthLabelTracking)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(
                        width: max(0, gridWidth - marker.x),
                        height: style.monthLabelHeight,
                        alignment: .leading
                    )
                    .offset(x: marker.x)
            }
        }
        .frame(width: gridWidth, height: style.monthLabelHeight, alignment: .leading)
        .clipped()
    }

    private var gridColumns: some View {
        HStack(alignment: .top, spacing: style.horizontalSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                VStack(spacing: style.verticalSpacing) {
                    ForEach(week.days.indices, id: \.self) { i in
                        let day = week.days[i]

                        if let day {
                            let normalizedDay = calendarProvider.calendar.startOfDay(for: day)
                            let isLockedDay = lockedDates.contains(normalizedDay)
                            let intensity = intensityByDate[normalizedDay] ?? 0

                            EquatableView(
                                content: HeatmapCellView(
                                    date: normalizedDay,
                                    isSelected: calendarProvider.calendar.isDate(normalizedDay, inSameDayAs: selectedDate),
                                    intensity: intensity,
                                    accent: accent,
                                    selectionAccent: selectionAccent
                                )
                            )
                            .frame(width: style.cellSize, height: style.cellSize)
                            .opacity(isLockedDay ? 0.35 : 1)
                            .contentShape(Rectangle())
                            .allowsHitTesting(true)
                            .highPriorityGesture(
                                TapGesture().onEnded {
                                    let locked = isDateLocked(normalizedDay)

                                    if locked {
                                        onTapLockedDay(normalizedDay)
                                    } else {
                                        onTapDay(normalizedDay)
                                    }
                                }
                            )
                        } else {
                            Color.clear
                                .frame(width: style.cellSize, height: style.cellSize)
                        }
                    }
                }
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .leading)
        .clipped()
    }

    private var scrollableGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: style.monthLabelToGridSpacing) {
                    monthLabels
                    gridColumns
                }
                .frame(width: gridWidth, height: contentHeight, alignment: .topLeading)
                .clipped()

                if let premiumLockPosition {
                    Image(systemName: "lock.fill")
                        .font(.system(size: max(8, style.cellSize * 0.62), weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: style.cellSize, height: style.cellSize)
                        .position(x: premiumLockPosition.x, y: premiumLockPosition.y)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: gridWidth, height: contentHeight, alignment: .topLeading)
            .padding(.trailing, style.rightEdgeFadeWidth)
            .clipped()
        }
        .defaultScrollAnchor(.trailing)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var contentHeight: CGFloat {
        style.monthLabelHeight + style.monthLabelToGridSpacing + gridHeight
    }

    private var columnCount: Int {
        weeks.count
    }

    private var gridWidth: CGFloat {
        let columns = CGFloat(columnCount)
        let spacingColumns = CGFloat(max(columnCount - 1, 0))
        return (columns * style.cellSize) + (spacingColumns * style.horizontalSpacing)
    }

    private var monthMarkers: [MonthMarker] {
        Array(weeks.enumerated()).compactMap { index, week in
            let isMonthBoundary = index == 0 || week.month != weeks[index - 1].month
            guard isMonthBoundary else { return nil }

            if let nextIndex = weeks.indices.dropFirst(index + 1).first(where: {
                weeks[$0].month != week.month
            }) {
                let distance = nextIndex - index
                guard distance >= 3 else { return nil }
            }

            return MonthMarker(
                id: index,
                label: monthLabel(for: week.id),
                x: xPosition(forColumn: index)
            )
        }
    }

    private var premiumBoundaryWeekIndex: Int? {
        guard let premiumBoundaryDate else { return nil }

        return weeks.firstIndex { week in
            week.days
                .compactMap { $0 }
                .map { calendarProvider.calendar.startOfDay(for: $0) }
                .contains(premiumBoundaryDate)
        }
    }

    private var premiumBoundaryDate: Date? {
        allDates.last(where: { date in
            isDateLocked(date)
        })
    }

    private var premiumLockPosition: CGPoint? {
        guard let premiumBoundaryWeekIndex else { return nil }
        guard let premiumBoundaryDate else { return nil }

        let row = calendarProvider.rowIndex(for: premiumBoundaryDate)
        let x = xPosition(forColumn: premiumBoundaryWeekIndex) + (style.cellSize / 2)
        let y = style.monthLabelHeight + style.monthLabelToGridSpacing + yPosition(forRow: row) + (style.cellSize / 2)
        return CGPoint(x: x, y: y)
    }

    private func xPosition(forColumn column: Int) -> CGFloat {
        CGFloat(column) * (style.cellSize + style.horizontalSpacing)
    }

    private func yPosition(forRow row: Int) -> CGFloat {
        CGFloat(row) * (style.cellSize + style.verticalSpacing)
    }

    private var allDates: [Date] {
        weeks
            .flatMap(\.days)
            .compactMap { $0 }
            .map { calendarProvider.calendar.startOfDay(for: $0) }
    }
}
