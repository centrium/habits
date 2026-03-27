import SwiftUI

struct ProSwoosh: View {
    @Environment(\.colorScheme) private var colorScheme
    enum Size {
        case large
        case small
        case launch

        var width: CGFloat {
            switch self {
            case .large:
                return 60
            case .small:
                return 36
            case .launch:
                return 80
            }
        }

        var height: CGFloat {
            switch self {
            case .large:
                return 2.5
            case .small:
                return 2
            case .launch:
                return 4
            }
        }
    }

    let size: Size
    let toAnimate: Bool

    @State private var hasAnimated = false
    @State private var animationTask: Task<Void, Never>?
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
                Color.systemAccent.opacity(colorScheme == .light ? 0.82 : 0.9),
                Color.systemAccent.opacity(colorScheme == .light ? 0.22 : 0.3),
                Color.systemAccent.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: size.width, height: size.height)
        .scaleEffect(x: scaleX, y: 1, anchor: .leading)
        .opacity(opacity)
        .onAppear {
            resetForAnimationIfNeeded()
            scheduleAnimationIfNeeded()
        }
        .onChange(of: toAnimate) { _, _ in
            resetForAnimationIfNeeded()
            scheduleAnimationIfNeeded()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
        .onTapGesture {
            guard toAnimate else { return }
            animationTask?.cancel()
            scaleX = 0.08
            opacity = 0.35
            triggerAnimation()
        }
        .accessibilityHidden(true)
    }

    private func resetForAnimationIfNeeded() {
        guard toAnimate else {
            scaleX = 1
            opacity = 1
            return
        }

        guard !hasAnimated else { return }
        scaleX = 0.08
        opacity = 0.35
    }

    private func scheduleAnimationIfNeeded() {
        animationTask?.cancel()

        guard toAnimate, !hasAnimated else { return }

        animationTask = Task {
            await Task.yield()
            guard !Task.isCancelled else { return }

            await MainActor.run {
                hasAnimated = true
                triggerAnimation()
                animationTask = nil
            }
        }
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
        case launch

        var swooshSize: ProSwoosh.Size {
            switch self {
            case .large:
                return .large
            case .small:
                return .small
            case .launch:
                return .launch
            }
        }

        var titleFont: Font {
            switch self {
            case .large:
                return .system(size: 40, weight: .bold)
            case .small:
                return .system(size: 16, weight: .semibold)
            case .launch:
                return .system(size: 46, weight: .semibold)
            }
        }

        var proFont: Font {
            switch self {
            case .large:
                return .system(size: 14, weight: .semibold)
            case .small:
                return .system(size: 10, weight: .semibold)
            case .launch:
                return .system(size: 14, weight: .semibold)
            }
        }

        var proBaselineOffset: CGFloat {
            switch self {
            case .large:
                return 16
            case .small:
                return 7
            case .launch:
                return 18
            }
        }

        var spacing: CGFloat {
            switch self {
            case .large:
                return 8
            case .small:
                return 6
            case .launch:
                return 14
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
            if showsProLabel {
                ProSwoosh(size: size.swooshSize, toAnimate: animateSwoosh)
            }

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
            .foregroundStyle(.secondary.opacity(0.76))
            .kerning(-0.15)
            .baselineOffset(size.proBaselineOffset - (size == .large ? 1 : 0.5))

        return Text("\(title)\(pro)")
    }
}
