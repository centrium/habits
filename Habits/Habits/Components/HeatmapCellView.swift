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

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(visuals.fill)
            .overlay(cellBorderOverlay)
            .overlay(todayOverlay(today: today))
            .overlay(selectionOverlay)
            .shadow(
                color: visuals.peakShadowColor.opacity(Double(CadenceTokens.Intensity.heatmapGlow)),
                radius: visuals.peakShadowRadius * max(0, CadenceTokens.Intensity.heatmapGlow),
                y: visuals.peakShadowYOffset * max(0, CadenceTokens.Intensity.heatmapGlow)
            )
            .scaleEffect(visuals.peakScale)
    }

    @ViewBuilder
    private var cellBorderOverlay: some View {
        let visuals = IntensityColorEngine.style(
            forLogCount: logCount,
            habitColor: habitColor,
            colorScheme: colorScheme
        )

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(visuals.border, lineWidth: 1)
    }

    @ViewBuilder
    private func todayOverlay(today: Bool) -> some View {
        if today {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(
                    Color.primary.opacity(colorScheme == .dark ? 0.52 : 0.3),
                    lineWidth: colorScheme == .dark ? 1.4 : 1.2
                )
                .scaleEffect(1.04)
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        let today = Calendar.current.isDateInToday(date)

        if isSelected {
            RoundedRectangle(cornerRadius: 4)
                .stroke(selectionAccent, lineWidth: today ? 2 : 1.6)
        }
    }
}
