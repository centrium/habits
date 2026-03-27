import SwiftUI

enum AppMotion {
    static let press = Animation.spring(response: 0.2, dampingFraction: 0.84, blendDuration: 0.06)
    static let feedback = Animation.spring(response: 0.24, dampingFraction: 0.82, blendDuration: 0.08)
    static let quickFade = Animation.easeInOut(duration: 0.2)
    static let reveal = Animation.easeOut(duration: 0.22)
    static let reorder = Animation.spring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.08)
    static let monthSlide = Animation.spring(response: 0.26, dampingFraction: 0.9, blendDuration: 0.1)
}

enum AppSurfaceLevel {
    case standard
    case highlighted
    case floating
}

struct TactileButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
    }
}

private struct PressableCardFeedbackModifier: ViewModifier {
    let pressedScale: CGFloat
    let pressedOpacity: Double
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1)
            .opacity(isPressed ? pressedOpacity : 1)
            .animation(AppMotion.press, value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {}
            )
    }
}

private struct AppSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let level: AppSurfaceLevel
    let accent: Color?
    let tinted: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(backgroundShape)
    }

    private var backgroundShape: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .fill(fillColor)
            .overlay {
                if let strokeColor {
                    shape.stroke(strokeColor, lineWidth: 1)
                }
            }
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                y: shadowYOffset
            )
    }

    private var fillColor: Color {
        switch level {
        case .standard:
            return Color.appBackground
        case .highlighted:
            guard tinted, let accent else { return Color.appBackground }
            return accent.opacity(colorScheme == .light ? 0.06 : 0.08)
        case .floating:
            return accent ?? Color.appBackground
        }
    }

    private var strokeColor: Color? {
        switch level {
        case .standard:
            return colorScheme == .light ? Color.primary.opacity(0.08) : Color.white.opacity(0.06)
        case .highlighted:
            return (accent ?? Color.primary).opacity(0.15)
        case .floating:
            return nil
        }
    }

    private var shadowColor: Color {
        guard colorScheme == .light else { return .clear }

        switch level {
        case .standard:
            return Color.black.opacity(0.03)
        case .highlighted:
            return Color.black.opacity(0.045)
        case .floating:
            return Color.black.opacity(0.1)
        }
    }

    private var shadowRadius: CGFloat {
        switch level {
        case .standard:
            return colorScheme == .light ? 6 : 0
        case .highlighted:
            return colorScheme == .light ? 8 : 0
        case .floating:
            return colorScheme == .light ? 14 : 0
        }
    }

    private var shadowYOffset: CGFloat {
        switch level {
        case .standard:
            return colorScheme == .light ? 2 : 0
        case .highlighted:
            return colorScheme == .light ? 3 : 0
        case .floating:
            return colorScheme == .light ? 6 : 0
        }
    }
}

extension View {
    func pressableCardFeedback(
        scale: CGFloat = 0.97,
        opacity: Double = 0.96
    ) -> some View {
        modifier(
            PressableCardFeedbackModifier(
                pressedScale: scale,
                pressedOpacity: opacity
            )
        )
    }

    func appSurface(
        level: AppSurfaceLevel,
        accent: Color? = nil,
        tinted: Bool = false,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(
            AppSurfaceModifier(
                level: level,
                accent: accent,
                tinted: tinted,
                cornerRadius: cornerRadius
            )
        )
    }
}
