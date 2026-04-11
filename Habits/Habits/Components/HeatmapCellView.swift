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
        let today = Calendar.current.isDateInToday(date)

        if isSelected {
            RoundedRectangle(cornerRadius: 2)
                .stroke(selectionAccent.opacity(0.2), lineWidth: 0.5)
                .overlay {
                    if today {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.primary.opacity(0.35), lineWidth: 1)
                    }
                }
        }
    }
}
