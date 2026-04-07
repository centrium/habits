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
        let glow = max(0, Double(CadenceTokens.Intensity.heatmapGlow))
        let today = Calendar.current.isDateInToday(date)

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(cellColor)
            .overlay(cellBorderOverlay)
            .overlay(todayOverlay(today: today))
            .overlay(selectionOverlay)
            .shadow(
                color: isActive
                    ? accent.opacity((colorScheme == .dark ? 0.1 : 0.12) * glow)
                    : .clear,
                radius: isActive ? 1.8 * glow : 0,
                y: isActive ? 0.8 * glow : 0
            )
    }

    private var cellColor: Color {
        let clamped = clampedIntensity

        guard clamped > 0 else {
            return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
        }

        let base = colorScheme == .dark ? 0.58 : 0.54
        let range = colorScheme == .dark ? 0.36 : 0.42
        let opacity = min(base + (clamped * range), 1)
        return accent.opacity(opacity)
    }

    private var clampedIntensity: Double {
        min(max(intensity, 0), 1)
    }

    @ViewBuilder
    private var cellBorderOverlay: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(accent.opacity(colorScheme == .dark ? 0.46 : 0.36), lineWidth: 1)
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

    private var isActive: Bool {
        intensity > 0.001
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
