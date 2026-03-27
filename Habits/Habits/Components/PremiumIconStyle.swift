import SwiftUI

private struct PremiumIconStyleModifier: ViewModifier {
    let isPremiumUnlocked: Bool
    let isFeatureLocked: Bool

    func body(content: Content) -> some View {
        content
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(iconForeground)
            .background(alignment: .center) {
                if isPremiumUnlocked && !isFeatureLocked {
                    Circle()
                        .fill(Color.systemAccent.opacity(0.16))
                        .padding(-4)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isPremiumUnlocked)
    }

    private var iconForeground: Color {
        if isPremiumUnlocked && !isFeatureLocked {
            return .systemAccent
        }

        return .secondary
    }
}

extension View {
    func premiumIconStyle(
        isPremiumUnlocked: Bool,
        isFeatureLocked: Bool
    ) -> some View {
        modifier(
            PremiumIconStyleModifier(
                isPremiumUnlocked: isPremiumUnlocked,
                isFeatureLocked: isFeatureLocked
            )
        )
    }
}
