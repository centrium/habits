import SwiftUI

struct MomentumSection: View {
    let percentage: Int
    let direction: HabitInsightsMomentumDirection

    var body: some View {
        HabitInsightsCard(background: Color(.secondarySystemGroupedBackground).opacity(0.85)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Momentum")
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(direction.arrow)
                        .foregroundStyle(direction.color)

                    Text("\(percentage)% vs last week")
                        .foregroundStyle(.primary)
                }
                .font(.title3.weight(.semibold))
                .monospacedDigit()

                Text(direction.momentumSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
