import SwiftUI

struct RhythmCardView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    let isPremium: Bool
    let data: [HourValue]
    let habit: Habit
    var onUnlock: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil

    @State private var selectedHour: Int?

    private var insight: RhythmInsight {
        generateRhythmInsight(data: data)
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
        var leading = AttributedString("Your strongest window is ")
        leading.foregroundColor = CadenceTokens.Color.Text.primary

        var value = AttributedString(formattedTime(insight.peakHour))
        value.foregroundColor = semanticAccent.cadenceAccentPrimary

        var trailing = AttributedString(".")
        trailing.foregroundColor = CadenceTokens.Color.Text.primary

        return leading + value + trailing
    }

    private var secondaryDetail: AttributedString {
        var text = AttributedString("Peak: ")
        text.foregroundColor = CadenceTokens.Color.Text.secondary

        var peak = AttributedString(formattedTime(insight.peakHour))
        peak.foregroundColor = semanticAccent.cadenceAccentPrimary
        text += peak

        var separator = AttributedString(" · Dip: ")
        separator.foregroundColor = CadenceTokens.Color.Text.secondary
        text += separator

        var dipStart = AttributedString(formattedTime(insight.lowRange.0))
        dipStart.foregroundColor = semanticAccent.cadenceAccentPrimary
        text += dipStart

        var dash = AttributedString("–")
        dash.foregroundColor = semanticAccent.cadenceAccentSecondary
        text += dash

        var dipEnd = AttributedString(formattedTime(insight.lowRange.1))
        dipEnd.foregroundColor = semanticAccent.cadenceAccentPrimary
        text += dipEnd

        return text
    }

    private var behaviouralSignal: String {
        let consistencyStart = max(0, insight.peakHour - 1)
        let consistencyEnd = min(23, insight.peakHour + 1)

        if insight.lowRange.0 >= 22 || insight.lowRange.1 <= 2 {
            return "Momentum tends to drop late at night."
        }

        return "Your consistency window is \(formattedTime(consistencyStart))–\(formattedTime(consistencyEnd))."
    }

    private var confidenceSignal: String {
        let sorted = data.sorted { $0.value > $1.value }
        guard sorted.count > 1 else { return "Pattern stabilising" }

        let separation = sorted[0].value - sorted[1].value
        return separation >= 0.18 ? "High confidence" : "Pattern stabilising"
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
                        .foregroundStyle(CadenceTokens.Color.Text.secondary)
                }
            }

            if isPremium {
                Text(primaryInsight)
                    .font(CadenceTokens.Typography.body.weight(.semibold))
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
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)

                Text(secondaryDetail)
                    .font(CadenceTokens.Typography.microCopy)
                    .fixedSize(horizontal: false, vertical: true)

                Text(behaviouralSignal)
                    .font(CadenceTokens.Typography.microCopy)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)
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
        let normalized = ((hour % 24) + 24) % 24
        switch normalized {
        case 0:
            return "Midnight"
        case 12:
            return "Noon"
        case 1..<12:
            return "\(normalized)am"
        default:
            return "\(normalized - 12)pm"
        }
    }
}
