import SwiftUI

struct RhythmCardView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    let isPremium: Bool
    let data: [HourValue]
    let rhythm: HabitRhythm?
    let habit: Habit
    var onUnlock: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil

    @State private var selectedHour: Int?

    private var insight: RhythmInsight {
        generateRhythmInsight(from: resolvedInsight)
    }

    private var strongestTimeframe: BestTimeTimeframe {
        bestTimeRecommendation(from: resolvedInsight, currentHour: currentHour).timeframe
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

    private var rightNowLine: String {
        if resolvedInsight.confidence < 0.35 {
            return "Right now: your pattern is still stabilising."
        }

        let peakHour = resolvedInsight.peakHour
        if wrappedHourDistance(currentHour, peakHour) <= 2 {
            return "Right now: you're in your strongest window."
        }

        if isBeforePeak(currentHour, peakHour: peakHour) {
            return "Right now: your strongest window is coming up."
        }

        return "Right now: you usually do this later in the day."
    }

    private var primaryInsight: AttributedString {
        let peakHour = resolvedInsight.peakHour
        if resolvedInsight.confidence < 0.35 {
            var soft = AttributedString("Usually \(softWindowPhrase(for: peakHour)).")
            soft.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)
            return soft
        }

        if resolvedInsight.confidence < 0.75 {
            var leading = AttributedString("Often around ")
            leading.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)

            var value = AttributedString(formattedTime(peakHour))
            value.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.82 : 0.74)

            var trailing = AttributedString(".")
            trailing.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)
            return leading + value + trailing
        }

        let prefix = strongestTimeframe == .today ? "Strongest window: " : "Strongest window tomorrow: "
        var leading = AttributedString(prefix)
        leading.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)

        var value = AttributedString(formattedTime(peakHour))
        value.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.82 : 0.74)

        var trailing = AttributedString(".")
        trailing.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)

        return leading + value + trailing
    }

    private var secondaryDetail: AttributedString {
        if resolvedInsight.confidence < 0.35 {
            var text = AttributedString("Recent logs usually land \(softWindowPhrase(for: resolvedInsight.peakHour)).")
            text.foregroundColor = CadenceTokens.Color.Text.secondary
            return text
        }

        var text = AttributedString("Peak: ")
        text.foregroundColor = CadenceTokens.Color.Text.secondary

        var peak = AttributedString(formattedTime(insight.peakHour))
        peak.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.8 : 0.72)
        text += peak

        var separator = AttributedString(" · Dip: ")
        separator.foregroundColor = CadenceTokens.Color.Text.secondary
        text += separator

        var dipStart = AttributedString(formattedTime(insight.lowRange.0))
        dipStart.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.8 : 0.72)
        text += dipStart

        var dash = AttributedString("–")
        dash.foregroundColor = semanticAccent.cadenceAccentSecondary.opacity(colorScheme == .dark ? 0.76 : 0.68)
        text += dash

        var dipEnd = AttributedString(formattedTime(insight.lowRange.1))
        dipEnd.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.8 : 0.72)
        text += dipEnd

        return text
    }

    private var behaviouralSignal: String {
        if resolvedInsight.confidence < 0.35 {
            return "Add more check-ins to sharpen your strongest window."
        }

        let consistencyStart = max(0, insight.peakHour - 1)
        let consistencyEnd = min(23, insight.peakHour + 1)

        if insight.lowRange.0 >= 22 || insight.lowRange.1 <= 2 {
            return "Momentum drops late at night."
        }

        return "Your consistency window is \(formattedTime(consistencyStart))–\(formattedTime(consistencyEnd))."
    }

    private var confidenceSignal: String {
        guard let rhythm else { return "Low confidence" }
        switch rhythm.confidence {
        case ..<0.35:
            return "Low confidence"
        case ..<0.75:
            return "Building confidence"
        default:
            return "High confidence"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceTokens.Space.md) {
            HStack(spacing: CadenceTokens.Space.xs) {
                Text("Momentum")
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
                Text(rightNowLine)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.84))

                Text(secondaryDetail)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                Text(behaviouralSignal)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.82))
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

    private func wrappedHourDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let raw = abs(lhs - rhs)
        return min(raw, 24 - raw)
    }

    private func isBeforePeak(_ currentHour: Int, peakHour: Int) -> Bool {
        let forwardDistance = (peakHour - currentHour + 24) % 24
        return forwardDistance > 0 && forwardDistance <= 12
    }

    private func formattedTime(_ hour: Int) -> String {
        humanTime(for: hour)
    }

    private func softWindowPhrase(for hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        switch normalized {
        case 0..<5:
            return "later at night"
        case 5..<11:
            return "earlier in the morning"
        case 11..<15:
            return "around midday"
        case 15..<18:
            return "later in the afternoon"
        case 18..<22:
            return "later in the evening"
        default:
            return "at night"
        }
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
