import SwiftUI

struct TopAmbientGradient: View {
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity)
        .frame(height: 260, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .mask(
            LinearGradient(
                colors: [
                    .white,
                    .white.opacity(0.6),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }

    private var gradientColors: [Color] {
        if colorScheme == .light {
            return [
                accent.opacity(0.35),
                accent.opacity(0.18),
                .clear
            ]
        } else {
            return [
                accent.opacity(0.25),
                accent.opacity(0.12),
                .clear
            ]
        }
    }
}
