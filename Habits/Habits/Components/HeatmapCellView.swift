import SwiftUI

struct HeatmapCellView: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let isSelected: Bool
    let intensity: Double
    let accent: Color

    static func == (lhs: HeatmapCellView, rhs: HeatmapCellView) -> Bool {
        lhs.date == rhs.date &&
        lhs.isSelected == rhs.isSelected &&
        lhs.intensity == rhs.intensity
    }

    var body: some View {
        let glow = max(0, Double(CadenceTokens.Intensity.heatmapGlow))

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(cellColor)
            .overlay(cellBorderOverlay)
            .overlay(selectionOverlay)
            .shadow(
                color: isActive
                    ? accent.opacity((colorScheme == .dark ? 0.2 : 0.25) * glow)
                    : .clear,
                radius: isActive ? 3.5 * glow : 0,
                y: isActive ? 1 * glow : 0
            )
    }

    private var cellColor: Color {
        if intensity <= 0 {
            return colorScheme == .dark
                ? Color.white.opacity(0.11)
                : accent.opacity(0.12)
        }

        let clamped = min(max(intensity, 0), 1)
        return accent.opacity(0.24 + (clamped * 0.76))
    }

    @ViewBuilder
    private var cellBorderOverlay: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(accent.opacity(colorScheme == .dark ? 0.34 : 0.4), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(
                    Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.1),
                    lineWidth: 1
                )
        }
    }

    private var isActive: Bool {
        intensity > 0.001
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary.opacity(0.9), lineWidth: 1.6)
        }
    }
}
