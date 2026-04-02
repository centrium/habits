import SwiftUI

struct HeatmapCellView: View, Equatable {
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
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(cellColor)
            .overlay(selectionOverlay)
    }

    private var cellColor: Color {
        if intensity <= 0 {
            return accent.opacity(0.10)
        }

        let clamped = min(max(intensity, 0), 1)
        return accent.opacity(0.24 + (clamped * 0.76))
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary.opacity(0.9), lineWidth: 1.6)
        }
    }
}
