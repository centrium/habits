import SwiftUI

struct HabitInsightsPanel<Content: View>: View {
    let content: Content
    let backgroundStyle: AnyShapeStyle
    let padding: CGFloat

    init(
        background: Color = Color(.secondarySystemGroupedBackground),
        padding: CGFloat = 22,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundStyle = AnyShapeStyle(background)
        self.padding = padding
        self.content = content()
    }

    init(
        backgroundStyle: AnyShapeStyle,
        padding: CGFloat = 22,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundStyle = backgroundStyle
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.05))
        )
        .overlay {
            LinearGradient(
                colors: [.white.opacity(0.04), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(0.08),
            radius: 12,
            y: 4
        )
    }
}
