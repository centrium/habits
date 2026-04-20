import SwiftUI

struct HeatmapCellView: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let isSelected: Bool
    let logCount: Int
    let habitColor: HabitColor
    let selectionAccent: Color
    let activityStripStyle: ActivityStripStyle

    init(
        date: Date,
        isSelected: Bool,
        logCount: Int,
        habitColor: HabitColor,
        selectionAccent: Color,
        activityStripStyle: ActivityStripStyle = .primary
    ) {
        self.date = date
        self.isSelected = isSelected
        self.logCount = logCount
        self.habitColor = habitColor
        self.selectionAccent = selectionAccent
        self.activityStripStyle = activityStripStyle
    }

    static func == (lhs: HeatmapCellView, rhs: HeatmapCellView) -> Bool {
        lhs.date == rhs.date &&
        lhs.isSelected == rhs.isSelected &&
        lhs.logCount == rhs.logCount &&
        lhs.habitColor == rhs.habitColor
    }

    var body: some View {
        let today = Calendar.current.isDateInToday(date)
        let visuals = IntensityColorEngine.style(
            forLogCount: effectiveLogCount,
            habitColor: habitColor,
            colorScheme: colorScheme
        )

        RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
            .fill(cellFillColor(from: visuals))
            .overlay(cellBorderOverlay)
            .overlay(todayOverlay(today: today))
            .overlay(selectionOverlay)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cellBorderOverlay: some View {
        let visuals = IntensityColorEngine.style(
            forLogCount: effectiveLogCount,
            habitColor: habitColor,
            colorScheme: colorScheme
        )

        RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
            .stroke(cellBorderColor(from: visuals), lineWidth: 1)
    }

    @ViewBuilder
    private func todayOverlay(today: Bool) -> some View {
        if today {
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .stroke(
                    Color.primary.opacity(todayStrokeOpacity),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .strokeBorder(selectionStrokeColor, lineWidth: 1)
        }
    }

    private var selectionStrokeColor: Color {
        colorScheme == .light
            ? Color.black.opacity(0.6)
            : Color.white.opacity(0.7)
    }

    private var effectiveLogCount: Int {
        switch activityStripStyle {
        case .primary:
            return logCount
        case .subtle:
            return min(logCount, 4)
        }
    }

    private var cellCornerRadius: CGFloat {
        switch activityStripStyle {
        case .primary:
            return 2
        case .subtle:
            return 1.5
        }
    }

    private var todayStrokeOpacity: Double {
        switch activityStripStyle {
        case .primary:
            return 0.35
        case .subtle:
            return 0.16
        }
    }

    private func cellFillColor(from visuals: IntensityVisualStyle) -> Color {
        switch activityStripStyle {
        case .primary:
            return visuals.fill
        case .subtle:
            if visuals.level == 0 {
                return colorScheme == .dark
                    ? Color.white.opacity(0.12)
                    : Color.black.opacity(0.12)
            }
            return visuals.fill.opacity(0.55)
        }
    }

    private func cellBorderColor(from visuals: IntensityVisualStyle) -> Color {
        switch activityStripStyle {
        case .primary:
            return visuals.border
        case .subtle:
            if visuals.level == 0 {
                return colorScheme == .dark
                    ? Color.white.opacity(0.14)
                    : Color.black.opacity(0.12)
            }
            return visuals.border.opacity(0.45)
        }
    }
}
