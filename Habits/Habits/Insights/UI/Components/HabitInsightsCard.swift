import SwiftUI

struct HabitInsightsCard<Content: View>: View {
    let content: Content
    let background: Color
    let padding: CGFloat

    init(
        background: Color = Color(.secondarySystemGroupedBackground),
        padding: CGFloat = 19,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
