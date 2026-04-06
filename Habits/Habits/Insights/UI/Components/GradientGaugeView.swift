import SwiftUI

struct GradientGaugeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: Double
    let labels: [String]

    @State private var displayedValue = 0.0
    @State private var isActiveMarker = false

    private let barHeight: CGFloat = 12
    private let indicatorSize: CGFloat = 10

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
                        .offset(y: indicatorSize + 6)

                    Circle()
                        .fill(Color.primary)
                        .frame(width: indicatorSize, height: indicatorSize)
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.white.opacity(colorScheme == .dark ? 0.9 : 0.7),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.2),
                            radius: 2,
                            y: 1
                        )
                        .scaleEffect(isActiveMarker ? 1.1 : 1.0)
                        .offset(x: indicatorX - (indicatorSize / 2))
                }
            }
            .frame(height: indicatorSize + barHeight + 14)

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
            isActiveMarker = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.2)) {
                displayedValue = clampedValue
                isActiveMarker = true
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
        return min(max(rawPosition, indicatorSize / 2), width - (indicatorSize / 2))
    }
}
