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
        generateRhythmInsight(data: data)
    }

    private var bestTime: BestTimeRecommendation {
        bestTimeRecommendation(from: data, currentHour: currentHour)
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
        if let rhythm, rhythm.confidence < 0.5 {
            return "Right now: your pattern is still stabilising."
        }

        guard let nowPoint = data.first(where: { $0.hour == currentHour }),
              let peakPoint = data.max(by: { $0.value < $1.value }) else {
            return "Right now: building toward your peak window."
        }

        let hourDistance = wrappedHourDistance(currentHour, peakPoint.hour)
        if hourDistance <= 1 {
            return "Right now: around your peak window."
        }

        if nowPoint.value >= peakPoint.value * 0.78 {
            return "Right now: close to your peak window."
        }

        if isEarlierInDay(currentHour, than: peakPoint.hour) {
            return "Right now: below your peak window."
        }

        return "Right now: past your peak window."
    }

    private var primaryInsight: AttributedString {
        if let rhythm, rhythm.confidence < 0.5 {
            var soft = AttributedString("Usually \(softWindowPhrase(for: bestTime.hour)).")
            soft.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)
            return soft
        }

        let prefix: String
        switch bestTime.timeframe {
        case .today:
            prefix = "Strongest window: "
        case .tomorrow:
            prefix = "Strongest window tomorrow: "
        }

        var leading = AttributedString(prefix)
        leading.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)

        var value = AttributedString(formattedTime(bestTime.hour))
        value.foregroundColor = semanticAccent.cadenceAccentPrimary.opacity(colorScheme == .dark ? 0.82 : 0.74)

        var trailing = AttributedString(".")
        trailing.foregroundColor = CadenceTokens.Color.Text.primary.opacity(0.9)

        return leading + value + trailing
    }

    private var secondaryDetail: AttributedString {
        if let rhythm, rhythm.confidence < 0.5 {
            var text = AttributedString("Recent logs usually land \(softWindowPhrase(for: rhythm.peakHour)).")
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
        if let rhythm, rhythm.confidence < 0.5 {
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
        guard let rhythm else { return "Pattern stabilising" }
        return rhythm.confidence >= 0.5 ? "High confidence" : "Pattern stabilising"
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
                showNowMarker: isPremium,
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
    }

    private func isEarlierInDay(_ lhs: Int, than rhs: Int) -> Bool {
        lhs < rhs
    }

    private func wrappedHourDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let raw = abs(lhs - rhs)
        return min(raw, 24 - raw)
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
}
