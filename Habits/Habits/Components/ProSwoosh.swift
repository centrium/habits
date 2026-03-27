import SwiftUI

struct ProSwoosh: View {
    enum Size {
        case large
        case small

        var width: CGFloat {
            switch self {
            case .large:
                return 60
            case .small:
                return 36
            }
        }

        var height: CGFloat {
            switch self {
            case .large:
                return 2.5
            case .small:
                return 2
            }
        }
    }

    let size: Size
    let toAnimate: Bool

    @State private var hasAnimated = false
    @State private var scaleX: CGFloat
    @State private var opacity: Double

    init(size: Size = .large, toAnimate: Bool = false) {
        self.size = size
        self.toAnimate = toAnimate
        _scaleX = State(initialValue: toAnimate ? 0.08 : 1)
        _opacity = State(initialValue: toAnimate ? 0.35 : 1)
    }

    var body: some View {
        LinearGradient(
            colors: [
                Color.systemAccent.opacity(0.9),
                Color.systemAccent.opacity(0.3),
                Color.systemAccent.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: size.width, height: size.height)
        .scaleEffect(x: scaleX, y: 1, anchor: .leading)
        .opacity(opacity)
        .onAppear {
            guard toAnimate, !hasAnimated else { return }
            hasAnimated = true
            triggerAnimation()
        }
        .onTapGesture {
            guard toAnimate else { return }
            scaleX = 0.08
            opacity = 0.35
            triggerAnimation()
        }
        .accessibilityHidden(true)
    }

    private func triggerAnimation() {
        withAnimation(.easeOut(duration: 1.4)) {
            scaleX = 1
            opacity = 1
        }
    }
}

struct ProswooshView: View {
    var body: some View {
        ProSwoosh(size: .large)
    }
}

struct CadenceProWordmark: View {
    enum Size {
        case large
        case small

        var swooshSize: ProSwoosh.Size {
            switch self {
            case .large:
                return .large
            case .small:
                return .small
            }
        }

        var titleFont: Font {
            switch self {
            case .large:
                return .system(size: 40, weight: .bold)
            case .small:
                return .system(size: 16, weight: .semibold)
            }
        }

        var proFont: Font {
            switch self {
            case .large:
                return .system(size: 14, weight: .semibold)
            case .small:
                return .system(size: 10, weight: .semibold)
            }
        }

        var proBaselineOffset: CGFloat {
            switch self {
            case .large:
                return 16
            case .small:
                return 7
            }
        }

        var spacing: CGFloat {
            switch self {
            case .large:
                return 8
            case .small:
                return 6
            }
        }
    }

    let size: Size
    let animateSwoosh: Bool
    let showsProLabel: Bool

    init(size: Size = .large, animateSwoosh: Bool = false, showsProLabel: Bool = true) {
        self.size = size
        self.animateSwoosh = animateSwoosh
        self.showsProLabel = showsProLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size.spacing) {
            ProSwoosh(size: size.swooshSize, toAnimate: animateSwoosh)

            wordmarkText
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsProLabel ? "Cadence Pro" : "Cadence")
    }

    private var wordmarkText: Text {
        let title = Text("Cadence")
            .font(size.titleFont)
            .foregroundStyle(.primary)

        guard showsProLabel else { return title }

        let pro = Text(" Pro")
            .font(size.proFont)
            .foregroundStyle(.secondary.opacity(0.7))
            .baselineOffset(size.proBaselineOffset)

        return Text("\(title)\(pro)")
    }
}
