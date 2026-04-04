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
        if intensity <= 0 {
            return Color.primary.opacity(0.08)
        }

        let clamped = min(max(intensity, 0), 1)
        return accent.opacity(0.4 + (clamped * 0.5))
    }

    @ViewBuilder
    private var cellBorderOverlay: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(
                    Color.primary.opacity(0.1),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private func todayOverlay(today: Bool) -> some View {
        if today {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(accent, lineWidth: 2)
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
                .stroke(today ? accent : Color.primary.opacity(0.9), lineWidth: today ? 2 : 1.6)
        }
    }
}
