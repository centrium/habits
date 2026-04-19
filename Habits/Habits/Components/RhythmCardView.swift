import SwiftUI

struct RhythmCardView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    let isPremium: Bool
    let data: [HourValue]
    let rhythm: HabitRhythm?
    let stateModel: HabitStateModel?
    let habit: Habit
    var onUnlock: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil

    @State private var selectedHour: Int?

    private var insight: RhythmInsight {
        generateRhythmInsight(from: resolvedInsight)
    }

    private var resolvedInsight: TimeInsightResult {
        if let existing = rhythm?.timeInsight {
            return existing
        }
        return fallbackInsightFromData
    }

    private var fallbackInsightFromData: TimeInsightResult {
        let values = (0..<24).map { hour in
            data.first(where: { $0.hour == hour })?.value ?? 0
        }
        let peakHour = values.enumerated().max { lhs, rhs in
            if lhs.element == rhs.element { return lhs.offset > rhs.offset }
            return lhs.element < rhs.element
        }?.offset ?? 0
        if values.allSatisfy({ $0 == 0 }) {
            return TimeInsightResult(
                hourlyScores: values,
                peakHour: peakHour,
                confidence: 0,
                distributionShape: .flat
            )
        }
        return TimeInsightResult(
            hourlyScores: values,
            peakHour: peakHour,
            confidence: 0,
            distributionShape: .flat
        )
    }

    private var accent: Color {
        semanticAccent.cadenceAccentPrimary
    }

    private var semanticAccent: CadenceSemanticAccentTokens {
        CadenceTokens.Color.semanticAccent(for: habit, colorScheme: colorScheme)
    }

    private var selectedLabel: String? {
        guard isPremium,
              let selectedHour,
              let point = data.first(where: { $0.hour == selectedHour }) else {
            return nil
        }

        return "\(formattedTime(selectedHour)) - \(Int((point.value * 100).rounded()))%"
    }

    private var currentHour: Int {
        calendar.component(.hour, from: .now)
    }

    private var primaryInsight: AttributedString {
        let label = timingMessage(confidence: timingConfidence)
        var text = AttributedString(label)
        text.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)
        return text
    }

    private var secondaryDetail: AttributedString {
        var text = AttributedString("Strongest window: ")
        text.foregroundColor = CadenceTokens.Color.Text.secondary

        var peak = AttributedString(formattedTime(resolvedInsight.peakHour))
        peak.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.8 : 0.72)
        text += peak

        return text
    }

    private var behaviouralSignal: String {
        let options = [
            "Activity clusters around this time",
            "Recent logs concentrate here"
        ]
        let seed = "\(habit.id.uuidString)|\(resolvedInsight.peakHour)|\(calendar.component(.day, from: .now))"
        let hash = seed.unicodeScalars.reduce(5381) { partial, scalar in
            ((partial << 5) &+ partial) &+ Int(scalar.value)
        }
        let index = abs(hash) % options.count
        return options[index]
    }

    private var confidenceInterpretation: String {
        timingMessage(confidence: timingConfidence)
    }

    private var confidenceSignal: String {
        timingMessage(confidence: timingConfidence)
    }

    private var timingConfidence: TimingConfidence {
        if let stateModel {
            return stateModel.timingConfidence
        }
        let confidence = rhythm?.confidence ?? resolvedInsight.confidence
        switch confidence {
        case ..<0.35:
            return .low
        case ..<0.75:
            return .medium
        default:
            return .high
        }
    }

    private func timingMessage(confidence: TimingConfidence) -> String {
        switch confidence {
        case .low:
            return "Timing is still forming"
        case .medium:
            return "A loose rhythm is emerging"
        case .high:
            return "A clear rhythm is established"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
            HStack(spacing: CadenceTokens.Space.xs) {
                Text("Rhythm")
                    .font(CadenceTokens.Typography.sectionHeader.weight(.semibold))
                    .foregroundStyle(CadenceTokens.Color.Text.primary)

                Spacer(minLength: 0)

                if isPremium {
                    Text(confidenceSignal)
                        .font(CadenceTokens.Typography.microCopy)
                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.82))
                }
            }

            if isPremium {
                Text(primaryInsight)
                    .font(CadenceTokens.Typography.body.weight(.medium))
                    .foregroundStyle(CadenceTokens.Color.Text.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            RhythmLineChart(
                data: data,
                accent: accent,
                selectedHour: $selectedHour,
                selectionEnabled: isPremium,
                nowHour: currentHour,
                peakHour: resolvedInsight.peakHour,
                showNowMarker: isPremium,
                showPeakMarker: isPremium,
                showTrailingIncompletenessFade: !isPremium
            )

            if let selectedLabel {
                Text(selectedLabel)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
            }

            if isPremium {
                Text(secondaryDetail)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                Text(behaviouralSignal)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Text(confidenceInterpretation)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    onUnlock?()
                } label: {
                    VStack(alignment: .leading, spacing: CadenceTokens.Space.xs) {
                        Text("Your rhythm is still forming")
                            .font(CadenceTokens.Typography.body)
                        Text("See your full daily pattern")
                            .font(CadenceTokens.Typography.microCopy)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, -4)
            }
        }
        .padding(.horizontal, CadenceTokens.Space.lg)
        .padding(.vertical, CadenceTokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen?()
        }
        .onAppear {
            logTimingTrace()
        }
        .onChange(of: rhythm?.timeInsight.peakHour) { _, _ in
            logTimingTrace()
        }
    }

    private func formattedTime(_ hour: Int) -> String {
        humanTime(for: hour)
    }

    private func logTimingTrace() {
        #if DEBUG
        let enginePeak = resolvedInsight.peakHour
        let displayedHour = enginePeak
        let chartHighlightedHour = resolvedInsight.peakHour
        print("[TimeInsight CONSISTENCY CHECK]")
        print("surface: Detail")
        print("enginePeak: \(enginePeak)")
        print("consumerHour: \(displayedHour)")
        print("match: \(displayedHour == enginePeak)")
        print("[TimeInsight CONSISTENCY CHECK]")
        print("surface: Momentum")
        print("enginePeak: \(enginePeak)")
        print("consumerHour: \(chartHighlightedHour)")
        print("match: \(chartHighlightedHour == enginePeak)")
        assert(displayedHour == enginePeak, "displayed peak label hour must equal engine peakHour")
        assert(chartHighlightedHour == enginePeak, "chart marker hour must equal engine peakHour")
        #endif
    }
}
