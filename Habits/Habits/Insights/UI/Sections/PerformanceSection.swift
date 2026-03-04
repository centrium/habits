import SwiftUI

struct PerformanceSection: View {
    let averagePerDay: Double
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        HabitInsightsCard {
            VStack(alignment: .leading, spacing: 0) {
                performanceRow(label: "Average This Month", value: "\(averagePerDay.formatted(.number.precision(.fractionLength(1)))) / day")
                performanceRow(label: "Current Streak", value: "\(currentStreak) days")
                performanceRow(label: "Longest Streak", value: "\(longestStreak) days")
            }
        }
    }

    private func performanceRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.vertical, 13)
    }
}
