import SwiftUI

struct TrendSection: View {
    let activity: [Int]
    let accent: Color
    let animateBars: Bool

    private let chartHeight: CGFloat = 64
    private let barSpacing: CGFloat = 6

    private var maxValue: Int {
        max(activity.max() ?? 1, 1)
    }

    var body: some View {
        HabitInsightsCard(padding: 17) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Last 14 Days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    let barCount = CGFloat(max(activity.count, 1))
                    let totalSpacing = barSpacing * CGFloat(max(activity.count - 1, 0))
                    let barWidth = max(4, (geometry.size.width - totalSpacing) / barCount)

                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(activity.enumerated()), id: \.offset) { index, value in
                            RoundedRectangle(cornerRadius: min(3, barWidth / 2), style: .continuous)
                                .fill(fillColor(for: value))
                                .frame(
                                    width: barWidth,
                                    height: barHeight(for: value, availableHeight: geometry.size.height)
                                )
                                .animation(
                                    .spring(response: 0.42, dampingFraction: 0.88)
                                        .delay(0.06 + (Double(index) * 0.025)),
                                    value: animateBars
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(height: chartHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fillColor(for value: Int) -> Color {
        value == 0 ? Color.secondary.opacity(0.18) : accent.opacity(0.78)
    }

    private func barHeight(for value: Int, availableHeight: CGFloat) -> CGFloat {
        guard animateBars else { return 0 }
        guard value > 0 else { return 6 }

        let normalized = CGFloat(value) / CGFloat(maxValue)
        return max(12, normalized * availableHeight)
    }
}
