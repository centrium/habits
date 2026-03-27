import SwiftUI

struct HabitInsightsPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    let backgroundStyle: AnyShapeStyle
    let padding: CGFloat

    init(
        background: Color = Color.appSecondaryGroupedBackground,
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
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
        )
        .overlay {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.06),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
            }
        }
        .shadow(
            color: colorScheme == .light ? Color.black.opacity(0.03) : Color.primary.opacity(0.08),
            radius: colorScheme == .light ? 6 : 12,
            y: colorScheme == .light ? 2 : 4
        )
    }
}
