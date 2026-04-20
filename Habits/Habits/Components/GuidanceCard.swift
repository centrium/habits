import SwiftUI

struct GuidanceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseOpacity: Double = 0.6

    let output: GuidanceOutput
    let accent: CadenceAccentTokens
    var variant: GuidanceVisualVariant = .focus
    var label: String = "NOW"
    var guidanceText: String? = nil
    var isLoading: Bool = false
    var loadingText: String = "Thinking…"

    var body: some View {
        let hasCustomGuidance = guidanceText?.isEmpty == false
        let resolvedGuidanceText = hasCustomGuidance ? (guidanceText ?? output.action) : output.action

        VStack(alignment: .leading, spacing: InsightCardHeader.contentSpacing) {
            InsightCardHeader(title: label)

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

                    if isLoading {
                        Text(loadingText)
                            .font(.body)
                            .foregroundStyle(CadenceTokens.Color.Text.secondary)
                            .opacity(pulseOpacity)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, minHeight: guidanceTextMinHeight, alignment: .topLeading)
                            .transition(.opacity)
                    } else {
                        Text(resolvedGuidanceText)
                            .font(hasCustomGuidance ? .body : .system(size: 13))
                            .foregroundStyle(hasCustomGuidance ? .primary : CadenceTokens.Color.Text.secondary.opacity(0.9))
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, minHeight: guidanceTextMinHeight, alignment: .topLeading)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, InsightCardHeader.topPadding)
        .padding(.horizontal, CadenceTokens.Space.lg + 4)
        .padding(.bottom, InsightCardHeader.bottomPadding)
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
        .accessibilityLabel([output.title, output.action].joined(separator: ". "))
        .onAppear {
            updatePulseAnimation()
        }
        .onChange(of: isLoading) { _, _ in
            updatePulseAnimation()
        }
    }

    private var accentColor: Color {
        accent.primary.opacity(variant == .glow ? (colorScheme == .dark ? 0.64 : 0.5) : (colorScheme == .dark ? 0.54 : 0.4))
    }

    private var titleSize: CGFloat {
        variant == .pinnedMoment ? 19.5 : 18.5
    }

    private var guidanceTextMinHeight: CGFloat {
        84
    }

    private var shadowColor: Color {
        if variant == .glow {
            return accent.primary.opacity(colorScheme == .dark ? 0.1 : 0.07)
        }
        return Color.black.opacity(0.07)
    }

    private func updatePulseAnimation() {
        if isLoading {
            pulseOpacity = 0.6
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 1.0
            }
            return
        }
        pulseOpacity = 1.0
    }
}
