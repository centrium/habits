import SwiftUI

struct HeroSection: View {
    let completionRate: Double
    let completedDays: Int
    let totalDays: Int
    let momentumPercentage: Int
    let momentumDirection: HabitInsightsMomentumDirection
    let accent: Color

    private var completionText: String {
        "\(Int((completionRate * 100).rounded()))%"
    }

    private func reinforcementMessage(for completionRate: Double) -> String {
        switch completionRate {
        case 0.8...:
            return "You're staying consistent."
        case 0.5..<0.8:
            return "You're building momentum."
        default:
            return "Consistency will strengthen this habit."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(completionText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .padding(.bottom, 10)

            Text("Completion (Last 30 Days)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 5)

            Text("\(completedDays) of \(totalDays) days completed")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(reinforcementMessage(for: completionRate))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 9)

            HStack(spacing: 6) {
                Text(momentumDirection.arrow)
                    .foregroundStyle(momentumDirection.color)

                Text("\(momentumPercentage)% \(momentumDirection.heroLabel)")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .padding(.top, 10)
        }
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
