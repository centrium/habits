import SwiftUI

struct HeatmapCellView: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let isSelected: Bool
    let intensity: Double
    let accent: Color
    let selectionAccent: Color

    static func == (lhs: HeatmapCellView, rhs: HeatmapCellView) -> Bool {
        lhs.date == rhs.date &&
        lhs.isSelected == rhs.isSelected &&
        lhs.intensity == rhs.intensity
    }

    var body: some View {
        let today = Calendar.current.isDateInToday(date)
        let visuals = IntensityColorEngine.style(
            for: intensity,
            baseColor: accent,
            colorScheme: colorScheme
        )

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(visuals.fill)
            .overlay(luminanceOverlay(opacity: visuals.highlightOpacity))
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
            for: intensity,
            baseColor: accent,
            colorScheme: colorScheme
        )

        if visuals.level > 0 {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(visuals.border, lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(
                    Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06),
                    lineWidth: 1
                )
        }
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
    private func luminanceOverlay(opacity: Double) -> some View {
        if opacity > 0 {
            let overlayTint = IntensityColorEngine.adjustedForScheme(
                accent,
                level: max(1, IntensityColorEngine.level(for: intensity)),
                scheme: colorScheme
            )
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            overlayTint.opacity(colorScheme == .dark ? 0.22 : 0.16),
                            overlayTint.opacity(colorScheme == .dark ? 0.08 : 0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(opacity)
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
