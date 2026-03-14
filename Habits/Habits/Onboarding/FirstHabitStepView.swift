import SwiftUI

struct FirstHabitStepView: View {
    let onSelectPreset: (QuickHabitPreset) -> Void
    let onCreateCustomHabit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Start your first habit")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Choose something small you want to do every day.")
                    .font(.body)
                    .foregroundStyle(Color.onboardingSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                ForEach(QuickHabitPreset.allCases) { preset in
                    Button {
                        onSelectPreset(preset)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: preset.symbolName)
                                .font(.system(size: 18, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.onboardingAccent)
                                .frame(width: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(preset.cadence)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.onboardingSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.onboardingSecondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(TactileButtonStyle())
                }
            }

            Button("Create my own habit") {
                onCreateCustomHabit()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.onboardingAccent)
        }
    }
}
