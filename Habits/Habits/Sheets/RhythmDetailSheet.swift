import SwiftUI

struct RhythmDetailSheet: View {
    let isPremium: Bool
    let data: [HourValue]
    let habit: Habit
    var onUnlock: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedHour: Int?

    private var insight: RhythmInsight {
        generateRhythmInsight(data: data)
    }

    private var accent: Color {
        habit.curatedColorVariants.strong
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CadenceTokens.Space.lg) {
                    Text("Your Rhythm")
                        .font(CadenceTokens.Typography.title)
                        .foregroundStyle(CadenceTokens.Color.Text.primary)

                    RhythmLineChart(
                        data: data,
                        accent: accent,
                        selectedHour: $selectedHour,
                        selectionEnabled: isPremium
                    )

                    VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                        Text("Peak / Dip Summary")
                            .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                        Text("Peak around \(humanTime(for: insight.peakHour)).")
                        Text("Momentum dips between \(humanTime(for: insight.lowRange.0)) and \(humanTime(for: insight.lowRange.1)).")
                    }
                    .font(CadenceTokens.Typography.body)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)

                    if isPremium {
                        Text(insight.summary)
                            .font(CadenceTokens.Typography.body)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: CadenceTokens.Space.sm) {
                            Text("Unlock your full rhythm")
                                .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                                .foregroundStyle(CadenceTokens.Color.Text.primary)

                            Text("Work with your natural rhythm")
                                .font(CadenceTokens.Typography.body)
                                .foregroundStyle(CadenceTokens.Color.Text.secondary)

                            Button("View full insight") {
                                onUnlock?()
                            }
                            .buttonStyle(.plain)
                            .font(CadenceTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(accent)
                        }
                    }
                }
                .padding(.horizontal, CadenceTokens.Space.lg)
                .padding(.vertical, CadenceTokens.Space.lg)
            }
            .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(CadenceTokens.Typography.body.weight(.semibold))
                }
            }
        }
    }
}
