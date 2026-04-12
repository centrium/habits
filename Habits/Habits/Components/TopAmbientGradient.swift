import SwiftUI

struct TopAmbientGradient: View {
    let tone: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    tone.opacity(colorScheme == .dark ? 0.24 : 0.18),
                    tone.opacity(colorScheme == .dark ? 0.14 : 0.1),
                    tone.opacity(colorScheme == .dark ? 0.08 : 0.05),
                    .clear
                ],
                center: .topLeading,
                startRadius: 12,
                endRadius: 260
            )
            .offset(x: -26, y: -86)
            .blur(radius: colorScheme == .dark ? 40 : 46)

            RadialGradient(
                colors: [
                    tone.opacity(colorScheme == .dark ? 0.18 : 0.13),
                    tone.opacity(colorScheme == .dark ? 0.1 : 0.07),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 240
            )
            .offset(x: 38, y: -72)
            .blur(radius: colorScheme == .dark ? 44 : 50)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 214, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .mask(
            LinearGradient(
                colors: [
                    .white,
                    .white.opacity(0.42),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }
}
