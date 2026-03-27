import SwiftUI

struct GradientGaugeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: Double
    let labels: [String]
    let valueText: String

    @State private var displayedValue = 0.0

    private let bubbleWidth: CGFloat = 58
    private let bubbleHeight: CGFloat = 32
    private let barHeight: CGFloat = 12
    private let indicatorSpacing: CGFloat = 7
    private let indicatorSize: CGFloat = 8

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.blue.opacity(colorScheme == .dark ? 0.78 : 0.62),
                Color.green.opacity(colorScheme == .dark ? 0.8 : 0.64),
                Color.orange.opacity(colorScheme == .dark ? 0.8 : 0.64),
                Color.red.opacity(colorScheme == .dark ? 0.78 : 0.62)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let indicatorX = indicatorPosition(in: width)

                ZStack(alignment: .topLeading) {
                    bar(width: width)
                        .offset(y: bubbleHeight + indicatorSpacing + 2)

                    VStack(spacing: indicatorSpacing) {
                        Text(valueText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: bubbleWidth, height: bubbleHeight)
                            .background(
                                colorScheme == .light
                                    ? AnyShapeStyle(Color.appBackground)
                                    : AnyShapeStyle(.ultraThinMaterial)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.1))
                            )
                            .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 10, y: 5)

                        Circle()
                            .fill(Color.appBackground.opacity(colorScheme == .dark ? 0.96 : 0.98))
                            .frame(width: indicatorSize, height: indicatorSize)
                            .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07), radius: 4, y: 2)
                    }
                    .offset(x: indicatorX - (bubbleWidth / 2))
                }
            }
            .frame(height: bubbleHeight + indicatorSpacing + indicatorSize + 18)

            HStack(alignment: .top, spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
        }
        .onAppear {
            displayedValue = 0
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.2)) {
                displayedValue = clampedValue
            }
        }
        .onChange(of: clampedValue) { _, newValue in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.2)) {
                displayedValue = newValue
            }
        }
    }

    @ViewBuilder
    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
            .fill(gradient)
            .frame(height: barHeight)
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    ForEach(1..<labels.count, id: \.self) { index in
                        Rectangle()
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.38 : 0.14))
                            .frame(width: 1, height: barHeight + 4)
                            .offset(x: (width * CGFloat(index) / CGFloat(labels.count)) - 0.5)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.08))
            }
            .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04), radius: 8, y: 3)
    }

    private func indicatorPosition(in width: CGFloat) -> CGFloat {
        let rawPosition = CGFloat(displayedValue) * width
        return min(max(rawPosition, bubbleWidth / 2), width - (bubbleWidth / 2))
    }
}
