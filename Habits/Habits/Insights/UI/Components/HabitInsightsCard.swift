import SwiftUI

struct HabitInsightsPanel<Content: View>: View {
    let content: Content
    let padding: CGFloat

    init(
        padding: CGFloat = 22,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cadenceSurface(cornerRadius: 18)
    }
}
