import SwiftUI

struct RhythmDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
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
        semanticAccent.cadenceAccentPrimary
    }

    private var semanticAccent: CadenceSemanticAccentTokens {
        CadenceTokens.Color.semanticAccent(for: habit, colorScheme: colorScheme)
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
                        Text(peakSummaryLine)
                        Text(dipSummaryLine)
                    }
                    .font(CadenceTokens.Typography.body)
                    .foregroundStyle(CadenceTokens.Color.Text.secondary)

                    if isPremium {
                        Text(highlightedTimesBySentence(in: insight.summary))
                            .font(CadenceTokens.Typography.body)
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

    private var peakSummaryLine: AttributedString {
        var line = AttributedString("Peak around ")
        line.foregroundColor = CadenceTokens.Color.Text.secondary

        var value = AttributedString(formattedTime(insight.peakHour))
        value.foregroundColor = semanticAccent.cadenceAccentPrimary
        line += value

        var suffix = AttributedString(".")
        suffix.foregroundColor = CadenceTokens.Color.Text.secondary
        line += suffix

        return line
    }

    private var dipSummaryLine: AttributedString {
        var line = AttributedString("Momentum dips between ")
        line.foregroundColor = CadenceTokens.Color.Text.secondary

        var start = AttributedString(formattedTime(insight.lowRange.0))
        start.foregroundColor = semanticAccent.cadenceAccentPrimary
        line += start

        var connector = AttributedString(" and ")
        connector.foregroundColor = CadenceTokens.Color.Text.secondary
        line += connector

        var end = AttributedString(formattedTime(insight.lowRange.1))
        end.foregroundColor = semanticAccent.cadenceAccentPrimary
        line += end

        var suffix = AttributedString(".")
        suffix.foregroundColor = CadenceTokens.Color.Text.secondary
        line += suffix

        return line
    }

    private func formattedTime(_ hour: Int) -> String {
        humanTime(for: hour)
    }

    private func highlightedTimesBySentence(in text: String) -> AttributedString {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)\b(midnight|noon|\d{1,2}(?:am|pm))\b"#,
            options: []
        ) else {
            var fallback = AttributedString(text)
            fallback.foregroundColor = CadenceTokens.Color.Text.secondary
            return fallback
        }

        var output = AttributedString()
        var cursor = 0
        let fullRange = NSRange(location: 0, length: nsText.length)

        var hasAccentInCurrentSentence = false

        for match in regex.matches(in: text, options: [], range: fullRange) {
            let preTokenRange = NSRange(location: cursor, length: match.range.location - cursor)
            if preTokenRange.length > 0 {
                let plain = nsText.substring(with: preTokenRange)
                var plainAttributed = AttributedString(plain)
                plainAttributed.foregroundColor = CadenceTokens.Color.Text.secondary
                output += plainAttributed

                if plain.contains(".") || plain.contains("!") || plain.contains("?") {
                    hasAccentInCurrentSentence = false
                }
            }

            let token = nsText.substring(with: match.range)
            var tokenAttributed = AttributedString(token)
            tokenAttributed.foregroundColor = hasAccentInCurrentSentence
                ? CadenceTokens.Color.Text.secondary
                : semanticAccent.cadenceAccentSecondary
            output += tokenAttributed

            hasAccentInCurrentSentence = true

            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            let trailing = nsText.substring(from: cursor)
            var trailingAttributed = AttributedString(trailing)
            trailingAttributed.foregroundColor = CadenceTokens.Color.Text.secondary
            output += trailingAttributed
        }

        return output
    }
}
