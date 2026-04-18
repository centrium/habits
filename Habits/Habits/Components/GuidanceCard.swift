import SwiftUI

struct GuidanceCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let output: GuidanceOutput
    let accent: CadenceAccentTokens
    var variant: GuidanceVisualVariant = .focus
    var label: String = "NOW"
    var guidanceText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
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

                    Text(guidanceText ?? output.action)
                        .font(guidanceText == nil ? .system(size: 13) : .body)
                        .foregroundStyle(guidanceText == nil ? CadenceTokens.Color.Text.secondary.opacity(0.9) : .primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityLabel([output.title, output.action].joined(separator: ". "))
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
}
