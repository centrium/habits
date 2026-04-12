import SwiftUI

struct HeatmapCellView: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let isSelected: Bool
    let logCount: Int
    let habitColor: HabitColor
    let selectionAccent: Color

    static func == (lhs: HeatmapCellView, rhs: HeatmapCellView) -> Bool {
        lhs.date == rhs.date &&
        lhs.isSelected == rhs.isSelected &&
        lhs.logCount == rhs.logCount &&
        lhs.habitColor == rhs.habitColor
    }

    var body: some View {
        let today = Calendar.current.isDateInToday(date)
        let visuals = IntensityColorEngine.style(
            forLogCount: logCount,
            habitColor: habitColor,
            colorScheme: colorScheme
        )

        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(visuals.fill)
            .overlay(cellBorderOverlay)
            .overlay(todayOverlay(today: today))
            .overlay(selectionOverlay)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cellBorderOverlay: some View {
        let visuals = IntensityColorEngine.style(
            forLogCount: logCount,
            habitColor: habitColor,
            colorScheme: colorScheme
        )

        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .stroke(visuals.border, lineWidth: 1)
    }

    @ViewBuilder
    private func todayOverlay(today: Bool) -> some View {
        if today {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(
                    Color.primary.opacity(0.35),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(selectionStrokeColor, lineWidth: 1)
        }
    }

    private var selectionStrokeColor: Color {
        colorScheme == .light
            ? Color.black.opacity(0.6)
            : Color.white.opacity(0.7)
    }
}
