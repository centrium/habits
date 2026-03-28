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
        Rectangle()
            .fill(cellColor)
            .overlay(selectionOverlay)
    }

    private var cellColor: Color {
        if intensity <= 0 {
            return accent.opacity(0.08)
        }

        return accent.opacity(min(max(intensity, 0), 1))
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary, lineWidth: 1.5)
        }
    }
}
