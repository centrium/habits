import SwiftUI

struct TopAmbientGradient: View {
    let accent: Color
    let highlight: Color

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
                highlight.opacity(0.22),
                accent.opacity(0.28),
                accent.opacity(0.14),
                .clear
            ]
        } else {
            return [
                highlight.opacity(0.24),
                accent.opacity(0.20),
                accent.opacity(0.10),
                .clear
            ]
        }
    }
}
