import SwiftUI

struct GuidanceCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let output: GuidanceOutput
    let accent: CadenceAccentTokens
    var variant: GuidanceVisualVariant = .focus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NOW")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.62))
                .padding(.bottom, variant == .pinnedMoment ? 8 : 6)

            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 7) {
                    Text(output.title)
                        .font(.system(size: titleSize, weight: .medium))
                        .foregroundStyle(CadenceTokens.Color.Text.primary.opacity(0.98))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(output.action)
                        .font(.system(size: 13))
                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.9))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    if let supportingContext = output.supportingContext {
                        let lines = contextLines(from: supportingContext)
                        let primaryIndex = primaryContextIndex(in: lines)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                let isPrimary = index == primaryIndex
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(CadenceTokens.Typography.body)
                                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.9))
                                        .opacity(isPrimary ? 0.72 : 0.42)

                                    Text(line)
                                        .font(.system(size: 11, weight: isPrimary ? .medium : .regular))
                                        .foregroundStyle(CadenceTokens.Color.Text.secondary.opacity(0.78))
                                        .opacity(isPrimary ? 1.0 : 0.7)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, topPadding)
        .padding(.horizontal, CadenceTokens.Space.lg + 4)
        .padding(.bottom, CadenceTokens.Space.lg)
        .background(
            ZStack {
                if variant == .glow {
                    RadialGradient(
                        colors: [
                            accent.primary.opacity(colorScheme == .dark ? 0.14 : 0.09),
                            .clear
                        ],
                        center: UnitPoint(x: 0.18, y: 0.02),
                        startRadius: 8,
                        endRadius: 180
                    )
                    .blur(radius: 10)
                }

                RoundedRectangle(cornerRadius: CadenceTokens.Surface.cardCornerRadius, style: .continuous)
                    .fill(accent.primary.opacity(colorScheme == .dark ? 0.055 : 0.04))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: CadenceTokens.Surface.cardCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .cadenceSurface(cornerRadius: CadenceTokens.Surface.cardCornerRadius)
        .shadow(color: shadowColor, radius: variant == .glow ? 14 : 10, y: variant == .glow ? 6 : 4)
        .overlay(alignment: .bottom) {
            if variant == .pinnedMoment {
                Divider()
                    .opacity(0.08)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([output.title, output.action, output.supportingContext].compactMap { $0 }.joined(separator: ". "))
    }

    private var accentColor: Color {
        accent.primary.opacity(variant == .glow ? (colorScheme == .dark ? 0.64 : 0.5) : (colorScheme == .dark ? 0.54 : 0.4))
    }

    private var titleSize: CGFloat {
        variant == .pinnedMoment ? 19.5 : 18.5
    }

    private var topPadding: CGFloat {
        variant == .pinnedMoment ? CadenceTokens.Space.lg + 2 : CadenceTokens.Space.lg
    }

    private var shadowColor: Color {
        if variant == .glow {
            return accent.primary.opacity(colorScheme == .dark ? 0.1 : 0.07)
        }
        return Color.black.opacity(0.07)
    }

    private func contextLines(from text: String) -> [String] {
        let lines = text
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [text] : Array(lines.prefix(3))
    }

    private func primaryContextIndex(in lines: [String]) -> Int {
        guard !lines.isEmpty else { return 0 }
        if lines.count <= 2 { return 0 }

        let patternKeywords = [
            "around",
            "morning",
            "midday",
            "afternoon",
            "evening",
            "night",
            "later in the day",
            "varies throughout the day"
        ]
        if let patternIndex = lines.firstIndex(where: { line in
            let normalized = line.lowercased()
            return patternKeywords.contains(where: { normalized.contains($0) })
        }) {
            return patternIndex
        }

        let consistencyKeywords = [
            "consistent",
            "consistency",
            "this week",
            "of last"
        ]
        if let consistencyIndex = lines.firstIndex(where: { line in
            let normalized = line.lowercased()
            return consistencyKeywords.contains(where: { normalized.contains($0) })
        }) {
            return consistencyIndex
        }

        return 0
    }
}
